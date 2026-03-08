#!/bin/bash

# Check if at least one search term was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <search_term1> [search_term2] [search_term3] ..."
    echo "Example: $0 paola lana"
    echo "Note: ALL search terms must be present in the folder/file name"
    exit 1
fi

# Configuration
DB_FILE="/mnt/unas/p/video_index.db"
DEST_DIR="/mnt/unas/_crap/tmp"

# Check if database exists
if [ ! -f "$DB_FILE" ]; then
    echo "ERROR: Database not found: $DB_FILE"
    echo "Please run create-index-db.sh first to create the index"
    exit 1
fi

mkdir -p "$DEST_DIR"

# Store all search terms
SEARCH_TERMS=("$@")

echo "Searching database for items containing ALL of: ${SEARCH_TERMS[*]}"
echo ""

# Build SQL WHERE clause for all terms (case-insensitive)
WHERE_CLAUSE=""
for term in "${SEARCH_TERMS[@]}"; do
    # Escape single quotes in search term
    term_escaped=$(echo "$term" | sed "s/'/''/g")
    
    if [ -z "$WHERE_CLAUSE" ]; then
        WHERE_CLAUSE="name LIKE '%$term_escaped%'"
    else
        WHERE_CLAUSE="$WHERE_CLAUSE AND name LIKE '%$term_escaped%'"
    fi
done

# Search folders (only active items)
echo "Querying folders..."
declare -a FOLDERS
while IFS= read -r path; do
    FOLDERS+=("$path")
done < <(sqlite3 "$DB_FILE" "SELECT path FROM items WHERE type='FOLDER' AND status='active' AND ($WHERE_CLAUSE);")

# Search files (only active items)
echo "Querying files..."
declare -a FILES
while IFS= read -r path; do
    FILES+=("$path")
done < <(sqlite3 "$DB_FILE" "SELECT path FROM items WHERE type='FILE' AND status='active' AND ($WHERE_CLAUSE);")

# Check if anything was found
if [ ${#FOLDERS[@]} -eq 0 ] && [ ${#FILES[@]} -eq 0 ]; then
    echo "No folders or files found containing ALL of: ${SEARCH_TERMS[*]}"
    exit 0
fi

echo ""
echo "Found ${#FOLDERS[@]} matching folder(s) and ${#FILES[@]} matching file(s)"

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
        # Check if folder still exists
        if [ ! -d "$folder" ]; then
            echo "WARNING: Folder no longer exists: $folder (run create-index-db.sh to update)"
            continue
        fi
        
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
        # Check if file still exists
        if [ ! -f "$file" ]; then
            echo "WARNING: File no longer exists: $file (run create-index-db.sh to update)"
            continue
        fi
        
        # Get the parent directory name to preserve some context
        parent_dir=$(basename "$(dirname "$file")")
        
        # Create a subdirectory for files found by filename
        mkdir -p "$DEST_DIR/_matched_files/$parent_dir"
        
        echo "Copying file: $file"
        rsync -a --append-verify --progress "$file" "$DEST_DIR/_matched_files/$parent_dir/"
    done
    echo ""
fi

echo "notRunning detox to clean up file and folder names..."
#detox -r "$DEST_DIR"

echo ""
echo "========================================="
echo "Done! All matching content has been copied to $DEST_DIR/"
echo "  - Folders copied with full structure"
echo "  - Individual files copied to $DEST_DIR/_matched_files/ organized by parent folder"
echo "========================================="
