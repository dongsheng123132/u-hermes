<#
.SYNOPSIS
    U-Hermes 便携版 · Windows 构建脚本（build kit）

.DESCRIPTION
    在一台【联网】的 Windows 开发机上跑一次，把上游 NousResearch/hermes-agent
    连同它的 Python / 依赖 / uv / PortableGit / ripgrep / ffmpeg 全部装进一个
    目录里，产出一个【完全离线、插上即用】的便携 U 盘目录：

        <Output>\U-Hermes\
            Windows-Start.bat       双击入口
            README.txt              客户说明
            runtime\win\            uv + python + git + tools（只读运行时）
            app\hermes-agent\       上游源码 + venv（离线已装好）
            cache\                  uv wheel 缓存（离线兜底）
            data\.env.example       配置模板

    原理：把 uv 的所有路径（UV_PYTHON_INSTALL_DIR / UV_CACHE_DIR）锁进输出目录内部，
    再用便携 uv 直接 clone + uv venv .venv + uv sync 把整套环境装进去
    （不调上游 install.ps1，它在代理环境下会卡在自举装 uv）。运行时启动脚本
    用 "uv run --project" 就地解析 .venv，所以换盘符 / 换机器都不会坏。

.PARAMETER Output
    输出根目录（会在下面创建 U-Hermes 子目录）。可直接给 U 盘盘符，如 D:\
    默认：当前目录下的 .\dist

.PARAMETER Tag
    要打包的上游 release tag。上游用日历版号（v2026.6.5 = 2026-06-05 的 "Surface" 版，
    自带 in-app self-update + 简体中文）。建议 pin 到具体 tag 保证可复现。
    默认：v2026.6.5。想跟最新可传 -Tag main（不可复现，不推荐）。
    最新版查询：https://github.com/NousResearch/hermes-agent/releases

.PARAMETER Name
    便携目录名。默认 U-Hermes。

.PARAMETER Proxy
    构建过程走的 HTTP 代理（下载上游 / wheel 用）。如 http://127.0.0.1:7897
    只影响构建，不写进成品。

.EXAMPLE
    pwsh portable\build-portable-win.ps1 -Output D:\ -Tag v2026.6.5

.EXAMPLE
    pwsh portable\build-portable-win.ps1 -Output .\dist -Proxy http://127.0.0.1:7897
#>

[CmdletBinding()]
param(
    [string]$Output = ".\dist",
    [string]$Tag = "v2026.6.5",
    [string]$Name = "U-Hermes",
    [string]$Proxy = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # 加速 Invoke-WebRequest

# 脚本所在目录 → 找 templates\
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateDir = Join-Path $ScriptDir "templates"

function Info($m)  { Write-Host "  $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m)  { Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Die($m)   { Write-Host "  [ERROR] $m" -ForegroundColor Red; exit 1 }

# 调用原生命令（git/uv）专用：它们常把进度写 stderr，在 $ErrorActionPreference=Stop
# 下会被 PowerShell 误当异常抛出并中断脚本。这里临时放行，只靠退出码判断成败。
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Exe @Arguments 2>&1 | ForEach-Object { Write-Host $_ }
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $old
    }
}
function Step($n,$t) { Write-Host ""; Write-Host "  [$n] $t" -ForegroundColor White }

Write-Host ""
Write-Host "  ==========================================" -ForegroundColor White
Write-Host "    U-Hermes 便携版 · Windows 构建" -ForegroundColor White
Write-Host "  ==========================================" -ForegroundColor White

