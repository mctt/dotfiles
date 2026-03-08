#!/bin/bash

TARGET_DIR="/mnt/unas/_crap/tmp/"
DB_FILE="/tmp/dupes_$(date +%s).db"

# Check if directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist"
    exit 1
fi

# Check if required tools are installed
for cmd in sqlite3 md5sum; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed"
        exit 1
    fi
done

echo "Scanning for duplicates in: $TARGET_DIR"
echo "========================================="
echo

# Get before size (using POSIX-compatible du)
echo "Current directory size:"
BEFORE_BLOCKS=$(du -sk "$TARGET_DIR" | cut -f1)
BEFORE_SIZE=$((BEFORE_BLOCKS * 1024))
du -sh "$TARGET_DIR"
echo

# Initialize database
sqlite3 "$DB_FILE" <<EOF
CREATE TABLE files (
    hash TEXT,
    path TEXT,
    size INTEGER
);
CREATE INDEX idx_hash ON files(hash);
EOF

echo "Analyzing files and computing hashes..."

# Find all files and compute hashes
find "$TARGET_DIR" -type f -print0 | while IFS= read -r -d '' file; do
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    hash=$(md5sum "$file" | cut -d' ' -f1)
    sqlite3 "$DB_FILE" "INSERT INTO files VALUES ('$hash', '$file', $size);"
done

# Find duplicates and calculate savings
echo
echo "Finding duplicates..."
DUPLICATE_INFO=$(sqlite3 "$DB_FILE" <<EOF
SELECT 
    hash,
    COUNT(*) as count,
    size,
    (COUNT(*) - 1) * size as wasted
FROM files
GROUP BY hash
HAVING count > 1
ORDER BY wasted DESC;
EOF
)

if [ -z "$DUPLICATE_INFO" ]; then
    echo "No duplicates found!"
    rm "$DB_FILE"
    exit 0
fi

# Display duplicate sets
echo "Duplicate file sets:"
echo "========================================="

TOTAL_WASTED=0
SET_NUM=1

echo "$DUPLICATE_INFO" | while IFS='|' read -r hash count size wasted; do
    echo
    echo "Set $SET_NUM: $count copies of file ($(numfmt --to=iec-i --suffix=B $size) each)"
    TOTAL_WASTED=$((TOTAL_WASTED + wasted))
    
    sqlite3 "$DB_FILE" "SELECT path FROM files WHERE hash='$hash';" | nl -v 1
    
    SET_NUM=$((SET_NUM + 1))
done

# Calculate total potential savings
POTENTIAL_SAVINGS=$(sqlite3 "$DB_FILE" <<EOF
SELECT SUM((COUNT(*) - 1) * size)
FROM files
GROUP BY hash
HAVING COUNT(*) > 1;
EOF
)

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
    
    # Process each duplicate set
    sqlite3 "$DB_FILE" "SELECT DISTINCT hash FROM files GROUP BY hash HAVING COUNT(*) > 1;" | while read -r hash; do
        echo "----------------------------------------"
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
    echo
    
    # Get after size
    echo "========================================="
    echo "SUMMARY"
    echo "========================================="
    AFTER_BLOCKS=$(du -sk "$TARGET_DIR" | cut -f1)
    AFTER_SIZE=$((AFTER_BLOCKS * 1024))
    
    echo "Directory size before: $(numfmt --to=iec-i --suffix=B $BEFORE_SIZE)"
    echo "Directory size after:  $(numfmt --to=iec-i --suffix=B $AFTER_SIZE)"
    
    # Calculate difference
    DIFF=$((BEFORE_SIZE - AFTER_SIZE))
    DIFF_GB=$(echo "scle=2; $DIFF / 1024 / 1024 / 1024" | bc)
    
    echo
    echo "Space freed: $(numfmt --to=iec-i --suffix=B $DIFF) (${DIFF_GB} GB)"
    echo "========================================="
else
    echo "Deletion cancelled."
fi

# Cleanup
#rm -f "$DB_FILE"
