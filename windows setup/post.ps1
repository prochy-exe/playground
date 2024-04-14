$defaultApps = @(
    '9MSMLRH6LZF3', # Notepad
    "9WZDNCRFHVN5", # Calculator
    '9WZDNCRFJBH4', # Photos
    '9MZ95KL8MR0L', # Snipping Tool
    '9PCFS5B6T72H' # Paint
)
$customApps = if (Test-Path -Path "$env:USERPROFILE\Desktop\apps.txt") { Get-Content -Path "$env:USERPROFILE\Desktop\apps.txt" } else { @() }

function Set-ExplorerPinnedToTaskbar {
    [string]$XmlPath = "$env:USERPROFILE\TaskbarLayout.xml"

    # Create the XML layout for pinning File Explorer
    $xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate
    xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification"
    xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
    xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
    xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout"
    Version="1">
  <CustomTaskbarLayoutCollection>
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
        <taskbar:DesktopApp DesktopApplicationID="Microsoft.Windows.Explorer"/>
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@

    # Write the XML content to the specified file
    $xmlContent | Out-File -FilePath $XmlPath -Encoding utf8

    Write-Host "XML file created at: $XmlPath"

    # Apply the XML layout using Group Policy
    $GPOPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"

    if (-Not (Test-Path -Path $GPOPath)) {
        New-Item -Path $GPOPath -Force | Out-Null
    }

    Set-ItemProperty -Path $GPOPath -Name "StartLayoutFile" -Value $XmlPath
    Set-ItemProperty -Path $GPOPath -Name "LockedStartLayout" -Value 0
    gpupdate /force

    Write-Host "Taskbar layout applied."
}

# Define the user context execution function
function Invoke-AsUser {
    param([string]$scriptBlock)

    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = "powershell.exe"
    $processStartInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command & {$scriptBlock}"
    $processStartInfo.UseShellExecute = $true
    $processStartInfo.Verb = "RUNASUSER"  # Forces execution as the current logged-in user

    $process = [System.Diagnostics.Process]::Start($processStartInfo)
    $process.WaitForExit()
}

# Unregister scheduled task
Unregister-ScheduledTask -TaskName "RunScriptOnNextReboot" -Confirm:$false

# Pin File Explorer to taskbar
Set-ExplorerPinnedToTaskbar

#Win11 debloat https://github.com/Raphire/Win11Debloat
Write-Host "Running Win11 debloat..."
& ([scriptblock]::Create((Invoke-RestMethod "https://debloat.raphi.re/"))) -ForceRemoveEdge -DisableDVR -DisableBing -DisableSuggestions -DisableTelemetry -DisableDesktopSpotlight -RevertContextMenu -ShowHiddenFolders -ShowKnownFileExt -HideDupliDrive -HideSearchTb -HideChat -DisableWidgets -DisableCopilot -DisableRecall -HideHome -HideGallery -ExplorerToHome -ExplorerToThisPC

# Chris titus tool https://github.com/ChrisTitusTech/winutil
Write-Host "Running Chris Titus Tool, load the config file then apply changes..."
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/prochy-exe/playground/refs/heads/main/windows%20setup/ctt.json" -OutFile "$env:USERPROFILE\Desktop\setup\ctt.json"
$cttResponse = Invoke-WebRequest -Uri "https://christitus.com/win" -UseBasicParsing
& Invoke-Expression $cttResponse

# Install UWP replacements for Windows 11
if ($defaultApps) {
    Write-Host "Installing modern basic apps..."
    foreach ($app in $defaultApps) {
        $command = "winget install -e --id $app"
        Invoke-Expression $command
    }
}

# Install custom apps using winget
if ($customApps) {
    Write-Host "Installing custom apps..."
    foreach ($app in $customApps) {
        $command = "winget install -e --id $app"
        Invoke-Expression $command
    }
}

$wingetList = winget list
$discordCheck = $wingetList | Select-String -Pattern "Discord"
$spotifyCheck = $wingetList | Select-String -Pattern "Spotify"

if ($discordCheck) {
    Write-Host "Patching Discord..."
    Invoke-AsUser {
        Invoke-WebRequest -Uri "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe" -OutFile "$env:USERPROFILE\Desktop\setup\vencord.exe"
        Start-Process -FilePath "$env:USERPROFILE\Desktop\setup\vencord.exe" -ArgumentList "-branch stable -install -install-openasar" -Wait
    }
}

if ($spotifyCheck) {
    Write-Host "Patching Spotify..."
    Invoke-AsUser {
        $spicetifyResponse = Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.ps1"
        Invoke-Expression $spicetifyResponse.Content
        $dynamicResponse = Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/JulienMaille/spicetify-dynamic-theme/master/install.ps1"
        Invoke-Expression $dynamicResponse.Content
        $patchResponse = Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/JulienMaille/spicetify-dynamic-theme/master/patch.ps1"
        Invoke-Expression $patchResponse.Content
    }
}

# Cleanup
Write-Host "Cleaning up..."
Invoke-Command -ScriptBlock {
    Set-Location -Path "$env:USERPROFILE\Desktop"
    Remove-Item -Path "$env:USERPROFILE\Desktop\setup\*" -Recurse -Force
} -AsJob

# Download and install Office
$officeResponse = Read-Host "Install Office? Please enter 'y' or 'n'"
while ($response -notin @('y', 'n')) {
    $response = Read-Host "Invalid input. Please enter 'y' or 'n'"
}

if ($officeResponse -eq 'y') {
    Write-Host "Downloading and installing Office..."
    New-Item -ItemType Directory -Path "C:\Office" -Force
    Invoke-WebRequest -Uri "https://officecdn.microsoft.com/pr/wsus/setup.exe" -OutFile "C:\Office\setup.exe"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/prochy-exe/playground/refs/heads/main/windows%20setup/Configuration.xml" -OutFile "C:\Office\Configuration.xml"
    Start-Process -FilePath "C:\Office\setup.exe" -ArgumentList "/configure C:\Office\setup.xml" -Wait
}

# Windows/Office Activation
$activationResponse = Invoke-WebRequest -Uri "https://get.activated.win" -UseBasicParsing
& Invoke-Expression $activationResponse