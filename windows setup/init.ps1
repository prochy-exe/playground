$featuresToRemove = @(
    "VBSCRIPT~~~~",
    "Microsoft.Windows.SnippingTool~~~~0.0.1.0",
    "Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0",
    "Microsoft.Windows.Notepad~~~~0.0.1.0",
    "Microsoft.Windows.MSPaint~~~~0.0.1.0",
    "Media.WindowsMediaPlayer~~~~0.0.12.0",
    "App.StepsRecorder~~~~0.0.1.0",
    "Browser.InternetExplorer~~~~0.0.11.0"
)

Write-Host "Installing Windows Store in the background..."
& wsreset -i

$folderPath = "$env:USERPROFILE\Desktop\setup"

if (!(Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath -Force
}

# Download the debloat script
$scriptToRun = "$folderPath\post.ps1"
Write-Host "Downloading debloat script to: $scriptToRun"

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/prochy-exe/playground/refs/heads/main/windows%20setup/post.ps1" -OutFile $scriptToRun

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
Invoke-WebRequest -Uri $AIUrl -OutFile $OutputPath
Add-AppxPackage -Path "$env:USERPROFILE\Desktop\setup\ai.msixbundle"
Write-Host "App Installer installed!"

# Custom apps
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/prochy-exe/playground/refs/heads/main/windows%20setup/apps.txt" -OutFile "$env:USERPROFILE\Desktop\apps.txt"
Write-Host "Now it's a good time to make changes to the apps.txt file on your desktop"
Write-Host "If you want to install custom apps, please add them to the file, you can find the IDs using winget search"
Write-Host "The default app selection is as follows:"
Write-Host "Gigabyte control center, Zen team browser, Asus armoury crate, Google android studio, Google quick share"
Write-Host "If you don't want to install one of these custom apps, remove the line from the file"
Read-Host -Prompt "Once you're done, press the Enter key to continue..."

# Remove Windows features
Write-Host "Removing prebuilt Windows apps..."
foreach ($feature in $featuresToRemove) {
    Remove-WindowsCapability -Online -Name $feature
}

#Xbox driver
$response = Read-Host "Install Xbox dongle driver? Please enter 'y' or 'n'"
while ($response -notin @('y', 'n')) {
    $response = Read-Host "Invalid input. Please enter 'y' or 'n'"
}

if ($response -eq 'y') {
    Write-Host "Installing Xbox dongle driver..."
    Invoke-WebRequest -Uri "https://pbani.me/ws/xd" -OutFile "$env:USERPROFILE\Desktop\setup\xd.zip"
    Expand-Archive -Path "$env:USERPROFILE\Desktop\setup\xd.zip" -DestinationPath "$env:USERPROFILE\Desktop\setup\xd"
    pnputil /add-driver "$env:USERPROFILE\Desktop\setup\xd\mt7612us_RL.inf" /install
}

Read-Host "Press the Enter key to reboot..."

Write-Host "Rebooting..."
& shutdown /r /t 0