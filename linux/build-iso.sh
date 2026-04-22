#!/usr/bin/env bash
# U-Hermes Linux Live USB 构建脚本（骨架，TODO）
#
# 用法：./build-iso.sh [--output=dist/u-hermes.iso] [--persistence=4G]
#
# 当前只是占位，完整实现见 https://github.com/dongsheng123132/u-hermes/issues

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${REPO_ROOT}/dist/u-hermes.iso"
UBUNTU_ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04.2-desktop-amd64.iso"

echo "🦐 U-Hermes Linux Live USB 构建器"
echo "==============================="
echo ""
echo "这个脚本还在 TODO 列表上。完整实现会包含："
echo ""
echo "  1. 下载 Ubuntu 24.04 Live ISO"
echo "  2. 挂载 ISO + 解包 squashfs"
echo "  3. chroot 进去 apt install hermes-agent + ollama + 依赖"
echo "  4. 注入 autostart 脚本（启动时开 hermes gateway）"
echo "  5. 重打包为 u-hermes.iso"
echo ""
echo "当前你可以："
echo "  - 直接用 Ubuntu 24.04 Live"
echo "  - 进 Live 模式后运行 install-live.sh（下面的脚本）"
echo ""
echo "或者关注 https://github.com/dongsheng123132/u-hermes/releases 等我们发布预构建 ISO"

exit 0
