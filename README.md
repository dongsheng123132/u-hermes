# 🐎 U-Hermes 马盘（U-Claw + U-Hermes）

> **Windows 便携 AI U 盘 —— 插上 U 盘，双击 .exe 起图形界面，U-Claw 和 U-Hermes 一盘双用**

U-Hermes 马盘是即插即用的 AI U 盘成品：同一张 Windows 便携 U 盘内置 U-Claw（通用 AI + IM 机器人）和 U-Hermes（编程 Agent）。U-Hermes 基于 [Nous Research hermes-agent](https://github.com/NousResearch/hermes-agent) 打包；本仓库同时提供 U-Hermes Linux 启动盘开源方案。

关键词：U-Hermes 马盘、马盘、Windows 便携 AI U 盘、U-Claw、U-Hermes、Hermes Agent、Linux Live USB、AI 编程助手、DeepSeek、通义千问、ollama。

## 三个版本

| 版本 | 形式 | 价格 | 适合谁 |
|------|------|------|--------|
| **Win/Mac 便携版** | 开源构建脚本，从上游一键造盘，完全离线、零依赖、插上即用 | 免费 | 想自己造盘 / 二次分发的人 |
| **Linux Live USB** | 开源脚本自己刻盘 | 免费 | 极客、开发者 |
| **U-Hermes 马盘 Windows 便携 U 盘** | 成品 U 盘开箱即用，内置 U-Claw + U-Hermes + 图形启动器 + 账户体系 | ¥199 起 / 淘宝 / 拼多多 | 所有 Windows 用户 |

## 本仓库是什么

**只放开源部分**：
- 🌐 `website/` — [u-hermes.org](https://u-hermes.org) 官网源码（Vercel 部署）
- 💾 `portable/` — **Win/Mac 便携版构建包**：从上游一键造盘，完全离线、零依赖、双击即用
- 🐧 `linux/` — Linux Live USB 刻盘脚本
- 📖 `docs/` — 文档

**不在本仓库**（Windows 商业版的私有内容）：
- Electron 启动器源码
- USB 指纹 / 激活码 / 付费账户对接

马盘 Windows 成品版的启动器和账户对接闭源；U-Hermes 的核心能力可以用这个仓库的 Linux 脚本自己搭出来（只是少了 U-Claw 集成、图形启动器、账户体系和一键化体验）。

## Linux Live 快速开始

Windows 制盘四步：

```powershell
git clone https://github.com/dongsheng123132/u-hermes.git
cd u-hermes\linux
.\1-prepare-usb.ps1
.\2-download-iso.ps1
.\3-create-persistence.ps1
.\4-copy-to-usb.ps1
```

详见 [`linux/README.md`](./linux/README.md)。

## Win/Mac 便携版（完全离线 · 零依赖）

从上游 hermes-agent 一键打包成插上即用的便携 U 盘目录，客户机不用装 Python、不用联网：

```powershell
# Windows
pwsh portable\build-portable-win.ps1 -Output D:\ -Tag v2026.6.5
```
```bash
# macOS
bash portable/build-portable-mac.sh --output /Volumes/MYUSB --tag v2026.6.5
```

成品里客户只需双击 `Windows-Start.bat` / `Mac-Start.command`。构建参数、便携原理、离线验证详见 [`portable/README.md`](./portable/README.md)。

## 商业版本

如果你想要开箱即用的成品 U 盘，请看官网和购买链接：

- 官网：[https://www.u-hermes.org/](https://www.u-hermes.org/)
- 购买页：[https://www.u-hermes.org/#buy](https://www.u-hermes.org/#buy)
- 淘宝：[购买马盘 U 盘](https://e.tb.cn/h.ij8LYYB0cZPkNHw?tk=FMo05XEJYk0)
- 拼多多：[购买马盘 U 盘](https://mobile.yangkeduo.com/goods1.html?ps=WaQeS00tDn)
- 抖音：[购买马盘 U 盘](https://haohuo.jinritemai.com/ecommerce/trade/detail/index.html?id=3814862440735309865&origin_type=604)

## 许可

代码 MIT。品牌与商标（"马盘"、"U-Hermes"、Logo）保留。

## 相关

- 📖 **[hermes-agent-zh](https://github.com/dongsheng123132/hermes-agent-zh)** — 配套中文教程（含安装/Provider/案例/工程进阶）
- [u-hermes.org](https://u-hermes.org) — U-Hermes 马盘官网
- [u-claw.org](https://u-claw.org) — U-Claw 项目
- [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) — 上游项目
