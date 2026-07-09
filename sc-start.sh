#!/usr/bin/env bash
# sc-start.sh — daily startup: confirm profile, sync git, ALWAYS start the app.
# Canonical copy lives in the sc-workspace-session-rules repo.
# Edit here and push; machines fetch the latest via the sc-start launcher.
set -u

SUPPORT="the dev team"

# Workspace branch convention for content users: "<id>-main" (lowercased).

# git setup never aborts the script — the app always starts at the end.
run_git_setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$REPO_ROOT" ]; then
    echo "(Not inside a project folder, so skipping git setup.)"
    return
  fi
  cd "$REPO_ROOT" || return

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

  # Developers: just sync current branch, no workspace management.
  if [ "$ROLE" != "content" ]; then
    sync_branch
    return
  fi

  # --- Content users: ensure they're on their own workspace branch "<id>-main" ---
  local key branch current
  key="$(echo "$ID" | tr '[:upper:]' '[:lower:]')"
  branch="${key}-main"
  current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [ "$current" = "$branch" ]; then
    echo "You're on your own workspace (${branch})."
    sync_branch
    return
  fi

  # Don't move if there are unsaved changes.
  if [ -n "$(git status --porcelain)" ]; then
    echo "You have unsaved changes on '${current}', so I won't switch workspaces automatically."
    echo "Ask me to save your work first, then run startup again."
    return
  fi

  if git show-ref --verify --quiet "refs/heads/${branch}"; then
    # Local branch exists
    git checkout "$branch" >/dev/null 2>&1
    echo "You're on your own workspace (${branch})."
  elif git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    # Exists on the remote — check it out tracking origin
    git checkout -t "origin/${branch}" >/dev/null 2>&1
    echo "You're on your own workspace (${branch})."
  else
    # Doesn't exist anywhere — create from main and publish it
    git checkout main >/dev/null 2>&1
    git checkout -b "$branch" >/dev/null 2>&1
    if git push -u origin "$branch" >/dev/null 2>&1; then
      echo "Created and saved your workspace (${branch}) to the cloud."
    else
      echo "Created your workspace (${branch}), but couldn't save it to the cloud yet."
      echo "It's safe on this machine for now. If it keeps happening, contact ${SUPPORT}."
    fi
  fi

  sync_branch
}

# Pull latest, and make sure the branch is published (has an upstream).
sync_branch() {
  local branch upstream
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)"

  if [ -z "$upstream" ]; then
    # No upstream yet: publish rather than warn about a failed pull.
    if git push -u origin "$branch" >/dev/null 2>&1; then
      echo "Saved your workspace to the cloud."
    fi
    # If the push fails (e.g. offline), stay quiet — nothing is broken locally.
    return
  fi

  echo "Getting the latest version..."
  if git pull --ff-only >/dev/null 2>&1; then
    echo "Up to date."
  else
    echo "Couldn't auto-update just now. That's usually fine — if anything looks off, contact ${SUPPORT}."
  fi
}

# ---- run git setup (never fatal), then ALWAYS start the app ----
run_git_setup
echo "Starting the app..."
start-app