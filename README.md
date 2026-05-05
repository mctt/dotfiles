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

### 2. github_personal key
Ensure you have grabbed your `github_personal` key before proceeding with the prep.sh and bootstrap.sh scripts.

### 3. Run prep.sh
```
mv executable_prep.txt prep.sh
chmod +x prep.sh
sh prep.sh
```

### 4. Run boostrap.sh
```
mv executable_boostrap.txt bootstrap.sh
chmod +x bootstrap.sh
sh boostrap.sh
```

### 5. To push changes use GitHub and chezmoi. unas is the master.
```
ssh unas
push.chezmoi_to_git.sh
```

### 6. To push changes on Termux use;
```
push.chezmoi_to_git_termux.sh
```

# End
