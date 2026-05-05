
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

Once the storage is mounted, enter the jail and copy your `github_personal` SSH key to `/mnt/unas/github_personal` before proceeding.

### Option A — Download individual files
1. https://github.com/mctt/dotfiles/blob/master/dot_gitconfig
2. https://github.com/mctt/dotfiles/blob/master/bin/executable_bootstrap.sh
3. https://github.com/mctt/dotfiles/blob/master/private_dot_ssh/private_config
4. https://github.com/mctt/dotfiles/blob/master/prep.sh

### Option B — Download the compressed file (recommended)
- https://github.com/mctt/dotfiles/blob/master/prep.tar.gz

Click ••• Menu and Download.

### 1. Extract and verify files
```bash
cd /mnt/unas
tar xvzf prep.tar.gz
```

Expected files after extraction:
```
/mnt/unas/private_dot_ssh/private_config
/mnt/unas/bin/executable_bootstrap.sh
/mnt/unas/prep.sh
/mnt/unas/dot_gitconfig
/mnt/unas/github_personal
```

### 2. Run prep.sh
```bash
sh /mnt/unas/prep.sh
```

prep.sh will:
- Set the hostname
- Install bash
- Copy SSH config, gitconfig, bootstrap.sh and github_personal to correct locations
- Set correct file permissions

### 3. Run bootstrap.sh
```bash
/usr/local/bin/bash ~/bin/bootstrap.sh
```

bootstrap.sh will:
- Install chezmoi, git, nano, screen
- Test GitHub SSH connection
- Pull and apply dotfiles from GitHub
- Install additional packages (sqlite3, python3, bash-completion, eza)
- Install fzf from GitHub
- Install detox from GitHub

---

## 🔄 Keeping Dotfiles in Sync

### unas is the master. To push changes:
```bash
ssh unas
push_chezmoi_to_git.sh
```

### On Termux (S23Ultra):
```bash
push_chezmoi_to_git_termux.sh
```

### On any other jail to pull latest changes:
```bash
chezmoi update
```

---

## 📎 Reference
- Dotfiles repo: https://github.com/mctt/dotfiles
- Setup conversation: https://claude.ai/share/256f15e2-cd71-409e-9270-7bef52dfbffa
```

Update it on unas:

```bash
chezmoi edit ~/README.md
chezmoi apply ~/README.md
~/bin/push_chezmoi_to_git.sh
```

# End
