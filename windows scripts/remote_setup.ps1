param (
    [string]$publicKey
)

if ($args -contains "-h") {
    Write-Host "Sample command execution: `n"
    Write-Host "powershell -File remote_setup.ps1 -publicKey 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD'" -ForegroundColor Cyan #this key isn't used, at least not by me xd
    exit
}

if ([string]::IsNullOrEmpty($publicKey)) {
    Write-Host "Public key is required." -ForegroundColor Red
    exit
}

# Check for admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "You need to run this script as an administrator." -ForegroundColor Red
    exit
}

$sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($null -eq $sshdService) {
    # Install OpenSSH
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'
    if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
        Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    } else {
        Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
    }
} else {
    Write-Output "OpenSSH Server (sshd) is already installed and running."
}

# Function to add a directory to the system PATH
function AddToPath {
    param(
        [string]$PathToAdd
    )
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$PathToAdd*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$PathToAdd", "Machine")
        Write-Host "Added $PathToAdd to PATH."
    } else {
        Write-Host "$PathToAdd is already in PATH."
    }
}

# Create a folder
$folderPath = "C:\Program Files (x86)\Tools"
if (!(Test-Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory | Out-Null
}

# Add the folder to PATH
AddToPath $folderPath

# Download helpers
$guardContent = "https://raw.githubusercontent.com/prochy-exe/playground/main/command_ssh_guard.bat"
$pathToGuard = "C:\Program Files (x86)\Tools\command_ssh_guard.bat"
Invoke-WebRequest -Uri $guardContent -OutFile $pathToGuard

$zzzContent = "https://raw.githubusercontent.com/prochy-exe/playground/main/zzz.bat"
$pathToZzz = "C:\Program Files (x86)\Tools\zzz.bat"
Invoke-WebRequest -Uri $zzzContent -OutFile $pathToZzz

$offContent = "https://raw.githubusercontent.com/prochy-exe/playground/main/off.bat"
$pathToOff = "C:\Program Files (x86)\Tools\off.bat"
Invoke-WebRequest -Uri $offContent -OutFile $pathToOff

# Modify sshd config
$sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
if (Test-Path $sshdConfigPath) {
    $sshdConfigContent = Get-Content $sshdConfigPath
    $modifiedContent = $sshdConfigContent | ForEach-Object {
        if ($_ -match "^#?PasswordAuthentication") {
            $_ -replace "PasswordAuthentication yes", "PasswordAuthentication no"
        }
        elseif ($_ -match "^#?PubkeyAuthentication") {
            $_ -replace "#PubkeyAuthentication no", "PubkeyAuthentication yes"
        }
        else {
            $_
        }
    }
    $modifiedContent | Set-Content $sshdConfigPath
} else {
    Write-Host "sshd_config not found at $sshdConfigPath."
}

$authKeys = "C:\ProgramData\ssh\administrators_authorized_keys"
if (!(Test-Path $authKeys)) {
    New-Item -Path $authKeys -ItemType File | Out-Null
    Write-Host "Created administrators_authorized_keys"
} else {
    $authKeyContent = "command=`"command_ssh_guard`" $($publicKey)"
    Add-Content -Path $authKeys -Value "`n" -NoNewline
}
Add-Content -Path $authKeys -Value "$authKeyContent" -NoNewline
Write-Host "Appended SSH key to administrators_authorized_keys"
Restart-Service -Name $serviceName
