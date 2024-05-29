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

# Create distrobox for Looking Glass (in background)
if [[ "$is_desktop" == 1 ]]; then
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
                                    libdecor-devel pipewire-devel libsamplerate-devel obs-studio-devel"

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
    code \
    dynamips \
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
        kernel-devel \
        kernel-headers \
        libvirt-devel \
        selinux-policy-devel \
        solaar

    # Enable libvirtd for VM autoboot
    sudo systemctl enable libvirtd
else
    sudo dnf install -y \
        steam
fi

# Install asdf Python build dependencies
sudo dnf install -y \
    make gcc patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel libuuid-devel gdbm-libs libnsl2

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

You should create a network bridge (with your primary NIC as slave) for VM-Host communication.
Disable STP unless you need it, as it will slow down your boot time.
If you use WiFi only, create a QEMU hook that port forward 3389 instead:
https://www.reddit.com/r/VFIO/comments/1blu8tk/comment/kwstktq/
Also, use \`Virtio\` video driver (after installing virtio drivers in the VM) for higher resolution.

=====================================================================================================

Here is a rough guideline for installing VFIO and Looking Glass: 

1. (If you are using an Intel CPU) Add \`intel_iommu=pt\` to \`GRUB_CMDLINE_LINUX\` in \`/etc/sysconfig/grub\`, then run (as root) \`grub2-mkconfig -o /etc/grub2-efi.cfg\`, reboot and check IOMMU is enabled
2. Load drivers:
    - Add \`vfio_pci.ids=<Device 1 ID>,<Device 2 ID>\` to \`GRUB_CMDLINE_LINUX\` in \`/etc/sysconfig/grub\`
    - Add to \`/etc/dracut.conf.d/vfio.conf\`:

        \`\`\`
add_drivers+=" vfio vfio_iommu_type1 vfio_pci vfio_pci_core " 
force_drivers+=" vfio_pci "
        \`\`\`

    - Run as root: \`grub2-mkconfig -o /etc/grub2-efi.cfg && dracut -fv\`, then reboot

3. Create a Windows 10 VM:
  - Open virt-manager and enable XML editing (under Edit->Preferences)
  - Create a Windows 10 VM. Do not create storage when asked
  - Use Q35+UEFI (Note: Cannot make LIVE snapshot of VM when using UEFI)
  - Use host-passthrough and manually set CPU cores/threads topology to match host
  - Mount the latest virtio-win.iso from Red Hat
  (Download from https://github.com/virtio-win/virtio-win-pkg-scripts)
  - Edit the XML:
    - CPU pinning by adding <cputune> section (under <domain>); Also add <emulatorpin> (should use all cores not pinned to VM)
    - Add PCIe devices (if you add a storage device here for installing Windows, you can skip the next section)
    - Add \`<feature policy='require' name='topoext'/>\` and \`<cache mode='passthrough'/>\` inside <CPU> if you are using an AMD CPU
  - If you are not going to install Windows on a passed through storage device:
    - Add storage of bus type \`SCSI\` and a \`VirtIO SCSI\` controller
    - Install the SCSI driver from virtio-win.iso during Windows VM installation
    - You may need to manually change the boot order after installation (make the storage device the first option)
    - Edit the XML:
        - Add \`io='threads'\` in <driver> inside <disk>
        - Set <driver iothread='1' queues='4'/> inside the disk controller we added 
        - Add <iothreads>1</iothreads> under <domain>
        - Add <iothreadpin> in <cputune> (should use all cores not pinned to VM)
  - Add these to the XML:

  \`\`\`
<features>
    ...
    <hyperv mode='custom'>
    <relaxed state='on'/>
    <vapic state='on'/>
    <spinlocks state='on' retries='8191'/>
    <vpindex state='on'/>
    <runtime state='on'/>
    <synic state='on'/>
    <stimer state="on"/>
    <vendor_id state='on' value='randomid'/>
    <frequencies state='on'/>
    <tlbflush state='on'/>
    <ipi state='on'/>
    </hyperv>
    <kvm>
    <hidden state="on"/>
    </kvm>
    ...
</features>
  \`\`\`

  \`\`\`
<clock offset="localtime">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
    <timer name="hypervclock" present="yes"/>
</clock>
  \`\`\`

  - Optional: Dynamically isolate CPU cores with QEMU hooks

4. Install Windows and perform basic setup, then:
  - Install virtio-win-gt-x64.msi in the attached virtio-win.iso
  - Install spice-guest-tools (from https://www.spice-space.org/download.html#windows-binaries)
  (Note: Clipboard sync should work now)
  - Reboot

5. Add support for Looking Glass: (Start from https://looking-glass.io/docs/stable/install/)
  - Git clone the repo (with submodules), checkout the version tag you want (with)
  - Edit XML as written in the docs (we want to use the kernel module)
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
    5. Install Looking Glass host binary in the Windows VM
    6. Done!

6. Optional: As the \`vfio-pci\` driver might draw a lot of power when attached to a GPU, create another low resource VM (e.g. Debian):
    1. Autostart this VM on boot (you need to enable libvirtd service)
    2. Attach the gaming GPU to this VM
    3. Shut the idle VM down before booting Windows VM, boot it again after shutting down the Windows VM (automate this with my scripts)

You can join the VFIO Discord and find more optimization tips in the \`wiki-and-psa\` channel.
EOF

unset is_desktop
unset filename
unset local_bin

# Start Zsh
zsh
