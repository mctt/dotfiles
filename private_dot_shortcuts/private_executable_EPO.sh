#!/bin/bash

BASE="/storage/emulated/0/Download/synco"

# Find highest existing New_folder number
HIGHEST=0
for dir in "$BASE"/New_folder*/; do
    if [ -d "$dir" ]; then
        NUM=$(basename "$dir" | grep -o '[0-9]*$')
        if [ -n "$NUM" ] && [ "$NUM" -gt "$HIGHEST" ]; then
            HIGHEST=$NUM
        fi
    fi
done

NEXT=$((HIGHEST + 1))
DEST="$BASE/New folder$NEXT"
mkdir -p "$DEST"

echo "Destination: $DEST"
echo ""

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
