fzf

Ctrl+R — History search
This replaces the default history search completely. Instead of cycling through matches one at a time, you get a full interactive list of your history that you fuzzy-filter in real time. Type fragments of any part of the command, not just the beginning. This alone is worth installing fzf for.
Ctrl+T — File search
Pastes a file path into your command line at the cursor position. You start typing a filename and it searches recursively from the current directory. So vim [Ctrl+T] lets you fuzzy-find any file to open.
Alt+C — Directory jump
Fuzzy-find a subdirectory and cd into it immediately.

So hostname returns test13 on unas, not unas. Check qnas too:
hostname
On qnas. Then we can set the case statement to match the actual hostnames. Alternatively, if you want friendlier names you can set them:
# On unas
hostname unas

# On qnas  
hostname qnas
To make it permanent on FreeBSD add to /etc/rc.conf:
echo 'hostname="unas"' >> /etc/rc.conf
