
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

### Option A — Download individual files from GitHub
Click ••• Menu and Download on each file, then rename and set permissions:

1. https://github.com/mctt/dotfiles/blob/master/dot_gitconfig
2. https://github.com/mctt/dotfiles/blob/master/bin/executable_bootstrap.sh
3. https://github.com/mctt/dotfiles/blob/master/private_dot_ssh/private_config
4. https://github.com/mctt/dotfiles/blob/master/prep.sh

```bash
cd /mnt/unas

cp dot_gitconfig ~/.gitconfig
chmod 600 ~/.gitconfig

mkdir -p ~/.ssh
cp private_config ~/.ssh/config
chmod 600 ~/.ssh/config

cp executable_bootstrap.sh ~/bin/bootstrap.sh
chmod 755 ~/bin/bootstrap.sh

chmod +x prep.sh
```

### Option B — Download the compressed file (recommended)
- https://github.com/mctt/dotfiles/blob/master/prep.tar.gz

Click ••• Menu and Download.

### 1. Copy github_personal key
Ensure you have copied your `github_personal` key to `/mnt/unas/github_personal` before proceeding.

### 2. Extract and verify files
```bash
cd /mnt/unas
tar xvzf prep.tar.gz
```

Expected files after extraction:
```
private_dot_ssh/private_config
bin/executable_bootstrap.sh
prep.sh
dot_gitconfig
```

### 3. Run prep.sh
```bash
sh /mnt/unas/prep.sh
```

prep.sh will:
- Set the hostname
- Install bash
- Copy SSH config, gitconfig, bootstrap.sh and github_personal to correct locations
- Set correct file permissions

### 4. Run bootstrap.sh
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
~/bin/push.chezmoi_to_git.sh
```

### On Termux (S23Ultra):
```bash
push.chezmoi_to_git_termux.sh
```

### On any other jail to pull latest changes:
```bash
chezmoi update
```

---

## 📎 Reference
- Dotfiles repo: https://github.com/mctt/dotfiles
- Setup conversation: https://claude.ai/share/256f15e2-cd71-409e-9270-7bef52dfbffa

# End
```

Update on unas:

```bash
chezmoi edit ~/README.md
chezmoi apply ~/README.md
~/bin/push.chezmoi_to_git.sh
```
