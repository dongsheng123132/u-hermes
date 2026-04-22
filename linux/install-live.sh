#!/usr/bin/env bash
# 在 Ubuntu Live 模式下手动安装 hermes-agent
#
# 用法：
#   curl -fsSL https://u-hermes.org/install-live.sh | bash
#   # 或
#   git clone https://github.com/dongsheng123132/u-hermes.git && cd u-hermes/linux && ./install-live.sh

set -euo pipefail

echo "🦐 U-Hermes · Ubuntu Live 安装脚本"
echo "=================================="

# 检查平台
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    echo "⚠  不在 Ubuntu 上，请使用 Ubuntu 20.04+ Live 模式运行"
    echo "   继续安装可能失败。"
    read -r -p "继续？[y/N] " ans
    [ "$ans" = "y" ] || exit 1
fi

# 1. 基础依赖
echo ""
echo "[1/4] 安装系统依赖..."
sudo apt update -qq
sudo apt install -y python3 python3-pip python3-venv nodejs npm curl

# 2. Python venv + hermes-agent
echo ""
echo "[2/4] 安装 hermes-agent..."
VENV_DIR="${HOME}/.u-hermes/venv"
mkdir -p "${HOME}/.u-hermes"
python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install hermes-agent

# 3. Web UI（可选）
echo ""
echo "[3/4] 下载 Web UI..."
WEBUI_DIR="${HOME}/.u-hermes/web-ui"
if [ ! -d "$WEBUI_DIR" ]; then
    npm install -g @nousresearch/hermes-web-ui 2>/dev/null || \
      echo "  ⚠ npm install 失败，Web UI 需要手动装"
fi

# 4. 启动脚本
echo ""
echo "[4/4] 生成启动脚本 ~/u-hermes/start.sh ..."
START_SCRIPT="${HOME}/.u-hermes/start.sh"
cat > "$START_SCRIPT" <<'EOF'
#!/usr/bin/env bash
# 启动 hermes gateway + web-ui
set -e
HERMES_HOME="${HOME}/.u-hermes/data"
VENV="${HOME}/.u-hermes/venv"
mkdir -p "$HERMES_HOME"

echo "Starting hermes gateway on port 8642 ..."
HERMES_HOME="$HERMES_HOME" "$VENV/bin/hermes" gateway run &
AGENT_PID=$!

trap "kill $AGENT_PID 2>/dev/null" EXIT
echo ""
echo "✓ Hermes 已启动"
echo "  Gateway API: http://127.0.0.1:8642"
echo "  Web UI:      http://127.0.0.1:8648（需先装 web-ui）"
echo ""
echo "  首次使用请编辑 ${HERMES_HOME}/.env 填入 API Key："
echo "    DEEPSEEK_API_KEY=sk-xxx"
echo "    OPENAI_API_KEY=sk-xxx"
echo ""
wait $AGENT_PID
EOF
chmod +x "$START_SCRIPT"

echo ""
echo "✅ 安装完成！"
echo ""
echo "启动 hermes："
echo "    ~/.u-hermes/start.sh"
echo ""
echo "查看帮助："
echo "    ~/.u-hermes/venv/bin/hermes --help"
echo ""
echo "配置虾盘云（国内用户推荐）："
echo "    echo 'UCLAW_CLOUD_API_KEY=sk-your-key' >> ~/.u-hermes/data/.env"
echo "    访问 https://u-hermes.org/buy 购买含初始额度的 U 盘"
