@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion
title U-Hermes Portable

REM ============================================================
REM  U-Hermes Portable - Windows launcher (TUI-first menu)
REM  Plug and play, fully offline. All data lives in data\ on the USB.
REM  Move between PCs / drive letters - just plug in and run again.
REM
REM  NOTE: this .bat is intentionally ASCII-only. cmd.exe reads .bat
REM  using the system ANSI codepage, so non-ASCII text here would be
REM  mis-decoded and executed as garbage commands. Chinese guidance
REM  lives in README.txt and in the hermes TUI itself.
REM ============================================================

REM --- USB root = folder of this script, strip trailing backslash ---
set "USB=%~dp0"
if "%USB:~-1%"=="\" set "USB=%USB:~0,-1%"

set "APP=%USB%\app\hermes-agent"
set "RT=%USB%\runtime\win"
set "UV=%RT%\uv.exe"

REM --- Portable paths: everything points inside the USB ---
set "HERMES_HOME=%USB%\data"
set "UV_PYTHON_INSTALL_DIR=%RT%\python"
set "UV_CACHE_DIR=%USB%\cache"
set "UV_NO_MODIFY_PATH=1"
set "PATH=%RT%;%RT%\tools;%RT%\git\cmd;%PATH%"

REM --- Hardened isolation: ignore host Python/pip, don't write to system ---
set "PYTHONNOUSERSITE=1"
set "PYTHONHOME="
set "PYTHONPATH="
set "PIP_USER=0"
set "APPDATA=%USB%\cache\win-appdata"
set "LOCALAPPDATA=%USB%\cache\win-localappdata"
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul

REM --- UTF-8 for the Python side (so hermes shows Chinese correctly) ---
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"

REM --- Loopback proxy bypass ---
set "NO_PROXY=127.0.0.1,localhost,::1"
set "no_proxy=127.0.0.1,localhost,::1"

REM --- Shared API key: if a sibling U-Claw on the SAME USB already wrote
REM     a key file, reuse it (so U-Claw and U-Hermes share one balance).
REM     The real key-derivation lives in the commercial build; here we only
REM     read an already-present file. Override path via HERMES_KEY_FILE.
if not defined HERMES_KEY_FILE set "HERMES_KEY_FILE=%USB%\..\shared-apikey.txt"

REM --- Self-check ---
if not exist "%UV%" goto :broken
if not exist "%APP%\pyproject.toml" goto :broken

REM --- First run: create data\.env and let user fill an API key ---
if not exist "%USB%\data" mkdir "%USB%\data"
if not exist "%USB%\data\.env" (
    if exist "%USB%\data\.env.example" copy "%USB%\data\.env.example" "%USB%\data\.env" >nul
    cls
    echo.
    echo   [First run] You need an AI model API key to start.
    echo.
    echo   Notepad will open. Uncomment a line like  DEEPSEEK_API_KEY=...
    echo   ^(remove the leading #^), paste your key, save and close.
    echo   Easiest: get a DeepSeek key at https://platform.deepseek.com/api_keys
    echo.
    pause
    notepad "%USB%\data\.env"
)

REM ============================================================
REM  Main menu  (TUI is the default - just press Enter)
REM ============================================================
:menu
cls
echo.
echo   ==========================================
echo     U-Hermes Portable    offline . plug and play
echo   ==========================================
echo.
echo     [1]  Start chat (TUI)            ^<-- default, just press Enter
echo     [2]  Start Web gateway (browser UI)
echo     [3]  Edit config (API key / model)
echo     [4]  Recharge / top up balance
echo     [5]  Check for updates (needs internet)
echo     [6]  Diagnostics (hermes doctor)
echo     [7]  Report a problem (collect logs)
echo     [0]  Exit
echo.
set "CHOICE="
set /p "CHOICE=  Enter a number then Enter [1]: "
if not defined CHOICE set "CHOICE=1"

if "%CHOICE%"=="1" goto :chat
if "%CHOICE%"=="2" goto :gateway
if "%CHOICE%"=="3" goto :config
if "%CHOICE%"=="4" goto :recharge
if "%CHOICE%"=="5" goto :update
if "%CHOICE%"=="6" goto :doctor
if "%CHOICE%"=="7" goto :report
if "%CHOICE%"=="0" goto :end
goto :menu

:chat
cls
echo   Starting chat... (first launch is slower, please wait)
echo.
cd /d "%APP%"
"%UV%" run --project "%APP%" hermes
echo.
pause
goto :menu

:gateway
cls
echo   Starting Web gateway...
echo.
echo     Gateway API : http://127.0.0.1:8642
echo     Web UI      : http://127.0.0.1:8648
echo.
echo   Your browser will open automatically. Close this window to stop.
echo.
start "" http://127.0.0.1:8648
cd /d "%APP%"
"%UV%" run --project "%APP%" hermes gateway run
echo.
pause
goto :menu

:config
notepad "%USB%\data\.env"
goto :menu

:recharge
cls
echo   ==========================================
echo     Recharge / top up
echo   ==========================================
echo.
REM Recharge URL comes from env (HERMES_RECHARGE_URL). The open-source repo
REM ships NO real URL - the commercial build injects it. Without it we just
REM point the user to the official site.
if defined HERMES_RECHARGE_URL (
    set "RU=%HERMES_RECHARGE_URL%"
) else (
    set "RU=https://u-hermes.org/#buy"
)
echo   Opening recharge page in your browser:
echo     !RU!
echo.
start "" "!RU!"
echo.
pause
goto :menu

:update
cls
echo   ==========================================
echo     Check for updates (needs internet)
echo   ==========================================
echo.
echo   Updating hermes (written back to this USB, stays new offline)...
echo.
cd /d "%APP%"
REM hermes self-update (v2026.6.5+ supports in-app self-update)
"%UV%" run --project "%APP%" hermes update
if errorlevel 1 (
    echo.
    echo   [!] hermes update failed, trying uv to reinstall deps...
    "%UV%" sync --project "%APP%" --extra all
    if errorlevel 1 "%UV%" pip install --python "%APP%\.venv\Scripts\python.exe" -e "%APP%[all]"
)
echo.
echo   Update finished. If you saw a network error, check internet/proxy and retry.
echo.
pause
goto :menu

:doctor
cls
cd /d "%APP%"
"%UV%" run --project "%APP%" hermes doctor
echo.
pause
goto :menu

:report
cls
echo   ==========================================
echo     Report a problem
echo   ==========================================
echo.
echo   Collecting logs + system info + diagnostics...
echo.
REM Delegate to a small node-free PowerShell collector. It packs a zip onto
REM the Desktop, and if HERMES_REPORT_URL is set it also uploads it.
powershell -NoProfile -ExecutionPolicy Bypass -File "%RT%\tools\report-bug.ps1" -Usb "%USB%" -App "%APP%" -Uv "%UV%"
echo.
pause
goto :menu

:broken
cls
echo.
echo   [ERROR] This USB looks incomplete:
if not exist "%UV%" echo          missing %UV%
if not exist "%APP%\pyproject.toml" echo          missing %APP%
echo.
echo   Rebuild it with build-portable-win.ps1
echo.
pause
goto :end

:end
endlocal
