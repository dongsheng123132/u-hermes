#!/usr/bin/env bash
# ============================================================
#  U-Hermes 便携版 · macOS 构建脚本（build kit）
#
#  在一台【联网】的 Mac 上跑一次，把上游 NousResearch/hermes-agent
#  连同 Python / 依赖 / uv / ripgrep / ffmpeg 全部装进一个目录，
#  产出【完全离线、插上即用】的便携 U 盘目录。
#
#  产物结构:
#     <output>/U-Hermes/
#       Mac-Start.command     双击入口
#       README.txt            客户说明
#       runtime/mac/          uv + python + tools（只读运行时）
#       app/hermes-agent/     上游源码 + venv（离线已装好）
#       cache/                uv wheel 缓存
#       data/.env.example     配置模板
#
#  原理: 把 uv 的所有路径锁进输出目录内，用便携 uv 直接 clone + uv venv .venv + uv sync
#  装整套环境（不调上游 install.sh，它在代理环境下会卡在自举装 uv）。
#  运行时启动脚本用 `uv run --project` 就地解析 .venv，换机器/换盘符都不坏。
#
#  用法:
#     bash portable/build-portable-mac.sh --output /Volumes/MYUSB --tag v2026.6.5
#     bash portable/build-portable-mac.sh --output ./dist --proxy http://127.0.0.1:7890
# ============================================================
set -euo pipefail

# ─── 默认参数 ───
OUTPUT="./dist"
TAG="v2026.6.5"   # 上游日历版号；最新见 https://github.com/NousResearch/hermes-agent/releases
NAME="U-Hermes"
PROXY=""

# ─── 解析参数 ───
while [ $# -gt 0 ]; do
    case "$1" in
        --output) OUTPUT="$2"; shift 2 ;;
        --tag)    TAG="$2";    shift 2 ;;
        --name)   NAME="$2";   shift 2 ;;
        --proxy)  PROXY="$2";  shift 2 ;;
        -h|--help)
            echo "用法: $0 --output <目录> [--tag v2026.6.5] [--name U-Hermes] [--proxy http://127.0.0.1:7890]"
            exit 0 ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# ─── 颜色输出 ───
info() { printf "  \033[36m%s\033[0m\n" "$1"; }
ok()   { printf "  \033[32m[OK]\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m[!]\033[0m %s\n" "$1"; }
die()  { printf "  \033[31m[ERROR]\033[0m %s\n" "$1"; exit 1; }
step() { printf "\n  \033[1m[%s] %s\033[0m\n" "$1" "$2"; }

# 脚本目录 → templates/
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"

echo ""
echo "  =========================================="
echo "    U-Hermes 便携版 · macOS 构建"
echo "  =========================================="

# ─── 解析输出路径 ───
mkdir -p "${OUTPUT}"
OUT_FULL="$(cd "${OUTPUT}" && pwd)"
ROOT="${OUT_FULL}/${NAME}"

RUNTIME_MAC="${ROOT}/runtime/mac"
PYTHON_DIR="${RUNTIME_MAC}/python"
TOOLS_DIR="${RUNTIME_MAC}/tools"
CACHE_DIR="${ROOT}/cache"
APP_DIR="${ROOT}/app/hermes-agent"
DATA_DIR="${ROOT}/data"

info "输出目录: ${ROOT}"
if [ -n "${TAG}" ]; then info "上游 tag : ${TAG}"; else warn "未指定 --tag，使用 main 最新（不可复现，正式发版建议 pin tag）"; fi

# ─── 代理 ───
if [ -n "${PROXY}" ]; then
    info "构建代理: ${PROXY}"
    export HTTP_PROXY="${PROXY}" HTTPS_PROXY="${PROXY}"
fi
export NO_PROXY="127.0.0.1,localhost,::1"

# ─── 0. 环境检查 ───
step "0/6" "环境检查"
command -v git  >/dev/null 2>&1 || die "需要 git（构建机需要，成品 U 盘不需要）"
command -v curl >/dev/null 2>&1 || die "需要 curl"
# 架构检测（uv 二进制要选对）
ARCH="$(uname -m)"
case "${ARCH}" in
    arm64)  UV_TRIPLE="aarch64-apple-darwin" ;;
    x86_64) UV_TRIPLE="x86_64-apple-darwin"  ;;
    *) die "不支持的架构: ${ARCH}" ;;
esac
ok "git/curl 可用，架构 ${ARCH}"

# ─── 1. 创建骨架 ───
step "1/6" "创建便携目录骨架"
mkdir -p "${RUNTIME_MAC}" "${PYTHON_DIR}" "${TOOLS_DIR}" "${CACHE_DIR}" "$(dirname "${APP_DIR}")" "${DATA_DIR}"
ok "目录已建"

# ─── 2. 下载便携 uv ───
step "2/6" "下载便携 uv（${UV_TRIPLE}）"
UV_BIN="${RUNTIME_MAC}/uv"
if [ -x "${UV_BIN}" ]; then
    ok "uv 已存在，跳过"
else
    UV_URL="https://github.com/astral-sh/uv/releases/latest/download/uv-${UV_TRIPLE}.tar.gz"
    info "从 ${UV_URL}"
    TMP_TGZ="$(mktemp -t uv-portable.XXXXXX).tar.gz"
    curl -fsSL "${UV_URL}" -o "${TMP_TGZ}" || die "下载 uv 失败（检查网络 / --proxy）"
    tar -xzf "${TMP_TGZ}" -C "${RUNTIME_MAC}" --strip-components=1 2>/dev/null \
        || tar -xzf "${TMP_TGZ}" -C "${RUNTIME_MAC}"
    rm -f "${TMP_TGZ}"
    # uv 二进制可能在子目录，扒出来
    if [ ! -x "${UV_BIN}" ]; then
        found="$(find "${RUNTIME_MAC}" -name uv -type f -perm +111 2>/dev/null | head -1 || true)"
        [ -n "${found}" ] && mv "${found}" "${UV_BIN}"
    fi
    chmod +x "${UV_BIN}" 2>/dev/null || true
    [ -x "${UV_BIN}" ] || die "解压后找不到可执行的 uv"
    ok "uv 就位: ${UV_BIN}"
