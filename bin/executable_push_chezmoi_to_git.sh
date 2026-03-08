#!/bin/bash
# https://claude.ai/share/256f15e2-cd71-409e-9270-7bef52dfbffa
# chezmoi add ~/.bashrc

# this keeps making subshells unless you add exit
#chezmoi cd
#git add .
#git commit -m "update from $(hostname)"
#git push
#exit

# note: chezmoi update downloads from GitHub AND apply(s)
echo "use chezmoi update to download from GutHub"

# Check if running on unas
if [ "$(hostname)" != "unas" ]; then
  read -p "Warning: This is not unas (hostname: $(hostname)). Are you sure? [y/N] " confirm
  [[ "$confirm" == [yY] ]] || exit 1
fi

#testing with the chezmoi git command
chezmoi git add .
chezmoi git commit -- -m "update from $(hostname)"
chezmoi git push
# and no need for exit because not subshell is created

