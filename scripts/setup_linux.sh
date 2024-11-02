#!/bin/bash
set -euo pipefail

##########################################################################
# This script assumes you installed Fedora KDE with the netinstaller
# and unticked all additional packages (except Firefox).

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

{
    # Setup flatpak in background
    echo "Setting up Flathub and installing flatpaks..."
    flatpak remote-add --user --if-not-exists --subset=verified flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    flatpak install -y flathub io.podman_desktop.PodmanDesktop

    flatpak install -y flathub \
        com.github.dynobo.normcap \
        com.obsproject.Studio \
        dev.vencord.Vesktop \
        md.obsidian.Obsidian \
        org.fedoraproject.MediaWriter \
        org.gnome.Calculator \
        org.inkscape.Inkscape \
        org.kde.gwenview \
        org.kde.kleopatra \
        org.kde.kolourpaint \
        org.kde.okular \
        org.libreoffice.LibreOffice \
        org.qbittorrent.qBittorrent \
        org.strawberrymusicplayer.strawberry

    if [[ "$is_desktop" != 1 ]]; then
        # For snappier control of Windows VM (using RDP)
        flatpak install -y flathub \
            com.moonlight_stream.Moonlight \
            org.remmina.Remmina
    fi
} &

# Install packages (that need configurations with root) early
sudo dnf install -y \
    @virtualization \
    wireshark \
    zsh

# Change default shell to Zsh
sudo chsh -s "$(which zsh)" "$(whoami)"

# Add user to Wireshark group for non-root usage
sudo usermod -aG wireshark "$(whoami)"

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
sudo dnf install -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

if [[ "$is_desktop" != 1 ]]; then
    sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
    sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
    sudo dnf swap -y mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686
    sudo dnf swap -y mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686
fi

# Add 3rd party repos
sudo dnf copr enable -y zeno/scrcpy
sudo dnf config-manager --set-enabled google-chrome
sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo

# VSCode repo
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null

# DNF install
echo "Installing packages from DNF..."
packages="@core \
    @sound-and-video \
    akmod-v4l2loopback \
    btop \
    btrfs-assistant \
    calibre \
    code \
    distrobox \
    docker-compose \
    dynamips \
    fastfetch \
    fcitx5-chinese-addons \
    fcitx5-table-extra \
    filezilla \
    git \
    gns3-gui \
    gns3-server \
    google-chrome-stable \
    hadolint \
    hugo \
    iperf3 \
    kate \
    maven \
    meld \
    neovim \
    nmap \
    pipx \
    podman-docker \
    scrcpy \
    shellcheck \
    sqlitebrowser \
    tailscale \
    tmux \
    vlc"

# LaTeX related items
packages="${packages} \
    texlive-latexindent \
    texlive-lipsum \
    texlive-nth \
    texlive-scheme-small"

# ASDF Python build dependencies
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
        steam"
fi

sudo dnf install -y $packages

# Enable Podman socket for Docker compatiblity
systemctl --user enable --now podman.socket

# Setup Sarasa Fixed Slab HC and Symbols Nerd Font Mono
# https://wiki.archlinux.org/title/fonts#Manual_installation
echo "Setting up Sarasa Fixed Slab HC and Nerd Font..."
filename=$(curl -fsSL "https://api.github.com/repos/be5invis/Sarasa-Gothic/releases/latest" |
    jq -c '.assets | map(select(.name | test("SarasaFixedSlabHC-TTF-[0-9\\.]+") ))[0].browser_download_url' |
    xargs curl -JLOw '%{filename_effective}')
7z x -o"$HOME/.local/share/fonts/${filename%.*}" "$filename"

filename=NerdFontsSymbolsOnly.tar.xz
wget -O $filename https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$filename
mkdir ${filename%%.*}
tar -xf $filename -C ${filename%%.*}
mv ./${filename%%.*}/ "$HOME/.local/share/fonts"

fc-cache -f

# Setup binaries from various sources
local_bin="$HOME/.local/bin"
mkdir -p "$local_bin"

# google-java-format
echo "Setting up google-java-format..."
wget -O "$local_bin/google-java-format" https://github.com/google/google-java-format/releases/latest/download/google-java-format_linux-x86-64
chmod u+x "$local_bin/google-java-format"

# Get asdf
echo "Setting up asdf and Chezmoi..."
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch \
    "$(git -c 'versionsort.suffix=-' ls-remote --exit-code --refs --sort='version:refname' --tags https://github.com/asdf-vm/asdf.git '*.*.*' | tail --lines=1 | cut --delimiter='/' --fields=3)"

source "$HOME/.asdf/asdf.sh"

asdf plugin-add chezmoi
asdf plugin-add java
asdf plugin-add k9s
asdf plugin-add nodejs
asdf plugin-add python

asdf install chezmoi latest
asdf global chezmoi latest

chezmoi init --apply regunakyle

# Get antidote
git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME"/.antidote

# Add variables to Bash start files in case Bash is called for some unknown reason
cat <<'EOF' >>~/.bash_profile
# https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland#KDE_Plasma
export XMODIFIERS=@im=fcitx
EOF

cat <<'EOF' >>~/.bashrc

# Point all Docker services to the Podman socket
export DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock

# Source asdf
source "$HOME/.asdf/asdf.sh"
source "$HOME/.asdf/completions/asdf.bash"

# ASDF java: Set JAVA_HOME
if [[ $(command -v asdf &>/dev/null && asdf list java 2>/dev/null | grep "^\s*\*") ]]; then
  source ~/.asdf/plugins/java/set-java-home.zsh
fi

# History substring search 
bind '"\e[1;5A":history-substring-search-backward' # Ctrl+Up
bind '"\e[1;5B":history-substring-search-forward' # Ctrl+Down
EOF

popd

echo "Waiting for flatpak installation to finish..."
wait

cat <<EOF
Install finished! You should reboot now to ensure everything works correctly.
After that, you may want to config fcitx5, SSH/GPG, VSCode and Windows 10 VM.
EOF

unset is_desktop
unset filename
unset packages
unset local_bin

# Start Zsh
zsh
