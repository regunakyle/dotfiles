# Dotfiles of my workstation setup

My dotfiles managed with [Chezmoi](https://www.chezmoi.io/).

This repo targets a **Windows 11 host with an Arch Linux WSL2 guest**.

## Overview

- **Host OS**: Windows 11
- **Guest OS**: Arch Linux on WSL2
- **Shell**: Zsh, with [Antidote](https://github.com/mattmc3/antidote) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- **Terminal**: Tmux, with [Oh My Tmux](https://github.com/gpakosz/.tmux) config files
- **Toolchain**: [Mise](https://mise.jdx.dev/)

Setup scripts are in `scripts/`.

## Pi Setup

Custom [Pi](https://github.com/earendil-works/pi) agent extensions and skills in `dot_pi/agent/`.

### Extensions and Skills

| Item | Type | Purpose |
| --- | --- | --- |
| `auto-toggle-thinking-visibility.ts` | Extension | Shows the model's thinking blocks while an agent run is in progress, and hides them again when the run settles. |
| `load-useful-info.ts` | Extension | Injects the current datetime, OS, and detected Python and Node.js versions as a hidden message on the first turn of a new chat. |
| `override-docs-section.ts` | Extension | Replaces the built-in `docs` section of the system prompt with custom instructions (read-only Git rule and *ASD-STE100*). |
| `print-system-prompt.ts` | Extension | Adds a `/system-prompt` command that writes the effective system prompt to `system-prompt.txt` for inspection. |
| `extend-pi` | Skill | Reference workflow for extending or explaining pi. Use together with `override-docs-section.ts`. |

## Hardware

- Desktop: AMD Ryzen 5900X + Nvidia GeForce 5070 Ti ([PCPartPicker list](https://pcpartpicker.com/list/Ttfpzv))
- Laptop: ASUS Zenbook S16-ZGAI9
