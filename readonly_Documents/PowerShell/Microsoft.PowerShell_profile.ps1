oh-my-posh init pwsh --config "$HOME/Documents/Powershell/powerlevel10k_rainbow.omp.json" | Invoke-Expression
$Env:VIRTUAL_ENV_DISABLE_PROMPT = $false

mise activate pwsh | Out-String | Invoke-Expression

function call_pip {
    python -m pip $args
}

Set-Alias pip call_pip

# fzf bindings
$Env:FZF_DEFAULT_COMMAND = "rg --files --hidden --glob `"!.git/*`""
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'