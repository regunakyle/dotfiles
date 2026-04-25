mise activate pwsh | Out-String | Invoke-Expression

function call_pip {
    python -m pip $args
}

Set-Alias pip call_pip

Set-Alias which gcm

# fzf bindings
$env:FZF_DEFAULT_COMMAND = "fd --type f --strip-cwd-prefix --hidden --follow --exclude .git --color always"
$env:FZF_DEFAULT_OPTS = "--ansi"
$env:FZF_CTRL_T_COMMAND = "$env:FZF_DEFAULT_COMMAND"

Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

$env:VIRTUAL_ENV_DISABLE_PROMPT = $false
oh-my-posh init pwsh --config "$HOME/Documents/Powershell/powerlevel10k_rainbow.omp.json" | Invoke-Expression