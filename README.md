# Dotfiles of my workstation setup

## Content

- Dotfiles in the root folder
- Setup scripts and VSCode config in the [scripts](scripts) folder

## Setup Information

### General

- Fedora KDE (installed with the [Fedora Everything](https://alt.fedoraproject.org/) image) with minimum bloat
- Windows 10 VM with [setup script](scripts/setup_windows_vm.ps1)
- RPM Fusion enabled, uses patent-encumbered codecs
- Use [Distrobox](https://github.com/89luca89/distrobox) container as primary development environment
  - [Debian Unstable](https://wiki.debian.org/DebianUnstable) container for [Playwright](https://playwright.dev/) compatibility and rolling updates (thus no need to upgrade between major versions)
  - VSCode installed and exported to host
- Install most GUI application as flatpak from [Flathub](https://flathub.org/) instead of DNF
- Use [Fcitx5](https://fcitx-im.org/wiki/Special:MyLanguage/Fcitx_5) with Quick Classic as input method
- Use [Podman](https://podman.io/) with Docker compatibility
  - Use the [docker-compose](https://github.com/docker/compose) binary from upstream as the distro version is out of date
- Use [Sarasa Gothic](https://github.com/be5invis/Sarasa-Gothic) and [Nerd Font Symbols](https://github.com/ryanoasis/nerd-fonts)
- Use the Zsh shell with [Antidote](https://github.com/mattmc3/antidote) and [plugins](dot_zsh_plugins.txt)
- Use [asdf](https://github.com/asdf-vm/asdf) and plugins
- Use [Chezmoi](https://github.com/twpayne/chezmoi) as dotfile manager

### Desktop setup

- [PCPartPicker list](https://pcpartpicker.com/list/bq4NZJ)
- [Solaar](https://github.com/pwr-Solaar/Solaar) for my G703 gaming mouse
- Play games on a high performance VFIO Windows 10 VM ([blog entry in Chinese](https://regunakyle.github.io/regunakyle/posts/002_win10_to_linux/))
  - Use [Looking Glass](https://looking-glass.io/) to control the VM
  - Instructions on the bottom of the [Linux setup script](scripts/setup_linux.sh)

### Laptop setup

- Lenovo ThinkPad T14s Gen 3 (AMD) ([21CQ000JUS](https://psref.lenovo.com/Detail/ThinkPad/ThinkPad_T14s_Gen_3_AMD?M=21CQ000JUS))
  - SSD upgraded to 1TB
  - Monitor upgraded to a 100% sRGB, 120Hz, 2560×1600 panel ([N140GLE-GT1](https://www.panelook.com/N140GLE-GT1_Innolux_14.0_LCM_parameter_59738.html))
    - Note: I do not recommend upgrading the monitor by yourself
- Use [TLP](https://github.com/linrunner/TLP) instead of [PDD](https://gitlab.freedesktop.org/upower/power-profiles-daemon)
- Use the OEM Windows 10 key ([how to find](https://www.cyberciti.biz/faq/linux-find-windows-10-oem-product-key-command/)) for the Windows VM

## TODO

- Prepare a Powershell script for bare metal Windows and WSL setup
- Use [Wezterm](https://github.com/wez/wezterm) and [Starship](https://github.com/starship/starship) for all installations
- Reimplement the installation scripts as Ansible Playbooks
