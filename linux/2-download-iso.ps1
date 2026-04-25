# Step 2: download Ubuntu Desktop ISO for the U-Hermes Linux USB.

$ErrorActionPreference = "Stop"

$UbuntuVersion = "24.04.4"
$IsoName = "ubuntu-$UbuntuVersion-desktop-amd64.iso"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$CacheDir = Join-Path $ScriptRoot ".download-cache"
$IsoPath = Join-Path $CacheDir $IsoName
$ShaPath = Join-Path $CacheDir "SHA256SUMS"

$MirrorBases = @(
    "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/24.04",
    "https://mirrors.aliyun.com/ubuntu-releases/24.04",
    "https://mirrors.ustc.edu.cn/ubuntu-releases/24.04",
    "https://releases.ubuntu.com/24.04"
)

New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

Write-Host "U-Hermes Linux USB - Step 2/4: Download Ubuntu ISO" -ForegroundColor Cyan
Write-Host "Target: $IsoName"

if (-not (Test-Path $IsoPath)) {
    $downloaded = $false
    foreach ($base in $MirrorBases) {
        $url = "$base/$IsoName"
        try {
            Write-Host "Downloading from $url"
            Invoke-WebRequest -Uri $url -OutFile $IsoPath
            $downloaded = $true
            break
        } catch {
            Write-Host "Failed: $url" -ForegroundColor Yellow
            Remove-Item -Path $IsoPath -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not $downloaded) {
        throw "Could not download $IsoName from any mirror."
    }
} else {
    Write-Host "Using cached $IsoPath"
}

$expectedHash = $null
foreach ($base in $MirrorBases) {
    try {
        Invoke-WebRequest -Uri "$base/SHA256SUMS" -OutFile $ShaPath
        $line = Select-String -Path $ShaPath -Pattern "\*$IsoName| $IsoName" | Select-Object -First 1
        if ($line) {
            $expectedHash = ($line.Line -split "\s+")[0].ToLowerInvariant()
            break
        }
    } catch {
        Write-Host "Could not read SHA256SUMS from $base" -ForegroundColor Yellow
    }
}

if ($expectedHash) {
    Write-Host "Verifying SHA256..."
    $actualHash = (Get-FileHash -Algorithm SHA256 -Path $IsoPath).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "SHA256 mismatch for $IsoName. Delete $IsoPath and run this script again."
    }
    Write-Host "SHA256 OK" -ForegroundColor Green
} else {
    Write-Host "SHA256SUMS not found for $IsoName; file was downloaded but not verified." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 2 complete. Continue with: .\3-create-persistence.ps1" -ForegroundColor Green
