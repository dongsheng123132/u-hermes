#!/usr/bin/env bash
# ============================================================
#  U-Hermes 便携版 · macOS 启动器（交互式菜单）
#  双击即用，完全离线，所有数据都在 U 盘的 data/ 目录里。
#  换电脑直接插上再双击即可，无需重装。
# ============================================================
set -uo pipefail

# --- 清除 Gatekeeper quarantine 标记（首次双击被拦才需要）---
xattr -rd com.apple.quarantine "$0" 2>/dev/null || true

# --- U 盘根目录（本脚本所在目录，无尾斜杠）---
USB="$(cd "$(dirname "$0")" && pwd)"
APP="${USB}/app/hermes-agent"
RT="${USB}/runtime/mac"
UV="${RT}/uv"

# ─── 便携路径：全部指向 U 盘内部，不写系统 ───
export HERMES_HOME="${USB}/data"
export UV_PYTHON_INSTALL_DIR="${RT}/python"
export UV_CACHE_DIR="${USB}/cache"
export UV_NO_MODIFY_PATH=1
export PATH="${RT}:${RT}/tools:${PATH}"

# ─── 加强隔离：防止客户机已装的 Python 污染，防止往系统目录乱写 ───
export PYTHONNOUSERSITE=1
unset PYTHONHOME 2>/dev/null || true
unset PYTHONPATH 2>/dev/null || true
export PIP_USER=0
# 把 hermes/uv 可能用到的家目录缓存重定向进盘内
export XDG_CACHE_HOME="${USB}/cache/xdg-cache"
export XDG_CONFIG_HOME="${USB}/cache/xdg-config"
mkdir -p "${XDG_CACHE_HOME}" "${XDG_CONFIG_HOME}" 2>/dev/null || true

# ─── UTF-8 ───
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8
export LANG="${LANG:-en_US.UTF-8}"

# ─── 回环白名单 ───
export NO_PROXY="127.0.0.1,localhost,::1"
export no_proxy="127.0.0.1,localhost,::1"

# ─── 自检 ───
if [ ! -x "${UV}" ] || [ ! -f "${APP}/pyproject.toml" ]; then
    clear
    echo ""
    echo "  [错误] 这个 U 盘没构建完整："
    [ ! -x "${UV}" ]                  && echo "         缺少 ${UV}"
    [ ! -f "${APP}/pyproject.toml" ]  && echo "         缺少 ${APP}"
    echo ""
    echo "  请用 build-portable-mac.sh 重新生成便携目录。"
    echo ""
    read -r -p "按回车退出..." _
    exit 1
fi

# ─── 首跑：生成 data/.env 并打开编辑器让用户填 API Key ───
mkdir -p "${USB}/data"
if [ ! -f "${USB}/data/.env" ]; then
    [ -f "${USB}/data/.env.example" ] && cp "${USB}/data/.env.example" "${USB}/data/.env"
    clear
    echo ""
    echo "  [首次使用] 需要先填一个 AI 模型的 API Key。"
    echo ""
    echo "  即将打开编辑器：取消某一行 *_API_KEY= 前的 #，填入你的 Key，保存关闭。"
    echo "  （最简单：注册 DeepSeek https://platform.deepseek.com/api_keys）"
    echo ""
    read -r -p "按回车打开编辑器..." _
    open -W -e "${USB}/data/.env" 2>/dev/null || nano "${USB}/data/.env"
fi

run_hermes() { ( cd "${APP}" && "${UV}" run --project "${APP}" hermes "$@" ); }

# ============================================================
#  主菜单
# ============================================================
while true; do
    clear
    echo ""
    echo "  =========================================="
    echo "    U-Hermes 便携版    完全离线 · 插上即用"
    echo "  =========================================="
    echo ""
    echo "    [1]  开始对话 (命令行 TUI)"
    echo "    [2]  启动 Web 网关 (浏览器界面)"
    echo "    [3]  编辑配置 (API Key / 模型)"
    echo "    [4]  检查更新 (需联网)"
    echo "    [5]  诊断 (hermes doctor)"
    echo "    [0]  退出"
    echo ""
    read -r -p "  请输入数字后回车: " CHOICE

    case "${CHOICE}" in
        1)
            clear; echo "  启动对话中…（首次稍慢，请耐心等待）"; echo ""
            run_hermes || true
            read -r -p "按回车返回菜单..." _ ;;
        2)
            clear
            echo "  启动 Web 网关…"; echo ""
            echo "    网关 API : http://127.0.0.1:8642"
            echo "    Web 界面 : http://127.0.0.1:8648"; echo ""
            echo "  启动后会自动打开浏览器。Ctrl+C 停止网关。"; echo ""
            ( sleep 3; open http://127.0.0.1:8648 2>/dev/null ) &
            run_hermes gateway run || true
            read -r -p "按回车返回菜单..." _ ;;
        3)
            open -W -e "${USB}/data/.env" 2>/dev/null || nano "${USB}/data/.env" ;;
        4)
            clear
            echo "  =========================================="
            echo "    检查更新（需要联网）"
            echo "  =========================================="; echo ""
            echo "  正在联网更新 hermes（更新会写回这个 U 盘，下次离线仍是新版）…"; echo ""
            # 优先用 hermes 自带的 update（v2026.6.5+ 支持 in-app self-update）
            if ! run_hermes update; then
                echo ""; echo "  [!] hermes update 失败，尝试用 uv 重装依赖…"
                if ! ( cd "${APP}" && "${UV}" sync --project "${APP}" --extra all ); then
                    ( cd "${APP}" && "${UV}" pip install --python "${APP}/.venv/bin/python" -e "${APP}[all]" ) || true
                fi
            fi
            echo ""; echo "  更新流程结束。若上面报网络错误，检查联网/代理后重试。"; echo ""
            read -r -p "按回车返回菜单..." _ ;;
        5)
            clear; run_hermes doctor || true
            read -r -p "按回车返回菜单..." _ ;;
        0)
            exit 0 ;;
        *)
            : ;;
    esac
done
