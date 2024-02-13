<# Instruction
0. Finish all available Windows update first (Preferably also activiate Windows)
1. Start an elevated Powershell prompt, run `Set-ExecutionPolicy Bypass -Scope Process -Force`,
then run this script

TODO: 
- Add user prompt instead of hard checks
#>
Set-Location $HOME\Downloads

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
if ((Get-WmiObject -q "SELECT * FROM win32_computersystem").Manufacturer -eq "QEMU") {
    Write-Host "Installing virtio guest tools..."
    Invoke-WebRequest https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win-guest-tools.exe `
        -OutFile virtio-win-guest-tools.exe
    $VIRTIO = Start-Process -FilePath .\virtio-win-guest-tools.exe -ArgumentList "/S" -PassThru
    while (!$VIRTIO.HasExited) {
        Write-Host "Waiting for virtio tool install to complete..."
        Start-Sleep -Seconds 3
    }
    Remove-Item .\virtio-win-guest-tools.exe
}

Write-Host "Installing common packages..."
choco install -y openjdk python 7zip chocolateygui cheatengine imageglass notepadplusplus `
    onlyoffice qbittorrent vlc powertoys foobar2000 itunes microsoft-windows-terminal gsudo

choco install -y powershell-core --install-arguments='"DISABLE_TELEMETRY=1"'
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
choco install -y vscode --params "/NoContextMenuFiles"
choco install -y git --params "'/GitOnlyOnPath /WindowsTerminalProfile /NoOpenSSH /DefaultBranchName:main /Editor:Notepad++'"

# Locale Emulator, workaround install method as AHK v2 fails
# https://github.com/chtof/chocolatey-packages/issues/103
choco install -y autohotkey.portable --version=1.1.37.1
choco install -y locale-emulator

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
    choco install -y geforce-experience steam discord

    Invoke-WebRequest https://looking-glass.io/artifact/stable/host -OutFile LG.zip
    Expand-Archive .\LG.zip
    $LG = Start-Process -FilePath .\LG\looking-glass-host-setup.exe -ArgumentList "/S" -PassThru
    while (!$LG.HasExited) {
        Write-Host "Waiting for Looking Glass host install to complete..."
        Start-Sleep -Seconds 3
    }
    Remove-Item .\LG.zip
    Remove-Item .\LG -Force -Recurse

    Write-Host "Installation finished! You should reboot now to ensure everything is installed completely."
    Write-Host "You may want to install Nvidia-Patch from Github manually."
    Write-Host "Also, set Looking Glass host to use NVFBC."
}
else {
    Write-Host "Installation finished! You should reboot now to ensure everything is installed completely."
}