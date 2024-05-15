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
        com.calibre_ebook.calibre \
        com.github.dynobo.normcap \
        com.obsproject.Studio \
        com.obsproject.Studio.Plugin.DroidCam \
        com.obsproject.Studio.Plugin.InputOverlay \
        dev.vencord.Vesktop \
        io.dbeaver.DBeaverCommunity \
        org.fedoraproject.MediaWriter \
        org.filezillaproject.Filezilla \
        org.gnome.Calculator \
        org.gnome.meld \
        org.kde.gwenview \
        org.kde.kleopatra \
        org.kde.kolourpaint \
        org.kde.okular \
        org.libreoffice.LibreOffice \
        org.mozilla.Thunderbird \
        org.qbittorrent.qBittorrent \
        org.sqlitebrowser.sqlitebrowser \
        org.strawberrymusicplayer.strawberry \
        org.videolan.VLC

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

# Create distrobox and install VSCode (in background)
{
    echo "Creating Debian distrobox..."
    distrobox create \
        --image quay.io/toolbx-images/debian-toolbox:12 \
        --name toolbox \
        --pull \
        --no-entry \
        --additional-packages "texlive-full zsh 
    build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl 
    xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libncursesw5-dev"
    podman start toolbox
} &

# Setup RPMFusion
echo "Enabling RPMFusion and install media codecs..."
sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Add 3rd party repos
sudo dnf copr enable -y zeno/scrcpy
sudo dnf copr enable -y mguessan/davmail
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
    code \
    davmail \
    fastfetch \
    fcitx5-chinese-addons \
    fcitx5-table-extra \
    git \
    gns3-gui \
    gns3-server \
    google-chrome-stable \
    hadolint \
    hugo \
    iperf3 \
    kate \
    maven \
    nmap \
    pipx \
    scrcpy \
    shellcheck \
    tmux \
    wireshark

# Add user to Wireshark group for non-root usage
sudo usermod -aG wireshark "$(whoami)"

if [[ "$is_desktop" == 1 ]]; then
    sudo dnf install -y \
        dkms \
        intel-media-driver \
        selinux-policy-devel \
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
After that, you may want to config fcitx5, SSH/GPG, VSCode and Windows 10 VM.

You should create a network bridge (with your primary NIC as slave) for VM-Host communication.
If you are on laptop, create a QEMU hook that port forward 3389 instead:
https://www.reddit.com/r/VFIO/comments/1blu8tk/comment/kwstktq/
Also, use \`Virtio\` video driver (after installing virtio drivers in the VM) for higher resolution.

=====================================================================================================

Here is a rough guideline for installing VFIO and Looking Glass: 

1. Add \`iommu=pt\` to \`/etc/sysconfig/grub\`, then regenerate grub config, reboot and check IOMMU is enabled"
2. Add \`options vfio-pci ids=<Device 1 ID>,<Device 2 ID>\` to /etc/modprobe.d/local.conf"
3. Add \`force_drivers+=" vfio vfio_iommu_type1 vfio_pci "\` to /etc/dracut.conf.d/local.conf
4. Regenerate the dracut initramfs with "sudo dracut -f --kver \`uname -r\`" and reboot
(See https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#X_does_not_start_after_enabling_vfio_pci if black screen after reboot)

5. Create a Windows 10 VM:
  - Use Q35+UEFI (Note: Cannot make LIVE snapshot of VM when using UEFI)
  - Use host-passthrough and manually set CPU cores/threads topology to match host
  - Edit the XML:
    - CPU pinning by adding <cputune> section; Also add emulatorpin (should use all cores not pinned to VM)
    - Add PCIe devices
    - Add \`<feature policy='require' name='topoext'/>\` inside <CPU> if you are using an AMD CPU
  - If you are not going to install Windows on a passed through storage device:
    - Do not create storage when asked: Instead manually add storage of bus type \`SCSI\` and a \`VirtIO SCSI\` controller
    - Mount the latest virtio-win.iso from Red Hat and load the SCSI driver during Windows VM installation
    (Download from https://github.com/virtio-win/virtio-win-pkg-scripts)
    - You may need to manually change the boot order after installation (make the storage device the first option)
    - Edit the XML:
      - Add iothread driver to disk controller
      - Add <iothreads>1</iothreads> under <domain>
      - Add iothreadpin in <cputune> (should use all cores not pinned to VM)
  - Optional: Dynamically isolate CPU cores with QEMU hooks

6. Add support for Looking Glass: (Start from https://looking-glass.io/docs/stable/install/)
  - Edit XML as written in the docs (we want to use the kernel \`kvmfr\` module)
  - Build the client binary and OBS plugin, symlink them to appropiate locations
  - Change the domain tag to <domain xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0" type="kvm">
  - Install the kernel module with DKMS, create \`.looking-glass-client.ini\` and set \`shmFile\` to \`/dev/kvmfr0\`
  - Create SELinux module for \`kvmfr0\`:
    1. Create a \`kvmfr0.te\` file with the following content:

        \`\`\`

        module kvmfr0 1.0;
        
        require {
        	type svirt_t;
        	type device_t;
        	class chr_file { map open read write };
        }
        
        #============= svirt_t ==============
        allow svirt_t device_t:chr_file { map open read write };
        
        \`\`\`

    2. Install \`selinux-policy-devel\`
    3. Run \`make -f /usr/share/selinux/devel/Makefile kvmfr0.pp\` in the same directory
    4. Run \`sudo semodule -X 300 -i kvmfr0.pp\`

7. In the Windows VM, install spice-guest-tools and Looking Glass host binary

8. Optional: As the \`vfio-pci\` driver might draw a lot of power when attached to a GPU, create another low resource VM (e.g. Debian):
    1. Autostart this VM on boot (you need to enable libvirtd service), shut it down before booting Windows VM, boot it again after shutting down the Windows VM
    2. Tell libvirtd to wait for bridge network if your VM is using bridged connection (https://www.reddit.com/r/Fedora/comments/14t8hhj/comment/jx2jzz2/)
    3. Attach GPU to this VM

You can join the VFIO Discord and find more optimization tips in the \`wiki-and-psa\` channel.
EOF

unset is_desktop
unset filename
unset local_bin

# Start Zsh
zsh