# ─── 解析输出路径 ───
# 注意：New-Item 不能拿来"创建"盘根（如 Z:\），只解析；不存在的普通目录才创建。
$resolved = Resolve-Path -LiteralPath $Output -ErrorAction SilentlyContinue
if ($resolved) {
    $OutFull = $resolved.ProviderPath
} else {
    $OutFull = (New-Item -ItemType Directory -Force -Path $Output).FullName
}
$OutFull = $OutFull.TrimEnd('\')   # 去掉盘根尾部反斜杠，免得 Join-Path 出双斜杠
$Root    = Join-Path $OutFull $Name

$RuntimeWin = Join-Path $Root "runtime\win"
$PythonDir  = Join-Path $RuntimeWin "python"
$ToolsDir   = Join-Path $RuntimeWin "tools"
$CacheDir   = Join-Path $Root "cache"
$AppDir     = Join-Path $Root "app\hermes-agent"
$DataDir    = Join-Path $Root "data"

Info "输出目录: $Root"
if ($Tag) { Info "上游 tag : $Tag" } else { Warn "未指定 -Tag，使用 main 分支最新（不可复现，正式发版建议 pin tag）" }

# ─── 代理 ───
if ($Proxy) {
    Info "构建代理: $Proxy"
    $env:HTTP_PROXY  = $Proxy
    $env:HTTPS_PROXY = $Proxy
}
# 回环不走代理
$env:NO_PROXY = "127.0.0.1,localhost,::1"

# ─── 前置检查 ───
Step "0/6" "环境检查"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Die "需要 git。请先安装 Git for Windows（构建机需要，成品 U 盘不需要系统 git）。"
}
Ok "git 可用"

# ─── 1. 创建骨架 ───
Step "1/6" "创建便携目录骨架"
foreach ($d in @($RuntimeWin, $PythonDir, $ToolsDir, $CacheDir, (Split-Path $AppDir), $DataDir)) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}
Ok "目录已建"

# ─── 2. 下载便携 uv ───
Step "2/6" "下载便携 uv"
$UvExe = Join-Path $RuntimeWin "uv.exe"
if (Test-Path $UvExe) {
    Ok "uv.exe 已存在，跳过"
} else {
    # astral-sh/uv 官方 Windows x86_64 release（standalone，无需安装）
    $uvUrl = "https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip"
    $uvZip = Join-Path $env:TEMP "uv-portable.zip"
    Info "从 $uvUrl"
    try {
        Invoke-WebRequest -Uri $uvUrl -OutFile $uvZip -UseBasicParsing
    } catch {
        Die "下载 uv 失败：$_  （检查网络 / 代理 -Proxy）"
    }
    Expand-Archive -Path $uvZip -DestinationPath $RuntimeWin -Force
    Remove-Item $uvZip -Force
    if (-not (Test-Path $UvExe)) {
        # 某些 release 解出来在子目录，扒出来
        $found = Get-ChildItem -Path $RuntimeWin -Filter uv.exe -Recurse | Select-Object -First 1
        if ($found) { Move-Item $found.FullName $UvExe -Force }
    }
    if (-not (Test-Path $UvExe)) { Die "解压后找不到 uv.exe" }
    Ok "uv 就位: $UvExe"
}

# ─── 3. 用我们已下好的便携 uv，把 Python + hermes-agent 装进 U 盘 ───
# 注：不依赖上游 install.ps1 —— 它会试图自举安装自己的 uv 到 data\bin，在
# 代理/重定向环境下易失败。我们已有可用 uv，直接 clone + uv venv + uv sync 更可控。
Step "3/6" "装 Python + hermes-agent[all]（git clone + uv venv + uv sync，联网，较慢）"

# 关键：让 uv 把 python / 缓存 / 自身都放进 U 盘目录内
$env:UV_INSTALL_DIR        = $RuntimeWin     # uv 自更新时也放这
$env:UV_PYTHON_INSTALL_DIR = $PythonDir      # 托管 Python 放这
$env:UV_CACHE_DIR          = $CacheDir       # wheel 缓存放这
$env:UV_NO_MODIFY_PATH     = "1"             # 别动系统 PATH
$env:HERMES_HOME           = $DataDir        # 数据目录
$env:PATH = "$RuntimeWin;$ToolsDir;$($env:PATH)"

# 3a. clone 上游源码（pin 到 tag）
if (-not (Test-Path (Join-Path $AppDir "pyproject.toml"))) {
    # 若上次残留了空 .git 目录，先清掉，否则 git clone 会拒绝
    if (Test-Path $AppDir) { Remove-Item -Recurse -Force $AppDir }
    $repo = "https://github.com/NousResearch/hermes-agent.git"
    Info "git clone $repo @ $(if($Tag){$Tag}else{'main'})"
    if ($Tag) {
        $rc = Invoke-Native git @("clone","--depth","1","--branch",$Tag,$repo,$AppDir)
    } else {
        $rc = Invoke-Native git @("clone","--depth","1",$repo,$AppDir)
    }
    if ($rc -ne 0) { Die "git clone 失败（检查网络 / 代理 / tag 是否存在）" }
} else {
    Ok "源码已存在，跳过 clone"
}

