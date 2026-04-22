#!/bin/bash

# 🦐 虾盘 U-Hermes 网站启动器 (Linux/Mac)

echo ""
echo "========================================"
echo "   🦐 虾盘 U-Hermes 网站启动器"
echo "========================================"
echo ""

# 检查Node.js是否安装
if ! command -v node &> /dev/null; then
    echo "❌ 错误：未找到 Node.js"
    echo "请先安装 Node.js (https://nodejs.org/)"
    read -p "按回车键退出..."
    exit 1
fi

# 检查是否在website目录中
if [ ! -f "server.js" ]; then
    echo "⚠ 提示：请确保在 website 目录中运行此脚本"
    echo "当前目录：$(pwd)"
    echo ""
    echo "请切换到 website 目录："
    echo "  cd website"
    read -p "按回车键退出..."
    exit 1
fi

# 检查依赖
if [ ! -d "node_modules" ]; then
    echo "📦 正在安装依赖..."
    npm install
    if [ $? -ne 0 ]; then
        echo "❌ 依赖安装失败"
        read -p "按回车键退出..."
        exit 1
    fi
    echo "✅ 依赖安装完成"
fi

echo ""
echo "🚀 正在启动 U-Hermes 网站服务器..."
echo "📍 网站地址：http://localhost:8650"
echo "📍 API 地址：http://localhost:8651"
echo "📍 Hermes Agent：http://localhost:8642"
echo "📍 Web UI：http://localhost:8648"
echo ""
echo "💡 提示："
echo "  • 按 Ctrl+C 停止服务器"
echo "  • 浏览器会自动打开网站"
echo "  • 确保 Hermes Agent 已启动"
echo ""

# 等待2秒后打开浏览器
sleep 2

# 根据操作系统打开浏览器
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open "http://localhost:8650" &
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v xdg-open &> /dev/null; then
        xdg-open "http://localhost:8650" &
    elif command -v gnome-open &> /dev/null; then
        gnome-open "http://localhost:8650" &
    fi
fi

# 启动服务器
echo "⏳ 启动服务器中..."
node server.js

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ 服务器启动失败"
    echo "可能的原因："
    echo "  1. 端口 8650 或 8651 已被占用"
    echo "  2. Node.js 版本太低"
    echo "  3. 文件权限问题"
    echo ""
    echo "💡 解决方案："
    echo "  1. 关闭占用端口的程序："
    echo "     lsof -i :8650"
    echo "     lsof -i :8651"
    echo "  2. 更新 Node.js 到 v14+"
    echo "  3. 使用 sudo 运行（不推荐）"
    read -p "按回车键退出..."
    exit 1
fi