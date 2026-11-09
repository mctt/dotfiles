#!/data/data/com.termux/files/usr/bin/bash

# Push Termux dotfiles to GitHub
# Only manages Termux-specific files - does not touch unas files

echo "Syncing Termux dotfiles to GitHub..."
echo ""

# Check if running on Termux
if [ ! -d "/data/data/com.termux" ]; then
    echo "Error: This script is for Termux only."
    exit 1
fi

# Make sure the remote uses SSH (HTTPS password auth no longer works)
REMOTE_URL="git@github.com:mctt/dotfiles.git"
CURRENT_URL=$(chezmoi git -- remote get-url origin 2>/dev/null)
if [ "$CURRENT_URL" != "$REMOTE_URL" ]; then
    echo "Switching origin to SSH..."
    chezmoi git -- remote set-url origin "$REMOTE_URL"
fi

# Pull latest from remote first to avoid divergence
echo "Pulling latest from GitHub..."
chezmoi git stash
chezmoi git pull -- --rebase || { echo "Pull failed - aborting."; exit 1; }
chezmoi git stash pop

echo "Re-adding tracked Termux dotfiles..."
chezmoi re-add

echo ""
echo "Committing and pushing to GitHub..."

chezmoi git add .
chezmoi git commit -- -m "update from termux - $(date '+%Y-%m-%d %H:%M:%S')"
chezmoi git push || { echo "Push failed."; exit 1; }

echo ""
echo "Done! Termux dotfiles pushed to GitHub"
echo ""
echo "To pull on other machines: chezmoi update"