# 3b. 装 Python 3.11（进 U 盘 python/）
Info "uv python install 3.11 ..."
$rc = Invoke-Native $UvExe @("python","install","3.11")
if ($rc -ne 0) { Die "uv python install 3.11 失败" }

# 3c. 建 venv + 装依赖
# 必须叫 .venv（uv 默认名）：否则 uv run 不认，会在客户机当场新建 .venv 重装依赖，
# 破坏离线。叫 .venv 则 uv run 直接复用，真离线、零重建。
$VenvDir = Join-Path $AppDir ".venv"
Push-Location $AppDir
try {
    Info "uv venv ..."
    $rc = Invoke-Native $UvExe @("venv",$VenvDir,"--python","3.11")
    if ($rc -ne 0) { Die "uv venv 失败" }

    $env:UV_PROJECT_ENVIRONMENT = $VenvDir
    $env:VIRTUAL_ENV            = $VenvDir

    # 优先锁文件同步（hash 校验），失败逐级回退
    Info "uv sync --extra all --locked ...（装全部依赖，最慢的一步）"
    $rc = Invoke-Native $UvExe @("sync","--extra","all","--locked")
    if ($rc -ne 0) {
        Warn "uv sync --locked 失败，回退 uv pip install -e .[all]"
        $py = Join-Path $VenvDir "Scripts\python.exe"
        $rc = Invoke-Native $UvExe @("pip","install","--python",$py,"-e",".[all]")
        if ($rc -ne 0) {
            Warn ".[all] 失败，回退到核心安装 -e ."
            $rc = Invoke-Native $UvExe @("pip","install","--python",$py,"-e",".")
            if ($rc -ne 0) { Die "依赖安装失败" }
        }
    }
} finally {
    Pop-Location
}

if (-not (Test-Path (Join-Path $AppDir "pyproject.toml"))) {
    Die "hermes-agent 没装进 $AppDir，构建失败。"
}
Ok "hermes-agent 已就位"

# ─── 4. 拷模板（启动脚本 / README / .env.example）───
Step "4/6" "拷入启动脚本与配置模板"
Copy-Item (Join-Path $TemplateDir "Windows-Start.bat") (Join-Path $Root "Windows-Start.bat") -Force
Copy-Item (Join-Path $TemplateDir "README.txt")        (Join-Path $Root "README.txt")        -Force
Copy-Item (Join-Path $TemplateDir ".env.example")      (Join-Path $DataDir ".env.example")   -Force
# data 子目录预建，运行时直接可写
foreach ($d in @("sessions","logs")) { New-Item -ItemType Directory -Force -Path (Join-Path $DataDir $d) | Out-Null }
Ok "模板已拷入"

# ─── 5. 离线自检 ───
Step "5/6" "离线自检 hermes --version"
$selfCheckOk = $false
Push-Location $AppDir
$rc = Invoke-Native $UvExe @("run","--project",$AppDir,"hermes","--version")
Pop-Location
if ($rc -eq 0) {
    Ok "hermes 自检通过"
    $selfCheckOk = $true
} else {
    Warn "hermes --version 返回非零（rc=$rc）"
}
if (-not $selfCheckOk) {
    Warn "自检未通过，但目录已生成。请手动双击 Windows-Start.bat 验证。"
}

# ─── 6. 报告 ───
Step "6/6" "完成"
$sizeGB = "{0:N2}" -f ((Get-ChildItem -Path $Root -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB)
Write-Host ""
Ok "便携目录已生成: $Root"
Info "体积约: ${sizeGB} GB"
Write-Host ""
Write-Host "  下一步：" -ForegroundColor White
Write-Host "    1. 把整个 '$Name' 目录拷到 U 盘根目录" -ForegroundColor Gray
Write-Host "    2. 在【断网】机器上插入 U 盘，双击 Windows-Start.bat 验证离线可用" -ForegroundColor Gray
Write-Host "    3. 换个盘符再测一次，确认便携无关盘符" -ForegroundColor Gray
Write-Host ""
