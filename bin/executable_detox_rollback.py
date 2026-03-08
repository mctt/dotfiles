#!/usr/bin/env python3.11
"""
Requires;
pkg install py311-sqlite3

script
https://claude.ai/public/artifacts/0cf63cb2-f8de-4e34-947e-2ca2505ea028

claude conversation
https://claude.ai/share/aefd6d0b-55d3-486e-a847-28e69e8435b7

Rollback detox changes using the SQLite database
Usage: python3.11 detox_rollback.py [--timestamp TIMESTAMP] [--dry-run]
"""

import sqlite3
import os
import sys
import argparse
from datetime import datetime

DB_PATH = "detox_changes.db"

def get_timestamps(conn):
    """Get all available timestamps"""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT DISTINCT timestamp, COUNT(*) as num_changes
        FROM filename_changes
        WHERE reverted = 0
        ORDER BY timestamp DESC
    """)
    return cursor.fetchall()

def rollback_changes(conn, timestamp=None, dry_run=False):
    """Rollback changes to original filenames"""
    cursor = conn.cursor()
    
    if timestamp:
        query = """
            SELECT id, old_path, new_path, old_name, new_name, is_directory
            FROM filename_changes
            WHERE timestamp = ? AND reverted = 0
            ORDER BY is_directory DESC, id DESC
        """
        cursor.execute(query, (timestamp,))
    else:
        # Rollback all non-reverted changes, most recent first
        query = """
            SELECT id, old_path, new_path, old_name, new_name, is_directory
            FROM filename_changes
            WHERE reverted = 0
            ORDER BY timestamp DESC, is_directory DESC, id DESC
        """
        cursor.execute(query)
    
    changes = cursor.fetchall()
    
    if not changes:
        print("No changes to rollback")
        return 0
    
    print(f"Found {len(changes)} changes to rollback")
    if dry_run:
        print("\n*** DRY RUN MODE - No actual changes will be made ***\n")
    
    successful = 0
    failed = 0
    
    for change_id, old_path, new_path, old_name, new_name, is_directory in changes:
        item_type = "DIR " if is_directory else "FILE"
        
        # Check if the new path exists
        if not os.path.exists(new_path):
            print(f"[SKIP] {item_type}: {new_path} (doesn't exist)")
            continue
        
        # Check if old path already exists (would cause conflict)
        if os.path.exists(old_path):
            print(f"[CONFLICT] {item_type}: {old_path} already exists!")
            failed += 1
            continue
        
        print(f"[{item_type}] {new_name} -> {old_name}")
        
        if not dry_run:
            try:
                os.rename(new_path, old_path)
                
                # Mark as reverted in database
                cursor.execute("""
                    UPDATE filename_changes
                    SET reverted = 1
                    WHERE id = ?
                """, (change_id,))
                
                successful += 1
            except Exception as e:
                print(f"  ERROR: {e}")
                failed += 1
        else:
            successful += 1
    
    if not dry_run:
        conn.commit()
    
    print(f"\nRollback complete:")
    print(f"  Successful: {successful}")
    print(f"  Failed: {failed}")
    
    return successful

def list_changes(conn, timestamp=None):
    """List all changes"""
    cursor = conn.cursor()
    
    if timestamp:
        cursor.execute("""
            SELECT timestamp, old_path, new_path, is_directory, reverted
            FROM filename_changes
            WHERE timestamp = ?
            ORDER BY is_directory DESC, old_path
        """, (timestamp,))
    else:
        cursor.execute("""
            SELECT timestamp, old_path, new_path, is_directory, reverted
            FROM filename_changes
            ORDER BY timestamp DESC, is_directory DESC, old_path
        """)
    
    changes = cursor.fetchall()
    
    print(f"\nTotal changes in database: {len(changes)}\n")
    
    for ts, old, new, is_dir, reverted in changes:
        item_type = "DIR " if is_dir else "FILE"
        status = "[REVERTED]" if reverted else "[ACTIVE]  "
        print(f"{status} {item_type} {ts}")
        print(f"  Old: {old}")
        print(f"  New: {new}")
        print()

def main():
    parser = argparse.ArgumentParser(description="Rollback detox filename changes")
    parser.add_argument('--timestamp', help='Rollback only changes from this timestamp')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without actually doing it')
    parser.add_argument('--list', action='store_true', help='List all changes in database')
    parser.add_argument('--list-timestamps', action='store_true', help='List available timestamps')
    
    args = parser.parse_args()
    
    if not os.path.exists(DB_PATH):
        print(f"Error: Database {DB_PATH} not found")
        sys.exit(1)
    
    conn = sqlite3.connect(DB_PATH)
    
    try:
        if args.list_timestamps:
            timestamps = get_timestamps(conn)
            if timestamps:
                print("\nAvailable timestamps with non-reverted changes:\n")
                for ts, count in timestamps:
                    print(f"  {ts}: {count} changes")
                print()
            else:
                print("\nNo non-reverted changes found in database\n")
        
        elif args.list:
            list_changes(conn, args.timestamp)
        
        else:
            # Perform rollback
            print("Detox Rollback Script")
            print(f"Database: {DB_PATH}")
            print("-" * 60)
            
            if args.timestamp:
                print(f"Rolling back changes from: {args.timestamp}")
            else:
                print("Rolling back ALL non-reverted changes")
            
            rollback_changes(conn, args.timestamp, args.dry_run)
    
    finally:
        conn.close()

if __name__ == "__main__":
    main()
