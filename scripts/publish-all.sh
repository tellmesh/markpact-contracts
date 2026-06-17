#!/usr/bin/env bash
# Publish all packs in markpact-contracts/packs/ to markpact.com portal.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="${MARKPACT_CLIENT:-}"
PORTAL_WRAPPER=""
if [ -z "$CLIENT" ]; then
  if command -v markpact >/dev/null 2>&1; then
    PORTAL_WRAPPER=markpact
  elif [ -f "$ROOT/../../markpact/markpact.com/httpdocs/public/client/markpact.py" ]; then
    CLIENT="$ROOT/../../markpact/markpact.com/httpdocs/public/client/markpact.py"
  else
    echo "Install markpact (pip) or set MARKPACT_CLIENT" >&2
    exit 1
  fi
fi
HOST="${MARKPACT_HOST:-https://markpact.com}"
TOKEN="${MARKPACT_TOKEN:-${MARKPACT_API_TOKEN:-}}"

if [ -z "$TOKEN" ]; then
  echo "Set MARKPACT_TOKEN or MARKPACT_API_TOKEN" >&2
  exit 1
fi

portal() {
  if [ -n "$PORTAL_WRAPPER" ]; then
    MARKPACT_HOST="$HOST" MARKPACT_TOKEN="$TOKEN" markpact portal "$@"
  else
    MARKPACT_HOST="$HOST" MARKPACT_TOKEN="$TOKEN" python3 "$CLIENT" "$@"
  fi
}

portal init --host "$HOST" --token "$TOKEN" >/dev/null

ok=0
fail=0
mkdir -p "$ROOT/generated"
for p in "$ROOT/packs"/*.markpact.md; do
  [ -f "$p" ] || continue
  name="$(basename "$p" .markpact.md)"
  echo "== publish $name =="
  if portal publish "$p" --name "$name" 2>&1 | tee "$ROOT/generated/last-publish-${name}.json"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
  fi
done
echo "PUBLISH SUMMARY ok=$ok fail=$fail"
