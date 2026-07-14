#!/bin/bash

# Assumptions:
# 1. Arch Linux on WSL2
# 2. Running as root
#
# Note to self:
# - Need to manually ignore Mise config in Windows side: `mise trust --ignore /mnt/c/Users/eleung/.config/mise/config.toml`
# - Manually mount a second storage drive to WSL if needed; Use a schedule task (on boot) to mount it automatically
#   See https://learn.microsoft.com/en-us/windows/wsl/wsl2-mount-disk#mounting-an-unpartitioned-disk

set -euo pipefail

echo "Updating package database..."
pacman -Syu --noconfirm

echo "Installing packages..."
pacman -S --noconfirm \
    7zip \
    age \
    bubblewrap \
    chezmoi \
    dive \
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
pacman -S --needed --noconfirm base-devel openssl zlib xz tk zstd

# Setup
chezmoi init --apply --force regunakyle
mise install

# Write .bash_profile to source files from ~/.bashrc.d
cat > ~/.bash_profile << 'EOF'
for f in ~/.bashrc.d/*; do
  [ -r "$f" ] && source "$f"
done
EOF

cat > /etc/wsl.conf << 'EOF'
[interop]
appendWindowsPath=true
EOF

git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME"/.antidote

echo ""
echo "Installation complete!"
