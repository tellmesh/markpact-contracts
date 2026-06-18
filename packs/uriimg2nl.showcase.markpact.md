# UriPack Showcase: uriimg2nl

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `uriimg2nl/uriimg2nl/manifest.yaml` · repo `uriimg2nl`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uriimg2nl-showcase
  version: '1'
  language: python
description: Screen capture + UI target detection via img2nl (KVM eyes).
schemes:
- img2nl
capabilities:
- id: img2nl-screen-capture_click
  uri: img2nl://{host}/screen/command/capture-click
  kind: command
  operation: img2nl.screen.capture_click
  handler: python://uriimg2nl.handlers:capture_click
  side_effects: true
  approval: required
- id: img2nl-image-click
  uri: img2nl://{host}/image/latest/command/click
  kind: command
  operation: img2nl.image.click
  handler: python://uriimg2nl.handlers:click_latest
  side_effects: true
  approval: required
- id: img2nl-image-targets
  uri: img2nl://{host}/image/latest/query/targets
  kind: query
  operation: img2nl.image.targets
  handler: python://uriimg2nl.handlers:targets_latest
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

import base64
import tempfile
from pathlib import Path
from typing import Any


def _real_allowed(context: dict[str, Any]) -> bool:
    return bool(context.get("allow_real")) and not context.get("dry_run")


def _require_img2nl() -> Any:
    try:
        from img2nl import api  # type: ignore[import-untyped]
    except ImportError as exc:
        raise RuntimeError(
            "img2nl not installed — pip install img2nl[analyze] uriimg2nl[real]"
        ) from exc
    return api


def _shot_path(context: dict[str, Any], payload: dict[str, Any]) -> str:
    explicit = payload.get("path") or payload.get("out")
    if explicit:
        return str(explicit)
    state = context.get("state", {})
    for key in ("latest_screen", "latest_screenshot"):
        shot = state.get(key) or {}
        file_path = shot.get("path")
        if file_path and Path(file_path).is_file():
            return str(file_path)
        b64 = shot.get("base64")
        mime = str(shot.get("mime") or "")
        if not b64 or mime.startswith("text/"):
            continue
        raw = base64.b64decode(b64)
        host = context.get("params", {}).get("host", "local")
        tmp = Path(tempfile.gettempdir()) / f"uriimg2nl-{host}.png"
        tmp.write_bytes(raw)
        return str(tmp)
    raise RuntimeError("no PNG screenshot — run screen:// or kvm:// (mss) screenshot first")


def capture_click(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    if not _real_allowed(context):
        return {
            "ok": True,
            "dry_run": True,
            "driver": "mock",
            "click_target": payload.get("click_target") or payload.get("label") or "button",
        }
    api = _require_img2nl()
    capture_fn = getattr(api, "capture_click_from_cmd", None) or api.capture_analyze_from_cmd
    cmd = {
        "out": payload.get("out") or payload.get("path") or "/tmp/uriimg2nl-capture.png",
        "monitor": int(payload.get("monitor", 1)),
        "backend": str(payload.get("backend", "auto")),
        "click_target": payload.get("click_target") or payload.get("target") or "button",
        "label": payload.get("label"),
        "text": payload.get("text"),
        "goal": payload.get("goal", "click"),
        "profile": payload.get("profile", "fast_ui"),
        "enable_ui_detect": True,
        "execute_click": bool(payload.get("execute_click", payload.get("execute", True))),
    }
    result = capture_fn(cmd)
    out = result.to_dict() if hasattr(result, "to_dict") else {"ok": result.ok, "error": result.error}
    return {"ok": bool(result.ok), "result": out, "driver": "img2nl"}


def click_latest(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    if not _real_allowed(context):
        return {"ok": True, "dry_run": True, "label": payload.get("label"), "text": payload.get("text")}
    api = _require_img2nl()
    path = _shot_path(context, payload)
    cmd = {
        "path": path,
        "click_target": payload.get("click_target") or payload.get("target") or "button",
        "label": payload.get("label"),
        "text": payload.get("text"),
        "execute_click": bool(payload.get("execute_click", payload.get("execute", True))),
        "goal": "click",
        "enable_ui_detect": True,
    }
    out = api.click_target_from_cmd(cmd)
    return {"ok": bool(out.get("ok")), "result": out, "driver": "img2nl", "path": path}


def targets_latest(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    if not _real_allowed(context):
        return {"ok": True, "dry_run": True, "targets": []}
    api = _require_img2nl()
    path = _shot_path(context, payload)
    out = api.targets_from_cmd({"path": path, "goal": payload.get("goal", "find"), "enable_ui_detect": True})
    return {"ok": out.get("ok", True) is not False, "result": out, "path": path}
```

```yaml markpact:tests
tests:
- id: img2nl.image.targets_query
  uri: img2nl://local/image/latest/query/targets
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: img2nl.image.targets
- id: img2nl.screen.capture_click_command
  uri: img2nl://local/screen/command/capture-click
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: img2nl.screen.capture_click
  payload: {}
```

```yaml markpact:flow id=img2nl-smoke
flow:
  id: img2nl-smoke
  description: Use case — smoke img2nl:// routes from uriimg2nl manifest.
defaults:
  approved: true
  dry_run: true
do:
- img2nl://local/screen/command/capture-click: {}
- img2nl://local/image/latest/command/click: {}
- img2nl://local/image/latest/query/targets
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/uriimg2nl.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'img2nl://local/screen/command/capture-click' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#img2nl-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e uriimg2nl`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``img2nl://`` (3 capability).
```

