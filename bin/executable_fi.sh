#!/bin/bash

# Parse options and search terms
AUTO_YES=false
SEARCH_TERMS=()
EXCLUDE_TERMS=()
DIR_INCLUDE=()
DIR_EXCLUDE=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -d)
            # Directory include: next argument is the directory pattern
            shift
            if [ -z "$1" ]; then
                echo "ERROR: -d requires a directory pattern"
                exit 1
            fi
            DIR_INCLUDE+=("$1")
            shift
            ;;
        -D)
            # Directory exclude: next argument is the directory pattern to exclude
            shift
            if [ -z "$1" ]; then
                echo "ERROR: -D requires a directory pattern"
                exit 1
            fi
            DIR_EXCLUDE+=("$1")
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-y] [-d dir] [-D dir] <search_term1> [search_term2] [-exclude_term] ..."
            echo ""
            echo "Options:"
            echo "  -y, --yes       Skip confirmation prompt and proceed automatically"
            echo "  -d <pattern>    Include only items with this pattern in their path"
            echo "  -D <pattern>    Exclude items with this pattern in their path"
            echo "  -h, --help      Show this help message"
            echo ""
            echo "Search Terms:"
            echo "  term            Include items with this term in filename"
            echo "  -term           Exclude items with this term in filename (prefix with -)"
            echo ""
            echo "Examples:"
            echo "  $0 paola lana                    # Output to: /tmp/paola_lana/"
            echo "  $0 paola -lana                   # Output to: /tmp/paola_not_lana/"
            echo "  $0 -d hall paola                 # Output to: /tmp/d_hall_paola/"
            echo "  $0 -d hall -D trailer paola      # Output to: /tmp/d_hall_notd_trailer_paola/"
            echo ""
            echo "Notes:"
            echo "  - Output folder is named based on search criteria"
            echo "  - Multiple -d flags = OR logic (match ANY directory)"
            echo "  - Multiple -D flags = AND logic (exclude ALL directories)"
            exit 0
            ;;
        -*)
            # Term starting with - is an exclusion (skip the - prefix)
            EXCLUDE_TERMS+=("${1#-}")
            shift
            ;;
        *)
            SEARCH_TERMS+=("$1")
            shift
            ;;
    esac
done

