#!/data/data/com.termux/files/usr/bin/bash

# Push Termux dotfiles to GitHub
# Only adds/commits Termux-specific files - never uses chezmoi re-add
# which would wipe unas files from the repo

TERMUX_FILES=(
    "bin/executable_gdl"
    "bin/executable_termux-url-opener"
    "bin/executable_push.chezmoi_to_git_termux.sh"
    "private_dot_bashrc.termux"
)

echo "Syncing Termux dotfiles to GitHub..."
echo ""

# Check if running on Termux
if [ ! -d "/data/data/com.termux" ]; then
    echo "Error: This script is for Termux only."
    exit 1
fi

# Pull latest from remote first
echo "Pulling latest from GitHub..."
cd ~/.local/share/chezmoi
git stash
git pull --rebase origin master
git stash pop 2>/dev/null || true

# Add only Termux-specific files from local filesystem
echo "Re-adding Termux dotfiles..."
chezmoi add ~/bin/gdl
chezmoi add ~/bin/termux-url-opener
chezmoi add ~/bin/push.chezmoi_to_git_termux.sh
chezmoi add ~/.bashrc.termux

echo ""
echo "Committing and pushing to GitHub..."

# Stage only Termux files explicitly - never git add .
for f in "${TERMUX_FILES[@]}"; do
    chezmoi git add -- "$f"
done

chezmoi git commit -- -m "update from termux - $(date '+%Y-%m-%d %H:%M:%S')"
chezmoi git push

echo ""
echo "Done! Termux dotfiles pushed to GitHub"
echo ""
echo "To pull on other machines: chezmoi update"
