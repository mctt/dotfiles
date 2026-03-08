#!/bin/bash

# Configuration
#UNAS
TARGET_DIR="/mnt/unas"
CRAP_DIR="/mnt/unas/_crap/tmp"
#QNAS
#TARGET_DIR="/mnt/pnas/m"
#CRAP_DIR="/mnt/pnas/m/_crap/tmp"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

# Show top 5 largest files
echo -e "${BLUE}Top 5 largest files:${NC}"
find "$CRAP_DIR" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -5 | awk '{printf "  %-10s %s\n", $1, $2}'
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
