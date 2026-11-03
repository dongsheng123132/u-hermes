# 🐎 U-Hermes 马盘

> **一张 Windows 便携 AI U 盘：插上双击，浏览器里就是最新版 Hermes Agent。**
> 引擎装在你这台电脑上，数据留在 U 盘里，设备钱包自动就位，充值一点就跳转。

关键词：U-Hermes 马盘、Windows 便携 AI U 盘、Hermes Agent、DeepSeek、设备钱包、虾盘云

## 它解决什么问题

装一个 AI Agent 本身不难，难的是「装完之后」：换台电脑要从零开始、数据散落各处、每次都要配 Key、上游一天一个样。

马盘把这四件事一次做掉：

| 问题 | 马盘的做法 |
|---|---|
| 换电脑就断档 | 数据（对话/配置/技能/记忆）全在 U 盘，插哪台都是同一个你 |
| U 盘 IO 慢 | 引擎展开到本机缓存目录，U 盘只做存储不跑程序 |
| 要注册、要填 Key | 设备钱包由服务端签发，插上就有可用额度 |
| 充值要跳三家 | 一个钱包全家通用，一点跳转支付宝 / 微信，客户端不碰支付 |

## 产品矩阵

同一个内核，不同外壳。**载体都免费开源，收钱只发生在钱包。**

| 产品 | 是什么 | 平台 |
|---|---|---|
| **U-Hermes 马盘** ← 本仓 | Hermes Agent 成品便携盘 | Windows |
| [U-Claw 虾盘](https://github.com/dongsheng123132/u-claw) | OpenClaw AI 助手离线安装盘，接 QQ/微信/飞书机器人 | Windows |
| [U-DSH](https://github.com/dongsheng123132/u-dsh-deepseek-harness-portable) | DeepSeek Harness 便携版 | Windows + macOS |
| [U-King](https://github.com/dongsheng123132/u-king) | AI 装机管家 + 多 AI 工作台 | Windows |
| 虾盘精灵 Picoclaw | 十几 MB 的超小 AI 随身助手 | Windows |
| 虾盘云钱包 | 上面所有产品共用的一套余额 | 服务端 |

各产品细节见 [u-claw.org](https://u-claw.org)。马盘官网：[www.u-hermes.org](https://www.u-hermes.org)。

## 本仓库是什么

**只放开源部分**：

- 🌐 `website/` — u-hermes.org 官网源码（Vercel 部署，含中文教程站 `website/study/`）
- 📖 `docs/` — 文档
- 🗄 `linux/` — Linux Live USB 制盘脚本（**已归档，不再维护**，见该目录 README 顶部说明）
- 🛠 `scripts/` — Cloudflare DNS 自动化脚本

**不在本仓库**（商业闭源）：启动壳、设备钱包客户端、虾盘云服务端与支付/充值链路。

## 运行原理（想自己复刻的人看这里）

```
U:\U-Hermes\
├── 启动 马盘.cmd          ← 双击入口，只负责定位路径 + 设环境变量
├── data\hermes-home\      ← 资产：config.yaml / .env / sessions / skills
└── app\                    ← 壳子与引擎归档
    ├── engine.tar.gz       ← 单归档引擎（不是几万个散文件）
    └── engine.json         ← 版本 + sha256
```

1. **路径永不持久化**：每次启动从脚本自身位置现推，U 盘盘符从 E: 变成 F: 也不影响。
2. **引擎 = 可重建缓存**：解到本机 `%LOCALAPPDATA%`，删了能重建；数据是资产，引擎不是。
3. **单归档分发**：松散目录上万个文件在 U 盘上又慢又容易坏，压成一个归档后拷盘快一个数量级。
4. **换代即换包**：引擎按版本分目录，旧版本原样保留，出问题直接回滚。

## 购买

- 官网：[www.u-hermes.org](https://www.u-hermes.org/)
- 淘宝：[购买 U-Hermes 马盘](https://e.tb.cn/h.ij8LYYB0cZPkNHw?tk=FMo05XEJYk0)

## 许可

代码 MIT（见 [LICENSE](./LICENSE)）。品牌、商标（"马盘"、"U-Hermes"、Logo）与商业闭源部分保留所有权利。

## 相关

- [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) — 上游 Agent 内核（MIT）
- [u-claw.org](https://u-claw.org) — 虾盘系产品总入口
- [hermes-agent-zh](https://github.com/dongsheng123132/hermes-agent-zh) — Hermes Agent 中文教程书
