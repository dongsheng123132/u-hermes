@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion
title U-Hermes Portable

REM ============================================================
REM  U-Hermes 便携版 · Windows 启动器（交互式菜单）
REM  双击即用，完全离线，所有数据都在 U 盘的 data\ 目录里。
REM  换电脑 / 换盘符 直接插上再双击即可，无需重装。
REM ============================================================

REM --- U 盘根目录（本脚本所在目录，去掉尾部反斜杠便于拼接）---
set "USB=%~dp0"
if "%USB:~-1%"=="\" set "USB=%USB:~0,-1%"

set "APP=%USB%\app\hermes-agent"
set "RT=%USB%\runtime\win"
set "UV=%RT%\uv.exe"

REM ─── 便携路径：全部指向 U 盘内部，不写系统 ───
set "HERMES_HOME=%USB%\data"
set "UV_PYTHON_INSTALL_DIR=%RT%\python"
set "UV_CACHE_DIR=%USB%\cache"
set "UV_NO_MODIFY_PATH=1"
set "PATH=%RT%;%RT%\tools;%RT%\git\cmd;%PATH%"

REM ─── 加强隔离：防止客户机已装的 Python/pip 污染，防止往系统目录乱写 ───
set "PYTHONNOUSERSITE=1"
set "PYTHONHOME="
set "PYTHONPATH="
set "PIP_USER=0"
set "APPDATA=%USB%\cache\win-appdata"
set "LOCALAPPDATA=%USB%\cache\win-localappdata"
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul

REM ─── UTF-8，避免中文乱码 ───
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"

REM ─── 回环白名单（防止本地请求被代理拦截）───
set "NO_PROXY=127.0.0.1,localhost,::1"
set "no_proxy=127.0.0.1,localhost,::1"

REM ─── 自检：uv 和 app 是否在 U 盘里 ───
if not exist "%UV%" goto :broken
if not exist "%APP%\pyproject.toml" goto :broken

REM ─── 首跑：生成 data\.env 并打开记事本让用户填 API Key ───
if not exist "%USB%\data" mkdir "%USB%\data"
if not exist "%USB%\data\.env" (
    if exist "%USB%\data\.env.example" copy "%USB%\data\.env.example" "%USB%\data\.env" >nul
    cls
    echo.
    echo   [首次使用] 需要先填一个 AI 模型的 API Key。
    echo.
    echo   即将打开记事本：取消某一行 *_API_KEY= 前的 #，填入你的 Key，保存关闭。
    echo   （最简单：注册 DeepSeek https://platform.deepseek.com/api_keys）
    echo.
    pause
    notepad "%USB%\data\.env"
)

REM ============================================================
REM  主菜单
REM ============================================================
:menu
cls
echo.
echo   ==========================================
echo     U-Hermes 便携版    完全离线 · 插上即用
echo   ==========================================
echo.
echo     [1]  开始对话 ^(命令行 TUI^)
echo     [2]  启动 Web 网关 ^(浏览器界面^)
echo     [3]  编辑配置 ^(API Key / 模型^)
echo     [4]  检查更新 ^(需联网^)
echo     [5]  诊断 ^(hermes doctor^)
echo     [0]  退出
echo.
set "CHOICE="
set /p "CHOICE=  请输入数字后回车: "

if "%CHOICE%"=="1" goto :chat
if "%CHOICE%"=="2" goto :gateway
if "%CHOICE%"=="3" goto :config
if "%CHOICE%"=="4" goto :update
if "%CHOICE%"=="5" goto :doctor
if "%CHOICE%"=="0" goto :end
goto :menu

:chat
cls
echo   启动对话中…（首次稍慢，请耐心等待）
echo.
cd /d "%APP%"
"%UV%" run --project "%APP%" hermes
echo.
pause
goto :menu

:gateway
cls
echo   启动 Web 网关…
echo.
echo     网关 API : http://127.0.0.1:8642
echo     Web 界面 : http://127.0.0.1:8648
echo.
echo   启动后会自动打开浏览器。关闭本窗口即停止网关。
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

:update
cls
echo   ==========================================
echo     检查更新（需要联网）
echo   ==========================================
echo.
echo   正在联网更新 hermes（更新会写回这个 U 盘，下次离线仍是新版）…
echo.
REM 清掉隔离用的占位代理变量影响，更新走真实网络
cd /d "%APP%"
REM 优先用 hermes 自带的 update（v2026.6.5+ 支持 in-app self-update）
"%UV%" run --project "%APP%" hermes update
if errorlevel 1 (
    echo.
    echo   [!] hermes update 失败，尝试用 uv 重装依赖…
    "%UV%" sync --project "%APP%" --extra all
    if errorlevel 1 "%UV%" pip install --python "%APP%\.venv\Scripts\python.exe" -e "%APP%[all]"
)
echo.
echo   更新流程结束。如果上面报网络错误，请检查联网/代理后重试。
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

:broken
cls
echo.
echo   [错误] 这个 U 盘没构建完整：
if not exist "%UV%" echo          缺少 %UV%
if not exist "%APP%\pyproject.toml" echo          缺少 %APP%
echo.
echo   请用 build-portable-win.ps1 重新生成便携目录。
echo.
pause
goto :end

:end
endlocal
