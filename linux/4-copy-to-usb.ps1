# Step 4: copy Ubuntu ISO, persistence image, Ventoy config, and U-Hermes scripts to the USB drive.

$ErrorActionPreference = "Stop"

$UbuntuVersion = "24.04.4"
$IsoName = "ubuntu-$UbuntuVersion-desktop-amd64.iso"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$CacheDir = Join-Path $ScriptRoot ".download-cache"
$IsoPath = Join-Path $CacheDir $IsoName
$PersistencePath = Join-Path $CacheDir "persistence.dat"
$VentoyConfigPath = Join-Path $ScriptRoot "ventoy\ventoy.json"

Write-Host "U-Hermes Linux USB - Step 4/4: Copy files to USB" -ForegroundColor Cyan

foreach ($path in @($IsoPath, $PersistencePath, $VentoyConfigPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing required file: $path"
    }
}

$volumes = @(Get-Volume | Where-Object { $_.DriveLetter -and ($_.FileSystemLabel -match "Ventoy|VENTOY") })
if (-not $volumes) {
    Write-Host "Could not auto-detect a Ventoy volume." -ForegroundColor Yellow
    Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, SizeRemaining, Size | Format-Table -AutoSize
    $letter = Read-Host "Enter the Ventoy USB drive letter, for example E"
} elseif ($volumes.Count -eq 1) {
    $letter = $volumes[0].DriveLetter
    Write-Host "Detected Ventoy drive: $letter`:"
} else {
    $volumes | Select-Object DriveLetter, FileSystemLabel, SizeRemaining, Size | Format-Table -AutoSize
    $letter = Read-Host "Multiple Ventoy volumes found. Enter the drive letter"
}

$UsbRoot = "$letter`:\"
if (-not (Test-Path $UsbRoot)) {
    throw "Drive not found: $UsbRoot"
}

$free = (Get-Volume -DriveLetter $letter).SizeRemaining
$need = (Get-Item $IsoPath).Length + (Get-Item $PersistencePath).Length
if ($free -lt $need) {
    throw "Not enough free space on $UsbRoot. Need at least $([math]::Round($need / 1GB, 1)) GB."
}

Write-Host "Copying Ubuntu ISO..."
Copy-Item -Path $IsoPath -Destination (Join-Path $UsbRoot $IsoName) -Force

Write-Host "Copying persistence image..."
Copy-Item -Path $PersistencePath -Destination (Join-Path $UsbRoot "persistence.dat") -Force

Write-Host "Copying Ventoy config..."
New-Item -ItemType Directory -Force -Path (Join-Path $UsbRoot "ventoy") | Out-Null
Copy-Item -Path $VentoyConfigPath -Destination (Join-Path $UsbRoot "ventoy\ventoy.json") -Force

Write-Host "Copying U-Hermes Linux setup scripts..."
$TargetDir = Join-Path $UsbRoot "u-hermes-linux"
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
Copy-Item -Path (Join-Path $ScriptRoot "setup-hermes.sh") -Destination $TargetDir -Force
Copy-Item -Path (Join-Path $ScriptRoot "start-hermes.sh") -Destination $TargetDir -Force
Copy-Item -Path (Join-Path $ScriptRoot "config.example") -Destination $TargetDir -Force

Write-Host ""
Write-Host "Done. Boot a target PC from the USB drive, then run:" -ForegroundColor Green
Write-Host "  sudo bash /media/*/Ventoy/u-hermes-linux/setup-hermes.sh"
