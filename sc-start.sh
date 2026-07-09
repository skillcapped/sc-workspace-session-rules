#!/usr/bin/env bash
# sc-start.sh — daily startup: confirm profile, sync git, ALWAYS start the app.
# Canonical copy lives in the sc-workspace-session-rules repo.
# Edit here and push; machines fetch the latest via the sc-start launcher.
set -u

SUPPORT="[#support-channel]"

# start_app is called at the very end no matter what happens above.
# Guard cases below "return" out of the git section instead of exiting,
# so the app always starts.

run_git_setup() {
  # --- Must be inside a project ---
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$REPO_ROOT" ]; then
    echo "(Not inside a project folder, so skipping git setup.)"
    return
  fi
  cd "$REPO_ROOT" || return

  # --- Read the contributor profile ---
  if [ ! -f "$REPO_ROOT/.contributor.json" ]; then
    echo "You don't have a contributor profile yet."
    echo "Ask me: \"set up my contributor profile\" -- I'll create it, then run startup again."
    return
  fi

  ID="$(node -e "try{const j=JSON.parse(require('fs').readFileSync('.contributor.json','utf8'));process.stdout.write(String(j.id||''))}catch(e){}" 2>/dev/null)"
  ROLE="$(node -e "try{const j=JSON.parse(require('fs').readFileSync('.contributor.json','utf8'));process.stdout.write(String(j.role||''))}catch(e){}" 2>/dev/null)"

  if [ -z "$ID" ] || [ -z "$ROLE" ]; then
    echo "Your contributor profile is incomplete."
    echo "Ask me: \"fix my contributor profile\" -- I'll sort it out, then run startup again."
    return
  fi

  echo "Hi ${ID}! You're set up as: ${ROLE}."

  # Developers: just pull current branch, no branch management.
  if [ "$ROLE" != "content" ]; then
    pull_latest
    return
  fi

  # --- Content users: make sure they're on their own workspace branch ---
  local key current
  key="$(echo "$ID" | tr '[:upper:]' '[:lower:]')"
  current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  # Already on a branch that belongs to them? Leave it.
  if branch_belongs "$current" "$key"; then
    echo "You're on your own workspace (${current})."
    pull_latest
    return
  fi

  # Don't move if there are unsaved changes.
  if [ -n "$(git status --porcelain)" ]; then
    echo "You have unsaved changes on '${current}', so I won't switch workspaces automatically."
    echo "Ask me to save your work first, then run startup again."
    return
  fi

  # Find candidate branches (local + remote) that look like theirs.
  local matches
  matches="$(list_matching_branches "$key")"
  local count
  count="$(printf '%s\n' "$matches" | grep -c . )"

  if [ "$count" -eq 1 ]; then
    git checkout "$matches" >/dev/null 2>&1
    echo "You're on your own workspace (${matches})."
    pull_latest
  elif [ "$count" -gt 1 ]; then
    echo "I found more than one workspace that could be yours:"
    printf '  - %s\n' $matches
    echo "Which one do you want to use? (tell me the name) -- I won't switch or create anything until you say."
  else
    echo "I couldn't find an existing workspace branch for '${ID}'."
    echo "Want me to create a new one named '${key}' from main? (yes/no) -- I won't create it until you confirm."
  fi
}

# A branch "belongs" to the user if it equals the key or starts with "key-" / "key/".
branch_belongs() {
  local b="$1" key="$2"
  [ "$b" = "$key" ] || [ "${b#${key}-}" != "$b" ] || [ "${b#${key}/}" != "$b" ]
}

# List local + remote branches matching the user's key, de-duplicated, remotes stripped of "origin/".
list_matching_branches() {
  local key="$1"
  {
    git for-each-ref --format='%(refname:short)' refs/heads/
    git for-each-ref --format='%(refname:short)' refs/remotes/origin/ | sed 's#^origin/##'
  } 2>/dev/null \
    | grep -vi '^HEAD$' \
    | awk -v k="$key" 'tolower($0)==k || index(tolower($0), k"-")==1 || index(tolower($0), k"/")==1' \
    | sort -u
}

pull_latest() {
  echo "Getting the latest version..."
  if git pull --ff-only >/dev/null 2>&1; then
    echo "Up to date."
  else
    echo "Couldn't auto-update (usually fine). If something looks off, ping ${SUPPORT}."
  fi
}

# ---- run git setup (never fatal), then ALWAYS start the app ----
run_git_setup
echo "Starting the app..."
start-app