#!/bin/bash

# Parse options
AUTO_YES=false
SEARCH_TERMS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-y] <search_term1> [search_term2] [search_term3] ..."
            echo ""
            echo "Options:"
            echo "  -y, --yes    Skip confirmation prompt and proceed automatically"
            echo "  -h, --help   Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 paola lana              # Search and ask for confirmation"
            echo "  $0 -y paola lana           # Search and copy automatically"
            echo ""
            echo "Note: ALL search terms must be present in the folder/file name"
            exit 0
            ;;
        *)
            SEARCH_TERMS+=("$1")
            shift
            ;;
    esac
done

# Check if at least one search term was provided
if [ ${#SEARCH_TERMS[@]} -eq 0 ]; then
    echo "Usage: $0 [-y] <search_term1> [search_term2] [search_term3] ..."
    echo "Use -h or --help for more information"
    exit 1
fi

# Configuration
DB_FILE="/mnt/unas/p/video_index.db"

# Build destination folder name from search terms
SEARCH_FOLDER=$(IFS="_"; echo "${SEARCH_TERMS[*]}" | tr '[:upper:]' '[:lower:]')
DEST_DIR="/mnt/unas/_crap/${SEARCH_FOLDER}"

# Check if database exists
if [ ! -f "$DB_FILE" ]; then
    echo "ERROR: Database not found: $DB_FILE"
    echo "Please run ultimate-index-update.sh first to create the index"
    exit 1
fi

mkdir -p "$DEST_DIR"

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
declare -a FILE_SIZES
while IFS='|' read -r path size; do
    FILES+=("$path")
    FILE_SIZES+=("$size")
done < <(sqlite3 -separator '|' "$DB_FILE" "SELECT path, COALESCE(size, 0) FROM items WHERE type='FILE' AND status='active' AND ($WHERE_CLAUSE);")

# Check if anything was found
if [ ${#FOLDERS[@]} -eq 0 ] && [ ${#FILES[@]} -eq 0 ]; then
    echo "No folders or files found containing ALL of: ${SEARCH_TERMS[*]}"
    exit 0
fi

echo ""
echo "Found ${#FOLDERS[@]} matching folder(s) and ${#FILES[@]} matching file(s)"

# Calculate sizes for folders
declare -a FOLDER_SIZES
total_folder_size=0

if [ ${#FOLDERS[@]} -gt 0 ]; then
    echo ""
    echo "Calculating folder sizes..."
    for folder in "${FOLDERS[@]}"; do
        folder_escaped=$(echo "$folder" | sed "s/'/''/g")
        folder_size=$(sqlite3 "$DB_FILE" "SELECT COALESCE(SUM(size), 0) FROM items WHERE type='FILE' AND status='active' AND parent_path LIKE '$folder_escaped%';")
        FOLDER_SIZES+=("$folder_size")
        total_folder_size=$((total_folder_size + folder_size))
    done
fi

# Calculate total size of individual files
total_file_size=0
for size in "${FILE_SIZES[@]}"; do
    total_file_size=$((total_file_size + size))
done

# Grand total to transfer
grand_total_size=$((total_folder_size + total_file_size))

# Convert bytes to human readable
human_readable_size() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes} B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}") KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}") MB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}") GB"
    fi
}

# Show what will be transferred
echo ""
echo "========================================"
echo "TRANSFER SUMMARY"
echo "========================================"

if [ ${#FOLDERS[@]} -gt 0 ]; then
    echo ""
    echo "Matching folders (${#FOLDERS[@]}):"
    for i in "${!FOLDERS[@]}"; do
        printf '  %s [%s]\n' "${FOLDERS[$i]}" "$(human_readable_size ${FOLDER_SIZES[$i]})"
    done
    echo "  Subtotal: $(human_readable_size $total_folder_size)"
fi

if [ ${#FILES[@]} -gt 0 ]; then
    echo ""
    echo "Matching files (${#FILES[@]}):"
    for i in "${!FILES[@]}"; do
        printf '  %s [%s]\n' "${FILES[$i]}" "$(human_readable_size ${FILE_SIZES[$i]})"
    done
    echo "  Subtotal: $(human_readable_size $total_file_size)"
fi

echo ""
echo "========================================"
echo "TOTAL TO TRANSFER:"

# Calculate total file count
total_file_count=${#FILES[@]}

if [ ${#FOLDERS[@]} -gt 0 ]; then
    # Build WHERE clause for folder files
    folder_where=""
    for folder in "${FOLDERS[@]}"; do
        folder_escaped=$(echo "$folder" | sed "s/'/''/g")
        if [ -z "$folder_where" ]; then
            folder_where="parent_path LIKE '$folder_escaped%'"
        else
            folder_where="$folder_where OR parent_path LIKE '$folder_escaped%'"
        fi
    done
    
    folder_file_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM items WHERE type='FILE' AND status='active' AND ($folder_where);")
    total_file_count=$((total_file_count + folder_file_count))
fi

echo "  Files: $total_file_count"
echo "  Size:  $(human_readable_size $grand_total_size)"
echo "========================================"
echo ""

# Ask for confirmation (unless -y flag was used)
if [ "$AUTO_YES" = false ]; then
    read -p "Proceed with transfer? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Transfer cancelled."
        exit 0
    fi
else
    echo "Auto-confirm enabled (-y flag). Proceeding with transfer..."
fi

echo ""
echo "Starting transfer..."
echo ""

# Track what was actually transferred
transferred_files=0
transferred_bytes=0
failed_transfers=0

# Copy all video files from matching folders while preserving structure
if [ ${#FOLDERS[@]} -gt 0 ]; then
    echo "Copying contents of matching folders..."
    for folder in "${FOLDERS[@]}"; do
        # Check if folder still exists
        if [ ! -d "$folder" ]; then
            echo "WARNING: Folder no longer exists: $folder (run ultimate-index-update.sh to update)"
            continue
        fi
        
        echo "Processing folder: $folder"
        folder_name=$(basename "$folder")
        
        # Copy the entire folder with only video files
        rsync -a --append-verify --progress --stats \
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
            "$folder/" "$DEST_DIR/$folder_name/" 2>&1 | tee /tmp/rsync_output_$$.txt
        
        # Parse rsync stats
        if [ -f /tmp/rsync_output_$$.txt ]; then
            rsync_files=$(grep "Number of regular files transferred:" /tmp/rsync_output_$$.txt | awk '{print $NF}' | tr -d ',')
            rsync_bytes=$(grep "Total transferred file size:" /tmp/rsync_output_$$.txt | awk '{print $5}' | tr -d ',')
            
            if [ -n "$rsync_files" ]; then
                transferred_files=$((transferred_files + rsync_files))
            fi
            if [ -n "$rsync_bytes" ]; then
                transferred_bytes=$((transferred_bytes + rsync_bytes))
            fi
            
            rm /tmp/rsync_output_$$.txt
        fi
    done
    echo ""
fi

# Copy individual matching files
if [ ${#FILES[@]} -gt 0 ]; then
    echo "Copying individual matching files..."
    for i in "${!FILES[@]}"; do
        file="${FILES[$i]}"
        
        # Check if file still exists
        if [ ! -f "$file" ]; then
            echo "WARNING: File no longer exists: $file (run ultimate-index-update.sh to update)"
            ((failed_transfers++))
            continue
        fi
        
        # Get the parent directory name to preserve some context
        parent_dir=$(basename "$(dirname "$file")")
        
        # Create a subdirectory for files found by filename
        mkdir -p "$DEST_DIR/_matched_files/$parent_dir"
        
        echo "Copying file: $file"
        if rsync -a --append-verify --progress "$file" "$DEST_DIR/_matched_files/$parent_dir/"; then
            ((transferred_files++))
            transferred_bytes=$((transferred_bytes + ${FILE_SIZES[$i]}))
        else
            echo "  ERROR: Failed to copy file"
            ((failed_transfers++))
        fi
    done
    echo ""
fi

echo "Running detox to clean up file and folder names..."
detox -r "$DEST_DIR" 2>/dev/null

echo ""
echo "========================================="
echo "TRANSFER COMPLETE!"
echo "========================================="
echo ""
echo "Transfer Statistics:"
echo "  Files transferred: $transferred_files"
echo "  Bytes transferred: $(human_readable_size $transferred_bytes)"
[ $failed_transfers -gt 0 ] && echo "  Failed transfers:  $failed_transfers"
echo ""
echo "Original Estimates:"
echo "  Expected size: $(human_readable_size $grand_total_size)"
echo ""
echo "Destination:"
echo "  Location: $DEST_DIR/"
echo "  Search terms: ${SEARCH_TERMS[*]}"
echo "  - Folders copied with full structure"
echo "  - Individual files in: $DEST_DIR/_matched_files/"
echo ""

# Show disk usage of destination
if command -v du >/dev/null 2>&1; then
    dest_size=$(du -sh "$DEST_DIR" 2>/dev/null | awk '{print $1}')
    echo "Total destination size: $dest_size"
fi

echo "========================================="