fi

# ─── 3. 用便携 uv 直接把 Python + hermes-agent 装进 U 盘 ───
# 注：不调上游 install.sh —— 它会自举装自己的 uv 再继续，代理环境下易失败。
# 我们已有可用 uv，直接 clone + uv venv + uv sync 更可控（与 Windows 版同策略）。
step "3/6" "装 Python + hermes-agent[all]（git clone + uv venv + uv sync，联网，较慢）"

export UV_PYTHON_INSTALL_DIR="${PYTHON_DIR}"
export UV_CACHE_DIR="${CACHE_DIR}"
export UV_NO_MODIFY_PATH=1
export HERMES_HOME="${DATA_DIR}"
export PATH="${RUNTIME_MAC}:${TOOLS_DIR}:${PATH}"

# 3a. clone 上游源码（pin 到 tag）
if [ ! -f "${APP_DIR}/pyproject.toml" ]; then
    [ -d "${APP_DIR}" ] && rm -rf "${APP_DIR}"   # 清残留空 .git，否则 clone 拒绝
    REPO="https://github.com/NousResearch/hermes-agent.git"
    info "git clone ${REPO} @ ${TAG:-main}"
    if [ -n "${TAG}" ]; then
        git clone --depth 1 --branch "${TAG}" "${REPO}" "${APP_DIR}" || die "git clone 失败（检查网络/代理/tag）"
    else
        git clone --depth 1 "${REPO}" "${APP_DIR}" || die "git clone 失败"
    fi
else
    ok "源码已存在，跳过 clone"
fi

# 3b. 装 Python 3.11（进盘内 python/）
info "uv python install 3.11 ..."
"${UV_BIN}" python install 3.11 || die "uv python install 3.11 失败"

# 3c. 建 .venv + 装依赖（必须叫 .venv，uv 默认名，否则 uv run 当场重建破坏离线）
(
    cd "${APP_DIR}"
    info "uv venv .venv ..."
    "${UV_BIN}" venv "${APP_DIR}/.venv" --python 3.11 || die "uv venv 失败"
    export UV_PROJECT_ENVIRONMENT="${APP_DIR}/.venv"
    export VIRTUAL_ENV="${APP_DIR}/.venv"
    info "uv sync --extra all --locked ...（装全部依赖，最慢的一步）"
    if ! "${UV_BIN}" sync --extra all --locked; then
        warn "uv sync --locked 失败，回退 uv pip install -e .[all]"
        if ! "${UV_BIN}" pip install --python "${APP_DIR}/.venv/bin/python" -e ".[all]"; then
            warn ".[all] 失败，回退核心 -e ."
            "${UV_BIN}" pip install --python "${APP_DIR}/.venv/bin/python" -e "." || die "依赖安装失败"
        fi
    fi
)

[ -f "${APP_DIR}/pyproject.toml" ] || die "hermes-agent 没装进 ${APP_DIR}，构建失败"
ok "hermes-agent 已就位"

# ─── 4. 补 ripgrep / ffmpeg（Mac 上系统多半没有，hermes 部分功能要）───
step "4/6" "检查 ripgrep / ffmpeg"
if command -v rg >/dev/null 2>&1; then
    info "系统已有 rg，便携目录不强制内置（如需绝对离线可手动放 tools/）"
else
    warn "系统无 ripgrep，建议: brew install ripgrep 后把二进制拷到 ${TOOLS_DIR}/"
fi
if command -v ffmpeg >/dev/null 2>&1; then
    info "系统已有 ffmpeg"
else
    warn "系统无 ffmpeg（仅语音/视频功能需要），可 brew install ffmpeg 后拷入 ${TOOLS_DIR}/"
fi
ok "工具检查完成"

# ─── 5. 拷模板 ───
step "5/6" "拷入启动脚本与配置模板"
cp "${TEMPLATE_DIR}/Mac-Start.command" "${ROOT}/Mac-Start.command"
cp "${TEMPLATE_DIR}/README.txt"         "${ROOT}/README.txt"
cp "${TEMPLATE_DIR}/.env.example"       "${DATA_DIR}/.env.example"
chmod +x "${ROOT}/Mac-Start.command"
mkdir -p "${DATA_DIR}/sessions" "${DATA_DIR}/logs"
# 清掉构建产物上的 quarantine，避免客户首次双击被 Gatekeeper 全拦
xattr -rd com.apple.quarantine "${ROOT}" 2>/dev/null || true
ok "模板已拷入"

# ─── 6. 离线自检 + 报告 ───
step "6/6" "离线自检"
if ( cd "${APP_DIR}" && "${UV_BIN}" run --project "${APP_DIR}" hermes --version ) ; then
    ok "hermes 自检通过"
else
    warn "自检未通过，但目录已生成。请手动双击 Mac-Start.command 验证。"
fi

SIZE="$(du -sh "${ROOT}" 2>/dev/null | cut -f1)"
echo ""
ok "便携目录已生成: ${ROOT}"
info "体积约: ${SIZE}"
echo ""
echo "  下一步："
echo "    1. 把整个 '${NAME}' 目录拷到 U 盘根目录"
echo "    2. 在【断网】Mac 上插入 U 盘，双击 Mac-Start.command 验证离线可用"
echo "       （首次双击被拦就右键 → 打开）"
echo ""
