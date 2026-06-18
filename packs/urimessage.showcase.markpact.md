# UriPack Showcase: urimessage

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `urimessage/urimessage/manifest.yaml` · repo `urimessage`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: urimessage-showcase
  version: '1'
  language: python
description: Simple alert/message dispatch mock for lab and node.
schemes:
- message
capabilities:
- id: message-alert-send
  uri: message://local/alert/command/send
  kind: command
  operation: message.alert.send
  handler: python://urimessage.handlers:alert_send
  side_effects: true
  approval: required
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


def alert_send(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    text = str(payload.get("text") or "")
    channel = str(payload.get("channel") or "alert")
    severity = str(payload.get("severity") or "info")
    return {
        "ok": True,
        "text": text,
        "channel": channel,
        "severity": severity,
        "delivered": bool(text),
        "echo": True,
    }
```

```yaml markpact:tests
tests:
- id: message.alert.send_command
  uri: message://local/alert/command/send
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: message.alert.send
  payload: {}
```

```yaml markpact:flow id=message-smoke
flow:
  id: message-smoke
  description: Use case — smoke message:// routes from urimessage manifest.
defaults:
  approved: true
  dry_run: true
do:
- message://local/alert/command/send: {}
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/urimessage.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'message://local/alert/command/send' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#message-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e urimessage`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``message://`` (1 capability).
```

