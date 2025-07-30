function Set-ExplorerPinnedToTaskbar {
    # Create the XML layout for pinning File Explorer
    $START_MENU_LAYOUT = @"
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

    $layoutFile="C:\Windows\StartMenuLayout.xml" 

    #Delete layout file if it already exists
    If(Test-Path $layoutFile) {
        Remove-Item $layoutFile
    }

    #Creates the blank layout file
    $START_MENU_LAYOUT | Out-File $layoutFile -Encoding ASCII

    $regAliases = @("HKLM", "HKCU")

    #Assign the start layout and force it to apply with "LockedStartLayout" at both the machine and user level

    foreach ($regAlias in $regAliases) {
        $basePath = $regAlias + ":\SOFTWARE\Policies\Microsoft\Windows"
        $keyPath = $basePath + "\Explorer"

        if (!(Test-Path -Path $keyPath)) {
            New-Item -Path $basePath -Name "Explorer"
        }
        Set-ItemProperty -Path $keyPath -Name "LockedStartLayout" -Value 1
        Set-ItemProperty -Path $keyPath -Name "StartLayoutFile" -Value $layoutFile
    } 

    Write-Host "Taskbar layout applied. Restart is required"
}

function Invoke-AsUser {
    param (
        [ScriptBlock]$Command
    )
    $tempDoneFile = "$env:TEMP\nonElevatedDone.txt"
    $tmpBlock = "$env:TEMP\block.ps1"
    Write-Host $tmpBlock
    if (Test-Path $tempDoneFile) { Remove-Item $tempDoneFile }
    if (Test-Path $tmpBlock) { Remove-Item $tmpBlock }

    $Command.ToString() | Out-File $tmpBlock

    # Start PowerShell as the current user (non-elevated)
    Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", $tmpBlock -Verb runasuser

    while (-not (Test-Path $tempDoneFile)) {
        Start-Sleep -Milliseconds 200
    }

    Remove-Item $tempDoneFile -Force
    Remove-Item $tmpBlock -Force
}

# Unregister scheduled task
Unregister-ScheduledTask -TaskName "RunScriptOnNextReboot" -Confirm:$false

#Win11 debloat https://github.com/Raphire/Win11Debloat
Write-Host "Running Win11 debloat..."
& ([scriptblock]::Create((Invoke-RestMethod "https://debloat.raphi.re/"))) -ForceRemoveEdge -DisableDVR -DisableBing -DisableSuggestions -DisableTelemetry -DisableDesktopSpotlight -RevertContextMenu -ShowHiddenFolders -ShowKnownFileExt -HideDupliDrive -HideSearchTb -HideChat -DisableWidgets -DisableCopilot -DisableRecall -HideHome -HideGallery -ExplorerToHome -ExplorerToThisPC

# Chris titus tool https://github.com/ChrisTitusTech/winutil
Write-Host "Running Chris Titus Tool, load the config file then apply changes..."
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/prochy-exe/playground/refs/heads/main/windows%20setup/ctt.json" -OutFile "$env:USERPROFILE\Desktop\setup\ctt.json"
$cttResponse = Invoke-WebRequest -Uri "https://christitus.com/win" -UseBasicParsing
& Invoke-Expression $cttResponse

# Custom apps
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/prochy-exe/playground/refs/heads/main/windows%20setup/apps.txt" -OutFile "$env:USERPROFILE\Desktop\apps.txt"
Write-Host "Now it's a good time to make changes to the apps.txt file on your desktop"
Write-Host "If you want to install custom apps, please add them to the file, you can find the IDs using winget search"
Write-Host "The default app selection is as follows:"
Write-Host "Gigabyte control center, Zen team browser, Asus armoury crate, Google android studio, Google quick share"
Write-Host "If you don't want to install one of these custom apps, remove the line from the file"
Read-Host -Prompt "Once you're done, press the Enter key to continue..."

$customApps = if (Test-Path -Path "$env:USERPROFILE\Desktop\apps.txt") { Get-Content -Path "$env:USERPROFILE\Desktop\apps.txt" } else { @() }

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
$vscodeCheck = $wingetList | Select-String -Pattern "Visual Studio Code"

