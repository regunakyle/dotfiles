#!/bin/bash

# Assumptions:
# 1. Arch Linux on WSL2
# 2. Running as root
#
# Note to self:
# - Need to manually ignore Mise config in Windows side, otherwise Linux Mise will complain
# - Manually mount a second storage drive to WSL if needed; Use a schedule task (on boot) to mount it automatically

set -euo pipefail

echo "Updating package database..."
sudo pacman -Syu --noconfirm

echo "Installing packages..."
sudo pacman -S --noconfirm \
    7zip \
    age \
    bubblewrap \
    chezmoi \
    fd \
    fzf \
    git \
    git-delta \
    hugo \
    iperf3 \
    mise \
    nano \
    nmap \
    openssh \
    python-docutils \
    ripgrep \
    shellcheck \
    socat \
    tmux \
    uv \
    which \
    zsh

# Python build dependencies
pacman -S --needed base-devel openssl zlib xz tk zstd

# LaTeX
pacman -S texlive-binextra texlive-latexextra texlive-plaingeneric

# Setup
chezmoi init --apply --force regunakyle
mise install

# Write .bash_profile to source files from ~/.bashrc.d
cat > ~/.bash_profile << 'EOF'
for f in ~/.bashrc.d/*; do
  [ -r "$f" ] && source "$f"
done
EOF

echo ""
echo "Installation complete!"
