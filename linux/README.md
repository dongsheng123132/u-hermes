# U-Hermes Linux 启动盘（开源方案）

> 把任意 x86_64 电脑变成 AI 编程工作站：插上 U 盘，从 USB 启动，进入 Ubuntu 桌面后运行 U-Hermes。

本目录是 U-Hermes 的开源 Linux 盘启动方案，参考了 [u-claw-linux](https://github.com/dongsheng123132/u-claw-linux) 的四步制盘结构：Ventoy 引导、Ubuntu Live ISO、casper-rw 持久化、Linux 端一键安装脚本。

商业成品版请看官网和购买链接：

- 官网：[https://www.u-hermes.org/](https://www.u-hermes.org/)
- 购买页：[https://www.u-hermes.org/#buy](https://www.u-hermes.org/#buy)
- 淘宝：[购买马盘 U 盘](https://e.tb.cn/h.ij8LYYB0cZPkNHw?tk=FMo05XEJYk0)
- 拼多多：[购买马盘 U 盘](https://mobile.yangkeduo.com/goods1.html?ps=WaQeS00tDn)
- 抖音：[购买马盘 U 盘](https://haohuo.jinritemai.com/ecommerce/trade/detail/index.html?id=3814862440735309865&origin_type=604)

## 开源版与商业版

| 版本 | 形态 | 适合谁 |
| --- | --- | --- |
| Linux 启动盘开源版 | 自己制盘、自己配置 API Key、自己排错 | 极客 / 开发者 |
| U-Hermes 马盘 Windows 商业版 | 成品 U 盘，内置 U-Claw + U-Hermes，双击 `.exe` 起图形界面 | 想开箱即用的 Windows 用户 |

Linux 版只覆盖 U-Hermes 的开源启动盘方案，不包含 Windows 启动器、U-Claw 集成、账户绑定、预装额度和售后服务。

## 技术方案

```text
U 盘
├── Ventoy 引导区（隐藏分区）
│   ├── BIOS + UEFI 双模式启动
│   └── Ventoy 1.0.99
│
└── Ventoy 数据分区（可见）
    ├── ubuntu-24.04.4-desktop-amd64.iso
    ├── persistence.dat
    ├── ventoy/
    │   └── ventoy.json
    └── u-hermes-linux/
        ├── setup-hermes.sh
        ├── start-hermes.sh
        └── config.example
```

核心选型：

| 技术 | 作用 |
| --- | --- |
| Ventoy 1.0.99 | ISO 直接放进 U 盘即可启动，兼容 BIOS / UEFI |
| Ubuntu 24.04 LTS | 驱动兼容性和社区支持较好 |
| casper-rw 持久化 | Live USB 重启后保留安装的软件、配置和对话数据 |
| hermes-agent | U-Hermes 的开源 Agent 核心 |

## 硬件要求

- 32GB+ U 盘，推荐 USB 3.0 或更快
- 制作环境：Windows 10/11 + PowerShell 5.1+
- 目标电脑：x86_64（Intel / AMD）
- 首次安装需要联网
- 自备 AI API Key（DeepSeek / 通义千问 / OpenAI 兼容接口 / 本地 ollama）

## Windows 四步制盘

在 Windows 上以普通 PowerShell 进入本目录：

```powershell
cd path\to\u-hermes-oss\linux
```

### Step 1：安装 Ventoy

```powershell
.\1-prepare-usb.ps1
```

脚本会下载 Ventoy 1.0.99 并打开 `Ventoy2Disk.exe`。你需要在 Ventoy 图形界面里选择 U 盘并点 Install。

注意：这一步会格式化 U 盘，先备份数据。

### Step 2：下载 Ubuntu ISO

```powershell
.\2-download-iso.ps1
```

脚本会优先从清华、阿里、中科大镜像下载 `ubuntu-24.04.4-desktop-amd64.iso`，并尽量用 `SHA256SUMS` 校验文件完整性。

### Step 3：创建持久化镜像

```powershell
.\3-create-persistence.ps1
```

默认创建 20GB 的 `persistence.dat`。如需指定大小：

```powershell
.\3-create-persistence.ps1 -SizeGB 40
```

推荐安装 WSL。脚本会通过 WSL 执行：

```bash
mkfs.ext4 -F -L casper-rw persistence.dat
```

如果没有 WSL，脚本只会创建空文件。你需要首次进入 Ubuntu 后手动格式化：

```bash
sudo mkfs.ext4 -F -L casper-rw /media/*/Ventoy/persistence.dat
```

### Step 4：复制文件到 U 盘

```powershell
.\4-copy-to-usb.ps1
```

脚本会把 ISO、`persistence.dat`、`ventoy/ventoy.json` 和 `setup-hermes.sh` / `start-hermes.sh` / `config.example` 复制到 Ventoy U 盘。

## 首次启动

1. 将 U 盘插入目标电脑。
2. 开机按启动键进入启动菜单（常见：F12 / F11 / F9 / Esc / Del）。
3. 选择 USB 设备。
4. 在 Ventoy 菜单里选择 Ubuntu ISO。
5. 进入 Ubuntu 桌面，连接网络。
6. 打开 Terminal，运行：

```bash
sudo bash /media/*/Ventoy/u-hermes-linux/setup-hermes.sh
```

安装完成后，桌面会出现 `U-Hermes` 图标。之后每次进入 Ubuntu，双击图标或运行：

```bash
~/u-hermes/start-hermes.sh
```

## 配置模型

首次启动前编辑：

```bash
~/.u-hermes/data/.env
```

支持的常见配置：

```bash
# DeepSeek
DEEPSEEK_API_KEY=sk-xxx

# 通义千问 / DashScope
DASHSCOPE_API_KEY=sk-xxx

# OpenAI 兼容接口
OPENAI_API_KEY=sk-xxx
OPENAI_BASE_URL=https://api.example.com/v1

# 本地 ollama
OPENAI_API_KEY=ollama
OPENAI_BASE_URL=http://127.0.0.1:11434/v1
```

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `1-prepare-usb.ps1` | 下载 Ventoy 并打开 Ventoy2Disk |
| `2-download-iso.ps1` | 下载 Ubuntu 24.04.4 Desktop ISO |
| `3-create-persistence.ps1` | 创建 `persistence.dat` 持久化镜像 |
| `4-copy-to-usb.ps1` | 复制 ISO、持久化镜像、Ventoy 配置和 U-Hermes 脚本 |
| `ventoy/ventoy.json` | 让 Ventoy 自动为 Ubuntu 加载持久化镜像 |
| `setup-hermes.sh` | Ubuntu 内首次安装 U-Hermes |
| `start-hermes.sh` | 每次启动 U-Hermes |
| `config.example` | API Provider 配置模板 |

## FAQ

**Q: 这个开源方案和 U-Hermes 马盘商业版有什么区别？**

A: 开源方案需要自己制盘、联网安装、配置 API Key 和排错；U-Hermes 马盘商业版是 Windows 成品 U 盘，内置 U-Claw + U-Hermes、图形启动器、账户体系、初始额度和售后。商业版请看 [官网购买页](https://www.u-hermes.org/#buy)。

**Q: 为什么不直接发布 ISO？**

A: ISO 体积通常 6GB 以上，不适合放在 GitHub release；不同 U 盘型号和持久化大小也需要用户自己选择。

**Q: Mac 能启动吗？**

A: Intel Mac 可能可以，Apple Silicon（M1/M2/M3/M4）不适合这个 x86_64 Ubuntu ISO。

**Q: 启动失败或卡住怎么办？**

A: 优先检查 U 盘是否为 USB 3.0、ISO 是否校验通过、`persistence.dat` 是否已格式化为 ext4 且卷标为 `casper-rw`。部分电脑需要在 BIOS 里关闭 Secure Boot。

## 相关项目

- [u-claw-linux](https://github.com/dongsheng123132/u-claw-linux) — OpenClaw / U-Claw 的 Linux 可启动 U 盘方案
- [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) — U-Hermes 上游 Agent 项目
- [Ventoy 官方文档](https://www.ventoy.net/en/doc_start.html)
