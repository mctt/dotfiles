
https://claude.ai/share/aefd6d0b-55d3-486e-a847-28e69e8435b7

# Requires
pkg install py311-sqlite3

Perfect! Here's how to use these scripts:
1. Run detox with tracking:
#Run
#python3.11 detox_tracker.py /mnt/pnas/m/p/
# python detox_tracker.py /mnt/pnas/m/p/
cd /root
nano .bashrc
alias python="python3.11"
cd /root/bin/
python detox_tracker.py /mnt/unas/p/synco/


This will:
Scan all files/folders before running detox
Run detox -prlt on your directory
Scan again and record all changes to detox_changes.db
2. View what changed:
# List all timestamps
python3.11 detox_rollback.py --list-timestamps

# View all changes
python3.11 detox_rollback.py --list

# View changes from specific run
python3.11 detox_rollback.py --list --timestamp "2026-01-26T12:34:56"
3. Rollback changes:
# Dry run first (see what would happen)
python3.11 detox_rollback.py --dry-run

# Actually rollback all changes
python3.11 detox_rollback.py

# Rollback only a specific run
python3.11 detox_rollback.py --timestamp "2026-01-26T12:34:56"
4. Query the database directly:
sqlite3 detox_changes.db "SELECT old_name, new_name FROM filename_changes WHERE reverted = 0;"
The database tracks everything: old paths, new paths, timestamps, and whether changes have been reverted. You can switch back and forth as needed!
