#!/bin/bash
set -euo pipefail

##########################################################################
# This script assumes you installed Fedora KDE with the netinstaller
# and unticked all additional packages (except Firefox).

# The desktop option targets a desktop with two GPUs (one Intel and one Nvidia),
# of which the Nvidia one would be passed through into a Windows 10 VM for gaming.

# The laptop option targets a Lenovo Thinkpad with AMD APU.

# TODO:
# - Automate the post installation tasks
# - Automate VFIO and Looking Glass installation
# - Add error handling
# - Handle sudo timeout
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

sudo dnf install -y \
    distrobox \
    podman-docker \
    zsh

# Change default shell to Zsh
sudo chsh -s "$(which zsh)" "$(whoami)"

# Enable Podman socket for Docker compatiblity
systemctl --user enable --now podman.socket

if [[ "$is_desktop" == 1 ]]; then
    # Create distrobox (in background) for building softwares
    {
        echo "Creating distrobox container for Looking Glass build..."
        distrobox create \
            --image registry.fedoraproject.org/fedora-toolbox \
            --name toolbox \
            --pull \
            --no-entry \
            --additional-packages "zsh texlive-scheme-full cmake gcc gcc-c++ libglvnd-devel fontconfig-devel spice-protocol make nettle-devel 
                                    pkgconf-pkg-config binutils-devel libXi-devel libXinerama-devel libXcursor-devel 
                                    libXpresent-devel libxkbcommon-x11-devel wayland-devel wayland-protocols-devel 
                                    libXScrnSaver-devel libXrandr-devel dejavu-sans-mono-fonts 
                                    libdecor-devel pipewire-devel libsamplerate-devel obs-studio-devel 
                                    patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel libuuid-devel gdbm-libs libnsl2"

        podman start toolbox
    } &
fi

# Setup RPMFusion
echo "Enabling RPMFusion and install media codecs..."
sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Add 3rd party repos
sudo dnf copr enable -y zeno/scrcpy
sudo dnf config-manager --set-enabled google-chrome

# VSCode repo
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null

# Multimedia related
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf install -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

if [[ "$is_desktop" != 1 ]]; then
    sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
    sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
    sudo dnf swap -y mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686
    sudo dnf swap -y mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686
fi

# DNF install
echo "Installing packages from DNF..."
sudo dnf install -y \
    @core \
    @sound-and-video \
    @virtualization \
    akmod-v4l2loopback \
    btop \
    calibre \
    code \
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
    nmap \
    pipx \
    scrcpy \
    shellcheck \
    sqlitebrowser \
    tmux \
    vlc \
    wireshark

# Add user to Wireshark group for non-root usage
sudo usermod -aG wireshark "$(whoami)"

if [[ "$is_desktop" == 1 ]]; then
    sudo dnf install -y \
        dkms \
        intel-media-driver \
        kernel-devel \
        kernel-headers \
        solaar

    # Enable libvirtd for VM autoboot
    sudo systemctl enable libvirtd
else
    sudo dnf install -y \
        steam
fi

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
unset local_bin

# Start Zsh
zsh
