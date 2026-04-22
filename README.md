# U-HERMES 虾盘 Hermes 一键安装版

把 NousResearch 的 [hermes-agent](https://github.com/NousResearch/hermes-agent) 通过 U盘交付到 Windows 用户手上，免去安装 Python、配置 WSL2、翻墙下 pip 包的门槛。

## 产品定位

- 目标平台：Windows 10 (1809+) / Windows 11
- 后端：NousResearch hermes-agent (Python)
- UI：[hermes-web-ui](https://github.com/EKKOLearnAI/hermes-web-ui) (Vue + Koa, fork 改造版)
- 授权：复用虾盘 ClawX 的 USB 指纹 → `sk-{fingerprint}` 虾盘云 API key

## 目录结构

```
U-HERMES/
├── installer/         安装脚本（PowerShell + Batch）
├── scripts/           构建脚本（Node.js）
├── packages/          离线资源（Python embeddable / Node / pip wheels / web-ui）
├── templates/         配置模板（hermes config / providers）
├── docs/              中文文档
└── README.md
```

## 用户使用流程

1. 插入 U盘 `I:\U-Hermes\`
2. 双击 `一键安装.bat`
3. 等待安装完成 → 桌面出现 U-Hermes 快捷方式
4. 双击启动 → 浏览器自动打开 hermes UI

详见 [docs/](./docs/) 与 [使用说明.txt](./使用说明.txt)。

## 开发

构建 U盘镜像：
```bash
node scripts/download-packages.mjs   # 下载离线资源到 packages/
node scripts/build-uhermes-usb.mjs --out=I:/U-Hermes   # 装配到 U盘
```

## 协议

MIT
