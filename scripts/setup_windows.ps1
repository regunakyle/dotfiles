<# Instruction
0. Finish all available Windows updates
1. Install PowerShell 7
2. Start an elevated Powershell prompt, run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force`, then run this script
#>

# Check for winget
try {
    # Powershell try-catch works only when the error is terminating
    Get-Command winget -ErrorAction Stop
}
catch {
    Write-Host "Winget not found, please update the `App Installer` in Microsoft Store!"
    exit 1
}

# Install packages
Write-Host "Installing winget packages..."
$packages = @(
    "gerardog.gsudo",
    "jdx.mise",
    "jftuga.less",
    "okibcn.nano",
    "twpayne.chezmoi"
)

foreach ($package in $packages) {
    winget install --id=$package -e --accept-package-agreements --accept-source-agreements --source winget
}

# fzf bindings
Install-Module -Name PSFzf -Repository PSGallery -Scope CurrentUser -Force

# Setup Chezmoi
chezmoi init --apply --force regunakyle
oh-my-posh font install NerdFontsSymbolsOnly

mise install

Write-Host "Installation finished!"

