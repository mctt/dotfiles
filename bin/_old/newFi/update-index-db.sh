#!/bin/bash

DB_FILE="/mnt/unas/p/video_index.db"
SEARCH_DIR="/mnt/unas/p/"

echo "SQLite Video Index - Incremental Update"
echo "========================================"
echo ""

# Create database and tables if they don't exist
if [ ! -f "$DB_FILE" ]; then
    echo "Database doesn't exist. Creating new database..."
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
    folders_scanned INTEGER DEFAULT 0,
    files_scanned INTEGER DEFAULT 0
);
EOF
    echo "Database created."
    echo ""
fi

# Start tracking this run
RUN_ID=$(sqlite3 "$DB_FILE" "INSERT INTO index_runs DEFAULT VALUES; SELECT last_insert_rowid();")

echo "Starting incremental index update..."
echo "Run ID: $RUN_ID"
echo ""

# Counters
folders_found=0
files_found=0
items_added=0
items_updated=0
items_deleted=0

# Mark all existing items as 'pending_check' - we'll verify they still exist
sqlite3 "$DB_FILE" "UPDATE items SET status='pending_check' WHERE status='active';"

echo "Phase 1: Scanning and updating folders..."
find "$SEARCH_DIR" -type d | while read -r folder; do
    name=$(basename "$folder")
    parent=$(dirname "$folder")
    
    # Escape single quotes for SQL
    folder_escaped=$(echo "$folder" | sed "s/'/''/g")
    name_escaped=$(echo "$name" | sed "s/'/''/g")
    parent_escaped=$(echo "$parent" | sed "s/'/''/g")
    
    # Check if item exists in database
    exists=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM items WHERE path='$folder_escaped';")
    
    if [ "$exists" -eq 0 ]; then
        # New folder - insert it
        sqlite3 "$DB_FILE" "INSERT INTO items (type, path, name, parent_path, status) VALUES ('FOLDER', '$folder_escaped', '$name_escaped', '$parent_escaped', 'active');"
        ((items_added++))
    else
        # Existing folder - mark as active and update if needed
        sqlite3 "$DB_FILE" "UPDATE items SET status='active', name='$name_escaped', parent_path='$parent_escaped', indexed_at=strftime('%s', 'now') WHERE path='$folder_escaped';"
        ((items_updated++))
    fi
    
    ((folders_found++))
    if [ $((folders_found % 500)) -eq 0 ]; then
        echo "  Processed $folders_found folders... (Added: $items_added, Updated: $items_updated)"
    fi
done

echo "  Total folders processed: $folders_found"
echo "  New folders added: $items_added"
echo ""

# Reset counters for files
items_added=0
items_updated=0

echo "Phase 2: Scanning and updating video files..."
find "$SEARCH_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.mpg" -o -iname "*.mpeg" \) | while read -r file; do
    name=$(basename "$file")
    parent=$(dirname "$file")
    
    # Get file size and modification time
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
    
    # Check if item exists and get current modified time
    result=$(sqlite3 "$DB_FILE" "SELECT COUNT(*), modified FROM items WHERE path='$file_escaped';")
    exists=$(echo "$result" | cut -d'|' -f1)
    db_modified=$(echo "$result" | cut -d'|' -f2)
    
    if [ "$exists" -eq 0 ]; then
        # New file - insert it
        sqlite3 "$DB_FILE" "INSERT INTO items (type, path, name, parent_path, size, modified, status) VALUES ('FILE', '$file_escaped', '$name_escaped', '$parent_escaped', $size, $modified, 'active');"
        ((items_added++))
    else
        # Existing file - check if modified
        if [ "$modified" != "$db_modified" ] || [ -z "$db_modified" ]; then
            # File was modified - update it
            sqlite3 "$DB_FILE" "UPDATE items SET status='active', name='$name_escaped', parent_path='$parent_escaped', size=$size, modified=$modified, indexed_at=strftime('%s', 'now') WHERE path='$file_escaped';"
            ((items_updated++))
        else
            # File unchanged - just mark as active
            sqlite3 "$DB_FILE" "UPDATE items SET status='active' WHERE path='$file_escaped';"
        fi
    fi
    
    ((files_found++))
    if [ $((files_found % 500)) -eq 0 ]; then
        echo "  Processed $files_found files... (Added: $items_added, Updated: $items_updated)"
    fi
