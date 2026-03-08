#!/bin/bash
#CTRL+z stops rsync
# Check if at least one search term was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <search_term1> [search_term2] [search_term3] ..."
    echo "Example: $0 paola lana"
    echo "Note: ALL search terms must be present in the folder/file name"
    exit 1
fi

# Create the destination directory if it doesn't exist
DEST_DIR="/mnt/unas/_crap/tmp"
mkdir -p "$DEST_DIR"

# Store all search terms
SEARCH_TERMS=("$@")

echo "Searching for folders and files that contain ALL of: ${SEARCH_TERMS[*]}"
echo ""

# Array to store all unique matching folders
declare -A UNIQUE_FOLDERS
# Array to store all unique matching video files
declare -A UNIQUE_FILES

# Function to check if a name contains all search terms (case-insensitive)
contains_all_terms() {
    local name=$(basename "$1" | tr '[:upper:]' '[:lower:]')
    for term in "${SEARCH_TERMS[@]}"; do
        local term_lower=$(echo "$term" | tr '[:upper:]' '[:lower:]')
        if [[ ! "$name" =~ $term_lower ]]; then
            return 1
        fi
    done
    return 0
}

echo "Searching folders..."
# Find all directories and filter for those containing all terms
while IFS= read -r folder; do
    if contains_all_terms "$folder"; then
        UNIQUE_FOLDERS["$folder"]=1
    fi
done < <(find /mnt/unas/p/ -type d)

echo "Searching video files..."
# Find all video files and filter for those containing all terms
while IFS= read -r file; do
    if contains_all_terms "$file"; then
        UNIQUE_FILES["$file"]=1
    fi
done < <(find /mnt/unas/p/ -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.mpg" -o -iname "*.mpeg" \))

# Convert associative array keys to regular arrays
FOLDERS=("${!UNIQUE_FOLDERS[@]}")
FILES=("${!UNIQUE_FILES[@]}")

# Check if anything was found
if [ ${#FOLDERS[@]} -eq 0 ] && [ ${#FILES[@]} -eq 0 ]; then
    echo "No folders or files found containing ALL of the search terms: ${SEARCH_TERMS[*]}"
    exit 0
fi

echo ""
echo "Found ${#FOLDERS[@]} unique matching folder(s) and ${#FILES[@]} unique matching file(s)"

if [ ${#FOLDERS[@]} -gt 0 ]; then
    echo ""
    echo "Matching folders:"
    printf '  %s\n' "${FOLDERS[@]}"
fi

if [ ${#FILES[@]} -gt 0 ]; then
    echo ""
    echo "Matching files:"
    printf '  %s\n' "${FILES[@]}"
fi

echo ""

# Copy all video files from matching folders while preserving structure
if [ ${#FOLDERS[@]} -gt 0 ]; then
    echo "Copying contents of matching folders..."
    for folder in "${FOLDERS[@]}"; do
        echo "Processing folder: $folder"
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
fi

# Copy individual matching files
if [ ${#FILES[@]} -gt 0 ]; then
    echo "Copying individual matching files..."
    for file in "${FILES[@]}"; do
        # Get the parent directory name to preserve some context
        parent_dir=$(basename "$(dirname "$file")")
        file_name=$(basename "$file")
        
        # Create a subdirectory for files found by filename
        mkdir -p "$DEST_DIR/_matched_files/$parent_dir"
        
        echo "Copying file: $file"
        rsync -a --append-verify --progress "$file" "$DEST_DIR/_matched_files/$parent_dir/"
    done
    echo ""
fi

echo "skipping detox to clean up file and folder names..."
#detox -r "$DEST_DIR"

echo ""
echo "Done! All matching content has been copied to $DEST_DIR/"
echo "  - Folders copied with full structure"
echo "  - Individual files copied to $DEST_DIR/_matched_files/ organized by parent folder"