# Step 3: create Ubuntu Live persistence image.
# WSL is recommended so the image can be formatted as ext4 with label casper-rw.

param(
    [ValidateRange(1, 128)]
    [int]$SizeGB = 20
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$CacheDir = Join-Path $ScriptRoot ".download-cache"
$PersistencePath = Join-Path $CacheDir "persistence.dat"

function ConvertTo-WslPath([string]$WindowsPath) {
    $full = [System.IO.Path]::GetFullPath($WindowsPath)
    if ($full -notmatch "^([A-Za-z]):\\(.*)$") {
        throw "Cannot convert path to WSL path: $full"
    }
    $drive = $matches[1].ToLowerInvariant()
    $rest = $matches[2] -replace "\\", "/"
    return "/mnt/$drive/$rest"
}

New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

Write-Host "U-Hermes Linux USB - Step 3/4: Create persistence image" -ForegroundColor Cyan
Write-Host "Target: $PersistencePath ($SizeGB GB)"

if (Test-Path $PersistencePath) {
    Write-Host "Existing persistence image found: $PersistencePath" -ForegroundColor Yellow
    $answer = Read-Host "Overwrite it? Type YES to continue"
    if ($answer -ne "YES") {
        Write-Host "Cancelled."
        exit 0
    }
    Remove-Item -Path $PersistencePath -Force
}

$bytes = [int64]$SizeGB * 1024 * 1024 * 1024
$stream = [System.IO.File]::Open($PersistencePath, [System.IO.FileMode]::CreateNew)
try {
    $stream.SetLength($bytes)
} finally {
    $stream.Close()
}

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($wsl) {
    $wslPath = ConvertTo-WslPath $PersistencePath
    Write-Host "Formatting ext4 via WSL..."
    wsl.exe bash -lc "mkfs.ext4 -F -L casper-rw '$wslPath'"
    if ($LASTEXITCODE -ne 0) {
        throw "mkfs.ext4 failed in WSL."
    }
    Write-Host "Persistence image formatted as ext4 label=casper-rw" -ForegroundColor Green
} else {
    Write-Host "WSL not found. Created an empty file only." -ForegroundColor Yellow
    Write-Host "Before using persistence, boot Ubuntu once and run:"
    Write-Host "  sudo mkfs.ext4 -F -L casper-rw /media/*/Ventoy/persistence.dat"
}

Write-Host ""
Write-Host "Step 3 complete. Continue with: .\4-copy-to-usb.ps1" -ForegroundColor Green
