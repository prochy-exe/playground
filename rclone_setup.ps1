
param (
    [string]$rclonePath,
    [string]$mountLetter,
    [string]$mountName,
    [string]$configName
)


if ($args -contains "-h") {
    Write-Host "Sample command execution: `n" -ForegroundColor Cyan
    Write-Host "rclone_setup.ps1 -rclonePath 'C:\Path\To\Binary.exe' -mountLetter 'M' -mountName 'MountName' -configName 'ConfigName'" -ForegroundColor Cyan
    Write-Host "-configName is optional, if not specified, the first config from rclone.conf will be used" -ForegroundColor Cyan
    Write-Host "if no configs are found, the script will call rclone config" -ForegroundColor Cyan
    exit
}

if ([string]::IsNullOrEmpty($rclonePath) -or [string]::IsNullOrEmpty($mountLetter) -or [string]::IsNullOrEmpty($mountName)) {
    Write-Host "rclonePath, mountLetter, and mountName are required." -ForegroundColor Red
    Write-Host "Use -h for help." -ForegroundColor Red
    exit
}

$mountLetter = $mountLetter -replace "[^a-zA-Z]", ""
$mountLetter = $mountLetter.ToUpper()

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "You need to run this script as an administrator." -ForegroundColor Red
    exit
}

if (Test-Path $rclonePath){
    $rcloneFullPath = $rclonePath
} else {
    $rcloneFullPath = (Get-Command rclone).Source
}

if ([string]::IsNullOrEmpty($configName)) {
    $rcloneConfigPath = "$env:APPDATA\rclone\rclone.conf"
    if (-not (Test-Path -Path $rcloneConfigPath)) {
        & $rclonePath config
    }
    $rcloneConfig = Get-Content $rcloneConfigPath
    if ($null -eq $rcloneConfig) {
        & $rclonePath config
    }
    $configName = ($rcloneConfig | Select-String -Pattern '\[(.*?)\]' | Select-Object -First 1).Matches.Groups[1].Value
}

if (-not (Test-Path -Path "C:\Program Files\Tools\nssm.exe")) {
    $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
    $tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    $targetDir = Get-Item - Path "$rcloneFullPath" | Select-Object -ExpandProperty DirectoryName
    
    New-Item -ItemType Directory -Path $tempDir -Force
    
    $nssmZipPath = "$tempDir\nssm-2.24.zip"
    Invoke-WebRequest -Uri $nssmUrl -OutFile $nssmZipPath
    
    Expand-Archive -Path $nssmZipPath -DestinationPath $tempDir
    
    $arch = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
    $nssmSourcePath = Join-Path -Path $tempDir -ChildPath "nssm-2.24\$arch\nssm.exe"
    
    if (-not (Test-Path -Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force
    }
    
    $nssmTargetPath = Join-Path -Path $targetDir -ChildPath "nssm.exe"
    Copy-Item -Path $nssmSourcePath -Destination $nssmTargetPath -Force
    Remove-Item -Path $tempDir -Recurse -Force
}

$startParameters = "mount --volname `"$($mountName)`" $($configName): $($mountLetter):"
$usernamePassword = Read-Host -Prompt "Enter the password of your Windows user account"
Start-Process -FilePath "C:\Program Files\Tools\nssm.exe" -ArgumentList "install rclone `"$($rcloneFullPath)`" `"$($startParameters)`"" -Wait
Start-Process -FilePath "C:\Program Files\Tools\nssm.exe" -ArgumentList "set rclone ObjectName `".\$($env:USERNAME)`" `"$($usernamePassword)`"" -Wait
Start-Service -Name rclone
