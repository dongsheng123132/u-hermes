#!/usr/bin/env bash
# Cloudflare DNS 一键绑定脚本
#
# 给 u-hermes.org 添加两条 DNS：
#   - study.u-hermes.org  → CNAME cname.vercel-dns.com  (proxied:false)
#   - dev.u-hermes.org    → CNAME dongsheng123132.github.io  (proxied:false)
#
# 用法：
#   export CF_API_TOKEN='cfut_xxx你的token'
#   bash scripts/cf-bind-dns.sh
#
# 需要的 token 权限：Zone:DNS:Edit (限定 zone u-hermes.org)
#
# License: MIT

set -euo pipefail

ZONE_NAME="u-hermes.org"
RECORDS=(
  # name|type|content|proxied
  "study|CNAME|cname.vercel-dns.com|false"
  "dev|CNAME|dongsheng123132.github.io|false"
)

if [ -z "${CF_API_TOKEN:-}" ]; then
  echo "❌ 请先 export CF_API_TOKEN='your_token_here'"
  echo ""
  echo "  Token 创建：https://dash.cloudflare.com/profile/api-tokens"
  echo "  权限：Zone:DNS:Edit (限定 ${ZONE_NAME})"
  exit 1
fi

API_BASE="https://api.cloudflare.com/client/v4"
HEADERS=(
  -H "Authorization: Bearer ${CF_API_TOKEN}"
  -H "Content-Type: application/json"
)

# 1. 验证 token
echo "[1/4] 验证 token..."
verify=$(curl -sS "${API_BASE}/user/tokens/verify" "${HEADERS[@]}")
status=$(echo "$verify" | jq -r '.result.status // "unknown"')
if [ "$status" != "active" ]; then
  echo "❌ Token 无效:"
  echo "$verify" | jq .
  exit 1
fi
echo "  ✓ Token active"

# 2. 拿 zone_id
echo ""
echo "[2/4] 获取 ${ZONE_NAME} 的 zone_id..."
zone_resp=$(curl -sS "${API_BASE}/zones?name=${ZONE_NAME}" "${HEADERS[@]}")
zone_id=$(echo "$zone_resp" | jq -r '.result[0].id // empty')
if [ -z "$zone_id" ]; then
  echo "❌ 找不到 zone ${ZONE_NAME}"
  echo "$zone_resp" | jq .
  exit 1
fi
echo "  ✓ zone_id: ${zone_id}"

# 3. 检查每个目标记录是否已存在
echo ""
echo "[3/4] 检查 + 创建 DNS 记录..."
for record_def in "${RECORDS[@]}"; do
  IFS='|' read -r name type content proxied <<< "$record_def"
  fqdn="${name}.${ZONE_NAME}"

  echo ""
  echo "  → ${fqdn}  ${type}  ${content}  proxied=${proxied}"

  # 查现有记录
  existing=$(curl -sS "${API_BASE}/zones/${zone_id}/dns_records?name=${fqdn}" "${HEADERS[@]}")
  existing_id=$(echo "$existing" | jq -r '.result[0].id // empty')
  existing_content=$(echo "$existing" | jq -r '.result[0].content // empty')

  body=$(jq -n \
    --arg type "$type" \
    --arg name "$name" \
    --arg content "$content" \
    --argjson proxied "$proxied" \
    '{type: $type, name: $name, content: $content, proxied: $proxied, ttl: 1}')

  if [ -n "$existing_id" ]; then
    if [ "$existing_content" = "$content" ]; then
      echo "    ✓ 已存在且内容一致，跳过"
    else
      echo "    ⚠ 已存在但内容不同（旧: ${existing_content}），更新..."
      resp=$(curl -sS -X PUT "${API_BASE}/zones/${zone_id}/dns_records/${existing_id}" \
        "${HEADERS[@]}" \
        --data "$body")
      success=$(echo "$resp" | jq -r '.success')
      if [ "$success" = "true" ]; then
        echo "    ✓ 已更新"
      else
        echo "    ❌ 更新失败:"
        echo "$resp" | jq .
      fi
    fi
  else
    echo "    新建中..."
    resp=$(curl -sS -X POST "${API_BASE}/zones/${zone_id}/dns_records" \
      "${HEADERS[@]}" \
      --data "$body")
    success=$(echo "$resp" | jq -r '.success')
    if [ "$success" = "true" ]; then
      created_id=$(echo "$resp" | jq -r '.result.id')
      echo "    ✓ 已创建 (id: ${created_id})"
    else
      echo "    ❌ 创建失败:"
      echo "$resp" | jq .
    fi
  fi
done

# 4. 最终列出当前所有相关 DNS
echo ""
echo "[4/4] 当前 ${ZONE_NAME} 的相关 DNS 记录："
curl -sS "${API_BASE}/zones/${zone_id}/dns_records?per_page=100" "${HEADERS[@]}" \
  | jq -r '.result[] | select(.name | test("^(study|dev)\\.")) | "  \(.name)  \(.type)  → \(.content)  (proxied: \(.proxied))"'

echo ""
echo "=================================="
echo " ✅ DNS 配置完成"
echo "=================================="
echo ""
echo "下一步："
echo ""
echo " study.u-hermes.org （Vercel 部署）："
echo "   1. 打开 https://vercel.com/<your-team>/u-hermes-oss/settings/domains"
echo "   2. Add Domain → study.u-hermes.org"
echo "   3. 5-30 分钟后访问 https://study.u-hermes.org/ 验证"
echo ""
echo " dev.u-hermes.org （GitHub Pages 部署 hermes-agent-zh）："
echo "   1. 在 hermes-agent-zh/site/static/ 加 CNAME 文件，内容: dev.u-hermes.org"
echo "   2. 仓库 push 后 → Settings → Pages → Custom domain: dev.u-hermes.org"
echo "   3. 等待 SSL 证书颁发（最多 24h，通常 5-15 分钟）"
echo ""
echo " 验证："
echo "   dig +short study.u-hermes.org"
echo "   dig +short dev.u-hermes.org"
echo "   curl -I https://study.u-hermes.org/"
echo "   curl -I https://dev.u-hermes.org/"
