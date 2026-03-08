#!/bin/bash

TARGET_DIR="/mnt/unas/_crap/tmp/"
DB_FILE="/tmp/dupes_$(date +%s).db"
USE_FDUPES=true

# Check if directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist"
    exit 1
fi

# Check which tools are available
if command -v fdupes &> /dev/null; then
    echo "fdupes found - using optimized fdupes method"
    USE_FDUPES=true
else
    echo "fdupes not found - using custom hash method"
    USE_FDUPES=false
    for cmd in sqlite3 md5sum; do
        if ! command -v $cmd &> /dev/null; then
            echo "Error: $cmd is not installed"
            exit 1
        fi
    done
fi

echo "Scanning for duplicates in: $TARGET_DIR"
echo "========================================="
echo

# Get before size
echo "Current directory size:"
BEFORE_BLOCKS=$(du -sk "$TARGET_DIR" | cut -f1)
BEFORE_SIZE=$((BEFORE_BLOCKS * 1024))
du -sh "$TARGET_DIR"
echo

if [ "$USE_FDUPES" = true ]; then
    # METHOD 1: Use fdupes for initial scan, store results, then process
    echo "Scanning for duplicates with fdupes..."
    
    # Create temp file to store fdupes output
    FDUPES_OUTPUT="/tmp/fdupes_output_$$.txt"
    
    # Run fdupes once and capture output
    fdupes -rS "$TARGET_DIR" > "$FDUPES_OUTPUT"
    
    # Check if any duplicates found
    if [ ! -s "$FDUPES_OUTPUT" ]; then
        echo "No duplicates found!"
        rm "$FDUPES_OUTPUT"
        exit 0
    fi
    
    # Parse fdupes output to calculate savings
    echo "Calculating potential savings..."
    
    TOTAL_WASTED=0
    CURRENT_SET=""
    SET_SIZE=0
    SET_COUNT=0
    
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            # Empty line = end of duplicate set
            if [ $SET_COUNT -gt 1 ]; then
                WASTED=$((SET_SIZE * (SET_COUNT - 1)))
                TOTAL_WASTED=$((TOTAL_WASTED + WASTED))
            fi
            SET_COUNT=0
            SET_SIZE=0
        elif [[ "$line" =~ ^[0-9]+ ]]; then
            # Line starts with size - extract it
            SET_SIZE=$(echo "$line" | grep -oE '^[0-9]+')
            SET_COUNT=$((SET_COUNT + 1))
        else
            # File path line (no size prefix)
            SET_COUNT=$((SET_COUNT + 1))
        fi
    done < "$FDUPES_OUTPUT"
    
    # Handle last set
    if [ $SET_COUNT -gt 1 ]; then
        WASTED=$((SET_SIZE * (SET_COUNT - 1)))
        TOTAL_WASTED=$((TOTAL_WASTED + WASTED))
    fi
    
    SAVINGS_GB=$(echo "scale=2; $TOTAL_WASTED / 1024 / 1024 / 1024" | bc)
    
    echo
    echo "Duplicate sets found!"
    echo "========================================="
    cat "$FDUPES_OUTPUT"
    echo "========================================="
    echo "Potential space savings: $(numfmt --to=iec-i --suffix=B $TOTAL_WASTED) (${SAVINGS_GB} GB)"
    echo "========================================="
    echo
    read -p "Do you want to proceed with deletion? (yes/no): " answer
    
    if [ "$answer" = "yes" ] || [ "$answer" = "y" ]; then
        echo
        echo "Starting interactive deletion with fdupes..."
        fdupes -rd "$TARGET_DIR"
        echo
        echo "Deletion complete!"
    else
        echo "Deletion cancelled."
        rm "$FDUPES_OUTPUT"
        exit 0
    fi
    
    rm "$FDUPES_OUTPUT"

