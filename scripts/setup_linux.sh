#!/bin/bash
set -euo pipefail

##########################################################################
# This script assumes you installed Fedora KDE with the netinstaller
# and unticked all additional packages (except Firefox and LibreOffice).

# Requires a good internet connection, otherwise you might need to input password
# for sudo multiple times.

# The desktop option targets a desktop with two GPUs (one Intel and one Nvidia),
# of which the Nvidia one would be passed through into a Windows 10 VM for gaming.

# The laptop option targets a Lenovo Thinkpad with AMD APU.

# TODO:
# - Automate the post installation tasks
# - Automate VFIO and Looking Glass installation
# - Add error handling
##########################################################################

# Check desktop or laptop
# https://superuser.com/a/1107191
if [[ "$(cat /sys/class/dmi/id/chassis_type)" == 3 ]]; then
    is_desktop=1
elif [[ " 9 10 11 14 " =~ [[:space:]]$(cat /sys/class/dmi/id/chassis_type)[[:space:]] ]]; then
    is_desktop=0
else
    echo "Unrecognized computer type."
    read -rp "Enter 1 if you are on desktop, 0 if you are on laptop."$'\n' is_desktop
    if [[ ! " 0 1 " =~ [[:space:]]${is_desktop}[[:space:]] ]]; then
        echo "Incorrect input, quitting..."
        exit 1
    fi
fi

if [[ "$is_desktop" == 1 ]]; then
    echo "Running on desktop..."
else
    echo "Running on laptop..."
fi

pushd /tmp

sudo dnf upgrade -y

# Disable searching for missing programs from DNF repo
sudo sed -ie 's/SoftwareSourceSearch=true/SoftwareSourceSearch=false/g' /etc/PackageKit/CommandNotFound.conf

# Delete built-in Fedora flatpak remote
sudo flatpak remote-delete fedora

{
    # Setup flatpak in background
    echo "Setting up Flathub and installing flatpaks..."
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    flatpak install -y flathub \
        com.github.wwmm.easyeffects \
        dev.vencord.Vesktop \
        io.podman_desktop.PodmanDesktop \
        md.obsidian.Obsidian \
        com.moonlight_stream.Moonlight

} &

# Install packages (that need configurations with root) early
sudo dnf install -y \
    @virtualization \
    zsh

# Change default shell to Zsh
sudo chsh -s "$(which zsh)" "$(whoami)"

if [[ "$is_desktop" == 1 ]]; then
    # Enable libvirtd for VM autoboot
    sudo systemctl enable libvirtd
fi

# Setup RPMFusion
echo "Enabling RPMFusion and install media codecs..."
sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Multimedia related
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf update -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

if [[ "$is_desktop" != 1 ]]; then
    sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
    sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
    sudo dnf swap -y mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686
    sudo dnf swap -y mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686
fi

# Add 3rd party repos
sudo dnf copr enable -y zeno/scrcpy
sudo dnf copr enable -y jdxcode/mise
sudo dnf copr enable -y regunakyle/sarasa-gothic
sudo dnf copr enable -y regunakyle/symbols-nerd-font
sudo dnf config-manager setopt google-chrome.enabled=1

# VSCode repo
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

# DNF install
echo "Installing packages from DNF..."
packages="@core \
    age \
    akmod-v4l2loopback \
    btop \
    btrfs-assistant \
    calibre \
    code \
    docker-compose \
    fcitx5-chinese-addons \
    fcitx5-table-extra \
    filezilla \
    fzf \
    git-all \
    git-delta \
    google-chrome-stable \
    gwenview \
    hugo \
    iperf3 \
    kate \
    kolourpaint \
    maven \
    mediawriter \
    meld \
    mise \
    mkcert \
    ncdu \
    nmap \
    obs-studio \
    okular \
    podman-docker \
    python3-docutils \
    python3-sdkmanager \
    qalculate-qt \
    qbittorrent \
    remmina \
    ripgrep \
    sarasa-gothic \
    scrcpy \
    shellcheck \
    sqlitebrowser \
    strawberry \
    symbols-nerd-font \
    tmux \
    tokei \
    uv \
    vlc \
    waypipe \
    yq"

# LaTeX related items for resume
packages="${packages} \
    texlive-latexindent \
    texlive-lipsum \
    texlive-nth \
    texlive-scheme-small"

# python-build dependencies
packages="${packages} \
    make gcc patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel \
    libffi-devel xz-devel libuuid-devel gdbm-libs libnsl2"

if [[ "$is_desktop" == 1 ]]; then
    packages="${packages} \
        intel-media-driver \
        libvirt-devel \
        solaar"

    # Looking Glass dependencies
    packages="${packages} \
        cmake gcc-c++ libglvnd-devel fontconfig-devel spice-protocol nettle-devel \
        pkgconf-pkg-config binutils-devel libxkbcommon-x11-devel wayland-devel wayland-protocols-devel \
        dejavu-sans-mono-fonts libdecor-devel pipewire-devel libsamplerate-devel \
        dkms kernel-devel kernel-headers obs-studio-devel"
else
    packages="${packages} \
        rpi-imager \
        steam \
        tailscale"
fi

# Suppress podman-docker messages
sudo mkdir -p /etc/containers
sudo touch /etc/containers/nodocker

sudo dnf install -y $packages

# Enable Podman socket for Docker compatiblity
systemctl --user enable --now podman.socket

# For Android development
mkdir -p "$HOME/Android/Sdk"
export ANDROID_HOME=$HOME/Android/Sdk
yes | sdkmanager --licenses
sdkmanager "platform-tools"

# Setup Mise and Chezmoi
mise use -g chezmoi

mise exec chezmoi -- chezmoi init --apply --force regunakyle

mise install

# Get antidote
git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME"/.antidote

popd

echo "Waiting for flatpak installation to finish..."
wait

cat <<EOF
Install finished! You should reboot now to ensure everything works correctly.
After that, you may want to config SSH, VSCode, JetBrains, BTRFS snapshots and Windows 10 VM.
EOF

unset is_desktop
unset filename
unset packages

# Start Tmux
exec tmux
