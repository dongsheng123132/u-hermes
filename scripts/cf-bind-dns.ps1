# Cloudflare DNS 一键绑定脚本（PowerShell 版，不需要 jq）
#
# 给 u-hermes.org 添加两条 DNS：
#   - study.u-hermes.org  → CNAME cname.vercel-dns.com  (proxied:false)
#   - dev.u-hermes.org    → CNAME dongsheng123132.github.io  (proxied:false)
#
# 用法（PowerShell）：
#   $env:CF_API_TOKEN = 'cfut_xxx你的token'
#   .\scripts\cf-bind-dns.ps1
#
# 需要的 token 权限：Zone:DNS:Edit (限定 zone u-hermes.org)

$ErrorActionPreference = 'Stop'

$ZoneName = 'u-hermes.org'
$Records = @(
  @{ name='study'; type='CNAME'; content='cname.vercel-dns.com';      proxied=$false },
  @{ name='dev';   type='CNAME'; content='dongsheng123132.github.io'; proxied=$false }
)

if (-not $env:CF_API_TOKEN) {
  Write-Host "❌ 请先设 `$env:CF_API_TOKEN" -ForegroundColor Red
  Write-Host ""
  Write-Host "  Token 创建：https://dash.cloudflare.com/profile/api-tokens"
  Write-Host "  权限：Zone:DNS:Edit (限定 $ZoneName)"
  exit 1
}

$ApiBase = 'https://api.cloudflare.com/client/v4'
$Headers = @{
  'Authorization' = "Bearer $env:CF_API_TOKEN"
  'Content-Type'  = 'application/json'
}

# 1. 验证 token
Write-Host "[1/4] 验证 token..."
try {
  $verify = Invoke-RestMethod -Uri "$ApiBase/user/tokens/verify" -Headers $Headers
  if ($verify.result.status -ne 'active') {
    Write-Host "❌ Token 无效: $($verify | ConvertTo-Json)" -ForegroundColor Red
    exit 1
  }
  Write-Host "  ✓ Token active" -ForegroundColor Green
}
catch {
  Write-Host "❌ Token 验证失败: $_" -ForegroundColor Red
  exit 1
}

# 2. 拿 zone_id
Write-Host ""
Write-Host "[2/4] 获取 $ZoneName 的 zone_id..."
$zoneResp = Invoke-RestMethod -Uri "$ApiBase/zones?name=$ZoneName" -Headers $Headers
if (-not $zoneResp.result -or $zoneResp.result.Count -eq 0) {
  Write-Host "❌ 找不到 zone $ZoneName" -ForegroundColor Red
  Write-Host ($zoneResp | ConvertTo-Json -Depth 5)
  exit 1
}
$zoneId = $zoneResp.result[0].id
Write-Host "  ✓ zone_id: $zoneId" -ForegroundColor Green

# 3. 创建/更新记录
Write-Host ""
Write-Host "[3/4] 检查 + 创建 DNS 记录..."
foreach ($r in $Records) {
  $fqdn = "$($r.name).$ZoneName"
  Write-Host ""
  Write-Host "  → $fqdn  $($r.type)  $($r.content)  proxied=$($r.proxied)"

  # 查现有
  $existing = Invoke-RestMethod -Uri "$ApiBase/zones/$zoneId/dns_records?name=$fqdn" -Headers $Headers
  $existingRecord = $existing.result | Select-Object -First 1

  $body = @{
    type    = $r.type
    name    = $r.name
    content = $r.content
    proxied = $r.proxied
    ttl     = 1
  } | ConvertTo-Json

  if ($existingRecord) {
    if ($existingRecord.content -eq $r.content) {
      Write-Host "    ✓ 已存在且内容一致，跳过" -ForegroundColor Green
    } else {
      Write-Host "    ⚠ 已存在但内容不同（旧: $($existingRecord.content)），更新..." -ForegroundColor Yellow
      try {
        $resp = Invoke-RestMethod -Method Put -Uri "$ApiBase/zones/$zoneId/dns_records/$($existingRecord.id)" -Headers $Headers -Body $body
        if ($resp.success) {
          Write-Host "    ✓ 已更新" -ForegroundColor Green
        } else {
          Write-Host "    ❌ 更新失败: $($resp | ConvertTo-Json)" -ForegroundColor Red
        }
      }
      catch {
        Write-Host "    ❌ 更新异常: $_" -ForegroundColor Red
      }
    }
  } else {
    Write-Host "    新建中..."
    try {
      $resp = Invoke-RestMethod -Method Post -Uri "$ApiBase/zones/$zoneId/dns_records" -Headers $Headers -Body $body
      if ($resp.success) {
        Write-Host "    ✓ 已创建 (id: $($resp.result.id))" -ForegroundColor Green
      } else {
        Write-Host "    ❌ 创建失败: $($resp | ConvertTo-Json)" -ForegroundColor Red
      }
    }
    catch {
      Write-Host "    ❌ 创建异常: $_" -ForegroundColor Red
    }
  }
}

# 4. 列出当前相关记录
Write-Host ""
Write-Host "[4/4] 当前 $ZoneName 的相关 DNS 记录："
$all = Invoke-RestMethod -Uri "$ApiBase/zones/$zoneId/dns_records?per_page=100" -Headers $Headers
$all.result | Where-Object { $_.name -match '^(study|dev)\.' } | ForEach-Object {
  Write-Host "  $($_.name)  $($_.type)  → $($_.content)  (proxied: $($_.proxied))"
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host " ✅ DNS 配置完成" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步：" -ForegroundColor Yellow
Write-Host ""
Write-Host " study.u-hermes.org （Vercel 部署）："
Write-Host "   1. 打开 https://vercel.com/<your-team>/u-hermes-oss/settings/domains"
Write-Host "   2. Add Domain → study.u-hermes.org"
Write-Host "   3. 5-30 分钟后访问 https://study.u-hermes.org/ 验证"
Write-Host ""
Write-Host " dev.u-hermes.org （GitHub Pages 部署 hermes-agent-zh）："
Write-Host "   1. hermes-agent-zh/site/static/CNAME 已准备好（内容: dev.u-hermes.org）"
Write-Host "   2. push 仓库后 → Settings → Pages → Custom domain: dev.u-hermes.org"
Write-Host "   3. 等待 SSL 证书颁发（最多 24h，通常 5-15 分钟）"
Write-Host ""
Write-Host " 验证：" -ForegroundColor Yellow
Write-Host "   nslookup study.u-hermes.org"
Write-Host "   nslookup dev.u-hermes.org"
Write-Host "   curl.exe -I https://study.u-hermes.org/"
