#!/bin/bash

DB_FILE="/mnt/unas/p/video_index.db"
SEARCH_DIR="/mnt/unas/p/"

# Remove old database
rm -f "$DB_FILE"

echo "Creating SQLite database index..."
echo "This may take a while for large directories..."
echo ""

# Create database and tables
sqlite3 "$DB_FILE" <<'EOF'
CREATE TABLE items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    path TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    parent_path TEXT,
    size INTEGER,
    modified INTEGER,
    indexed_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX idx_name ON items(name COLLATE NOCASE);
CREATE INDEX idx_type ON items(type);
CREATE INDEX idx_parent ON items(parent_path);
EOF

echo "Database created. Starting indexing..."
echo ""

# Counter for progress
folder_count=0
file_count=0

# Insert folders
echo "Indexing folders..."
find "$SEARCH_DIR" -type d | while read -r folder; do
    name=$(basename "$folder")
    parent=$(dirname "$folder")
    
    # Escape single quotes for SQL
    folder_escaped=$(echo "$folder" | sed "s/'/''/g")
    name_escaped=$(echo "$name" | sed "s/'/''/g")
    parent_escaped=$(echo "$parent" | sed "s/'/''/g")
    
    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO items (type, path, name, parent_path) VALUES ('FOLDER', '$folder_escaped', '$name_escaped', '$parent_escaped');"
    
    ((folder_count++))
    if [ $((folder_count % 100)) -eq 0 ]; then
        echo "  Indexed $folder_count folders..."
    fi
done

echo "  Total folders indexed: $folder_count"
echo ""

# Insert video files
echo "Indexing video files..."
find "$SEARCH_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.mpg" -o -iname "*.mpeg" \) | while read -r file; do
    name=$(basename "$file")
    parent=$(dirname "$file")
    
    # Get file size and modification time (FreeBSD compatible)
    if command -v stat >/dev/null 2>&1; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        modified=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo 0)
    else
        size=0
        modified=0
    fi
    
    # Escape single quotes for SQL
    file_escaped=$(echo "$file" | sed "s/'/''/g")
    name_escaped=$(echo "$name" | sed "s/'/''/g")
    parent_escaped=$(echo "$parent" | sed "s/'/''/g")
    
    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO items (type, path, name, parent_path, size, modified) VALUES ('FILE', '$file_escaped', '$name_escaped', '$parent_escaped', $size, $modified);"
    
    ((file_count++))
    if [ $((file_count % 100)) -eq 0 ]; then
        echo "  Indexed $file_count files..."
    fi
done

echo "  Total video files indexed: $file_count"
echo ""

# Show statistics
echo "========================================="
echo "Index created successfully: $DB_FILE"
echo "========================================="
sqlite3 "$DB_FILE" <<'EOF'
SELECT 
    'Total entries: ' || COUNT(*) 
FROM items;

SELECT 
    'Folders: ' || COUNT(*) 
FROM items 
WHERE type='FOLDER';

SELECT 
    'Video files: ' || COUNT(*) 
FROM items 
WHERE type='FILE';

SELECT 
    'Total size: ' || ROUND(SUM(size)/1024.0/1024.0/1024.0, 2) || ' GB'
FROM items 
WHERE type='FILE';

SELECT 
    'Indexed at: ' || datetime(indexed_at, 'unixepoch', 'localtime')
FROM items 
LIMIT 1;
EOF
echo "========================================="
