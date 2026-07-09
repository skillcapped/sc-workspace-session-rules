#!/usr/bin/env bash
# sc-start.sh — daily startup: confirm profile, sync git, start the app.
# Canonical copy lives in the sc-workspace-session-rules repo.
# Edit here and push; machines fetch the latest via the sc-start launcher.
set -u

SUPPORT="[#support-channel]"

# --- Must be inside a project ---
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "I'm not inside a project folder. Open your project first, then run startup again."
  exit 1
fi
cd "$REPO_ROOT" || exit 1

# --- Read the contributor profile ---
CONFIG="$REPO_ROOT/.contributor.json"
if [ ! -f "$CONFIG" ]; then
  echo "You don't have a contributor profile yet."
  echo "Ask me: \"set up my contributor profile\" -- I'll create it, then run startup again."
  exit 1
fi

ID="$(node -e "try{const j=JSON.parse(require('fs').readFileSync('.contributor.json','utf8'));process.stdout.write(String(j.id||''))}catch(e){}" 2>/dev/null)"
ROLE="$(node -e "try{const j=JSON.parse(require('fs').readFileSync('.contributor.json','utf8'));process.stdout.write(String(j.role||''))}catch(e){}" 2>/dev/null)"

if [ -z "$ID" ] || [ -z "$ROLE" ]; then
  echo "Your contributor profile is incomplete."
  echo "Ask me: \"fix my contributor profile\" -- I'll sort it out, then run startup again."
  exit 1
fi

echo "Hi ${ID}! You're set up as: ${ROLE}."

# --- Content users must be on their own branch (= id, lowercased), never main ---
if [ "$ROLE" = "content" ]; then
  BRANCH="$(echo "$ID" | tr '[:upper:]' '[:lower:]')"
  CURRENT="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ "$CURRENT" != "$BRANCH" ]; then
    if [ -n "$(git status --porcelain)" ]; then
      echo "You have unsaved changes on '${CURRENT}', so I won't switch automatically."
      echo "Ask me to save your work first, then run startup again."
      exit 1
    fi
    if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
      git checkout "$BRANCH" >/dev/null 2>&1
    elif git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
      git checkout -t "origin/${BRANCH}" >/dev/null 2>&1
    else
      git checkout main >/dev/null 2>&1
      git checkout -b "$BRANCH" >/dev/null 2>&1
      echo "Created your workspace branch '${BRANCH}'."
    fi
    echo "You're on your own workspace (${BRANCH})."
  else
    echo "You're on your own workspace (${BRANCH})."
  fi
fi

# --- Pull latest for the current branch ---
echo "Getting the latest version..."
if git pull --ff-only >/dev/null 2>&1; then
  echo "Up to date."
else
  echo "Couldn't auto-update (usually fine). If something looks off, ping ${SUPPORT}."
fi

# --- Start the app (reuses the start-app helper) ---
echo "Starting the app..."
start-app