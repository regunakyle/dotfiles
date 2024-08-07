<# Instruction
0. Finish all available Windows update first (Preferably also activiate Windows)
1. Start an elevated Powershell prompt, run `Set-ExecutionPolicy Bypass -Scope Process -Force`,
then run this script

TODO: 
- Add error handling
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
$bloatware = @(
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

foreach ($item in $bloatware) {
    Get-AppxPackage $item | Remove-AppxPackage
}

# Install Chocolatey
Write-Host "Installing Chocolatey..."
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install packages
Write-Host "Installing common packages..."
choco install -y 7zip.install vlc.install microsoft-windows-terminal imageglass notepadplusplus.install nano-win `
    libreoffice-fresh powertoys foobar2000 itunes gsudo cheatengine chocolateygui qbittorrent

winget install vfox
if (-not (Test-Path -Path $PROFILE)) { New-Item -Type File -Path $PROFILE -Force }; Add-Content -Path $PROFILE -Value 'Invoke-Expression "$(vfox activate pwsh)"'

# SSH server for ProxyJump
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}

choco install -y git.install --params "'/GitOnlyOnPath /WindowsTerminalProfile /NoOpenSSH /DefaultBranchName:main /Editor:Nano'"

# Trader Workstation from IBKR
Write-Host "Installing Trader Workstation..."
Invoke-WebRequest https://download2.interactivebrokers.com/installers/tws/latest/tws-latest-windows-x64.exe `
    -OutFile tws-latest-windows-x64.exe
$TWD = Start-Process -FilePath .\tws-latest-windows-x64.exe -ArgumentList "-q" -PassThru
while (!$TWD.HasExited) {
    Write-Host "Waiting for TWS installation to complete..."
    Start-Sleep -Seconds 3
}
Remove-Item .\tws-latest-windows-x64.exe

if ((Get-CimInstance win32_VideoController).Name | Select-String "Nvidia") {
    # Desktop specific scripts; Assume only desktop uses Nvidia GPU
    Write-Host "Detected Nvidia GPU. Installing desktop specific apps..."
    choco install -y discord.install geforce-experience

    # Steam
    Invoke-WebRequest https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe `
        -OutFile SteamSetup.exe
    $STEAM = Start-Process -FilePath .\SteamSetup.exe -ArgumentList "/S" -PassThru
    while (!$STEAM.HasExited) {
        Write-Host "Waiting for steam install to complete..."
        Start-Sleep -Seconds 3
    }
    Remove-Item .\SteamSetup.exe

}

Write-Host "Installation finished! You should reboot now to avoid stability problems."

Pop-Location 