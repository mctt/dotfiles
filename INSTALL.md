# unas jail — package install
# https://claude.ai/share/35e8c040-aaf8-458a-85eb-ba0888a38648

## pkg packages

```sh
pkg query -e '%a = 0' '%n' | sort
```

```sh
pkg install -y \
  bash \
  bash-completion \
  bat \
  chezmoi \
  eza \
  fd-find \
  fdupes \
  fusefs-sshfs \
  fzf \
  gdu \
  git \
  go-ntfy \
  jdupes \
  nano \
  ncdu \
  py311-pip \
  py311-sqlite3 \
  python \
  rclone \
  ripgrep \
  rsync \
  screen \
  sqlite3 \
  tmux
```

## Python packages

```sh
pip list --not-required --format=freeze | cut -d= -f1 | sort
```
## unas python pip
```sh
pip install \
  detoxpy \
  packaging
```
## Termux python pip
```sh
detoxpy                                           gallery_dl
httpx                                             pip
poetry
setuptools
termux-apt-repo
wheel                                             yt-dlp
zstandard
```