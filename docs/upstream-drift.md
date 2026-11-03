# 上游 hermes-agent 差异清单

> 用途：改本仓库的脚本、文案、教程之前先看这里。
> 最后核实：**2026-11-03**，上游 release **v0.22.6（2026-11-02）**。
> 上游变化极快（v0.22.5→v0.22.6 十天约 776 个 PR），超过一个月就要重新核。

## 一句话结论

我们原来假设的安装方式、端口、命令，**一半已经过时**。最容易踩的坑是「pip 装得上，但装的是三个月前的老版本」——它能跑，所以没人发现。

## 逐条对照

| 我们的假设 | 上游今天的实际情况 | 判定 |
|---|---|---|
| `pip install hermes-agent` 装最新版 | 官方 [platform-support.md] 把 **pypi 安装列为 Unsupported**（连 `uv tool install`、`brew` 一起）；PyPI 冻结在 **0.19.0（2026-07-20）**，比上游落后 3 个 minor。官方安装只剩 `install.sh` / `install.ps1`（uv + 自管 Python 3.14） | ❌ 断 |
| `python3 -m venv` + Ubuntu 自带 Python 3.12 | 官方要求 **Python 3.14**（`pyproject` 的 `>=3.11` 只是给老装升级用）；0.19.0 的 wheel 有 120 条未门控依赖，所以 3.12 上仍能装能跑——**这是被老版本救着** | ⚠️ 侥幸 |
| `hermes gateway run` + `HERMES_HOME` | **仍然有效**，且是官方给 WSL / Docker / Termux 的推荐姿势；`HERMES_HOME` 仍存在，默认 `~/.hermes` | ✅ 对 |
| gateway 监听 8642 | 8642 是 **OpenAI 兼容 API server**，`API_SERVER_ENABLED` **默认 false** → 默认根本没人监听 | ❌ 半错（探活会假失败） |
| Web UI 在 8648 | **上游文档里没有 8648**。Web 面是 `hermes dashboard` = 9119、`hermes webapp`（gateway 自 serve）= 9120（默认关） | ❌ 错 |
| 配置在 `$HERMES_HOME/data/.env` | 是 `$HERMES_HOME/config.yaml` + `$HERMES_HOME/.env`，**没有 `data/` 这一层** | ⚠️ 歪打正着 |
| 平台：Telegram/Discord/Slack/WhatsApp/Matrix | 上游主线是 Telegram/Discord/Slack/WhatsApp/**Signal**/Email；Matrix 适配器仍在但 Linux-only | ⚠️ 需校对 |
| 技能 104 个 / 工具 20+ | 上游 README 现在写 **40+ tools**；插件目录 600+ | ⚠️ 需校对 |

## 分发与打包相关（对 Windows 商业版影响最大）

- **v0.22.0 起 Windows 桌面只发 MSIX**，NSIS/MSI 安装器已删除 → 「便携 exe」是逆着上游走，要自己维护。
- **v0.22.0 起默认一台机器一个 gateway**，`hermes update` 会把多 profile 折叠成 multiplexed default → 一张盘插到已装 Hermes 的机器上必须靠 `HERMES_HOME` 隔离。
- **messaging 依赖已从 `[all]` 移出**，改由 `pm` 首次使用时**懒装** → 离线机器第一次开 Telegram 会失败。
- 命令改名：`hermes login/logout` → `hermes auth`；`hermes sync` 删除；`hermes mcp serve`（0.22.5）移出核心进插件。
- **v0.22.2 存在的原因是「v0.22.1 从错误的 commit 构建」** —— 这就是必须锁版本的现成理由。

## 我们的对策（已定）

1. 引擎基线按批次锁死（当前 `v0.22.6`），**不自动追每日 commit**；换代 = 换整包，旧版本目录保留即回滚。
2. 对外话术写「本批次已验证版本 + 版本号」，不写「最新版」。
3. 壳子起 `hermes dashboard`（固定端口 + 占用探测），不用 `--port 0`。
4. 启动探活**不能只听 8642**——改用进程存活 + 日志关键字。
5. 数据目录仍是 `HERMES_HOME` → 指向 U 盘；引擎解到本机缓存。

## 参考

- <https://github.com/NousResearch/hermes-agent>
- <https://hermes-agent.nousresearch.com/docs/getting-started/installation>
- <https://hermes-agent.nousresearch.com/docs/reference/cli-commands>
- <https://hermes-agent.nousresearch.com/docs/reference/environment-variables>