done

echo "  Total video files processed: $files_found"
echo "  New files added: $items_added"
echo "  Files updated: $items_updated"
echo ""

echo "Phase 3: Removing deleted items..."
# Items still marked as 'pending_check' no longer exist on disk
items_deleted=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM items WHERE status='pending_check';")

if [ "$items_deleted" -gt 0 ]; then
    # Move to 'deleted' status instead of removing (keeps history)
    sqlite3 "$DB_FILE" "UPDATE items SET status='deleted', indexed_at=strftime('%s', 'now') WHERE status='pending_check';"
    echo "  Marked $items_deleted items as deleted"
else
    echo "  No deleted items found"
fi
echo ""

# Update run statistics
sqlite3 "$DB_FILE" <<EOF
UPDATE index_runs SET 
    items_added = (SELECT COUNT(*) FROM items WHERE indexed_at >= (SELECT run_date FROM index_runs WHERE id=$RUN_ID) AND status='active'),
    items_updated = $items_updated,
    items_deleted = $items_deleted,
    folders_scanned = $folders_found,
    files_scanned = $files_found
WHERE id = $RUN_ID;
EOF

# Clean up old deleted items (optional - remove items deleted more than 30 days ago)
echo "Phase 4: Cleaning up old deleted items (older than 30 days)..."
old_deleted=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM items WHERE status='deleted' AND indexed_at < strftime('%s', 'now', '-30 days');")
if [ "$old_deleted" -gt 0 ]; then
    sqlite3 "$DB_FILE" "DELETE FROM items WHERE status='deleted' AND indexed_at < strftime('%s', 'now', '-30 days');"
    echo "  Removed $old_deleted old deleted items from database"
else
    echo "  No old deleted items to remove"
fi
echo ""

# Optimize database
echo "Phase 5: Optimizing database..."
sqlite3 "$DB_FILE" "VACUUM; ANALYZE;"
echo "  Database optimized"
echo ""

# Show final statistics
echo "========================================="
echo "Index update completed successfully!"
echo "========================================="
sqlite3 "$DB_FILE" <<EOF
.mode column
.headers on

SELECT 
    'Run Statistics' as '';
    
SELECT 
    datetime(run_date, 'unixepoch', 'localtime') as 'Run Date',
    items_added as 'Added',
    items_updated as 'Updated',
    items_deleted as 'Deleted',
    folders_scanned as 'Folders',
    files_scanned as 'Files'
FROM index_runs 
WHERE id = $RUN_ID;

SELECT '';

SELECT 'Database Statistics' as '';

SELECT 
    'Active items' as Category,
    COUNT(*) as Count
FROM items 
WHERE status='active'
UNION ALL
SELECT 
    'Deleted items',
    COUNT(*)
FROM items 
WHERE status='deleted'
UNION ALL
SELECT 
    'Active folders',
    COUNT(*)
FROM items 
WHERE type='FOLDER' AND status='active'
UNION ALL
SELECT 
    'Active files',
    COUNT(*)
FROM items 
WHERE type='FILE' AND status='active'
UNION ALL
SELECT 
    'Total size',
    ROUND(SUM(size)/1024.0/1024.0/1024.0, 2) || ' GB'
FROM items 
WHERE type='FILE' AND status='active';
EOF
echo "========================================="

# Show recent index history
echo ""
echo "Recent Index Runs:"
sqlite3 "$DB_FILE" <<'EOF'
.mode column
.headers on
SELECT 
    datetime(run_date, 'unixepoch', 'localtime') as 'Date',
    items_added as 'Added',
    items_updated as 'Updated',
    items_deleted as 'Deleted',
    folders_scanned + files_scanned as 'Total Scanned'
FROM index_runs 
ORDER BY run_date DESC 
LIMIT 5;
EOF
echo "========================================="