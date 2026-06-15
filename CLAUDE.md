# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

`u-hermes-oss` 是 U-Hermes 项目的**开源仓库**(GitHub: `dongsheng123132/u-hermes`,公开,MIT)。
绝对**不是** monorepo,只放可公开的三件事:

1. `website/` —— 官网静态页面 (Vercel 部署到 `u-hermes.org` / `study.u-hermes.org`)
2. `linux/` —— Linux Live USB 制盘脚本 (PowerShell 制盘 + Bash 安装)
3. `portable/` —— **Win/Mac 便携版构建包**:从上游 `NousResearch/hermes-agent` 一键打包成完全离线、零依赖、双击即用的便携 U 盘目录。纯打包上游 MIT 代码 + 启动脚本,**不含任何商业逻辑**。`build-portable-win.ps1` / `build-portable-mac.sh` + `templates/`(启动脚本/.env.example/README.txt)。

商业版闭源逻辑 (Electron 启动器 / USB 指纹 / 激活码 / 虾盘云对接) 在 `../u-hermes-pro/`,**严禁污染本仓库**。

> ⚠️ 写 `portable/*.ps1`(含中文) 必须存 **UTF-8 with BOM**,否则构建机的 Windows PowerShell 5.1 按 GBK 读会报字符串语法错。改完用 `[Parser]::ParseFile` 自检。

## Critical: 提交禁区

提交前必跑禁区扫描 (`.claude-project-note.md` 强制):

```bash
grep -riE "fingerprint|dealer|activate.*secret|sk-[a-f0-9]{30}|UCLAW_CLOUD_|uclaw2026activate" website/ linux/ portable/ docs/
```

任何匹配都意味着泄密。下列字符串/逻辑**绝不能**出现:

- USB 指纹生成 (PowerShell SHA256 规则、Model+SerialNumber+PNPDeviceID)
- ED25519 公钥/私钥、dealer HTML
- 虾盘云 API key 派发对接
- 客户的 DeepSeek/OpenAI API key

## Commands

### 官网本地预览

```bash
# 静态站,直接打开即可
start website/index.html              # Windows
# 或用任何 static server,如:
npx serve website
```

### Linux Live USB 制盘 (用户使用流程)

```powershell
# Windows PowerShell,严格按 1→2→3→4 顺序
cd linux
.\1-prepare-usb.ps1        # 装 Ventoy(会格盘)
.\2-download-iso.ps1       # 下 Ubuntu 24.04.4 ISO
.\3-create-persistence.ps1 # 创建 casper-rw persistence.dat (默认 20GB)
.\4-copy-to-usb.ps1        # 复制 ISO + persistence + setup-hermes.sh 到 U 盘
```

### Win/Mac 便携版构建 (从上游一键造盘)

```powershell
# Windows (联网机器跑一次,产出完全离线的便携目录)
pwsh portable\build-portable-win.ps1 -Output D:\ -Tag v2026.6.5 -Proxy http://127.0.0.1:7897
```
```bash
# macOS
bash portable/build-portable-mac.sh --output /Volumes/MYUSB --tag v2026.6.5
```

成品里客户双击 `Windows-Start.bat` / `Mac-Start.command`。便携原理:启动脚本现算 U 盘位置,把 `HERMES_HOME` / `UV_*` 指进盘内,`uv run --project` 就地解析 venv,所以换盘符/换机器都不坏。详见 `portable/README.md`。

### Cloudflare DNS 自动化

```bash
# Token 拿法见 scripts/README.md
export CF_API_TOKEN='cfut_xxx'
bash scripts/cf-bind-dns.sh
# Windows: $env:CF_API_TOKEN='cfut_xxx'; .\scripts\cf-bind-dns.ps1
```

脚本幂等添加 `study` / `zh` 两条 CNAME 到 `cname.vercel-dns.com`。Vercel 处理 SSL,所以 **proxied=false** (灰云) 是必须的 —— proxied=true 会因双层加密导致 525 错误。

### Vercel 部署

```bash
vercel --prod         # outputDirectory 已在 vercel.json 锁为 website/
```

注意 `vercel.json` 里 `cleanUrls: true`,所有 redirect 都不带 trailing slash。

## Architecture

### 站点拓扑 (u-hermes.org 子域分工)

```
u-hermes.org           → 主官网卖货 (website/index.html, 571 行单页)
study.u-hermes.org     → 客户售后教程 (website/study/index.html, 2243 行单页)
zh.u-hermes.org        → 中文社区 + 实体书 (独立项目 ../hermes中文社区/, VitePress)
www.u-hermes.org       → CNAME 到主站
```

历史上有过 `dev.u-hermes.org` (hermes-agent-zh GitHub Pages),已撤销 —— 与 zh 站内容 100% 重叠会自抢 SEO,实体书统一在 zh 站。

详见 `__SITE_ARCHITECTURE_2026-04-27.md` (内部文档,被 .gitignore 排除)。

### 三个商业版本 vs 开源版的边界

| 形态 | 仓库位置 | 包含 |
|------|---------|------|
| **本仓库 (开源)** | `u-hermes-oss/` | 官网 + Linux 制盘脚本 |
| Windows 商业版 (闭源) | `../u-hermes-pro/` | Electron 启动器 + 激活 + 虾盘云 |
| 中文社区 + 实体书 | `../hermes中文社区/` | VitePress 站,有自己的部署链 |
| 上游 hermes-agent | `NousResearch/hermes-agent` | Python AI Agent 内核 |

### Linux 启动盘流程

四阶段制盘 + 一阶段安装:

1. **制盘 (Windows)**: Ventoy 1.0.99 写引导 → 下 Ubuntu ISO → 建 ext4 `casper-rw` persistence (要 WSL 才能本地 mkfs.ext4) → 复制到 Ventoy 数据分区
2. **运行时 (Ubuntu Live)**: `setup-hermes.sh` apt 装依赖 → 建 `~/.u-hermes/{venv,data}/` → pip 装 `hermes-agent` → 用户填 `~/.u-hermes/data/.env` 写 API key
3. **启动**: `start-hermes.sh` activate venv → 起 hermes-agent

`ventoy/ventoy.json` 让 Ventoy 自动挂载 persistence.dat,否则每次重启数据丢失。

### 内部禁公开文档约定

`.gitignore` 用前缀 `__` 圈出运营文档不公开:

```
__SITE_ARCHITECTURE_*.md
__STUDY_SITE_HANDOFF*.md
__USER_TUTORIAL_*.md
.tmp-*
```

写新内部笔记时**必须**用 `__` 前缀,否则会被 push 到公开仓。

## Environment

- **Platform**: Windows 11 + Git Bash (Unix path syntax: `/c/Users/...`)
- **Language**: 用户用中文沟通,文档/UI/commit message 都用中文
- **Vercel project**: `u-hermes-oss` (主站) 和 `u-hermes-study` (study 子站独立 project)
- **Cloudflare zone**: `u-hermes.org`,token 见 `scripts/README.md` 现配现用
