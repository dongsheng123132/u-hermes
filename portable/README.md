# U-Hermes 便携版（Windows + Mac · 完全离线 · 开源构建包）

把上游 [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)（MIT）打包成一个**插上即用、完全离线、零依赖**的便携 U 盘目录。客户机不需要装 Python、不需要联网、不写系统注册表——双击一个脚本就能跑。

本目录是**构建包（build kit）**：任何人都能用这里的脚本，从上游源码生成自己的便携 U 盘。这是纯开源打包，**不含**任何指纹 / 激活码 / 虾盘云逻辑（那些在闭源的 `../u-hermes-pro/`）。

> Linux Live 制盘方案见仓库的 [`../linux/`](../linux/)。本目录专做 **Windows + Mac**。

---

## 这是给谁的

| 你是… | 用哪个 |
|-------|--------|
| **发版的人**（自己造盘卖 / 分发） | 跑 `build-portable-win.ps1` / `build-portable-mac.sh` 生成成品目录，拷进 U 盘 |
| **拿到成品 U 盘的客户** | 不用看本文档，直接双击 `Windows-Start.bat` / `Mac-Start.command`，看 `README.txt` |

---

## 成品目录长什么样

```
U-Hermes/
├─ Windows-Start.bat       ← Windows 客户双击这个
├─ Mac-Start.command       ← Mac 客户双击这个
├─ README.txt              ← 给客户的中文说明
├─ runtime/
│  ├─ win/  { uv.exe, python/, git/, tools/ }   只读运行时（Windows）
│  └─ mac/  { uv,    python/, tools/ }           只读运行时（Mac）
├─ app/hermes-agent/       ← 上游源码 + venv（离线已装好全部依赖）
├─ cache/                  ← uv wheel 缓存（离线兜底）
└─ data/                   ← 唯一可写区：客户的 .env / 会话 / 日志
   └─ .env.example
```

**便携原理**：`runtime/` + `app/` 是盘符无关的只读运行时；启动脚本用 `%~dp0`（Win）/ `dirname $0`（Mac）现算 U 盘位置，把 `HERMES_HOME`、`UV_PYTHON_INSTALL_DIR`、`UV_CACHE_DIR` 指进盘内，再用 `uv run --project` **就地解析 venv**。所以换电脑、换盘符（`E:` 变 `H:`）都不会坏，无需重装。客户数据全在 `data/`。

---

## 怎么构建

### Windows（在一台联网的 Windows 机器上）

```powershell
# 生成到 dist\U-Hermes，pin 到上游某个 release tag（推荐）
pwsh portable\build-portable-win.ps1 -Output .\dist -Tag v2026.6.5

# 直接生成到 U 盘（比如 D:）
pwsh portable\build-portable-win.ps1 -Output D:\ -Tag v2026.6.5

# 走代理下载（国内常用）
pwsh portable\build-portable-win.ps1 -Output .\dist -Proxy http://127.0.0.1:7897
```

| 参数 | 说明 | 默认 |
|------|------|------|
| `-Output` | 输出根目录（可给 U 盘盘符） | `.\dist` |
| `-Tag` | 上游 release tag（日历版号，如 `v2026.6.5`）。传 `main` 跟最新但不可复现 | `v2026.6.5` |
| `-Name` | 便携目录名 | `U-Hermes` |
| `-Proxy` | 构建时下载用的代理（只影响构建，不写进成品） | 空 |

