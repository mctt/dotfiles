#!/bin/bash
# https://claude.ai/share/256f15e2-cd71-409e-9270-7bef52dfbffa
# chezmoi add ~/.bashrc
chezmoi cd
git add .
git commit -m "update from $(hostname)"
git push
