# UriPack Showcase: urivql

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `urivql/urivql/manifest.yaml` · repo `urivql`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: urivql-showcase
  version: '1'
  language: python
description: Visual query language — UI detect/compare for urisys-node.
schemes:
- vql
capabilities:
- id: vql-ui-detect
  uri: vql://{host}/ui/latest/query/detect
  kind: query
  operation: vql.ui.detect
  handler: python://urivql.handlers:ui_detect
  side_effects: false
  approval: not_required
- id: vql-ui-compare
  uri: vql://{host}/ui/latest/query/compare
  kind: query
  operation: vql.ui.compare
  handler: python://urivql.handlers:ui_compare
  side_effects: false
  approval: not_required
policy:
  default: deny_mutations_without_approval
runtime:
  default_environment: real
  supports:
  - mock
  - local
  - docker
```

```python markpact:source path=handlers.py
from __future__ import annotations

from typing import Any


def ui_detect(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    target = str(payload.get("target") or payload.get("text") or payload.get("selector") or "")
    boxes = (context.get("state", {}).get("latest_ocr") or {}).get("boxes") or payload.get("boxes") or []
    matches = []
    for box in boxes:
        text = str(box.get("text") or "")
        if not target or target.lower() in text.lower():
            matches.append(box)
    return {
        "target": target,
        "matches": matches[:20],
        "count": len(matches),
        "source": "urivql-mock",
    }


def ui_compare(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    before = payload.get("before") or context.get("state", {}).get("screen_before")
    after = payload.get("after") or context.get("state", {}).get("screen_after")
    expect = payload.get("expect") or {}
    changed = before != after if before is not None and after is not None else bool(expect.get("changed", True))
    ok = changed if expect.get("changed") is None else (changed == bool(expect.get("changed")))
    return {
        "ok": ok,
        "changed": changed,
        "expect": expect,
        "source": "urivql-mock",
    }
```

```yaml markpact:tests
tests:
- id: vql.ui.detect_query
  uri: vql://local/ui/latest/query/detect
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: vql.ui.detect
```

```yaml markpact:flow id=vql-smoke
flow:
  id: vql-smoke
  description: Use case — smoke vql:// routes from urivql manifest.
defaults:
  approved: true
  dry_run: true
do:
- vql://local/ui/latest/query/detect
- vql://local/ui/latest/query/compare
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/urivql.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'vql://local/ui/latest/query/detect' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#vql-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e urivql`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``vql://`` (2 capability).
```

