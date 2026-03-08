#!/bin/bash

TARGET_DIR="/mnt/unas/_crap/tmp/"
DB_FILE="/tmp/dupes_$(date +%s).db"
USE_JDUPES=true

# Detect OS
if [ "$(uname)" = "FreeBSD" ]; then
    IS_FREEBSD=true
    STAT_CMD="stat -f%z"
    NPROC_CMD="sysctl -n hw.ncpu"
else
    IS_FREEBSD=false
    STAT_CMD="stat -c%s"
    NPROC_CMD="nproc"
fi

# Check if directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist"
    exit 1
fi

# Check which tools are available (prefer jdupes over fdupes)
if command -v jdupes &> /dev/null; then
    echo "jdupes found - using optimized jdupes method"
    USE_JDUPES=true
    DUPES_CMD="jdupes"
elif command -v fdupes &> /dev/null; then
    echo "fdupes found - using optimized fdupes method"
    USE_JDUPES=true
    DUPES_CMD="fdupes"
else
    echo "jdupes/fdupes not found - using custom hash method"
    USE_JDUPES=false
    for cmd in sqlite3; do
        if ! command -v $cmd &> /dev/null; then
            echo "Error: $cmd is not installed"
            echo "On FreeBSD/TrueNAS: pkg install sqlite3"
            exit 1
        fi
    done
    # Check for hash command
    if [ "$IS_FREEBSD" = true ]; then
        if ! command -v md5 &> /dev/null; then
            echo "Error: md5 is not installed"
            exit 1
        fi
    else
        if ! command -v md5sum &> /dev/null; then
            echo "Error: md5sum is not installed"
            exit 1
        fi
    fi
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

if [ "$USE_JDUPES" = true ]; then
    # METHOD 1: Use jdupes/fdupes for duplicate detection
    
    echo "Running $DUPES_CMD scan..."
    
    # Create temp file to store output
    DUPES_OUTPUT="/tmp/dupes_output_$$.txt"
    
    # Run jdupes/fdupes once with size display
    $DUPES_CMD -rS "$TARGET_DIR" > "$DUPES_OUTPUT"
    
    # Check if any duplicates found
    if [ ! -s "$DUPES_OUTPUT" ]; then
        echo "No duplicates found!"
        rm -f "$DUPES_OUTPUT"
        exit 0
    fi
    
    # Parse output to calculate savings
    echo "Calculating potential savings..."
    
    TOTAL_WASTED=0
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
        elif echo "$line" | grep -qE '^[0-9]+'; then
            # Line starts with size - extract it
            SET_SIZE=$(echo "$line" | grep -oE '^[0-9]+')
            SET_COUNT=$((SET_COUNT + 1))
        else
            # File path line (no size prefix)
            SET_COUNT=$((SET_COUNT + 1))
        fi
    done < "$DUPES_OUTPUT"
    
    # Handle last set
    if [ $SET_COUNT -gt 1 ]; then
        WASTED=$((SET_SIZE * (SET_COUNT - 1)))
        TOTAL_WASTED=$((TOTAL_WASTED + WASTED))
    fi
    
    if [ "$TOTAL_WASTED" -eq 0 ]; then
        echo "No duplicates found!"
        rm -f "$DUPES_OUTPUT"
        exit 0
    fi
    
    SAVINGS_GB=$(echo "scale=2; $TOTAL_WASTED / 1024 / 1024 / 1024" | bc)
    
    echo
    echo "Duplicate sets found!"
    echo "========================================="
    cat "$DUPES_OUTPUT"
    echo "========================================="
    echo "Potential space savings: $(numfmt --to=iec-i --suffix=B $TOTAL_WASTED) (${SAVINGS_GB} GB)"
    echo "========================================="
    echo
    read -p "Do you want to proceed with deletion? (yes/no): " answer
    
    if [ "$answer" = "yes" ] || [ "$answer" = "y" ]; then
        echo
        echo "Starting interactive deletion with $DUPES_CMD..."
        $DUPES_CMD -rd "$TARGET_DIR"
        echo
        echo "Deletion complete!"
    else
        echo "Deletion cancelled."
        rm -f "$DUPES_OUTPUT"
        exit 0
    fi
    
    rm -f "$DUPES_OUTPUT"

else
    # METHOD 2: Custom implementation with FreeBSD compatibility
    
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
        size=$($STAT_CMD "$file" 2>/dev/null)
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
    
    NUM_CORES=$($NPROC_CMD)
    
    # FreeBSD uses 'md5' instead of 'md5sum'
    if [ "$IS_FREEBSD" = true ]; then
        HASH_CMD='md5 -q'
    else
        HASH_CMD='md5sum | cut -d" " -f1'
    fi
    
    sqlite3 "$DB_FILE" "SELECT DISTINCT t1.path FROM temp_sizes t1 WHERE EXISTS (SELECT 1 FROM temp_sizes t2 WHERE t1.size = t2.size AND t1.path != t2.path);" | \
    tr '\n' '\0' | \
    xargs -0 -P "$NUM_CORES" -I {} sh -c "
        hash=\$($HASH_CMD '{}' 2>/dev/null)
        size=\$($STAT_CMD '{}' 2>/dev/null)
        safe_path=\$(echo '{}' | sed \"s/'/''/g\")
        echo \"INSERT INTO files VALUES ('\$hash', '\$safe_path', \$size);\"
    " | sqlite3 "$DB_FILE"

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
        echo "Deletion cancelled."
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
