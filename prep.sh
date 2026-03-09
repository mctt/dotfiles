#!/bin/sh
# prep.sh - Prepare new jail for bootstrap
# Run this first before bootstrap.sh
# Usage: sh /mnt/unas/prep.sh

echo "============================================"
echo " Prep - New Jail Setup"
echo "============================================"
echo ""

# Set hostname
echo "Setting hostname to qnas..."
hostname qnas
echo 'hostname="qnas"' >> /etc/rc.conf

# Install bash first so bootstrap.sh can run
echo "Installing bash..."
pkg install -y bash

# Create ~/bin and ~/.ssh with correct permissions
mkdir -p ~/bin
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Copy and rename files
echo "Copying files from /mnt/unas..."
cp /mnt/unas/private_config.txt ~/.ssh/config
cp /mnt/unas/dot_gitconfig.txt ~/.gitconfig
cp /mnt/unas/github_personal ~/.ssh/github_personal
cp /mnt/unas/executable_bootstrap.txt ~/bin/bootstrap.sh

# Set correct permissions
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/github_personal
chmod 600 ~/.gitconfig
chmod 755 ~/bin/bootstrap.sh

echo ""
echo "Files copied:"
ls -la ~/.ssh/
ls -la ~/.gitconfig
ls -la ~/bin/bootstrap.sh

echo ""
echo "Done. Now run:"
echo "  bash ~/bin/bootstrap.sh"