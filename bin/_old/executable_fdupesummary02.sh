#!/bin/bash

TARGET_DIR="/mnt/unas/_crap/tmp/"

# Check if directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist"
    exit 1
fi

# Check if fdupes is installed
if ! command -v fdupes &> /dev/null; then
    echo "Error: fdupes is not installed"
    echo "Install it with: sudo apt install fdupes"
    exit 1
fi

echo "Scanning for duplicates in: $TARGET_DIR"
echo "========================================="
echo

# Get before size
echo "Current directory size:"
BEFORE_SIZE=$(du -sb "$TARGET_DIR" | cut -f1)
du -hs "$TARGET_DIR"
echo

# Show summary of potential savings
echo "Calculating potential space savings..."
fdupes -rm "$TARGET_DIR"

echo
echo "========================================="
read -p "Do you want to proceed with deletion? (yes/no): " answer

if [ "$answer" = "yes" ] || [ "$answer" = "y" ]; then
    echo
    echo "Starting interactive deletion..."
    echo "For each set of duplicates, enter the number(s) to DELETE"
    echo "or press Enter to skip that set"
    echo
    fdupes -rd "$TARGET_DIR"
    echo
    echo "Deletion complete!"
    echo
    
    # Get after size
    echo "========================================="
    echo "SUMMARY"
    echo "========================================="
    AFTER_SIZE=$(du -sb "$TARGET_DIR" | cut -f1)
    
    echo "Directory size before: $(numfmt --to=iec-i --suffix=B $BEFORE_SIZE)"
    echo "Directory size after:  $(numfmt --to=iec-i --suffix=B $AFTER_SIZE)"
    
    # Calculate difference
    DIFF=$((BEFORE_SIZE - AFTER_SIZE))
    DIFF_GB=$(echo "scale=2; $DIFF / 1024 / 1024 / 1024" | bc)
    
    echo
    echo "Space freed: $(numfmt --to=iec-i --suffix=B $DIFF) (${DIFF_GB} GB)"
    echo "========================================="
else
    echo "Deletion cancelled."
fi
