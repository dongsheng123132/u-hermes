#!/usr/bin/env bash
# U-Hermes · 每次启动执行
# 启动 hermes gateway + 打开浏览器
#
# 用法：
#   ./start-hermes.sh
#   # 或双击桌面上的 U-Hermes 快捷方式

set -euo pipefail

HERMES_HOME="${HOME}/.u-hermes"
DATA_DIR="${HERMES_HOME}/data"
VENV="${HERMES_HOME}/venv"
LOG="${DATA_DIR}/logs/agent.log"

echo "🦐 U-Hermes · 启动中"
echo "===================="

# 检查 setup 跑过没
if [ ! -x "${VENV}/bin/hermes" ]; then
    echo "⚠  找不到 ${VENV}/bin/hermes"
    echo "   先运行 $(dirname $0)/setup-hermes.sh"
    read -r -p "按回车退出..."
    exit 1
fi

# 检查 .env
if [ ! -f "${DATA_DIR}/.env" ] || ! grep -qE "^(DEEPSEEK|OPENAI|ANTHROPIC|DASHSCOPE)_API_KEY=" "${DATA_DIR}/.env" 2>/dev/null; then
    echo "⚠  ${DATA_DIR}/.env 里没有配置 API Key"
    echo "   请用文本编辑器打开，取消某行的注释，填入你的 Key"
    echo ""
    echo "   或者跑本地 ollama："
    echo "     ollama serve &"
    echo "     ollama pull qwen2.5:7b"
    echo ""
    read -r -p "想继续启动（用占位 key）吗？[y/N] " ans
    [ "$ans" = "y" ] || exit 1
fi

# 启动 gateway
echo ""
echo "启动 hermes gateway ..."
cd "${HERMES_HOME}"

HERMES_HOME="${DATA_DIR}" \
PYTHONIOENCODING=utf-8 \
PYTHONUTF8=1 \
    "${VENV}/bin/hermes" gateway run > "${LOG}" 2>&1 &

AGENT_PID=$!
echo "  agent pid: ${AGENT_PID}"
echo "  log: ${LOG}"

# 等 gateway listen
for i in $(seq 1 30); do
    if ss -tln 2>/dev/null | grep -q ":8642"; then
        break
    fi
    sleep 0.5
done

if ! ss -tln 2>/dev/null | grep -q ":8642"; then
    echo ""
    echo "❌ gateway 30 秒内没起来，查看日志:"
    echo "   tail -50 ${LOG}"
    exit 1
fi

echo ""
echo "✅ U-Hermes 已启动"
echo "  Gateway API: http://127.0.0.1:8642"
echo ""
echo "按回车退出后 gateway 会继续在后台跑（nohup 模式）"

# 可选：打开浏览器（如果装了 hermes-web-ui）
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open http://127.0.0.1:8642/health 2>/dev/null || true
fi

# hold terminal open so user sees output
read -r -p "按回车关闭本窗口（gateway 继续跑）..."
