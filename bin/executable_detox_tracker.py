#!/usr/bin/env python3.11
"""
Requires;
pkg install py311-sqlite3

# Usage;
cd to /mnt/pnas/m/p/synced/tox/
Why? so the database is created there, or not, up to you.

# https://claude.ai/public/artifacts/0cf63cb2-f8de-4e34-947e-2ca2505ea028

# Usage
python detox_tracker.py /mnt/pnas/m/p/


Detox wrapper that tracks all filename changes in SQLite database
Usage: python3.11 detox_tracker.py /mnt/pnas/m/p/
"""

import sqlite3
import subprocess
import os
import sys
from pathlib import Path
from datetime import datetime

"""
DB_PATH = "/mnt/whatever/detox_changes.db"
"""
DB_PATH = "detox_changes.db"

def init_database():
    """Initialize SQLite database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS filename_changes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            old_path TEXT NOT NULL,
            new_path TEXT NOT NULL,
            parent_dir TEXT NOT NULL,
            old_name TEXT NOT NULL,
            new_name TEXT NOT NULL,
            is_directory INTEGER NOT NULL,
            reverted INTEGER DEFAULT 0
        )
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_old_path ON filename_changes(old_path)
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_timestamp ON filename_changes(timestamp)
    """)
    
    conn.commit()
    return conn

def get_all_paths(root_dir):
    """Get all file and directory paths recursively"""
    paths = []
    for dirpath, dirnames, filenames in os.walk(root_dir, topdown=False):
        # Add files
        for filename in filenames:
            full_path = os.path.join(dirpath, filename)
            paths.append((full_path, False))
        
        # Add directories
        for dirname in dirnames:
            full_path = os.path.join(dirpath, dirname)
            paths.append((full_path, True))
    
    return paths

def run_detox(target_dir):
    """Run detox on the target directory"""
    print(f"Running detox on: {target_dir}")
    result = subprocess.run(
        ['detox', '-prlt', target_dir],
        capture_output=True,
        text=True
    )
    
    print(result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr)
    
    return result.returncode == 0

def record_changes(conn, before_paths, after_paths, timestamp):
    """Compare before/after and record changes"""
    cursor = conn.cursor()
    
    # Create lookup dictionaries
    before_dict = {path: is_dir for path, is_dir in before_paths}
    after_dict = {path: is_dir for path, is_dir in after_paths}
    
    changes = []
    
    # Find what changed
    for old_path, is_dir in before_paths:
        if old_path not in after_dict:
            # This path was renamed
            # Try to find the new name by checking parent directory
            parent = os.path.dirname(old_path)
            old_name = os.path.basename(old_path)
            
            # Look for a new file/dir in the same parent that wasn't there before
            possible_new = [p for p in after_dict.keys() 
                          if os.path.dirname(p) == parent 
                          and p not in before_dict
                          and after_dict[p] == is_dir]
            
            if possible_new:
                # Assume the first match is the renamed file
                new_path = possible_new[0]
                new_name = os.path.basename(new_path)
                
                changes.append({
                    'timestamp': timestamp,
                    'old_path': old_path,
                    'new_path': new_path,
                    'parent_dir': parent,
                    'old_name': old_name,
                    'new_name': new_name,
                    'is_directory': 1 if is_dir else 0
                })
    
    # Insert changes into database
    if changes:
        cursor.executemany("""
            INSERT INTO filename_changes 
            (timestamp, old_path, new_path, parent_dir, old_name, new_name, is_directory)
            VALUES 
            (:timestamp, :old_path, :new_path, :parent_dir, :old_name, :new_name, :is_directory)
        """, changes)
        
        conn.commit()
        print(f"\nRecorded {len(changes)} filename changes to database")
    else:
        print("\nNo changes detected")
    
    return len(changes)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3.11 detox_tracker.py <target_directory>")
        sys.exit(1)
    
    target_dir = sys.argv[1]
    
    if not os.path.isdir(target_dir):
        print(f"Error: {target_dir} is not a directory")
        sys.exit(1)
    
    print(f"Detox Tracker - Reversible filename sanitization")
    print(f"Target: {target_dir}")
    print(f"Database: {DB_PATH}")
    print("-" * 60)
    
    # Initialize database
    conn = init_database()
    
    # Get timestamp for this run
    timestamp = datetime.now().isoformat()
    
    # Record before state
    print("\nScanning directory structure...")
    before_paths = get_all_paths(target_dir)
    print(f"Found {len(before_paths)} items (files + directories)")
    
    # Run detox
    print("\n" + "=" * 60)
    if not run_detox(target_dir):
        print("Warning: detox returned non-zero exit code")
    
    print("=" * 60)
    
    # Record after state
    print("\nScanning directory structure again...")
    after_paths = get_all_paths(target_dir)
    
    # Record changes
    num_changes = record_changes(conn, before_paths, after_paths, timestamp)
    
    conn.close()
    
    print(f"\nComplete! Database saved to: {DB_PATH}")
    print(f"Run timestamp: {timestamp}")
    print(f"\nTo view changes: sqlite3 {DB_PATH} 'SELECT * FROM filename_changes'")
    print(f"To rollback: python3.11 detox_rollback.py")

if __name__ == "__main__":
    main()
