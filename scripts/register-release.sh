#!/usr/bin/env bash
# Register materialized release on markpact.com (GitHub artifact-index URL).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${MARKPACT_HOST:-https://markpact.com}"
TOKEN="${MARKPACT_TOKEN:-${MARKPACT_API_TOKEN:-}}"
CONTRACT_ID="${1:-uristepper-pack}"
VERSION="${2:-0.1.0}"
GITHUB_OWNER="${GITHUB_OWNER:-tellmesh}"
GITHUB_REPO="${GITHUB_REPO:-urisys}"
GIT_REF="${GIT_REF:-main}"
# For tagged releases use: GIT_REF=v0.1.0 bash scripts/register-release.sh

if [ -z "$TOKEN" ] && [ -f "$HOME/.markpact/config.json" ]; then
  TOKEN="$(python3 -c "import json; print(json.load(open('$HOME/.markpact/config.json')).get('token',''))" 2>/dev/null || true)"
fi

if [ -z "$TOKEN" ]; then
  echo "Set MARKPACT_TOKEN" >&2
  exit 1
fi

INDEX_URL="${ARTIFACT_INDEX_URL:-https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/${GIT_REF}/releases/${CONTRACT_ID}/${VERSION}/artifact-index.json}"
ARTIFACTS_FILE="$(mktemp)"
curl -fsSL "$INDEX_URL" -o "$ARTIFACTS_FILE"
CLIENT="${MARKPACT_CLIENT:-$ROOT/../../markpact/markpact.com/httpdocs/public/client/markpact.py}"

register_args=(
  release register
  --contract-id "$CONTRACT_ID"
  --version "$VERSION"
  --artifact-index-url "$INDEX_URL"
  --artifacts-file "$ARTIFACTS_FILE"
)

if [ -f "$CLIENT" ]; then
  MARKPACT_HOST="$HOST" MARKPACT_TOKEN="$TOKEN" python3 "$CLIENT" "${register_args[@]}"
elif command -v markpact >/dev/null 2>&1 && markpact portal --help >/dev/null 2>&1; then
  MARKPACT_HOST="$HOST" MARKPACT_TOKEN="$TOKEN" markpact portal "${register_args[@]}"
else
  echo "Set MARKPACT_CLIENT or install markpact (pip)" >&2
  exit 1
fi
