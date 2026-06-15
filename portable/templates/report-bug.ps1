<#
.SYNOPSIS
    U-Hermes 便携版 · 问题反馈收集器（借鉴 u-claw report-bug.mjs 思路）

.DESCRIPTION
    收集运行日志 + 系统信息 + hermes doctor 输出，打包成一个 zip 放到桌面。
    若设了环境变量 HERMES_REPORT_URL，则额外把 zip POST 上传到该地址。

    重要：本开源仓**不含**任何真实上报地址。地址完全从 HERMES_REPORT_URL
    读取，由商业版构建时注入。没设就只在本地生成 zip，用户手动发给客服。
    同理设备标识从 HERMES_DEVICE_ID 读（没有就用 anonymous），不含指纹算法。

.PARAMETER Usb   U 盘根目录
.PARAMETER App   hermes-agent 目录
.PARAMETER Uv    uv.exe 路径
#>
param(
    [Parameter(Mandatory=$true)][string]$Usb,
    [Parameter(Mandatory=$true)][string]$App,
    [Parameter(Mandatory=$true)][string]$Uv
)
$ErrorActionPreference = "Continue"

function Info($m) { Write-Host "  $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!]  $m" -ForegroundColor Yellow }

$stamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$work    = Join-Path $env:TEMP "u-hermes-report-$stamp"
New-Item -ItemType Directory -Force -Path $work | Out-Null

# 1) 系统信息
Info "收集系统信息 ..."
$sys = [ordered]@{
    product       = "u-hermes-portable"
    time          = (Get-Date).ToString("o")
    os            = [System.Environment]::OSVersion.VersionString
    arch          = $env:PROCESSOR_ARCHITECTURE
    psVersion     = $PSVersionTable.PSVersion.ToString()
    usbRoot       = $Usb
    deviceId      = if ($env:HERMES_DEVICE_ID) { $env:HERMES_DEVICE_ID } else { "anonymous" }
}
$sys | ConvertTo-Json | Set-Content -Path (Join-Path $work "system.json") -Encoding UTF8

# 2) hermes 版本 + doctor
Info "运行 hermes doctor ..."
$ver = & $Uv run --project $App hermes --version 2>&1
$ver | Out-File -FilePath (Join-Path $work "hermes-version.txt") -Encoding UTF8
$doc = & $Uv run --project $App hermes doctor 2>&1
$doc | Out-File -FilePath (Join-Path $work "hermes-doctor.txt") -Encoding UTF8

# 3) 日志（data\logs 下最近几个，尾部 256KB 截断避免太大）
Info "收集日志 ..."
$logDir = Join-Path $Usb "data\logs"
if (Test-Path $logDir) {
    $logs = Get-ChildItem -Path $logDir -Filter *.log -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 5
    $outLogs = Join-Path $work "logs"
    New-Item -ItemType Directory -Force -Path $outLogs | Out-Null
    foreach ($f in $logs) {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        $tail  = if ($bytes.Length -gt 262144) { $bytes[($bytes.Length-262144)..($bytes.Length-1)] } else { $bytes }
        [System.IO.File]::WriteAllBytes((Join-Path $outLogs $f.Name), $tail)
    }
}

# 4) 用户描述（可选，回车跳过）
Write-Host ""
$desc = Read-Host "  一句话描述问题（可直接回车跳过）"
if ($desc) { $desc | Set-Content -Path (Join-Path $work "description.txt") -Encoding UTF8 }

# 5) 打包到桌面
$desktop = [Environment]::GetFolderPath("Desktop")
if (-not $desktop -or -not (Test-Path $desktop)) { $desktop = $env:USERPROFILE }
$zip = Join-Path $desktop "u-hermes-report-$stamp.zip"
Info "打包 ..."
if (Test-Path $zip) { Remove-Item $zip -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($work, $zip)
Ok "已生成: $zip"

# 6) 可选上传（地址走环境变量，开源仓不含真实地址）
if ($env:HERMES_REPORT_URL) {
    Info "上传到 $env:HERMES_REPORT_URL ..."
    try {
        $form = @{
            file      = Get-Item $zip
            product   = "u-hermes-portable"
            device_id = $sys.deviceId
        }
        # PS 5.1 没有原生 multipart，简单用 InFile 上传 zip 二进制
        Invoke-RestMethod -Uri $env:HERMES_REPORT_URL -Method Post -InFile $zip -ContentType "application/zip" -TimeoutSec 30 | Out-Null
        Ok "上传成功。感谢反馈！"
    } catch {
        Warn "上传失败：$_"
        Warn "请手动把桌面的 zip 发给客服。"
    }
} else {
    Write-Host ""
    Info "未配置上传地址，请把桌面上的 zip 发给客服："
    Write-Host "    $zip" -ForegroundColor White
}

# 清理临时目录
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
