#!/bin/bash

# Check if a search term was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <search_term>"
    echo "Example: $0 paola"
    exit 1
fi

# Set the search term from the first argument
SEARCH_TERM="$1"

# Create the destination directory if it doesn't exist
DEST_DIR="/mnt/unas/_crap/tmp"
mkdir -p "$DEST_DIR"

echo "Searching for folders matching '*${SEARCH_TERM}*'..."

# Find all matching directories
mapfile -t FOLDERS < <(find /mnt/unas/p/ -type d -iname "*${SEARCH_TERM}*")

# Check if any folders were found
if [ ${#FOLDERS[@]} -eq 0 ]; then
    echo "No folders found matching '*${SEARCH_TERM}*'"
    exit 0
fi

echo "Found ${#FOLDERS[@]} matching folder(s):"
printf '  %s\n' "${FOLDERS[@]}"
echo ""

# Copy all video files from matching folders while preserving structure
for folder in "${FOLDERS[@]}"; do
    echo "Processing: $folder"
    folder_name=$(basename "$folder")
    
    # Copy the entire folder with only video files
    rsync -a --append-verify --progress \
        --include="*/" \
        --include="*.mp4" --include="*.MP4" \
        --include="*.mkv" --include="*.MKV" \
        --include="*.avi" --include="*.AVI" \
        --include="*.mov" --include="*.MOV" \
        --include="*.wmv" --include="*.WMV" \
        --include="*.flv" --include="*.FLV" \
        --include="*.webm" --include="*.WEBM" \
        --include="*.m4v" --include="*.M4V" \
        --include="*.mpg" --include="*.MPG" \
        --include="*.mpeg" --include="*.MPEG" \
        --exclude="*" \
        "$folder/" "$DEST_DIR/$folder_name/"
done

echo ""
echo "Running detox to clean up file and folder names..."
detox -r "$DEST_DIR"

echo ""
echo "Done! All video files from folders matching '*${SEARCH_TERM}*' have been copied to $DEST_DIR/ with folder structure preserved and names cleaned"