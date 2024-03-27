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
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    flatpak install -y flathub io.podman_desktop.PodmanDesktop

    flatpak install -y flathub \
        com.borgbase.Vorta \
        com.calibre_ebook.calibre \
        com.github.dynobo.normcap \
        com.google.Chrome \
        com.obsproject.Studio \
        com.obsproject.Studio.Plugin.DroidCam \
        com.obsproject.Studio.Plugin.InputOverlay \
        com.usebruno.Bruno \
        dev.vencord.Vesktop \
        io.dbeaver.DBeaverCommunity \
        md.obsidian.Obsidian \
        org.davmail.DavMail \
        org.fedoraproject.MediaWriter \
        org.filezillaproject.Filezilla \
        org.gnome.Calculator \
        org.gnome.meld \
        org.kde.gwenview \
        org.kde.kleopatra \
        org.kde.kolourpaint \
        org.kde.okular \
        org.mozilla.Thunderbird \
        org.onlyoffice.desktopeditors \
        org.qbittorrent.qBittorrent \
        org.sqlitebrowser.sqlitebrowser \
        org.strawberrymusicplayer.strawberry \
        org.torproject.torbrowser-launcher \
        org.videolan.VLC

    if [[ "$is_desktop" != 1 ]]; then
        # For snappier control of Windows VM (using RDP)
        flatpak install -y flathub org.remmina.Remmina
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

# Create distrobox and install VSCode (in background)
{
    echo "Creating Debian distrobox..."
    distrobox create \
        --image quay.io/toolbx-images/debian-toolbox:12 \
        --name toolbox \
        --pull \
        --no-entry \
        --additional-packages "maven shellcheck texlive-full zsh 
    build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl 
    xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libncursesw5-dev" \
        --init-hooks "command -v code >/dev/null 2>&1 || {
    wget -O /tmp/code.deb \"https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64\" ;
    sudo apt install -y /tmp/code.deb ;
    sudo apt install -y --no-install-recommends fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk3 fcitx5-frontend-qt5 fcitx5-module-xorg kde-config-fcitx5 im-config ;
    sudo ln -s /usr/bin/distrobox-host-exec /usr/local/bin/docker ;
    sudo ln -s /usr/bin/distrobox-host-exec /usr/local/bin/git ;
    sudo ln -s /usr/bin/distrobox-host-exec /usr/local/bin/hadolint ;
    sudo ln -s /usr/bin/distrobox-host-exec /usr/local/bin/pipx ;
    sudo ln -s /usr/bin/distrobox-host-exec /usr/local/bin/podman ;
    }"
    podman start toolbox
} &

# Setup RPMFusion
echo "Enabling RPMFusion and install media codecs..."
sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Add scrcpy repo
sudo dnf copr enable -y zeno/scrcpy

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
    fcitx5-chinese-addons \
    fcitx5-table-extra \
    git \
    hadolint \
    iperf3 \
    kate \
    pipx \
    scrcpy

if [[ "$is_desktop" == 1 ]]; then
    sudo dnf install -y \
        dkms \
        gns3-gui \
        gns3-server \
        intel-media-driver \
        libXpresent-devel \
        solaar
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

# docker-compose
echo "Setting up docker-compose..."
wget -O "$local_bin/docker-compose" https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64
chmod u+x "$local_bin/docker-compose"

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
asdf plugin-add hugo
asdf plugin-add java
asdf plugin-add nodejs
asdf plugin-add python

asdf install chezmoi latest
asdf global chezmoi latest

chezmoi init --apply regunakyle
pipx ensurepath

# Get antidote
git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME"/.antidote

# Add variables to Bash start files in case Bash is called for some unknown reason
cat <<'EOF' >>~/.bash_profile
# https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland#KDE_Plasma
export XMODIFIERS=@im=fcitx
EOF

cat <<'EOF' >>~/.bashrc
export DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock
source "$HOME/.asdf/asdf.sh"
source "$HOME/.asdf/completions/asdf.bash"
# ASDF java: Set JAVA_HOME
if [[ $(command -v asdf &>/dev/null && asdf list java 2>/dev/null | grep "^\s*\*") ]];then
source "$HOME/.asdf/plugins/java/set-java-home.bash"
fi
EOF

popd

echo "Waiting for flatpak installation and distrobox creation to finish..."
wait

cat <<EOF
Install finished! You should reboot now to ensure everything works correctly.
After that, you may want to config fcitx5, SSH/GPG, VSCode, Distrobox and Windows 10 VM.

You should create a network bridge (with your primary NIC as slave) for VM-Host communication.
If you are on laptop, create a QEMU hook that port forward 3389 instead:
https://www.reddit.com/r/VFIO/comments/1blu8tk/comment/kwstktq/
Also, use \`Virtio\` video driver (after installing virtio drivers in the VM) for higher resolution.

NOTE: 
The distrobox probably is still initializing. After it finishes, 
enter it and export the VSCode inside the Distrobox with the following commands:

distrobox-export --bin /usr/bin/code --export-path "\$HOME/.local/bin"
distrobox-export --app code

EOF

cat <<EOS
Here is a rough guideline for installing VFIO and Looking Glass: 

1. Add \`iommu=pt\` to \`/etc/sysconfig/grub\`, then reboot and check IOMMU is enabled"
2. Add \`options vfio-pci ids=<Your device IDs>\` to /etc/modprobe.d/local.conf"
3. Add \`force_drivers+=" vfio vfio_iommu_type1 vfio_pci "\` to /etc/dracut.conf.d/local.conf
4. Regenerate the dracut initramfs with "sudo dracut -f --kver \`uname -r\`" and reboot
(See https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#X_does_not_start_after_enabling_vfio_pci if black screen after reboot)

5. Create a Windows 10 VM:
  - Use Q35+UEFI (Note: Cannot make live snapshot of VM when using UEFI)
  - Use host-passthrough and set CPU cores/threads
  - Use virtio as storage driver
  - (Optional) Delete NIC
  - Edit the XML:
    - CPU pinning by adding <cputune> section; Add emulatorpin (should use all cores not pinned to VM)
    - Add PCIe devices
    - Add \`<feature policy='require' name='topoext'/>\` inside <CPU> if you are using an AMD CPU
  - If you are not going to install Windows on a passed through storage device:
    - Mount virtio-win.iso from Red Hat and load the SCSI driver during Windows VM installation
    (Download from https://github.com/virtio-win/virtio-win-pkg-scripts)
    - Edit the XML:
      - Add iothread to disk driver
      - Add <iothreads>1</iothreads> under <domain>
      - Add iothreadpin in <cputune> (should use all cores not pinned to VM)
  - (Optional) Dynamically isolate CPU cores with QEMU hooks

6. Add support for Looking Glass: (Start from https://looking-glass.io/docs/stable/install/)
  - Edit XML as written in the docs (Skip the IVSHMEM section as we want to use the kernel \`kvmfr\` module)
  - Change the domain tag to <domain xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0" type="kvm">
  - Build the client binary and OBS plugin, symlink them to appropiate locations
  - Build the kernel module, set in \`.looking-glass-client.ini\` to use the shmFile
  - Make selinux audit for kvmfr0

7. In the Windows VM, install virtio-win-guest-tools and Looking Glass host binary
8. If the VM is using a Nvidia GPU:
  - Install Nvidia GPU drivers
  - Apply Nvidia-Patch (both NvFBC and NvENC)
  - Set Looking Glass to use NvFBC
EOS

unset is_desktop
unset filename
unset local_bin

# Start Zsh
zsh
