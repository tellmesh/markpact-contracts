#!/usr/bin/env bash
# Validate all extracted Markpact packs with urisys.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/../urisys"
mapfile -t PACKS < <(find "$ROOT/packs" -name '*.markpact.md' | sort)
pass=0
fail=0
for p in "${PACKS[@]}"; do
  if urisys markpact validate "$p" >/dev/null 2>&1; then
    echo "PASS $p"
    pass=$((pass + 1))
  else
    echo "FAIL $p"
    fail=$((fail + 1))
  fi
done
echo "SUMMARY pass=$pass fail=$fail total=${#PACKS[@]}"
[ "$fail" -eq 0 ]
