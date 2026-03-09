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
```
https://github.com/mctt/dotfiles/blob/master/dot_gitconfig
```

```
https://github.com/mctt/dotfiles/blob/master/bin/executable_bootstrap.sh
```

```
https://github.com/mctt/dotfiles/blob/master/private_dot_ssh/private_config
```

https://github.com/mctt/dotfiles/blob/master/dot_gitconfig
https://github.com/mctt/dotfiles/blob/master/bin/executable_bootstrap.sh
https://github.com/mctt/dotfiles/blob/master/private_dot_ssh/private_config


### Or just get the compressed file.
```
https://github.com/mctt/dotfiles/blob/master/prep.tar.gz
```

### 1. Verify files
```bash
cd /mnt/unas
ls *.txt
```

```
tar xvzf prep.tar.sh
```

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
