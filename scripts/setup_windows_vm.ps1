<# Instruction
0. Finish all available Windows update (Preferably also activiate Windows)
1. Update the `App Installer` in Microsoft Store
2. Start an elevated Powershell prompt, run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force`, then run this script

TODO: 
- Add error handling
- Automate winget installation with https://github.com/microsoft/winget-cli/discussions/1738#discussioncomment-5484927
#>

if (Test-Path env:TEMP) {
    Push-Location $env:TEMP
}
elseif (Test-Path env:tmp) {
    Push-Location $env:TMP
}
else {
    Write-Host "No temp folder in PATH, quitting..."
    exit 1
}

# Uninstall bloatware
Write-Host "Uninstalling bloatware..."
$bloatwares = @(
    "Microsoft.Microsoft3DViewer",
    "Microsoft.WindowsAlarms",
    # Mail, Calendar
    "Microsoft.windowscommunicationsapps",
    # Cortana
    "Microsoft.549981C3F5F10",
    "Microsoft.WindowsFeedbackHub",
    # Groove Music
    "Microsoft.ZuneMusic",
    # Movies & TV
    "Microsoft.ZuneVideo",
    # Paint 3D
    "Microsoft.MSPaint",
    "Microsoft.WindowsMaps",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal",
    "Microsoft.Office.OneNote",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.XboxApp",
    "Microsoft.BingWeather",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.SkypeApp",
    "Microsoft.ScreenSketch",
    "Microsoft.People",
    "Microsoft.Windows.Photos",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.WindowsCamera"
)

foreach ($bloatware in $bloatwares) {
    Get-AppxPackage $bloatware | Remove-AppxPackage
}

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
Write-Host "Installing common packages..."
$packages = @(
    "7zip.7zip",
    "Apple.iTunes",
    "DuongDieuPhap.ImageGlass",
    "Git.Git",
    "gerardog.gsudo",
    "JanDeDobbeleer.OhMyPosh",
    "jdx.mise",
    "Microsoft.PowerShell",
    "Microsoft.WindowsTerminal",
    "Mozilla.Firefox",
    "Notepad++.Notepad++",
    "okibcn.nano",
    "PeterPawlowski.foobar2000",
    "qBittorrent.qBittorrent",
    "RaspberryPiFoundation.RaspberryPiImager",
    "TheDocumentFoundation.LibreOffice",
    "twpayne.chezmoi",
    "VideoLAN.VLC"
)

foreach ($package in $packages) {
    winget install --id=$package -e --accept-package-agreements --accept-source-agreements --source winget
}

# Setup chezmoi
chezmoi init --apply --force regunakyle
oh-my-posh font install NerdFontsSymbolsOnly

# SSH server for ProxyJump
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Confirm the Firewall rule is configured. It should be created automatically by setup.
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}

# Trader Workstation from IBKR
Write-Host "Installing Trader Workstation..."
Invoke-WebRequest https://download2.interactivebrokers.com/installers/tws/latest/tws-latest-windows-x64.exe `
    -OutFile tws-latest-windows-x64.exe
$install = Start-Process -FilePath .\tws-latest-windows-x64.exe -ArgumentList "-q" -PassThru
while (!$install.HasExited) {
    Write-Host "Waiting for TWS installation to complete..."
    Start-Sleep -Seconds 3
}
Remove-Item .\tws-latest-windows-x64.exe

if ((Get-CimInstance win32_VideoController).Name | Select-String "Nvidia") {
    Write-Host "Installing desktop packages..."
    $packages = @(
        "Discord.Discord",
        "Valve.Steam"
    )

    foreach ($package in $packages) {
        winget install --id=$package -e --accept-package-agreements --accept-source-agreements --source winget
    }

    # https://github.com/microsoft/winget-pkgs/issues/140696
    Write-Host "You should install the Nvidia App manually."

}

Write-Host "Installation finished! You should reboot now to avoid stability problems."

Pop-Location 
