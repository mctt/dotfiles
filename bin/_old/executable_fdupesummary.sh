#!/bin/bash
# https://claude.ai/share/f7a7f5dd-0101-44d4-b610-e811b0757412
# Check if directory argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 /path/to/directory"
    exit 1
fi
##tt_edit
TARGET_DIR="$1"
#TARGET_DIR="/mnt/unas/_crap/tmp/"

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
else
    echo "Deletion cancelled."
fi
