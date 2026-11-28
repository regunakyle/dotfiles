#!/bin/bash

# Setup repo, manual input required
termux-change-repo
pkg upgrade -y

termux-setup-storage

echo "Installing packages..."
pkg install -y \
    7zip \
    age \
    chezmoi \
    dnsutils \
    fd \
    fzf \
    git \
    git-delta \
    jq \
    mandoc \
    nmap \
    nodejs-lts \
    python \
    ripgrep \
    rsync \
    sqlite3 \
    tealdeer \
    tmux \
    traceroute \
    wget \
    which \
    yq \
    zip \
    zsh

npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# Key files must be in place before running this
chezmoi init --apply --force regunakyle

git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME"/.antidote

# Nerd Font (Iosevka Term Slab Mono) for Powerlevel10k
font_tmp="$(mktemp -d)"
curl -fLo "$font_tmp/IosevkaTermSlab.tar.xz" \
    https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/IosevkaTermSlab.tar.xz
tar --no-same-owner -xJf "$font_tmp/IosevkaTermSlab.tar.xz" -C "$font_tmp" IosevkaTermSlabNerdFontMono-Regular.ttf
mkdir -p "$HOME/.termux"
cp "$font_tmp/IosevkaTermSlabNerdFontMono-Regular.ttf" "$HOME/.termux/font.ttf"
rm -rf "$font_tmp"
termux-reload-settings

echo ""
echo "Installation complete!"
