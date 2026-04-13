
in [Section 'fi.sh'](#fi.sh) 

# TrueNAS Jail Configuration Guide

This guide outlines the essential steps for setting up a TrueNAS jail, configuring networking, and mounting external storage.

---

## ⚙️ Initial Jail Setup
When creating the jail, ensure the following options are checked to allow for updates and proper networking:

* **✅ NAT**: Must be enabled or `pkg install` will fail due to no internet access.
* **✅ VNET**: Enabled to give the jail its own virtual network stack.

---

## 📂 Add Storage
Map your host datasets to the jail's internal directory:

**Mount Point:**
`Source: /mnt/pnas/m/` ➡️ `Destination: /mnt/unas/`

---

## 🚀 Configuration & Bootstrapping

Once the storage is mounted, enter the jail and verify your configuration files.

1. https://github.com/mctt/dotfiles/blob/master/dot_gitconfig
1. https://github.com/mctt/dotfiles/blob/master/bin/executable_bootstrap.sh
1. https://github.com/mctt/dotfiles/blob/master/private_dot_ssh/private_config
1. https://github.com/mctt/dotfiles/blob/master/prep.sh

### Or just Download the compressed file.
- https://github.com/mctt/dotfiles/blob/master/prep.tar.gz

••• Menu and Download.

### 1. Verify files
```bash
cd /mnt/unas
ls *.txt
```

```
tar xvzf prep.tar.gz
```

Expected Files:
```
/mnt/unas/dot_gitconfig.txt
/mnt/unas/executable_bootstrap.txt
/mnt/unas/private_config.txt
/mnt/unas/github_personal
```

### 2. Run Bootstrap
Ensure you have grabbed your `github_personal` key before proceeding with the bootstrap script.

### 3. Run prep.sh
```
mv executable_prep.txt prep.sh
chmod +x prep.sh
sh prep.sh
```
That's it. You can now start using your bash environment.

## fi.sh <a id='fi.sh'></a>

# fi.sh — Video File Index Search & Transfer

`fi.sh` searches a SQLite video index (built by `ultimate-index-update.sh`) and copies matching files and folders to a staging destination using rsync. It supports flexible include/exclude filtering on both filenames and directory paths, with an optional batch mode for processing multiple searches from a file.

---

## Dependencies

| Tool | Purpose |
|------|---------|
| `sqlite3` | Query the video index database |
| `rsync` | Copy matched files to destination |
| `detox` | Clean up file/folder
| `detoxpy` | detoxpy is better. It doesn't fail and works well with detox -prlt . Of course you have detoxpy aliases to detox.|
| `bash` | v4+ (uses arrays, `read -ra`, process substitution) |

The index database must exist at `/mnt/unas/p/video_index.db`. Run `ultimate-index-update.sh` first if it doesn't.

---

## Usage

```bash
fi.sh [OPTIONS] [SEARCH_TERMS...]
```

### Options

| Flag | Description |
|------|-------------|
| `-y`, `--yes` | Skip the confirmation prompt and proceed automatically |
| `-f`, `-a`, `-b <file>` | Batch mode: read folder names from a file and run each as a separate search |
| `-d <pattern>` | Include only items whose **path** contains this pattern (repeatable; OR logic) |
| `-D <pattern>` | Exclude items whose **path** contains this pattern (repeatable; AND logic) |
| `-h`, `--help` | Show help and exit |

### Search terms

- Bare words are **filename include** terms — all must match (AND logic).
- Terms prefixed with `-` are **filename exclude** terms — none can match.

---

## How matching works

`fi.sh` queries both `FOLDER` and `FILE` rows from the index. The SQL WHERE clause is built from all supplied flags and terms:

| Filter type | Logic |
|-------------|-------|
| Multiple filename include terms | AND (all must appear in name) |
| Multiple filename exclude terms | AND (none may appear in name) |
| Multiple `-d` directory includes | OR (path must match any one) |
| Multiple `-D` directory excludes | AND (path must not match any of them) |

Folder matches are transferred as complete directory trees (video files only). File matches that aren't inside a matched folder are transferred individually, grouped under their parent directory name.

---

## Output destination

The destination path is derived automatically from the search criteria and written to:

```
/mnt/unas/_crap/tmp/<DEST_NAME>/
```

The name is built from flags and terms in this order:

1. `-d` includes → `d_<term>`
2. `-D` excludes → `notd_<term>`
3. Filename include terms → `<term>`
4. Filename exclude terms → `not_<term>`

Parts are joined with underscores. Special characters are sanitised and the name is capped at 100 characters.

**Examples:**

| Command | Destination |
|---------|-------------|
| `fi.sh paola lana` | `/tmp/paola_lana/` |
| `fi.sh paola -lana` | `/tmp/paola_not_lana/` |
| `fi.sh -d hall paola` | `/tmp/d_hall_paola/` |
| `fi.sh -d hall -D vip paola` | `/tmp/d_hall_notd_vip_paola/` |

> The destination folder is only created **after** the user confirms the transfer (or `-y` is passed).

---

## Transfer behaviour

- Folders are copied with `rsync -a --append-verify`, video files only (mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg, mpeg — case-insensitive).
- Individual files are placed under `<DEST>/<parent_folder_name>/` to preserve context.
- If a file or folder listed in the index no longer exists on disk, a warning is printed and the item is skipped. Run `ultimate-index-update.sh` to resync.
- `detox -r` is run on the destination after transfer to sanitise filenames.
- Transfer stats (files transferred, bytes transferred, failures) are printed on completion.

---

## Batch mode

Pass a text file with `-f`, `-a`, or `-b`. Each non-blank, non-comment line is treated as a **folder name** that encodes search arguments using underscore-separated tokens:

| Token | Meaning |
|-------|---------|
| `d` | Next token is a `-d` directory include |
| `notd` | Next token is a `-D` directory exclude |
| `not` | Next token is a filename exclude (`-<term>`) |
| anything else | Filename include term |

**Examples:**

| Folder name in file | Equivalent command |
|--------------------|--------------------|
| `d_hall_lana` | `fi.sh -d hall lana` |
| `ella_not_logan` | `fi.sh ella -logan` |
| `d_fair_LUX` | `fi.sh -d fair LUX` |

Lines starting with `#` are treated as comments and skipped. Each line runs as an independent `fi.sh` invocation. Pass `-y` to auto-confirm all searches in the batch.

```bash
# Run a batch, auto-confirming each transfer
fi.sh -y -f searches.txt
```

---

## Examples

```bash
# Single term search
fi.sh lana

# Multi-term — filename must contain both
fi.sh paola lana

# Exclude a term
fi.sh paola -lana

# Restrict to paths containing "hall"
fi.sh -d hall paola

# Multiple directory filters (OR): path must contain "hall" OR "vip"
fi.sh -d hall -d vip paola

# Exclude a directory from results
fi.sh -D behind paola

# Batch from file, no prompts
fi.sh -y -f my_searches.txt
```

---

## Related scripts

| Script | Purpose |
|--------|---------|
| `ultimate-index-update.sh` | Scans `/mnt/unas/p/` with rsync and `find`, syncs results into the SQLite index at `/mnt/unas/p/video_index.db` |

Run `ultimate-index-update.sh` periodically (or after adding/removing files) to keep the index accurate. `fi.sh` will warn when indexed paths no longer exist on disk.

---

## Notes

- Batch mode uses `eval` to reconstruct and invoke `fi.sh` recursively; folder names in the batch file must not contain shell metacharacters.
- DEBUG lines are currently active in `parse_folder_to_args` and print to stderr during batch runs.
- The `-f`, `-a`, and `-b` flags are aliases for the same behaviour.

- Use FD to generate your input file list;
  ```
fd -t d -d 1 . > directories.txt
  ```

