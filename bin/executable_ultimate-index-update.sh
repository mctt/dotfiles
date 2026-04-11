#!/bin/bash
# ultimate-index-update.sh - Uses rsync for fast scanning + SQLite3 for storage

DB_FILE="/mnt/unas/p/video_index.db"
SOURCE_DIR="/mnt/unas/p/"
TEMP_DIR="/tmp/index_update_$$"

mkdir -p "$TEMP_DIR"

echo "Ultimate Index Update - rsync + SQLite3"
echo "========================================"
echo ""

# Ensure database exists
if [ ! -f "$DB_FILE" ]; then
    echo "Database doesn't exist. Creating..."
    sqlite3 "$DB_FILE" <<'EOF'
CREATE TABLE items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    path TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    parent_path TEXT,
    size INTEGER,
    modified INTEGER,
    indexed_at INTEGER DEFAULT (strftime('%s', 'now')),
    status TEXT DEFAULT 'active'
);

CREATE INDEX idx_name ON items(name COLLATE NOCASE);
CREATE INDEX idx_type ON items(type);
CREATE INDEX idx_parent ON items(parent_path);
CREATE INDEX idx_path ON items(path);
CREATE INDEX idx_status ON items(status);

CREATE TABLE index_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_date INTEGER DEFAULT (strftime('%s', 'now')),
    items_added INTEGER DEFAULT 0,
    items_updated INTEGER DEFAULT 0,
    items_deleted INTEGER DEFAULT 0,
    scan_method TEXT DEFAULT 'rsync'
);
EOF
fi

# Start tracking this run
echo "Creating run record..."
sqlite3 "$DB_FILE" "INSERT INTO index_runs (scan_method) VALUES ('rsync');"
RUN_ID=$(sqlite3 "$DB_FILE" "SELECT MAX(id) FROM index_runs;")

# Verify RUN_ID was set
if [ -z "$RUN_ID" ] || [ "$RUN_ID" = "" ]; then
    echo "ERROR: Failed to create run record in database"
    exit 1
fi

echo "Run ID: $RUN_ID"
echo ""

echo "Phase 1: Scanning filesystem with rsync..."
echo "This is much faster than find..."
echo ""

# Use rsync to get complete file list with metadata
rsync -an --list-only --recursive --times \
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
    "$SOURCE_DIR" | grep -v "^d" | grep -E "\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg)$" -i > "$TEMP_DIR/rsync_files.txt"

files_found=$(wc -l < "$TEMP_DIR/rsync_files.txt" | tr -d ' ')
echo "Found $files_found video files"
echo ""

# Get folder list using find (fast for directories)
echo "Scanning folders..."
find "$SOURCE_DIR" -type d > "$TEMP_DIR/rsync_dirs_raw.txt"

# Format to match expected output
while read -r folder; do
    echo "drwxr-xr-x          0 2025/01/25 00:00:00 $(echo "$folder" | sed "s|^$SOURCE_DIR||")"
done < "$TEMP_DIR/rsync_dirs_raw.txt" > "$TEMP_DIR/rsync_dirs.txt"

dirs_found=$(wc -l < "$TEMP_DIR/rsync_dirs.txt" | tr -d ' ')
echo "Found $dirs_found directories"
echo ""

echo "Phase 2: Extracting current database state..."
sqlite3 -separator '|' "$DB_FILE" "SELECT path, size, modified FROM items WHERE type='FILE' AND status='active';" | sort > "$TEMP_DIR/db_files.txt"
sqlite3 -separator '|' "$DB_FILE" "SELECT path FROM items WHERE type='FOLDER' AND status='active';" | sort > "$TEMP_DIR/db_folders.txt"

db_files=$(wc -l < "$TEMP_DIR/db_files.txt" | tr -d ' ')
db_folders=$(wc -l < "$TEMP_DIR/db_folders.txt" | tr -d ' ')
echo "Database has $db_files files and $db_folders folders"
echo ""

echo "Phase 3: Processing filesystem snapshot into comparable format..."
while read -r line; do
    size=$(echo "$line" | awk '{print $2}' | tr -d ',')
    filepath=$(echo "$line" | awk '{for(i=5;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":""); print ""}')
    fullpath="${SOURCE_DIR}${filepath}"
    
    if [ ! -f "$fullpath" ]; then
        continue
    fi
    modified=$(stat -f%m "$fullpath" 2>/dev/null || stat -c%Y "$fullpath" 2>/dev/null || echo 0)
    
    echo "$fullpath|$size|$modified"
done < "$TEMP_DIR/rsync_files.txt" | sort > "$TEMP_DIR/fs_files.txt"

while read -r line; do
    filepath=$(echo "$line" | awk '{for(i=5;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":""); print ""}')
    fullpath="${SOURCE_DIR}${filepath}"
    echo "$fullpath"
done < "$TEMP_DIR/rsync_dirs.txt" | sort > "$TEMP_DIR/fs_folders.txt"

echo "Phase 4: Computing differences..."
comm -23 "$TEMP_DIR/fs_files.txt" "$TEMP_DIR/db_files.txt" > "$TEMP_DIR/new_files.txt"
new_count=$(wc -l < "$TEMP_DIR/new_files.txt" | tr -d ' ')

