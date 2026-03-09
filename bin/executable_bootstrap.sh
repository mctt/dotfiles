#!/bin/bash
# Bootstrap a new FreeBSD jail

echo "============================================"
echo " Bootstrap - FreeBSD Jail Setup"
echo "============================================"
echo ""
echo "Pre-requisites:"
echo "  1. Copy ~/.ssh/github_personal to this jail"
echo "  2. https://github.com/mctt/dotfiles/tree/master/private_dot_ssh"
echo "  3. Copy ~/.gitconfig to this jail"
echo "  4. https://github.com/mctt/dotfiles/blob/master/dot_gitconfig"
echo ""

# Test required files exist before proceeding
ERRORS=0

if [ ! -f ~/.ssh/github_personal ]; then
  echo "ERROR: ~/.ssh/github_personal not found"
  ERRORS=$((ERRORS + 1))
fi

if [ ! -f ~/.gitconfig ]; then
  echo "ERROR: ~/.gitconfig not found"
  ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "Fix the above errors then re-run this script."
  exit 1
fi

echo "All pre-requisites found."
echo ""
read -p "Proceed with bootstrap on $(hostname)? [y/N] " confirm
[[ "$confirm" == [yY] ]] || exit 1
echo ""

# Minimum requirements first
echo "Installing core packages..."
pkg install -y chezmoi git nano screen

# SSH setup
echo "Testing GitHub SSH connection..."
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/github_personal
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" && \
  echo "GitHub SSH OK" || { echo "ERROR: GitHub SSH failed"; exit 1; }

# Pull and apply dotfiles
echo "Applying dotfiles..."
chezmoi init --apply git@github.com:mctt/dotfiles.git

# Additional packages
echo "Installing additional packages..."
pkg install -y sqlite3 python3 bash-completion eza

# Install fzf from GitHub (includes keyboard shortcuts and shell integration)
echo "Installing fzf..."
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --all

# Install detox from GitHub
echo "Installing detox..."
git clone https://github.com/Alyetama/detox.git ~/detox
cd ~/detox
pip install -e . --break-system-packages
cd ~

echo ""
echo "Bootstrap complete. Run 'source ~/.bashrc' to apply dotfiles."