if ($vscodeCheck) {
    $vscodeCommand = 'winget install --force Microsoft.VisualStudioCode --override "/VERYSILENT /SP- /MERGETASKS=""addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"""'
    Write-Host "VSCode install detected, reinstalling with context menu flags"
    Invoke-Expression $vscodeCommand
}

if ($discordCheck -or $spotifyCheck) {
    Invoke-AsUser {
        $wingetList = winget list
        $discordCheck = $wingetList | Select-String -Pattern "Discord"
        $spotifyCheck = $wingetList | Select-String -Pattern "Spotify"
        $tempDoneFile = "$env:TEMP\nonElevatedDone.txt"

        if ($discordCheck) {
            Write-Host "Patching Discord..."
            Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe" -OutFile "$env:USERPROFILE\Desktop\setup\vencord.exe"
            Start-Process -FilePath "$env:USERPROFILE\Desktop\setup\vencord.exe" -ArgumentList "-branch stable -install -install-openasar" -Wait
        }

        if ($spotifyCheck) {
            Write-Host "Patching Spotify..."
            Write-Host "Starting Spotify to generate files..."
            Start-Process -FilePath "$env:USERPROFILE\Desktop\Spotify.lnk"
            Start-Sleep -Seconds 10

            # Run standard setup scripts
            Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.ps1" | Invoke-Expression
            Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/JulienMaille/spicetify-dynamic-theme/master/install.ps1" | Invoke-Expression

            $osVersion = [version](Get-CimInstance Win32_OperatingSystem).Version
            $minWindowsVersion = [version]"10.0.22000.0"

            if ($osVersion -lt $minWindowsVersion) {
                $pwshPath = (Get-Command "pwsh.exe" -ErrorAction SilentlyContinue)
                if ($pwshPath) {
                    Write-Host "Detected a low version of Windows 10 - running dark mode patch with PowerShell 6+"
$darkModeCommand = @"
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/JulienMaille/spicetify-dynamic-theme/master/patch-dark-mode.ps1" | Invoke-Expression;
New-Item -Path '$tempDoneFile' -ItemType File -Force | Out-Null
"@

Start-Process $pwshPath -ArgumentList @(
    '-NoLogo',
    '-NoProfile',
    '-Command',
    $darkModeCommand
)
                } else {
                    Write-Warning "pwsh.exe not found. Skipping dark mode patch. Please install PowerShell 6+"
                }
            } else {
                Write-Host "Running dark mode patch in current session"
                Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/JulienMaille/spicetify-dynamic-theme/master/patch-dark-mode.ps1" | Invoke-Expression
                New-Item -Path $tempDoneFile -ItemType File -Force | Out-Null
            }
        }
    }
}

Write-Host "Setting taskbar layout..."
Set-ExplorerPinnedToTaskbar

# Cleanup
Write-Host "Cleaning up..."
Start-Job -ScriptBlock {
    Set-Location -Path "$env:USERPROFILE\Desktop"
    Remove-Item -Path "$env:USERPROFILE\Desktop\setup" -Recurse -Force
    Remove-Item -Path "$env:USERPROFILE\Desktop\apps.txt" -Force
}

# Download and install Office
$officeResponse = Read-Host "Install Office? Please enter 'y' or 'n'"
while ($response -notin @('y', 'n')) {
    $response = Read-Host "Invalid input. Please enter 'y' or 'n'"
}

if ($officeResponse -eq 'y') {
    Write-Host "Downloading and installing Office..."
    New-Item -ItemType Directory -Path "C:\Office" -Force
    Invoke-WebRequest -UseBasicParsing -Uri "https://officecdn.microsoft.com/pr/wsus/setup.exe" -OutFile "C:\Office\setup.exe"
    Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/prochy-exe/playground/refs/heads/main/windows%20setup/Configuration.xml" -OutFile "C:\Office\Configuration.xml"
    Start-Process -FilePath "C:\Office\setup.exe" -ArgumentList "/configure C:\Office\Configuration.xml" -Wait
}

# Windows/Office Activation
$activationResponse = Invoke-WebRequest -Uri "https://get.activated.win" -UseBasicParsing
& Invoke-Expression $activationResponse