comm -13 "$TEMP_DIR/fs_files.txt" "$TEMP_DIR/db_files.txt" > "$TEMP_DIR/deleted_files.txt"
deleted_count=$(wc -l < "$TEMP_DIR/deleted_files.txt" | tr -d ' ')

comm -23 "$TEMP_DIR/fs_folders.txt" "$TEMP_DIR/db_folders.txt" > "$TEMP_DIR/new_folders.txt"
new_folders_count=$(wc -l < "$TEMP_DIR/new_folders.txt" | tr -d ' ')

comm -13 "$TEMP_DIR/fs_folders.txt" "$TEMP_DIR/db_folders.txt" > "$TEMP_DIR/deleted_folders.txt"
deleted_folders_count=$(wc -l < "$TEMP_DIR/deleted_folders.txt" | tr -d ' ')

echo "Changes detected:"
echo "  New files: $new_count"
echo "  Deleted files: $deleted_count"
echo "  New folders: $new_folders_count"
echo "  Deleted folders: $deleted_folders_count"
echo ""

echo "Phase 5: Updating database..."

if [ "$new_folders_count" -gt 0 ]; then
    echo "Adding $new_folders_count new folders..."
    while read -r folder; do
        name=$(basename "$folder")
        parent=$(dirname "$folder")
        
        folder_escaped=$(echo "$folder" | sed "s/'/''/g")
        name_escaped=$(echo "$name" | sed "s/'/''/g")
        parent_escaped=$(echo "$parent" | sed "s/'/''/g")
        
        sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO items (type, path, name, parent_path, status) VALUES ('FOLDER', '$folder_escaped', '$name_escaped', '$parent_escaped', 'active');"
    done < "$TEMP_DIR/new_folders.txt"
fi

if [ "$new_count" -gt 0 ]; then
    echo "Adding $new_count new files..."
    while IFS='|' read -r path size modified; do
        name=$(basename "$path")
        parent=$(dirname "$path")
        
        path_escaped=$(echo "$path" | sed "s/'/''/g")
        name_escaped=$(echo "$name" | sed "s/'/''/g")
        parent_escaped=$(echo "$parent" | sed "s/'/''/g")
        
        sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO items (type, path, name, parent_path, size, modified, status) VALUES ('FILE', '$path_escaped', '$name_escaped', '$parent_escaped', $size, $modified, 'active');"
    done < "$TEMP_DIR/new_files.txt"
fi

if [ "$deleted_count" -gt 0 ]; then
    echo "Marking $deleted_count deleted files..."
    while IFS='|' read -r path size modified; do
        path_escaped=$(echo "$path" | sed "s/'/''/g")
        sqlite3 "$DB_FILE" "UPDATE items SET status='deleted', indexed_at=strftime('%s', 'now') WHERE path='$path_escaped';"
    done < "$TEMP_DIR/deleted_files.txt"
fi

if [ "$deleted_folders_count" -gt 0 ]; then
    echo "Marking $deleted_folders_count deleted folders..."
    while read -r folder; do
        folder_escaped=$(echo "$folder" | sed "s/'/''/g")
        sqlite3 "$DB_FILE" "UPDATE items SET status='deleted', indexed_at=strftime('%s', 'now') WHERE path='$folder_escaped';"
    done < "$TEMP_DIR/deleted_folders.txt"
fi

# Calculate total changes
total_added=$((new_count + new_folders_count))
total_deleted=$((deleted_count + deleted_folders_count))

# Update run statistics
sqlite3 "$DB_FILE" "UPDATE index_runs SET items_added = $total_added, items_deleted = $total_deleted WHERE id = $RUN_ID;"

echo ""
echo "Phase 6: Cleaning up old deleted items (>30 days)..."
old_deleted=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM items WHERE status='deleted' AND indexed_at < strftime('%s', 'now', '-30 days');")
if [ "$old_deleted" -gt 0 ]; then
    sqlite3 "$DB_FILE" "DELETE FROM items WHERE status='deleted' AND indexed_at < strftime('%s', 'now', '-30 days');"
    echo "Removed $old_deleted old deleted items"
fi

echo ""
echo "Phase 7: Optimizing database..."
sqlite3 "$DB_FILE" "VACUUM; ANALYZE;"

# Cleanup temp files
rm -rf "$TEMP_DIR"

echo ""
echo "========================================="
echo "Update Complete!"
echo "========================================="

# Get final statistics
sqlite3 -column -header "$DB_FILE" <<EOF
SELECT 'Database Statistics' as '';

SELECT 
    'Active files' as Category,
    COUNT(*) as Count
FROM items 
WHERE type='FILE' AND status='active'
UNION ALL
SELECT 
    'Active folders',
    COUNT(*)
FROM items 
WHERE type='FOLDER' AND status='active'
UNION ALL
SELECT 
    'Total size',
    ROUND(SUM(size)/1024.0/1024.0/1024.0, 2) || ' GB'
FROM items 
WHERE type='FILE' AND status='active';
EOF

echo ""
echo "This Run (ID: $RUN_ID):"
sqlite3 "$DB_FILE" "SELECT 
    'Date: ' || datetime(run_date, 'unixepoch', 'localtime'),
    'Added: ' || items_added,
    'Deleted: ' || items_deleted,
    'Method: ' || scan_method
FROM index_runs WHERE id = $RUN_ID;" | tr '|' ' '

echo "========================================="