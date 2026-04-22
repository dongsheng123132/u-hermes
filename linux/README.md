# U-Hermes Linux 启动盘（教程版）

> **把任意电脑变成 AI 编程工作站 — 插上 U 盘，开机即用 Hermes Agent**

🎯 **本目录是教程和参考脚本，不提供编译好的 ISO release**。跟着文档走，你能自己做一个 Linux U 盘启动盘，开机即进 Ubuntu + hermes-agent。

## 为什么只发教程不发 release

- 打包 ISO 体积 6-8GB，GitHub release 有大小限制
- 每个人的 U 盘品牌/型号不同，需要自己适配
- 真正想折腾 Linux 的人，自己刻盘比下别人的 ISO 更有价值
- **如果你想要开箱即用的成品 U 盘**，请看 [Windows 商业版](https://www.u-hermes.org/#buy)

## 前置条件

- 16GB+ 的 U 盘（USB 3.0 以上，慢盘会卡）
- Windows 或 Linux 制作机
- [Ventoy 1.0.99+](https://www.ventoy.net/)
- [Ubuntu 24.04 Desktop ISO](https://releases.ubuntu.com/24.04/ubuntu-24.04.2-desktop-amd64.iso) (~5.8GB)
- 自备 AI API Key（DeepSeek / OpenAI / 或本地 ollama）

## 整体流程

```
┌────────────────────────────────────────────┐
│                U 盘结构                      │
│                                            │
│  Ventoy 引导区（隐藏分区）                   │
│    - BIOS + UEFI 双模式启动                  │
│    - 开源引导管理器 v1.0.99                  │
│                                            │
│  Ventoy 数据分区（可见）                     │
│    ubuntu-24.04.2-desktop-amd64.iso  5.8GB │
│    ventoy-persistence-casper.dat     20GB  │  ← 系统级持久化
│    ventoy/ventoy.json                配置   │
│    u-hermes-linux/                   脚本   │
│      ├── setup-hermes.sh             首次 bootstrap
│      ├── start-hermes.sh             每次启动运行
│      └── config.example              .env 模板
└────────────────────────────────────────────┘
```

## 步骤

### 1. 制作 Ventoy U 盘

参考 [u-claw-linux 仓库](https://github.com/dongsheng123132/u-claw-linux) 的 `1-prepare-usb.ps1` 到 `4-copy-to-usb.ps1`。步骤一样，只是 ISO 内的脚本换成我们的。

或者命令行版（Linux 制作机）：

```bash
# 假设 U 盘是 /dev/sdX（先 lsblk 确认，别插错！）
# 1. 安装 Ventoy
wget https://github.com/ventoy/Ventoy/releases/download/v1.0.99/ventoy-1.0.99-linux.tar.gz
tar xf ventoy-1.0.99-linux.tar.gz
cd ventoy-1.0.99
sudo ./Ventoy2Disk.sh -i /dev/sdX   # ⚠ 会清空 U 盘

# 2. 把 Ubuntu ISO 拷到 U 盘数据分区
sudo mkdir -p /mnt/usb
sudo mount /dev/sdX1 /mnt/usb
sudo cp ~/Downloads/ubuntu-24.04.2-desktop-amd64.iso /mnt/usb/

# 3. 创建持久化文件（20GB，给 hermes 装 venv + pip 依赖）
sudo truncate -s 20G /mnt/usb/ventoy-persistence-casper.dat
sudo mkfs.ext4 -L casper-rw /mnt/usb/ventoy-persistence-casper.dat

# 4. Ventoy 开启持久化配置
sudo mkdir -p /mnt/usb/ventoy
sudo tee /mnt/usb/ventoy/ventoy.json > /dev/null <<'EOF'
{
    "control": [
        { "VTOY_DEFAULT_MENU_MODE": "0" },
        { "VTOY_TREE_VIEW_STYLE": "1" }
    ],
    "persistence": [
        {
            "image": "/ubuntu-24.04.2-desktop-amd64.iso",
            "backend": "/ventoy-persistence-casper.dat"
        }
    ]
}
EOF

# 5. 拷 U-Hermes 脚本
sudo cp -r setup-hermes.sh start-hermes.sh config.example /mnt/usb/u-hermes-linux/
sudo sync
sudo umount /mnt/usb
```

### 2. 启动目标电脑

1. U 盘插入目标电脑 → 开机按 F12 / F2 / Esc（不同品牌不同）进 BIOS 启动菜单
2. 选 USB 启动
3. Ventoy 菜单出现 → 选 Ubuntu ISO
4. Ubuntu 启动菜单选 "**Try or Install Ubuntu**"
5. 进入 Ubuntu 桌面

### 3. 首次运行 setup

```bash
# 进 Ubuntu 后打开 Terminal（左下角 Show Applications 搜 terminal）
sudo cp -r /cdrom/u-hermes-linux ~/u-hermes
cd ~/u-hermes
chmod +x setup-hermes.sh start-hermes.sh
./setup-hermes.sh
```

`setup-hermes.sh` 会：
- `apt install python3-venv nodejs npm curl`
- 创建 `~/.u-hermes/venv`
- pip 装 `hermes-agent` + 依赖
- 创建 `~/.u-hermes/data/` 目录 + 默认 `.env`
- 装桌面图标

### 4. 日常使用

```bash
# 每次启动运行
~/u-hermes/start-hermes.sh
```

或者双击桌面上的 "U-Hermes" 图标。

浏览器会打开 http://127.0.0.1:8648 开始聊天。

## 配置 Provider

首次启动需要配 AI API。编辑 `~/.u-hermes/data/.env`：

```bash
# 选一个填就行
DEEPSEEK_API_KEY=sk-xxx          # 国内推荐，直连
OPENAI_API_KEY=sk-xxx            # 需代理
ANTHROPIC_API_KEY=sk-ant-xxx     # 需代理
# ... 其它 OpenAI 兼容接口
```

或者用 Ollama 本地模型（离线）：

```bash
# 安装 ollama
curl -fsSL https://ollama.com/install.sh | sh

# 下载模型
ollama pull qwen2.5:7b

# Hermes 自动检测到 ollama
```

## 脚本源代码

- `setup-hermes.sh` — 首次 bootstrap
- `start-hermes.sh` — 每次启动执行
- `config.example` — .env 模板

见本目录下的文件。欢迎 PR 改进。

## FAQ

**Q: 跟 Windows 商业版比有什么区别？**
A: 两者 AI 核心能力一致（都是 hermes-agent + web-ui）。区别在体验：
- Linux 版需要自己刻盘、跑脚本、排错
- Windows 版开箱即用，插上 exe 双击即可
- Linux 版需自备 API Key，Windows 版赠送初始额度

**Q: 持久化分区多大合适？**
A: 建议 20GB+。hermes 的 Python 依赖约 2GB，再加上模型缓存、聊天历史、ollama 模型等。

**Q: 能在 Mac 上启动吗？**
A: Intel Mac 可以（按住 Option 选启动盘）。M1/M2/M3 Mac 不行（ARM 架构不兼容 x86 ISO）。

**Q: 报错 "Kernel panic" / 启动卡住？**
A: 多半是 Ventoy 或 ISO 损坏。重新刻一遍盘试试。某些杂牌 U 盘兼容性差。

**Q: 为什么不直接发 release ISO？**
A: ISO 太大（6-8GB），GitHub release 限制 2GB。想要成品请看 [Windows 商业版](https://www.u-hermes.org/#buy)。

## 相关

- [u-claw-linux](https://github.com/dongsheng123132/u-claw-linux) — 姊妹项目，同样的 Ventoy 模式做 U-Claw
- [Ventoy 官方文档](https://www.ventoy.net/en/doc_start.html)
- [Ubuntu Live Wiki](https://help.ubuntu.com/community/Installation/FromUSBStick)

## License

MIT
