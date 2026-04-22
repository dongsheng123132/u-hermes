#!/usr/bin/env bash
# U-Hermes 首次 bootstrap 脚本
# 在 Ubuntu Live 模式（Ventoy + persistence）或干净的 Ubuntu 系统上运行。
#
# 用法：
#   chmod +x setup-hermes.sh
#   ./setup-hermes.sh

set -euo pipefail

echo "🦐 U-Hermes · Ubuntu 首次安装"
echo "================================"

# ─── 1. 平台检查 ───
if [ ! -f /etc/os-release ]; then
    echo "⚠  无法识别 Linux 发行版"
    exit 1
fi
. /etc/os-release
echo "检测到: $PRETTY_NAME"

# ─── 2. apt 依赖 ───
echo ""
echo "[1/5] 安装系统依赖（Python / Node / curl）..."
sudo apt update -qq
sudo apt install -y \
    python3 python3-pip python3-venv python3-full \
    nodejs npm \
    curl git build-essential

# ─── 3. 创建数据目录 ───
HERMES_HOME="${HOME}/.u-hermes"
DATA_DIR="${HERMES_HOME}/data"
VENV_DIR="${HERMES_HOME}/venv"

echo ""
echo "[2/5] 创建 ${HERMES_HOME} ..."
mkdir -p "${HERMES_HOME}" "${DATA_DIR}" "${DATA_DIR}/logs" "${DATA_DIR}/sessions"

# ─── 4. Python venv + hermes-agent ───
echo ""
echo "[3/5] 创建 Python venv 并安装 hermes-agent ..."
python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/pip" install --upgrade pip --quiet
"${VENV_DIR}/bin/pip" install hermes-agent --quiet

# ─── 5. 默认配置 ───
ENV_FILE="${DATA_DIR}/.env"
if [ ! -f "${ENV_FILE}" ]; then
    echo ""
    echo "[4/5] 生成 ${ENV_FILE} ..."
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "${SCRIPT_DIR}/config.example" ]; then
        cp "${SCRIPT_DIR}/config.example" "${ENV_FILE}"
    else
        cat > "${ENV_FILE}" <<'EOF'
# U-Hermes 配置（Linux）
# 选一个 provider 取消注释即可

# DeepSeek（国内推荐，直连）
# DEEPSEEK_API_KEY=sk-xxx

# 阿里云通义
# DASHSCOPE_API_KEY=sk-xxx

# OpenAI（需代理）
# OPENAI_API_KEY=sk-xxx

# Anthropic（需代理）
# ANTHROPIC_API_KEY=sk-ant-xxx

# Ollama 本地模型（不需要 key，先跑 `ollama serve`）
# OPENAI_API_KEY=ollama
# OPENAI_BASE_URL=http://127.0.0.1:11434/v1

# 代理配置（如果用海外 provider）
# HTTPS_PROXY=http://127.0.0.1:7890
# HTTP_PROXY=http://127.0.0.1:7890
# NO_PROXY=127.0.0.1,localhost,::1

NO_PROXY=127.0.0.1,localhost,::1
no_proxy=127.0.0.1,localhost,::1
EOF
    fi
fi

# ─── 6. 生成桌面快捷方式 ───
echo ""
echo "[5/5] 生成桌面快捷方式 ..."
DESKTOP_FILE="${HOME}/Desktop/U-Hermes.desktop"
mkdir -p "${HOME}/Desktop"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=U-Hermes
Comment=AI Coding Agent
Exec=${SCRIPT_DIR}/start-hermes.sh
Icon=utilities-terminal
Terminal=true
Categories=Development;
EOF
chmod +x "${DESKTOP_FILE}"

# On some DE's the desktop file needs trusting
if command -v gio >/dev/null 2>&1; then
    gio set "${DESKTOP_FILE}" metadata::trusted true 2>/dev/null || true
fi

echo ""
echo "✅ 安装完成！"
echo ""
echo "下一步："
echo "  1. 编辑 ${ENV_FILE} 填入你的 API Key"
echo "  2. 运行 $(dirname $0)/start-hermes.sh 启动"
echo "     或者双击桌面上的 U-Hermes 图标"
echo ""
echo "Hermes 会启动在："
echo "  - http://127.0.0.1:8642 (gateway API)"
echo "  - http://127.0.0.1:8648 (Web UI，浏览器打开)"
