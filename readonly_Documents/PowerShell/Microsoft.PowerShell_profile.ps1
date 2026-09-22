Import-Module "gsudoModule"

mise activate pwsh | Out-String | Invoke-Expression

Set-Alias which gcm
Set-Alias sudo gsudo

$env:OBSIDIAN_PATH = "$HOME/Documents/Obsidian"

# fzf bindings
$env:FZF_DEFAULT_COMMAND = "fd --type f --strip-cwd-prefix --hidden --follow --exclude .git --color always"
$env:FZF_DEFAULT_OPTS = "--ansi"
$env:FZF_CTRL_T_COMMAND = "$env:FZF_DEFAULT_COMMAND"

Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

$env:VIRTUAL_ENV_DISABLE_PROMPT = $false

# https://pi.dev/packages/@ff-labs/pi-fff
$env:PI_FFF_MODE = "override"

# Mise Python shenanigans
function call_pip {
    python -m pip $args
}
Set-Alias pip call_pip

oh-my-posh init pwsh --config "$HOME/Documents/Powershell/powerlevel10k_rainbow.omp.json" | Invoke-Expression