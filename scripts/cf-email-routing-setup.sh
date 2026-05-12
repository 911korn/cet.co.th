#!/usr/bin/env bash
# Set up Cloudflare Email Routing for cet.co.th.
#
# - Enables Email Routing for the zone (auto-adds MX/SPF/TXT records).
# - Adds a destination address (will trigger a verification email).
# - Adds a forwarding rule from ceo@cet.co.th to that destination.
#
# Usage:
#   CLOUDFLARE_API_TOKEN=cfut_xxx \
#   DESTINATION_EMAIL=you@gmail.com \
#   SOURCE_EMAIL=ceo@cet.co.th \
#     ./scripts/cf-email-routing-setup.sh
#
# Required token permissions:
#   Account - Email Routing Addresses - Edit
#   Zone    - Email Routing Rules     - Edit
#   Zone    - DNS                     - Edit (for MX/SPF/TXT fallback)
#   Zone    - Zone                    - Read

set -euo pipefail

ZONE_NAME="${ZONE_NAME:-cet.co.th}"
SOURCE_EMAIL="${SOURCE_EMAIL:-ceo@cet.co.th}"
DESTINATION_EMAIL="${DESTINATION_EMAIL:?DESTINATION_EMAIL is required}"

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"

api() {
  curl -sS \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

echo "→ Looking up zone id for ${ZONE_NAME}..."
# Allow pre-set IDs to bypass requirement of zone:list permission on token.
if [ -z "${ZONE_ID:-}" ] || [ -z "${ACCOUNT_ID:-}" ]; then
  ZONE_JSON=$(api "https://api.cloudflare.com/client/v4/zones?name=${ZONE_NAME}")
  ZONE_ID=$(echo "$ZONE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('result') or []; print(r[0]['id'] if r else '')")
  ACCOUNT_ID=$(echo "$ZONE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('result') or []; print(r[0]['account']['id'] if r else '')")
fi
if [ -z "$ZONE_ID" ] || [ -z "$ACCOUNT_ID" ]; then
  echo "ERROR: could not resolve ZONE_ID/ACCOUNT_ID. Pass them explicitly:" >&2
  echo "  ZONE_ID=... ACCOUNT_ID=... $0" >&2
  exit 1
fi
echo "  zone_id=$ZONE_ID  account_id=$ACCOUNT_ID"

echo ""
echo "→ Ensuring MX / SPF / TXT records (idempotent) ..."
upsert_dns() {
  local TYPE="$1" NAME="$2" CONTENT="$3" PRIO="${4:-}"
  # Only match an existing record with the SAME content (so multiple MX records can coexist).
  local EXISTING_ID
  EXISTING_ID=$(api "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=${TYPE}&name=${NAME}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('result') or []; ok=[x for x in r if x.get('content')=='${CONTENT}']; print(ok[0]['id'] if ok else '')")
  local PAYLOAD
  if [ -n "$PRIO" ]; then
    PAYLOAD=$(python3 -c "import json; print(json.dumps({'type':'${TYPE}','name':'${NAME}','content':'${CONTENT}','priority':int('${PRIO}'),'ttl':1,'proxied':False}))")
  else
    PAYLOAD=$(python3 -c "import json; print(json.dumps({'type':'${TYPE}','name':'${NAME}','content':'${CONTENT}','ttl':1,'proxied':False}))")
  fi
  if [ -n "$EXISTING_ID" ]; then
    api -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${EXISTING_ID}" -d "$PAYLOAD" \
      | python3 -c "import json,sys; d=json.load(sys.stdin);
r=d.get('result') or {}; print('  upd ${TYPE} ${NAME}: ', r.get('content'))"
  else
    api -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" -d "$PAYLOAD" \
      | python3 -c "import json,sys; d=json.load(sys.stdin);
r=d.get('result') or {}; print('  add ${TYPE} ${NAME}: ', r.get('content'))"
  fi
}

# CF Email Routing recommended records
upsert_dns "MX"  "${ZONE_NAME}" "route1.mx.cloudflare.net" 17
upsert_dns "MX"  "${ZONE_NAME}" "route2.mx.cloudflare.net" 86
upsert_dns "MX"  "${ZONE_NAME}" "route3.mx.cloudflare.net" 14
upsert_dns "TXT" "${ZONE_NAME}" "v=spf1 include:_spf.mx.cloudflare.net ~all"

echo ""
echo "→ Adding destination address ${DESTINATION_EMAIL} (this triggers a verification email)..."
DEST_RESP=$(api -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/email/routing/addresses" \
  -d "$(python3 -c "import json,sys; print(json.dumps({'email':'${DESTINATION_EMAIL}'}))")")
echo "$DEST_RESP" | python3 -c "
import json,sys
d = json.load(sys.stdin)
if d.get('success'):
    r = d.get('result') or {}
    print('  added:', r.get('email'), '| verified:', r.get('verified'))
else:
    errs = d.get('errors') or []
    codes = [str(e.get('code')) for e in errs]
    msgs = [e.get('message','') for e in errs]
    if 'already exists' in ' '.join(msgs).lower() or '1007' in codes:
        print('  already present; OK')
    else:
        print('  WARN:', errs)
"

echo ""
echo "→ Creating routing rule: ${SOURCE_EMAIL} → ${DESTINATION_EMAIL}"
RULE_PAYLOAD=$(python3 -c "
import json
print(json.dumps({
  'name': 'Forward ${SOURCE_EMAIL} to ${DESTINATION_EMAIL}',
  'enabled': True,
  'priority': 0,
  'matchers': [{'type': 'literal', 'field': 'to', 'value': '${SOURCE_EMAIL}'}],
  'actions':  [{'type': 'forward', 'value': ['${DESTINATION_EMAIL}']}]
}))")

# Check if a rule for this source already exists; update or create.
EXISTING_RULE_ID=$(api "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/email/routing/rules?per_page=50" \
  | python3 -c "
import json,sys
d=json.load(sys.stdin); r=d.get('result') or []
for x in r:
    for m in x.get('matchers') or []:
        if m.get('type')=='literal' and m.get('field')=='to' and m.get('value')=='${SOURCE_EMAIL}':
            print(x.get('id')); break
")

if [ -n "$EXISTING_RULE_ID" ]; then
  api -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/email/routing/rules/${EXISTING_RULE_ID}" -d "$RULE_PAYLOAD" \
    | python3 -c "
import json,sys
d = json.load(sys.stdin)
if d.get('success'):
    r = d.get('result') or {}
    print('  updated rule:', r.get('id'), '| enabled:', r.get('enabled'))
else:
    print('  ERROR:', d.get('errors')); sys.exit(1)
"
else
  api -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/email/routing/rules" -d "$RULE_PAYLOAD" \
    | python3 -c "
import json,sys
d = json.load(sys.stdin)
if d.get('success'):
    r = d.get('result') or {}
    print('  created rule:', r.get('id'), '| enabled:', r.get('enabled'))
else:
    print('  ERROR:', d.get('errors')); sys.exit(1)
"
fi

echo ""
echo "✓ Done. Final steps for you:"
echo "  1. Check ${DESTINATION_EMAIL} inbox for a Cloudflare verification email"
echo "     (subject: 'Verify your email address for Cloudflare Email Routing')."
echo "  2. Click the verification link in that email."
echo "  3. After verification, ${SOURCE_EMAIL} will automatically forward to ${DESTINATION_EMAIL}."
