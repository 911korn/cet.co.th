#!/usr/bin/env bash
# Add Vercel DNS records to the cet.co.th zone in Cloudflare.
#
# Usage:
#   CLOUDFLARE_API_TOKEN=cfat_xxx ./scripts/cf-dns-setup.sh
#
# The token needs the following permissions on the cet.co.th zone:
#   Zone   - DNS         - Edit
#   Zone   - Zone        - Read

set -euo pipefail

ZONE_NAME="cet.co.th"
ROOT_TARGET="76.76.21.21"            # Vercel anycast IPv4
WWW_TARGET="cname.vercel-dns.com"    # Vercel CNAME

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "ERROR: CLOUDFLARE_API_TOKEN env var is required" >&2
  exit 1
fi

api() {
  curl -sS \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

echo "→ Verifying token..."
api https://api.cloudflare.com/client/v4/user/tokens/verify \
  | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('success'), d; print('  ok, status:', d['result']['status'])"

echo "→ Looking up zone id for ${ZONE_NAME}..."
ZONE_ID=$(api "https://api.cloudflare.com/client/v4/zones?name=${ZONE_NAME}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('success'), d; r=d['result']; assert r, 'zone not found'; print(r[0]['id'])")
echo "  zone_id=${ZONE_ID}"

upsert_record() {
  local TYPE="$1" NAME="$2" CONTENT="$3"
  echo "→ Upserting ${TYPE} ${NAME} → ${CONTENT}"
  local EXISTING_ID
  EXISTING_ID=$(api "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=${TYPE}&name=${NAME}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('result') or []; print(r[0]['id'] if r else '')")
  local PAYLOAD
  PAYLOAD=$(python3 -c "import json; print(json.dumps({'type':'${TYPE}','name':'${NAME}','content':'${CONTENT}','ttl':1,'proxied':False}))")
  if [ -n "${EXISTING_ID}" ]; then
    api -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${EXISTING_ID}" -d "${PAYLOAD}" \
      | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('success'), d; print('  updated:', d['result']['name'], '→', d['result']['content'], '| proxied:', d['result']['proxied'])"
  else
    api -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" -d "${PAYLOAD}" \
      | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('success'), d; print('  created:', d['result']['name'], '→', d['result']['content'], '| proxied:', d['result']['proxied'])"
  fi
}

upsert_record "A"     "${ZONE_NAME}"        "${ROOT_TARGET}"
upsert_record "CNAME" "www.${ZONE_NAME}"    "${WWW_TARGET}"

echo ""
echo "→ Setting SSL/TLS mode to 'full' (Vercel issues its own valid cert)"
api -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/ssl" \
  -d '{"value":"full"}' \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('  ssl mode:', d.get('result',{}).get('value'))" || true

echo ""
echo "✓ Done. DNS records configured."
echo "  Verify with:"
echo "    dig +short A     cet.co.th     @1.1.1.1"
echo "    dig +short CNAME www.cet.co.th @1.1.1.1"
