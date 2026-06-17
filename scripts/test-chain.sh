#!/usr/bin/env bash
# Smoke-test the full markpact.com + GitHub raw + urisys-node chain.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="${MARKPACT_CATALOG:-https://markpact.com}"
CONTRACT="${1:-uristepper-pack}"
VERSION="${2:-0.1.0}"

echo "== validate local packs =="
bash "$ROOT/scripts/validate-all.sh"

echo "== markpact.com health =="
curl -fsS "$CATALOG/api/health" | python3 -m json.tool | head -6

echo "== catalog release =="
curl -fsS "$CATALOG/api/contracts/$CONTRACT/releases/$VERSION" | python3 -m json.tool | head -25

echo "== artifact-index redirect =="
INDEX_URL="$(curl -fsSI "$CATALOG/api/contracts/$CONTRACT/releases/$VERSION/artifact-index.json" | awk -F': ' '/^location:/ {print $2}' | tr -d '\r')"
echo "redirect -> $INDEX_URL"
curl -fsS "$INDEX_URL" | python3 -c "import json,sys; d=json.load(sys.stdin); print('schema', d.get('schema')); print('ref', d['artifacts'][0]['ref'][:80])"

echo "== urisys-node fetch-release =="
cd "$ROOT/../urisys-node"
pip install -e . -q
urisys-node artifact fetch-release --catalog "$CATALOG" --contract "$CONTRACT" --version "$VERSION"

echo "CHAIN OK"
