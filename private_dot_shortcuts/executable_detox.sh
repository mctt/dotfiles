# done use bin/bash because the widget wont.
# works fine detox -prl ~/storage/downloads/synco/*
detox -prlt ~/storage/downloads/synco/*
# wrong version detox -r -s utf_8 -s safe ~/storage/downloads/synco/*
#fdupes -rdm ~/storage/downloads/synco/*

# https://askubuntu.com/questions/177346/how-to-delete-duplicate-files-with-fdupes
# fdupes -rdN dir/

# r - recursive
# d - preserver first file, delete other dupes
# N - run silently (no prompt)

echo "touch synco"
touch ~/storage/downloads/synco

echo "touch Instagram"
touch ~/storage/shared/Instagram

echo "touch Instander"
touch ~/storage/shared/Pictures/Instander

echo "touch downloads"
touch ~/storage/downloads

echo "detoxed synco"
sleep 1
echo -e '\a' #vibrate

# detox help
# -p print output
# -r recursive
# -l keep leading _
# -t keep trailing _

# fdupes help
# https://claude.ai/share/f7a7f5dd-0101-44d4-b610-e811b0757412
# -r recursive
# -S size
# -d delete, so actually delete.
# -m summurise
