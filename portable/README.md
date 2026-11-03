# U-Hermes 马盘 · 便携启动壳

> 这一层是「让 U 盘插上就能用」的那部分，开源（MIT）。
> 商业闭源的是**服务端**（虾盘云钱包、签发、计费、支付），客户端这一层全部在这里。

## 它是什么 / 不是什么

**是**：桌面启动器 + 便携层。双击 → 找引擎 → 装引擎（本机缓存）→ 拿钱包 → 起服务 → 打开界面。

**不是**：一套新的图形界面。界面用 hermes 自带的 Web 控制台（`hermes dashboard`，默认 9119），
壳子只负责把它在正确的位置、用正确的数据目录、以单实例的方式拉起来。

## 盘上布局

```
U:\U-Hermes\
├── 启动 马盘.cmd          ← 双击入口（纯 ASCII 内容，中文只从 node 输出）
├── 钱包.cmd / 充值.cmd     ← 后续接
├── app\
│   ├── launch.cjs          ← 主启动器：单实例 / 起服务 / 抓 URL 开浏览器
│   ├── engine-install.cjs  ← 引擎：sha256 → 空间预检 → staging → 原子 rename
│   ├── wallet.cjs          ← 设备钱包：五字段状态机 + bind/rotate/adopt
│   ├── engine.json         ← {version, sha256, archive, entry}
│   └── engine.tar.gz       ← 单归档引擎（不是几万个散文件）
├── runtime\node-win-x64\node.exe
└── data\hermes-home\        ← ★ 资产：config.yaml / .env / sessions / skills
```

本机只放可重建的东西：`%LOCALAPPDATA%\U-Hermes\engine\<版本>\`。

## 四条硬规则

1. **路径永不持久化**：每次启动从 `%~dp0` 现推，盘符 E:→F: 天然无感。
2. **引擎是缓存、数据是资产**：删引擎目录不影响用户任何东西，下次启动自愈。
3. **凭据永不离盘**：钱包状态写 `data\wallet.json`，宿主机一个字节都不留。
4. **失败不阻断**：没网 / 盘只读 / 钱包坏了 → 跳过钱包，主程序照常起。

## 当前状态（诚实版）

| 项 | 状态 |
|---|---|
| 单实例锁 / 路径现推 / 剥 provider env | 已实现，**未在真机 Windows 验证** |
| 引擎单归档安装（sha256 + 空间预检 + 原子落地） | 已实现，**未验证真盘** |
| 端口探测 + 抓 stdout 拿真实 URL | 依赖 hermes 输出格式，**待真机核对** |
| 设备钱包五字段状态机 | 骨架已写，**未接服务端** |
| 引擎归档本身 | **未构建**（需要先量体积，见下） |

### 未验证项（验证前不作承诺）

- hermes 在 Windows 原生跑起来后的真实输出格式（抓 URL 的正则要按真机校准）
- 引擎闭包体积（含 Python 3.14 + 依赖）能否压到 U 盘可接受
- NTFS 盘在不同 Windows 账户下会不会因 ACL 报权限错

## 快速自检（L1，秒级）

```bash
node --check app/launch.cjs
node --check app/engine-install.cjs
node --check app/wallet.cjs
node -e "require('./app/engine-install.cjs')"   # 能 import 不报错
```
