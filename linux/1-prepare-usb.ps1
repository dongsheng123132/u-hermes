# Step 1: download Ventoy and open Ventoy2Disk.
# Run in Windows PowerShell. Ventoy will format the selected USB drive.

$ErrorActionPreference = "Stop"

$VentoyVersion = "1.0.99"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$CacheDir = Join-Path $ScriptRoot ".download-cache"
$ZipPath = Join-Path $CacheDir "ventoy-$VentoyVersion-windows.zip"
$ExtractDir = Join-Path $CacheDir "ventoy-$VentoyVersion"
$VentoyUrl = "https://github.com/ventoy/Ventoy/releases/download/v$VentoyVersion/ventoy-$VentoyVersion-windows.zip"

New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

Write-Host "U-Hermes Linux USB - Step 1/4: Prepare Ventoy" -ForegroundColor Cyan
Write-Host ""
Write-Host "Detected USB disks:" -ForegroundColor Yellow
Get-CimInstance Win32_DiskDrive |
    Where-Object { $_.InterfaceType -eq "USB" } |
    Select-Object Model, Size, DeviceID |
    Format-Table -AutoSize

Write-Host ""
Write-Host "WARNING: Ventoy installation formats the selected USB drive." -ForegroundColor Red
Read-Host "Press Enter to download/open Ventoy, or Ctrl+C to cancel"

if (-not (Test-Path $ZipPath)) {
    Write-Host "Downloading Ventoy $VentoyVersion..."
    Invoke-WebRequest -Uri $VentoyUrl -OutFile $ZipPath
} else {
    Write-Host "Using cached $ZipPath"
}

if (-not (Test-Path $ExtractDir)) {
    Write-Host "Extracting Ventoy..."
    Expand-Archive -Path $ZipPath -DestinationPath $CacheDir -Force
}

$VentoyExe = Get-ChildItem -Path $ExtractDir -Recurse -Filter "Ventoy2Disk.exe" | Select-Object -First 1
if (-not $VentoyExe) {
    throw "Ventoy2Disk.exe not found under $ExtractDir"
}

Write-Host ""
Write-Host "Opening Ventoy2Disk as administrator. Select the USB drive and click Install." -ForegroundColor Yellow
Start-Process -FilePath $VentoyExe.FullName -Verb RunAs -Wait

Write-Host ""
Write-Host "Step 1 complete. Continue with: .\2-download-iso.ps1" -ForegroundColor Green
