#!/bin/bash
# https://claude.ai/share/256f15e2-cd71-409e-9270-7bef52dfbffa
# chezmoi add ~/.bashrc

# this keeps making subshells unless you add exit
#chezmoi cd
#git add .
#git commit -m "update from $(hostname)"
#git push
#exit

#testing with the chezmoi git command
#!/bin/bash
chezmoi git add .
chezmoi git commit -- -m "update from $(hostname)"
chezmoi git push
# and no need for exit because not subshell is created

