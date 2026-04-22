@echo off
chcp 65001 >nul
echo.
echo ========================================
echo    🦐 虾盘 U-Hermes 网站启动器
echo ========================================
echo.

REM 检查Node.js是否安装
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ 错误：未找到 Node.js
    echo 请先安装 Node.js (https://nodejs.org/)
    pause
    exit /b 1
)

REM 检查是否在website目录中
if not exist "server.js" (
    echo ⚠ 提示：请确保在 website 目录中运行此脚本
    echo 当前目录：%cd%
    echo.
    echo 请切换到 website 目录：
    echo   cd website
    pause
    exit /b 1
)

REM 检查依赖
if not exist "node_modules" (
    echo 📦 正在安装依赖...
    call npm install
    if %errorlevel% neq 0 (
        echo ❌ 依赖安装失败
        pause
        exit /b 1
    )
    echo ✅ 依赖安装完成
)

echo.
echo 🚀 正在启动 U-Hermes 网站服务器...
echo 📍 网站地址：http://localhost:8650
echo 📍 API 地址：http://localhost:8651
echo 📍 Hermes Agent：http://localhost:8642
echo 📍 Web UI：http://localhost:8648
echo.
echo 💡 提示：
echo   • 按 Ctrl+C 停止服务器
echo   • 浏览器会自动打开网站
echo   • 确保 Hermes Agent 已启动
echo.

REM 等待2秒后打开浏览器
timeout /t 2 /nobreak >nul
start "" "http://localhost:8650"

REM 启动服务器
echo ⏳ 启动服务器中...
node server.js

if %errorlevel% neq 0 (
    echo.
    echo ❌ 服务器启动失败
    echo 可能的原因：
    echo   1. 端口 8650 或 8651 已被占用
    echo   2. Node.js 版本太低
    echo   3. 文件权限问题
    echo.
    echo 💡 解决方案：
    echo   1. 关闭占用端口的程序
    echo   2. 更新 Node.js 到 v14+
    echo   3. 以管理员身份运行
    pause
    exit /b 1
)

pause