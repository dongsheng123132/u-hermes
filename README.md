# 🦐 U-Hermes 虾米

> **NousResearch Hermes Agent 的中文便携版 —— 插上 U 盘，双击运行，开始对话**

基于 [Nous Research hermes-agent](https://github.com/NousResearch/hermes-agent) 打包的即插即用 AI 助手。支持 Linux Live（开源免费）和 Windows 便携 U 盘（商业成品）两个版本。

## 两个版本

| 版本 | 形式 | 价格 | 适合谁 |
|------|------|------|--------|
| **Linux Live USB** | 开源脚本自己刻盘 | 免费 | 极客、开发者 |
| **Windows 便携 U 盘** | 成品 U 盘开箱即用 | 淘宝 / 拼多多 | 所有 Windows 用户 |

## 本仓库是什么

**只放开源部分**：
- 🌐 `website/` — [u-hermes.org](https://u-hermes.org) 官网源码（Vercel 部署）
- 🐧 `linux/` — Linux Live USB 刻盘脚本
- 📖 `docs/` — 文档

**不在本仓库**（Windows 商业版的私有内容）：
- Electron 启动器源码
- USB 指纹 / 激活码 / 付费账户对接

Windows 版核心逻辑闭源，但它的功能你用这个仓库的 Linux 脚本也能自己搭出来（只是少了图形界面和一键化体验）。

## Linux Live 快速开始

```bash
git clone https://github.com/dongsheng123132/u-hermes.git
cd u-hermes/linux
./install-live.sh   # Ubuntu Live 模式下运行
```

详见 [`linux/README.md`](./linux/README.md)。

## 许可

代码 MIT。品牌与商标（"U-Hermes 虾米"、Logo）保留。

## 相关

- [u-hermes.org](https://u-hermes.org) — 官网
- [u-claw.org](https://u-claw.org) — 姊妹项目 U-Claw 虾盘
- [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) — 上游项目