else
    # METHOD 2: Custom implementation with optimizations
    
    # Initialize database
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE temp_sizes (size INTEGER, path TEXT);
CREATE TABLE files (hash TEXT, path TEXT, size INTEGER);
CREATE INDEX idx_temp_size ON temp_sizes(size);
CREATE INDEX idx_hash ON files(hash);
CREATE INDEX idx_size ON files(size);
EOF

    echo "Collecting file sizes..."
    
    # Collect all file sizes first
    find "$TARGET_DIR" -type f -print0 | while IFS= read -r -d '' file; do
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        # Escape single quotes in paths for SQL
        safe_path=$(echo "$file" | sed "s/'/''/g")
        echo "INSERT INTO temp_sizes VALUES ($size, '$safe_path');"
    done | sqlite3 "$DB_FILE"

    # Count potential duplicates
    POTENTIAL_DUPES=$(sqlite3 "$DB_FILE" <<EOF
SELECT COUNT(*)
FROM temp_sizes t1
WHERE EXISTS (
    SELECT 1 FROM temp_sizes t2 
    WHERE t1.size = t2.size AND t1.path != t2.path
);
EOF
)

    TOTAL_FILES=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM temp_sizes;")

    echo "Total files: $TOTAL_FILES"
    echo "Files needing hash comparison: $POTENTIAL_DUPES"
    echo

    if [ "$POTENTIAL_DUPES" -eq 0 ]; then
        echo "No duplicates found (no files with matching sizes)!"
        rm "$DB_FILE"
        exit 0
    fi

    # Hash only files with duplicate sizes (in parallel)
    echo "Computing hashes for potential duplicates..."
    
    sqlite3 "$DB_FILE" "SELECT DISTINCT t1.path FROM temp_sizes t1 WHERE EXISTS (SELECT 1 FROM temp_sizes t2 WHERE t1.size = t2.size AND t1.path != t2.path);" | \
    tr '\n' '\0' | \
    xargs -0 -P $(nproc) -I {} sh -c '
        hash=$(md5sum "{}" 2>/dev/null | cut -d" " -f1)
        size=$(stat -f%z "{}" 2>/dev/null || stat -c%s "{}" 2>/dev/null)
        safe_path=$(echo "{}" | sed "s/'\''/'\''\''/g")
        echo "INSERT INTO files VALUES (\"$hash\", \"$safe_path\", $size);"
    ' | sqlite3 "$DB_FILE"

    # Find duplicates
    DUPLICATE_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM (SELECT hash FROM files GROUP BY hash HAVING COUNT(*) > 1);")

    if [ -z "$DUPLICATE_COUNT" ] || [ "$DUPLICATE_COUNT" -eq 0 ]; then
        echo "No duplicates found!"
        rm "$DB_FILE"
        exit 0
    fi

    echo
    echo "Duplicate file sets found: $DUPLICATE_COUNT"
    echo "========================================="

    SET_NUM=1
    sqlite3 "$DB_FILE" "SELECT DISTINCT hash FROM files GROUP BY hash HAVING COUNT(*) > 1;" | while read -r hash; do
        count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM files WHERE hash='$hash';")
        size=$(sqlite3 "$DB_FILE" "SELECT size FROM files WHERE hash='$hash' LIMIT 1;")
        wasted=$((size * (count - 1)))
        
        echo
        echo "Set $SET_NUM: $count copies ($(numfmt --to=iec-i --suffix=B $size) each, $(numfmt --to=iec-i --suffix=B $wasted) wasted)"
        sqlite3 "$DB_FILE" "SELECT path FROM files WHERE hash='$hash';" | nl -v 1
        
        SET_NUM=$((SET_NUM + 1))
    done

    # Calculate total savings
    POTENTIAL_SAVINGS=$(sqlite3 "$DB_FILE" "SELECT SUM((COUNT(*) - 1) * size) FROM files GROUP BY hash HAVING COUNT(*) > 1;")
    SAVINGS_GB=$(echo "scale=2; $POTENTIAL_SAVINGS / 1024 / 1024 / 1024" | bc)

    echo
    echo "========================================="
    echo "Potential space savings: $(numfmt --to=iec-i --suffix=B $POTENTIAL_SAVINGS) (${SAVINGS_GB} GB)"
    echo "========================================="
    echo
    read -p "Do you want to proceed with deletion? (yes/no): " answer

    if [ "$answer" = "yes" ] || [ "$answer" = "y" ]; then
        echo
        echo "Starting interactive deletion..."
        echo
        
        sqlite3 "$DB_FILE" "SELECT DISTINCT hash FROM files GROUP BY hash HAVING COUNT(*) > 1;" | while read -r hash; do
            echo "----------------------------------------"
            count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM files WHERE hash='$hash';")
            size=$(sqlite3 "$DB_FILE" "SELECT size FROM files WHERE hash='$hash' LIMIT 1;")
            echo "Set: $count copies ($(numfmt --to=iec-i --suffix=B $size) each)"
            sqlite3 "$DB_FILE" "SELECT path FROM files WHERE hash='$hash';" | nl -v 1
            echo
            read -p "Enter number(s) to DELETE (space-separated) or press Enter to skip: " nums
            
            if [ -n "$nums" ]; then
                i=1
                sqlite3 "$DB_FILE" "SELECT path FROM files WHERE hash='$hash';" | while read -r filepath; do
                    for num in $nums; do
                        if [ "$i" -eq "$num" ]; then
                            rm -f "$filepath"
                            echo "Deleted: $filepath"
                        fi
                    done
                    i=$((i + 1))
                done
            fi
        done
        
        echo
        echo "Deletion complete!"
    else
        echo "Deletion cncelled."
        rm -f "$DB_FILE"
        exit 0
    fi
    
    rm -f "$DB_FILE"
fi

# Get after size and show summary
echo
echo "========================================="
echo "SUMMARY"
echo "========================================="
AFTER_BLOCKS=$(du -sk "$TARGET_DIR" | cut -f1)
AFTER_SIZE=$((AFTER_BLOCKS * 1024))

echo "Directory size before: $(numfmt --to=iec-i --suffix=B $BEFORE_SIZE)"
echo "Directory size after:  $(numfmt --to=iec-i --suffix=B $AFTER_SIZE)"

DIFF=$((BEFORE_SIZE - AFTER_SIZE))
DIFF_GB=$(echo "scale=2; $DIFF / 1024 / 1024 / 1024" | bc)

echo
echo "Space freed: $(numfmt --to=iec-i --suffix=B $DIFF) (${DIFF_GB} GB)"
echo "========================================="
