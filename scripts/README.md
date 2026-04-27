# Cloudflare DNS 自动化脚本

## 快速使用

### 1. 创建 API Token

打开 https://dash.cloudflare.com/profile/api-tokens

- "Create Token" → 选模板 **"Edit zone DNS"**
- Zone Resources → Specific zone → **u-hermes.org**
- Continue → Create Token
- **复制 token**（只显示一次）

### 2. 跑脚本

#### Windows PowerShell

```powershell
$env:CF_API_TOKEN = 'cfut_xxx你的token'
.\scripts\cf-bind-dns.ps1
```

#### Git Bash / Linux / Mac（需先装 jq）

```bash
# Windows Git Bash 装 jq:
#   pacman -S jq    （MSYS2）
# 或下载 https://stedolan.github.io/jq/download/

export CF_API_TOKEN='cfut_xxx你的token'
bash scripts/cf-bind-dns.sh
```

## 脚本会做什么

幂等添加 / 更新两条 DNS 记录：

| 域名 | 类型 | 目标 | 用途 |
|---|---|---|---|
| study.u-hermes.org | CNAME | cname.vercel-dns.com | 客户教程站（Vercel） |
| dev.u-hermes.org   | CNAME | dongsheng123132.github.io | 开发者教程（GitHub Pages） |

均设 proxied=false（灰云）—— 因为：

- **Vercel** 自己处理 SSL，proxied=true 会重复加密导致 525 错误
- **GitHub Pages** 也自己处理 SSL，proxied=true 会让证书颁发卡住

如果以后想开 Cloudflare 加速 / 防火墙，再单独把 proxied 改 true。

## 安全

- Token 用完可在 Cloudflare 后台 revoke
- 永远**不要**把 token 写进 git commit
- `.gitignore` 已排除 `.env*` 文件
