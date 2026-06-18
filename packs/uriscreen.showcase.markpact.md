# UriPack Showcase: uriscreen

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `uriscreen/uriscreen/manifest.yaml` · repo `uriscreen`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uriscreen-showcase
  version: '1'
  language: python
description: Screen capture — frame query, single capture, capture loop.
schemes:
- screen
capabilities:
- id: screen-frame
  uri: screen://{target}/monitor/{monitor}/query/frame
  kind: query
  operation: screen.frame
  handler: python://uriscreen.handlers:frame
  side_effects: false
  approval: not_required
- id: screen-capture
  uri: screen://{target}/monitor/{monitor}/command/capture
  kind: command
  operation: screen.capture
  handler: python://uriscreen.handlers:capture
  side_effects: true
  approval: required
- id: screen-capture_loop
  uri: screen://{target}/capture/command/loop
  kind: command
  operation: screen.capture_loop
  handler: python://uriscreen.handlers:capture_loop
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

import base64
import io
import os
import time
from datetime import datetime
from pathlib import Path
from typing import Any


def _screen_cfg(context: dict[str, Any]) -> dict[str, Any]:
    return context.get("config", {}).get("screen", {})


def _backend(context: dict[str, Any], payload: dict[str, Any]) -> str:
    return payload.get("backend") or _screen_cfg(context).get("default_backend", "mss")


def _output_dir(payload: dict[str, Any], context: dict[str, Any]) -> Path:
    raw = payload.get("output") or _screen_cfg(context).get("output_dir", "/tmp/urisys-screens")
    path = Path(raw)
    path.mkdir(parents=True, exist_ok=True)
    return path


def _monitor_index(payload: dict[str, Any], context: dict[str, Any], monitor_param: str | None) -> int:
    if payload.get("monitor") is not None:
        return int(payload["monitor"])
    monitors = _screen_cfg(context).get("monitors") or {}
    if monitor_param == "primary":
        return int(monitors.get("primary", {}).get("index", 1))
    if monitor_param and monitor_param.isdigit():
        return int(monitor_param)
    return 1


def _store_latest(context: dict[str, Any], entry: dict[str, Any]) -> None:
    context.setdefault("state", {})["latest_screen"] = entry


def _mock_png(label: str) -> bytes:
    return base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
    )


def capture(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    from uriscreen.backends import capture_with_fallback, resolve_backend

    monitor = _monitor_index(payload, context, context.get("params", {}).get("monitor"))
    out_dir = _output_dir(payload, context)
    ts = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    path = out_dir / f"screen_{monitor}_{ts}.png"

    if context.get("dry_run"):
        path.write_bytes(_mock_png("mock"))
        entry = {"path": str(path), "monitor": monitor, "mime": "image/png", "backend": "mock", "dry_run": True}
        _store_latest(context, entry)
        return entry

    backend = resolve_backend(context, payload)
    if backend == "mock":
        path.write_bytes(_mock_png("mock"))
        entry = {"path": str(path), "monitor": monitor, "mime": "image/png", "backend": "mock"}
        _store_latest(context, entry)
        return entry

    if not (context.get("allow_real") or os.environ.get("URISYS_ALLOW_REAL") == "1"):
        raise PermissionError("screen capture requires allow_real=true or URISYS_ALLOW_REAL=1")

    entry = capture_with_fallback(path, monitor, context, payload)
    _store_latest(context, entry)
    return entry


def frame(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    entry = capture(payload, context)
    raw = Path(entry["path"]).read_bytes()
    entry["base64"] = base64.b64encode(raw).decode("ascii")
    return entry


def capture_loop(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    from uriscreen.backends import resolve_backend

    count = int(payload.get("count", 3))
    interval = float(payload.get("interval", 1.0))
    shots = []
    for i in range(count):
        shots.append(capture({**payload, "index": i}, context))
        if interval > 0 and i < count - 1:
            time.sleep(interval)
    return {"count": len(shots), "shots": shots, "backend": resolve_backend(context, payload)}
```

```yaml markpact:tests
tests:
- id: screen.frame_query
  uri: screen://local/monitor/primary/query/frame
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: screen.frame
- id: screen.capture_command
  uri: screen://local/monitor/primary/command/capture
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: screen.capture
  payload: {}
```

```yaml markpact:flow id=screen-smoke
flow:
  id: screen-smoke
  description: Use case — smoke screen:// routes from uriscreen manifest.
defaults:
  approved: true
  dry_run: true
do:
- screen://local/monitor/primary/query/frame
- screen://local/monitor/primary/command/capture: {}
- screen://local/capture/command/loop: {}
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/uriscreen.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'screen://local/monitor/primary/query/frame' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#screen-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e uriscreen`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``screen://`` (3 capability).
```

