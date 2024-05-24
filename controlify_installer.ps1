$systemArch = $Env:PROCESSOR_ARCHITECTURE

if (("$systemArch" -eq "AMD64") -or ("$systemArch" -eq "x86")) {
    $programFiles = "C:\Program Files (x86)"
    $exeArch = "x86"
} else {
    $programFiles = "C:\Program Files (arm)"
    $exeArch = "arm"
}

$controlifyDir = $programFiles + "\Controlify"

function Grant-Ownership {
    param (
        [string]$FilePath
    )
    # Take ownership of the file or directory
    try {
        & takeown /f $FilePath /R *>$null
    } catch {
        Write-Host "Failed to take ownership: $_" -ForegroundColor Red
        exit
    }

    # Grant full control permissions
    try {
        & icacls $FilePath /grant *S-1-3-4:F /t /c /l *>$null
    } catch {
        Write-Host "Failed to grant permissions: $_" -ForegroundColor Red
        exit
    }
}

function Add-StartupShortcut {
    param(
        [string]$controlifyName,
        [string]$controlifyExe,
        [string]$controlifyArgs
    )
    $startupPath = [Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path -Path $startupPath -ChildPath "$controlifyName.lnk"

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = $controlifyExe
    $Shortcut.WorkingDirectory = $controlifyDir
    $Shortcut.Arguments = $controlifyArgs
    $Shortcut.Save()
}

function Add-StartUpTask {
    param(
        [string]$controlifyName,
        [string]$controlifyExe,
        [string]$controlifyArgs
    )
    $taskTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $taskAction = New-ScheduledTaskAction -Execute $controlifyExe -Argument "$controlifyArgs" -WorkingDirectory $controlifyDir

    Register-ScheduledTask "Start $controlifyName" -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings
}

function Get-Controlify {
    $controlifyUrl = "https://github.com/prochy-exe/controlify/releases/latest/download/windows-$exeArch-controlify.zip"
    if (-not (Test-Path -Path $controlifyDir)) {
        New-Item -ItemType Directory -Path $controlifyDir -Force | Out-Null
    }
    Invoke-WebRequest -Uri $controlifyUrl -OutFile "$controlifyDir\controlify.zip"
    Expand-Archive -Path "$controlifyDir\controlify.zip" -DestinationPath $controlifyDir
    Remove-Item "$controlifyDir\controlify.zip"
    Grant-Ownership "$controlifyDir"
    Write-Host "Download complete, we will now open the config.json so you can configure the keybinds for different events..."
    Read-Host -Prompt "Press Enter to continue..."
    & "$controlifyDir\config.json" *>$null
    Read-Host -Prompt "When you are done configuring, press Enter to continue..."
}

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "You need to run this script as an administrator." -ForegroundColor Red
    exit
}

if (-not (Test-Path -Path "$controlifyDir")) {
    $downloadRequest = Read-Host -Prompt "Do you want to download Controlify? (yes/y no/n)"
    if (($downloadRequest -eq "yes") -or ($downloadRequest -eq "y")) {
        Get-Controlify
    } else {
        Write-Output "You need Controlify at $controlifyDir to continue. Exiting..."
        exit
    }
} else {
    Write-Output "Controlify is already installed at $controlifyDir"
}

if (Test-Path -Path "$controlifyDir") {
    $startupOption = Read-Host -Prompt "Start Controlify on startup (y/yes n/no)?"
    if (($startupOption -eq "y") -or ($startupOption -eq "yes")) {
        $watcherOption = Read-Host -Prompt "Use Controlify Watcher (y/yes n/no)?"
        if (($watcherOption -eq "y") -or ($watcherOption -eq "yes")) {
            $controlifyWatcherUrl = "https://github.com/prochy-exe/playground/raw/main/controlifywatcher/build/windows-$exeArch/controlifywatcher.exe"
            if (-not (Test-Path -Path "$controlifyDir\controlifywatcher.exe")) {
                Invoke-WebRequest -Uri $controlifyWatcherUrl -OutFile "$controlifyDir\controlifywatcher.exe"
            }
            $startupMessage = "Controlify will run on startup with Controlify Watcher."
            Write-Host "Controlify Watcher can run completely hidden in the background if you'd like."
            Write-Host "If you'd like to close it, you'll have to do so via the Task Manager."
            Write-Host "However, you can also choose to show it in the system tray."
            $watcherTrayOption = Read-Host -Prompt "Show Controlify Watcher in tray (y/yes n/no)?"
            $shortcutTarget = $controlifyDir + "\controlifywatcher.exe"
            $shortcutApp = "Controlify Watcher"
            if (("$watcherTrayOption" -ne "y") -and (-not "$watcherTrayOption" -ne "yes")) {
                $shortcutArgs = "--silent "
            }
        } else {
            $startupMessage = "Controlify will run on startup."
            $shortcutTarget = $controlifyPath + "\controlify.exe"
            $shortcutApp = "Controlify"
        }
        $controlifyMode = Read-Host -Prompt "Would you like to run Controlify in tray (y/yes n/no)?"
        if (("$controlifyMode" -ne "y") -and ("$controlifyMode" -ne "yes")) {
            $shortcutArgs = $shortcutArgs + "--cli"
        }
        Write-Host "Enter 1 for regular startup shortcut, or 2 for startup task."
        Write-Host "The only difference is that the startup task will run sooner than the shortcut."
        while ($true) {
            $startupType = Read-Host -Prompt "Option"
            if ($startupType -eq "1") {
                Add-StartupShortcut "$shortcutApp" "$shortcutTarget" "$shortcutArgs"
                break
            } elseif ($startupType -eq "2") {
                Add-StartUpTask "$shortcutApp" "$shortcutTarget" "$shortcutArgs"
                break
            } else {
                Write-Host "Invalid option, please type 1 or 2."
            }
        }
    } else {
        $startupMessage = "Controlify will not run on startup."
    }
    Write-Output "Controlify has been installed to $controlifyDir"
    Write-Output $startupMessage
    Write-Output "Controlify setup complete, happy listening!"
    $startControlify = Read-Host -Prompt "Start Controlify now? (y/yes n/no)"
    if (($startControlify -eq "y") -or ($startControlify -eq "yes")) {
        if (($startupOption -eq "y") -or ($startupOption -eq "yes")) {
            & "$shortcutTarget" $shortcutArgs
        } else {
            & "$controlifyDir\controlify.exe"
        }
    }
    
} else {
    Write-Output "You need Controlify installed at $controlifyDir. Exiting..."
    exit
}