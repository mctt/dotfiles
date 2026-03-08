#!/bin/bash

# https://claude.ai/share/04be737a-1f65-4f74-9913-887cf6e0f245

# Configuration
TARGET_DIR="/mnt/unas"
CRAP_DIR="/mnt/unas/_crap"

## tt_edit
#echo -e "${GREEN}Make it writeable/${NC}"
chmod -R +w "$CRAP_DIR"/*


# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Disk Cleanup Script ===${NC}\n"

# Check initial disk usage
echo -e "${GREEN}Initial disk usage:${NC}"
df -h "$TARGET_DIR"
echo ""

# Get initial size of directory to be deleted
echo -e "${GREEN}Directory to be cleaned:${NC}"
INITIAL_SIZE=$(du -sb "$CRAP_DIR" 2>/dev/null | cut -f1)
INITIAL_SIZE_HUMAN=$(du -sh "$CRAP_DIR" 2>/dev/null | cut -f1)
echo "$CRAP_DIR: $INITIAL_SIZE_HUMAN"
echo ""

# Confirm deletion
read -p "Do you want to delete all contents of $CRAP_DIR? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Perform deletion
echo -e "${RED}Deleting contents...${NC}"
rm -rf "$CRAP_DIR"/*

# Check final disk usage
echo -e "${GREEN}Final disk usage:${NC}"
df -h "$TARGET_DIR"
echo ""

# Calculate and display summary
FINAL_SIZE=$(du -sb "$CRAP_DIR" 2>/dev/null | cut -f1)
DELETED_BYTES=$((INITIAL_SIZE - FINAL_SIZE))
DELETED_GB=$(awk "BEGIN {printf \"%.2f\", $DELETED_BYTES/1024/1024/1024}")

echo -e "${YELLOW}=== Summary ===${NC}"
echo "Data deleted: ${DELETED_GB} GB"
echo "Space freed: ${INITIAL_SIZE_HUMAN}"