# Check if at least one search criterion was provided
if [ ${#SEARCH_TERMS[@]} -eq 0 ] && [ ${#EXCLUDE_TERMS[@]} -eq 0 ] && [ ${#DIR_INCLUDE[@]} -eq 0 ] && [ ${#DIR_EXCLUDE[@]} -eq 0 ]; then
    echo "Usage: $0 [-y] [-d dir] [-D dir] <search_term1> [search_term2] [-exclude_term] ..."
    echo "Use -h or --help for more information"
    exit 1
fi

# Configuration
DB_FILE="/mnt/unas/p/video_index.db"

# Build destination folder name from search criteria
DEST_NAME=""

# Add directory filters to name
for dir_term in "${DIR_INCLUDE[@]}"; do
    if [ -z "$DEST_NAME" ]; then
        DEST_NAME="d_${dir_term}"
    else
        DEST_NAME="${DEST_NAME}_d_${dir_term}"
    fi
done

for dir_term in "${DIR_EXCLUDE[@]}"; do
    if [ -z "$DEST_NAME" ]; then
        DEST_NAME="notd_${dir_term}"
    else
        DEST_NAME="${DEST_NAME}_notd_${dir_term}"
    fi
done

# Add include terms to name
for term in "${SEARCH_TERMS[@]}"; do
    if [ -z "$DEST_NAME" ]; then
        DEST_NAME="${term}"
    else
        DEST_NAME="${DEST_NAME}_${term}"
    fi
done

# Add exclude terms to name
for term in "${EXCLUDE_TERMS[@]}"; do
    if [ -z "$DEST_NAME" ]; then
        DEST_NAME="not_${term}"
    else
        DEST_NAME="${DEST_NAME}_not_${term}"
    fi
done

# If no name built (shouldn't happen), use timestamp
if [ -z "$DEST_NAME" ]; then
    DEST_NAME="search_$(date +%Y%m%d_%H%M%S)"
fi

# Clean the name (remove special chars, limit length)
DEST_NAME=$(echo "$DEST_NAME" | sed 's/[^a-zA-Z0-9_-]/_/g' | cut -c1-100)

DEST_DIR="/mnt/unas/_crap/tmp/${DEST_NAME}"

# Check if database exists
if [ ! -f "$DB_FILE" ]; then
    echo "ERROR: Database not found: $DB_FILE"
    echo "Please run ultimate-index-update.sh first to create the index"
    exit 1
fi

# Don't create destination folder yet - wait until user confirms transfer

echo "Output destination: $DEST_DIR"
echo ""

# Display search criteria
echo "Search Criteria:"
if [ ${#SEARCH_TERMS[@]} -gt 0 ]; then
    echo "  Filename includes (ALL): ${SEARCH_TERMS[*]}"
fi
if [ ${#EXCLUDE_TERMS[@]} -gt 0 ]; then
    echo "  Filename excludes (NONE): ${EXCLUDE_TERMS[*]}"
fi
if [ ${#DIR_INCLUDE[@]} -gt 0 ]; then
    echo "  Path must contain (ANY): ${DIR_INCLUDE[*]}"
fi
if [ ${#DIR_EXCLUDE[@]} -gt 0 ]; then
    echo "  Path must NOT contain (ALL): ${DIR_EXCLUDE[*]}"
fi
echo ""

# Build SQL WHERE clause for filename INCLUDE terms (all must match)
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

# Add filename EXCLUDE terms (none can match)
for term in "${EXCLUDE_TERMS[@]}"; do
    # Escape single quotes in exclude term
    term_escaped=$(echo "$term" | sed "s/'/''/g")
    
    if [ -z "$WHERE_CLAUSE" ]; then
        WHERE_CLAUSE="name NOT LIKE '%$term_escaped%'"
    else
        WHERE_CLAUSE="$WHERE_CLAUSE AND name NOT LIKE '%$term_escaped%'"
    fi
done

# Add directory INCLUDE terms (any must match - OR logic)
if [ ${#DIR_INCLUDE[@]} -gt 0 ]; then
    dir_include_clause=""
    for dir_term in "${DIR_INCLUDE[@]}"; do
        # Escape single quotes
        dir_escaped=$(echo "$dir_term" | sed "s/'/''/g")
        
        if [ -z "$dir_include_clause" ]; then
            dir_include_clause="path LIKE '%$dir_escaped%'"
        else
            dir_include_clause="$dir_include_clause OR path LIKE '%$dir_escaped%'"
        fi
    done
    
    if [ -z "$WHERE_CLAUSE" ]; then
        WHERE_CLAUSE="($dir_include_clause)"
    else
        WHERE_CLAUSE="$WHERE_CLAUSE AND ($dir_include_clause)"
    fi
fi

# Add directory EXCLUDE terms (none can match - AND logic)
for dir_term in "${DIR_EXCLUDE[@]}"; do
    # Escape single quotes
    dir_escaped=$(echo "$dir_term" | sed "s/'/''/g")
    
    if [ -z "$WHERE_CLAUSE" ]; then
        WHERE_CLAUSE="path NOT LIKE '%$dir_escaped%'"
    else
        WHERE_CLAUSE="$WHERE_CLAUSE AND path NOT LIKE '%$dir_escaped%'"
    fi
done

# If no conditions, match everything
if [ -z "$WHERE_CLAUSE" ]; then
    WHERE_CLAUSE="1=1"
fi

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
    echo "No folders or files found matching criteria"
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

# NOW create the destination folder (after confirmation)
mkdir -p "$DEST_DIR"

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
        
        # Copy directly to destination, preserving parent folder name
        mkdir -p "$DEST_DIR/$parent_dir"
        
        echo "Copying file: $file"
        if rsync -a --append-verify --progress "$file" "$DEST_DIR/$parent_dir/"; then
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
echo "  - Matched folders copied with full structure"
echo "  - Matched files organized by parent folder"
echo ""

# Show disk usage of destination
if command -v du >/dev/null 2>&1; then
    dest_size=$(du -sh "$DEST_DIR" 2>/dev/null | awk '{print $1}')
    echo "Total destination size: $dest_size"
fi

echo "========================================="
