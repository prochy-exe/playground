param (
    [string]$deejPath
)

function Test-IsExecutable {
    param (
        [string]$path
    )

    if (Test-Path $path) {
        $extension = [System.IO.Path]::GetExtension($path)
        return $extension -eq ".exe"
    }

    return $false
}

$programFiles = "C:\Program Files (x86)"

if (-not $deejPath) {
    $deejDir = $programFiles + "\deej"
    $deejPath = $programFiles + "\deej\deej.exe"
} else {
    $deejDir = Get-Item -Path $deejPath | Select-Object -ExpandProperty DirectoryName
}

function Add-StartupShortcut {
    $startupPath = [Environment]::GetFolderPath("Startup")
    $shortcutPath = $startupPath + "\deej.lnk"

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = $deejPath
    $Shortcut.WorkingDirectory = $deejDir
    $Shortcut.Save()
}

function Add-StartUpTask {
    $taskTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $taskAction = New-ScheduledTaskAction -Execute $deejPath -WorkingDirectory $deejDir

    Register-ScheduledTask "Start deej" -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings
}
function Get-Deej {
    $deejUrl = "https://github.com/prochy-exe/deej/releases/latest/download/deej.exe"
    $configUrl = "https://github.com/prochy-exe/deej/releases/latest/download/config.yaml"

    if (-not (Test-Path -Path $deejDir)) {
        New-Item -ItemType Directory -Path $deejDir -Force | Out-Null
    }

    Invoke-WebRequest -Uri $deejUrl -OutFile "$deejDir\deej.exe"
    Invoke-WebRequest -Uri $configUrl -OutFile "$deejDir\config.yaml"
    Write-Host "Download complete, we will now open the config.yaml and Device Manager so you can configure the COM port of your Arduino..."
    Write-Host "Please make sure to set the correct COM port in the config.yaml file."
    Write-Host "Your COM port can be found in Device Manager under 'Ports (COM & LPT)'. (Ignore COM1, it's not a real port.)"
    Read-Host -Prompt "Press Enter to continue..."
    Grant-Ownership $deejDir
    & "$deejDir\config.yaml" *>$null
    & "devmgmt.msc" *>$null
    Read-Host "When you are done configuring, press Enter to continue..."
}

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

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "You need to run this script as an administrator." -ForegroundColor Red
    exit
}

if (-not (Test-Path -Path "$deejPath")) {
    $downloadRequest = Read-Host -Prompt "Do you want to download deej? (y/yes n/no)"
    if (($downloadRequest -eq "yes") -or ($downloadRequest -eq "y")) {
        Get-Deej
    } else {
        Write-Output "Please run again with the path to the deej executable. Exiting..."
        exit
    }
} elseif (-not (Test-IsExecutable $deejPath)) {
    Write-Output "The provided path does not point to an executable. Exiting..."
    exit
}

$deejConfig = $deejDir + "\config.yaml"

if ((Test-IsExecutable "$deejPath") -and (Test-Path -Path "$deejConfig")) {
    $startupOption = Read-Host -Prompt "Start deej on startup? (y/yes n/no)"
    if (($startupOption -eq "y") -or ($startupOption -eq "yes")) {
        Write-Host "Enter 1 for regular startup shortcut, or 2 for startup task."
        Write-Host "The only difference is that the startup task will run sooner than the shortcut."
        while ($true) {
            $startupType = Read-Host -Prompt "Option"
            if ($startupType -eq "1") {
                Add-StartupShortcut
                break
            } elseif ($startupType -eq "2") {
                Add-StartUpTask
                break
            } else {
                Write-Host "Invalid option, please type 1 or 2."
            }
        }
        $startupMessage = "deej will run on startup."
    } else {
        $startupMessage = "deej will not run on startup."
    }

    Write-Output "deej has been installed to $deejDir"
    Write-Output $startupMessage
    Write-Output "deej setup complete, happy listening!"
    $startDeej = Read-Host -Prompt "Start deej now? (y/yes n/no)"
    if (($startDeej -eq "y") -or ($startDeej -eq "yes")) {
        & $deejPath
    }
} else {
    if (-not (Test-IsExecutable $deejPath)) {
        Write-Output "The provided path does not point to an executable. Exiting..."
    } else {
        Write-Output "Config file does not exist at $deejConfig. Exiting..."
    }
}