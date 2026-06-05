#!/bin/bash

# Find the next available folder number
BASE="/storage/emulated/0/Download/synco"
NUM=785
while [ -d "$BASE/New folder$NUM" ]; do
    NUM=$((NUM + 1))
done

DEST="$BASE/New folder$NUM"
mkdir -p "$DEST"

echo "Destination: $DEST"
echo ""

# Move files
COUNT=0
for file in /storage/emulated/0/Download/EPO*; do
    if [ -f "$file" ]; then
        echo "Moving: $(basename "$file")"
        mv "$file" "$DEST/"
        COUNT=$((COUNT + 1))
    fi
done

echo ""
echo "Moved $COUNT file(s) to $DEST"
