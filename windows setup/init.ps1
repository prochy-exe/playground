$osVersion = [version](Get-CimInstance Win32_OperatingSystem).Version
$minWindowsVersion = [version]"10.0.22000.0"

$featuresToRemove = @(
    "VBSCRIPT~~~~",
    "Microsoft.Windows.SnippingTool~~~~0.0.1.0",
    "Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0",
    "Microsoft.Windows.Notepad~~~~0.0.1.0",
    "Microsoft.Windows.MSPaint~~~~0.0.1.0",
    "Media.WindowsMediaPlayer~~~~0.0.12.0",
    "App.StepsRecorder~~~~0.0.1.0",
    "Browser.InternetExplorer~~~~0.0.11.0",
    "Microsoft.Windows.WordPad~~~~0.0.1.0",
    "App.Support.QuickAssist~~~~0.0.1.0"
)

$defaultApps = @(
    '9MSMLRH6LZF3', # Notepad
    "9WZDNCRFHVN5", # Calculator
    '9WZDNCRFJBH4', # Photos
    '9MZ95KL8MR0L', # Snipping Tool
    '9PCFS5B6T72H'  # Paint
)

if ($osVersion -lt $minWindowsVersion) {
    Write-Host "Detected OS version is lower than required. Removing Notepad and Paint from lists..."

    # Remove Notepad and Paint
    $featuresToRemove = $featuresToRemove | Where-Object {
        $_ -notlike "*Notepad*" -and $_ -notlike "*Paint*"
    }

    $defaultApps = $defaultApps | Where-Object {
        $_ -ne '9MSMLRH6LZF3' -and $_ -ne '9PCFS5B6T72H'
    }
}

function Install-Store {
    Write-Host "Installing Windows Store in the background..."
    & wsreset -i
    $storePackage = "Microsoft.WindowsStore"
    Write-Host "Waiting for Microsoft Store install to finish..."
    $counter = 0
    while (-not (Get-AppxPackage -Name $storePackage)) {
        Start-Sleep -Seconds 5
        $counter += 5

        if ($counter -ge 60) {
            & wsreset -i
            $counter = 0
        }
    }
    Write-Host "Microsoft Store is installed!"
    # Install App Installer
    Write-Host "Installing App Installer..."
    $AIUrl = "https://pbani.me/ws/ai"
    $OutputPath = "$env:USERPROFILE\Desktop\setup\ai.msixbundle"
    Invoke-WebRequest -UseBasicParsing -Uri $AIUrl -OutFile $OutputPath
    Add-AppxPackage -Path "$env:USERPROFILE\Desktop\setup\ai.msixbundle"
    Write-Host "App Installer installed!"
}

$folderPath = "$env:USERPROFILE\Desktop\setup"

if (!(Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath -Force
}

Install-Store

# Download the debloat script
$scriptToRun = "$folderPath\post.ps1"
Write-Host "Downloading debloat script to: $scriptToRun"

Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/prochy-exe/playground/refs/heads/main/windows%20setup/post.ps1" -OutFile $scriptToRun

# Define the task name
$taskName = "RunScriptOnNextReboot"

function Get-CurrentUsername {
    return [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
}

$principal = New-ScheduledTaskPrincipal -UserId (Get-CurrentUsername) -RunLevel Highest

Write-Host "Creating scheduled task to run debloat script at startup..."

# Create a new scheduled task action
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptToRun`""

# Create a new scheduled task trigger (run at startup)
$trigger = New-ScheduledTaskTrigger -AtLogOn -User (Get-CurrentUsername)

# Create the task
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal

# Register the scheduled task
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null

# Remove calculator shortcut
Remove-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Calculator.lnk" -Force

# Remove Windows features
Write-Host "Removing prebuilt Windows apps..."
foreach ($feature in $featuresToRemove) {
    Remove-WindowsCapability -Online -Name $feature
}

# Install UWP replacements for Windows 11
if ($defaultApps) {
    Write-Host "Installing modern basic apps..."
    foreach ($app in $defaultApps) {
        $command = "winget install -e --id $app"
        Invoke-Expression $command
    }
}

#Xbox driver
$response = Read-Host "Install Xbox dongle driver? Please enter 'y' or 'n'"
while ($response -notin @('y', 'n')) {
    $response = Read-Host "Invalid input. Please enter 'y' or 'n'"
}

if ($response -eq 'y') {
    Write-Host "Installing Xbox dongle driver..."
    Invoke-WebRequest -UseBasicParsing -Uri "https://pbani.me/ws/xd" -OutFile "$env:USERPROFILE\Desktop\setup\xd.zip"
    Expand-Archive -Path "$env:USERPROFILE\Desktop\setup\xd.zip" -DestinationPath "$env:USERPROFILE\Desktop\setup\xd"
    pnputil /add-driver "$env:USERPROFILE\Desktop\setup\xd\mt7612us_RL.inf" /install
}

Read-Host "Press the Enter key to reboot..."

Write-Host "Rebooting..."
& shutdown /r /t 0