> 📌 **版本策略**：默认锁 `v2026.6.5`（上游 "Surface" 版，自带 in-app self-update + 简体中文）。最新版查 [releases](https://github.com/NousResearch/hermes-agent/releases)，上游是 **日历版号 `v2026.M.D`**。造盘时锁版本保证可复现；客户拿到盘后可以在启动菜单里**自更新**到更新的版本（见下文「自更新」）。

> ⚠️ **脚本是 UTF-8 with BOM**。如果你编辑后中文乱码或报字符串语法错误，多半是保存时丢了 BOM——这台机器是 Windows PowerShell 5.1，无 BOM 会按 GBK 读崩。

### macOS（在一台联网的 Mac 上）

```bash
bash portable/build-portable-mac.sh --output ./dist --tag v2026.6.5
bash portable/build-portable-mac.sh --output /Volumes/MYUSB --tag v2026.6.5
bash portable/build-portable-mac.sh --output ./dist --proxy http://127.0.0.1:7890
```

Mac 上 `ripgrep` / `ffmpeg` 若系统已有则不强制内置；要做到**绝对离线**，可 `brew install ripgrep ffmpeg` 后把二进制拷到 `runtime/mac/tools/`。

---

## 构建脚本做了什么

1. 下载便携 `uv`（[astral-sh/uv](https://github.com/astral-sh/uv) standalone 二进制）进 `runtime/`。
2. 把 uv 的所有路径（`UV_PYTHON_INSTALL_DIR` / `UV_CACHE_DIR`）锁进输出目录。
3. 用这个便携 uv 直接编排：
   - `git clone --depth 1 --branch <Tag>` 拉上游源码进 `app/hermes-agent/`；
   - `uv python install 3.11` 把 Python 装进盘内 `runtime/win/python/`；
   - `uv venv .venv` 建虚拟环境（**必须叫 `.venv`**，uv 默认名，否则 `uv run` 会在客户机当场重建、破坏离线）；
   - `uv sync --extra all --locked` 装全部依赖（回退 `uv pip install -e .[all]` → `-e .`）。
4. 拷入启动脚本 / `README.txt` / `.env.example`。
5. 离线自检 `uv run hermes --version`，打印体积。

> **为什么不调上游官方 `install.ps1`？** 实测它会自举安装自己的 uv 到 `data\bin` 再继续，这一步在代理/重定向环境下会失败（`uv installed but not found`）。我们已经有可用的便携 uv，直接 `clone + venv + sync` 更可控、更稳，也不受上游安装器改版影响。

---

## 发版后怎么验证（必做）

1. **构建机**：脚本末尾的 `hermes --version` 自检应通过。
2. **离线冒烟**：把成品拷到 U 盘 → 插到一台**断网**机器 → 双击启动脚本：
   - 首跑自动开编辑器让填 `.env`（填个 DeepSeek key 或配本地 Ollama）。
   - 关掉编辑器后 `hermes` TUI 正常起来、能对话。
   - 改成 `hermes gateway run`，`netstat`/`ss` 看 `8642` LISTENING，浏览器开 `127.0.0.1:8648`。
3. **盘符无关**：同一 U 盘在另一台机器换了盘符再插，双击仍能跑。
4. **数据隔离**：确认只有 `data/` 有写入，`runtime/` `app/` 保持只读干净。

---

## 自更新（造盘锁版 + 盘内更新，两者兼得）

- **造盘时**：`-Tag v2026.6.5` 把一个**确定的版本**烤进 U 盘，保证每次造盘产物一致、可复现、纯离线。
- **客户用时**：成品启动菜单的 **`[4] 检查更新`** 在**联网**时会:
  1. 先跑上游自带的 `hermes update`（v2026.6.5+ 支持 in-app self-update），把新代码拉下来；
  2. 失败则回退 `uv sync --extra all` 重装依赖；再失败回退 `uv pip install -e .[all]`。
- 更新**写回 U 盘的 `app/hermes-agent/`**，所以**下次离线启动仍是更新后的新版**。断网时这个菜单项会报网络错误并提示重试，不影响离线使用旧版。

> 设计取舍：U 盘卖给小白，默认**不自动更新**（避免联网失败/版本漂移把能用的盘搞坏），把更新做成**用户主动点的菜单项**。要批量升级一批盘，重新造盘是最稳的。

---

## 启动菜单（客户双击后看到的）

```
[1] 开始对话 (命令行 TUI)
[2] 启动 Web 网关 (浏览器界面)   → http://127.0.0.1:8648
[3] 编辑配置 (API Key / 模型)
[4] 检查更新 (需联网)
[5] 诊断 (hermes doctor)
[0] 退出
```

首跑会自动生成 `data/.env` 并打开编辑器引导填 key。`Windows-Start.bat` 和 `Mac-Start.command` 都是这套菜单。

---

## 环境隔离（防污染客户机 / 防被客户机污染）

启动脚本除了重定向 `HERMES_HOME` / `UV_*`，还设了:

| 变量 | 作用 |
|------|------|
| `PYTHONNOUSERSITE=1` | 忽略客户机用户级 site-packages，防外部包串味 |
| `PYTHONHOME=` / `PYTHONPATH=`（清空） | 不认客户机已装的 Python |
| `PIP_USER=0` | 禁止 pip 往用户目录装 |
| `APPDATA` / `LOCALAPPDATA` → 盘内 `cache/`（Win）<br>`XDG_CACHE_HOME` / `XDG_CONFIG_HOME` → 盘内 `cache/`（Mac） | 防止 hermes/uv 往客户机系统目录写缓存 |

效果：在**任何一台机器**（哪怕客户自己装了乱七八糟的 Python）上，U 盘都用自己盘内那套环境，且不在客户机留垃圾。

---

## 和其他 hermes 便携仓库的对比（为什么这样做）

社区已有几个便携 hermes 仓库，思路相近，但针对**离线卖 U 盘**这个场景，本方案做了不同取舍:

| 维度 | techjarves / Aiworksolutions | aivrar (Win GUI) | **本方案** |
|------|------|------|------|
| 核心架构 | `HERMES_HOME`+uv venv | 嵌入式 Py + Tkinter | `HERMES_HOME`+uv venv（同源思路） |
| 运行时来源 | **首跑联网下 ~600MB** | 装时下 | **造盘预装，完全离线** ✅ |
| 装 hermes 的方式 | 自己硬编码一堆下载 URL（python-build-standalone / Node / git / rg 各 pin 版本） | 自定义 | **便携 uv 直接 `clone + venv + sync`**，Python/依赖全交给 uv 解析，不硬编码 URL ✅ |
| 版本 | 拉 main / 或硬 pin | pull upstream | **默认 pin `v2026.6.5`，可改** |
| 自更新 | ✅ 菜单/`hermes update` | ✅ | ✅（菜单 `[4]`，更新写回盘） |
| 隔离 | `PYTHONNOUSERSITE`/`PYTHONHOME`/重定向 `APPDATA` | — | ✅（借鉴并补全到 Win+Mac） |

**借鉴了它们的**：交互式菜单、`PYTHONNOUSERSITE`/`PYTHONHOME`/`APPDATA` 三件套隔离、自更新做成菜单项。
**和它们不同的**：(1) 离线预装而非首跑联网——卖 U 盘必须断网可用；(2) 用 uv 解析依赖而非硬编码下载 URL（它们 pin 一堆 Python/Node/git/rg 的固定 URL，上游几乎每周发版会很快失效）；(3) 实测上游官方 `install.ps1` 在代理环境下会卡在自举装 uv，所以我们用便携 uv 自己编排，更稳。

参考仓库（都基于上游 MIT，自行评估）：
- [techjarves/hermes-usb-portable](https://github.com/techjarves/hermes-usb-portable)
- [Aiworksolutions/hermesAgent-usb-portable](https://github.com/Aiworksolutions/hermesAgent-usb-portable)
- [aivrar/portable-hermes-agent](https://github.com/aivrar/portable-hermes-agent)

---

## 常见坑

| 现象 | 原因 / 处理 |
|------|------------|
| Windows Defender 报警 | 便携程序常见误报，选「仍要运行」。代码签名是商业版的事，开源版不处理。 |
| Mac「已损坏 / 无法验证开发者」 | 右键 → 打开；或系统设置→隐私与安全性→仍要打开。构建脚本已对成品 `xattr -rd com.apple.quarantine`。 |
| `npm` / `uv` 装到旧版本 | 代理缓存了过期 registry 元数据。换直连或用 `--proxy` 指明，或清缓存重试。 |
| 体积太大（~1.5GB） | `[all]` extras 很全。后续可加 `-Minimal` 只装核心 provider 砍到 ~600MB。 |
| 首次启动慢 | U 盘 IO 慢，正常。长期用建议把整个目录拷到本地硬盘再双击。 |

---

## 体积预期

完整 `[all]` 安装约 **1.3–1.6 GB**（Python + 全部 provider/工具依赖 + Node + git + ffmpeg）。用 16GB 以上 U 盘绰绰有余。

---

基于 [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)（MIT）。官网 [u-hermes.org](https://u-hermes.org) · 教程 [study.u-hermes.org](https://study.u-hermes.org)。
