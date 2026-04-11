#!/bin/bash
# https://claude.ai/share/256f15e2-cd71-409e-9270-7bef52dfbffa

# NOTE: chezmoi re-add syncs ALL tracked files from local filesystem to chezmoi
# This makes local files the "master" - no need to run chezmoi add after each edit

echo "Syncing local dotfiles to GitHub..."
echo ""

# Check if running on unas
if [ "$(hostname)" != "unas" ]; then
  read -p "Warning: This is not unas (hostname: $(hostname)). Are you sure? [y/N] " confirm
  [[ "$confirm" == [yY] ]] || exit 1
fi

# Re-add all tracked dotfiles from local filesystem (local = master)
echo "Re-adding all tracked dotfiles from local filesystem..."
chezmoi re-add

# Apply is needed for the /tmp edits
chezmoi apply

echo ""
echo "Committing and pushing to GitHub..."

# Using chezmoi git commands (no subshell created)
chezmoi git add .
chezmoi git commit -- -m "update from $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
chezmoi git pull -- --rebase
chezmoi git push

echo ""
echo "✓ Done! Local changes pushed to GitHub"
echo ""
echo "To pull on other machines: chezmoi update"
