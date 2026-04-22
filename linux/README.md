# U-Hermes Linux Live USB（开源版）

Ubuntu 24.04 Live + hermes-agent + ollama 的 Live USB 启动盘脚本。  
完全开源，MIT 许可，任何人都可以自己刻一个。

## 能做什么

- 从 U 盘启动任何 x86_64 电脑进入 Ubuntu Live 模式
- 自动启动 hermes-agent（gateway + web-ui）
- 可选：本地 ollama 跑开源模型（Qwen 2.5、DeepSeek-R1 等）
- 配任何 OpenAI 兼容 API（DeepSeek / OpenAI / Claude / ...）

## 跟 Windows 商业版的区别

| | Linux Live（本仓库） | Windows 商业版（淘宝/拼多多） |
|---|---|---|
| 价格 | 免费 | ¥99 起 |
| 启动 | 命令行 + Web UI | 双击 .exe 图形界面 |
| 安装 | 自己刻盘、跑脚本 | 开箱即用 |
| API Key | 自己填 | 成品附带 |
| 适合 | 极客 | 想省心的人 |

## 准备工作

- 一个 ≥ 16GB 的 U 盘
- 一台 Linux 开发机（用于刻盘）
- Ubuntu 24.04 Live ISO（脚本自动下载）
- 自备 API Key（DeepSeek / OpenAI / 或本地 ollama）

## 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/dongsheng123132/u-hermes.git
cd u-hermes/linux

# 2. 构建 ISO（会下载 Ubuntu 官方 ISO + 注入 hermes）
./build-iso.sh

# 3. 刻到 U 盘
sudo dd if=dist/u-hermes.iso of=/dev/sdX bs=4M status=progress
# 或用 Ventoy：把 ISO 文件拖到 Ventoy U 盘的根目录

# 4. U 盘启动目标电脑
# 5. 进入 Live 模式后自动跑 hermes
```

## 当前状态

🚧 **尚未开始实现**。当前仓库只有骨架，PR 欢迎。

## 设计要点

### hermes 的 Linux 部署

`hermes-agent` 本身是 Python 包，Linux 原生支持好，但有依赖：
- Python 3.11+
- Node.js 20+（给 web-ui）
- ollama（可选，本地模型）

Ubuntu 24.04 Live 自带 Python 3.12，Node 和 ollama 需要 inject 进 ISO。

### ISO 注入方式

两条路径：
1. **remaster**：用 `cubic` 或 `live-build` 重新生成 squashfs，体积大但开箱即用
2. **overlay**：用 Ventoy 的 persistence 功能或 `casper-rw` 分区存放 hermes，首次启动时 `apt install` 依赖 → 更小但需要网络

推荐 2，因为 Ventoy 是目前最流行的多 ISO U 盘方案。

### 持久化

用户的配置（API key / 聊天历史）存在 Ventoy 的 persistence 分区，跨重启保留。

## License

MIT
