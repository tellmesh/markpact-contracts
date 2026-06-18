# UriPack Showcase: uriwebrtc

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `uriwebrtc/uriwebrtc/manifest.yaml` · repo `uriwebrtc`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uriwebrtc-showcase
  version: '1'
  language: python
description: WebRTC session mock — HTTP signaling relay and DataChannel URI envelopes.
schemes:
- webrtc
capabilities:
- id: webrtc-session-start
  uri: webrtc://local/session/{session}/command/start
  kind: command
  operation: webrtc.session.start
  handler: python://uriwebrtc.handlers:session_start
  side_effects: true
  approval: required
- id: webrtc-data-send
  uri: webrtc://local/session/{session}/data/command/send
  kind: command
  operation: webrtc.data.send
  handler: python://uriwebrtc.handlers:data_send
  side_effects: true
  approval: required
- id: webrtc-signal-post
  uri: webrtc://local/session/{session}/signal/command/post
  kind: command
  operation: webrtc.signal.post
  handler: python://uriwebrtc.handlers:signal_post
  side_effects: true
  approval: required
- id: webrtc-signal-inbox
  uri: webrtc://local/session/{session}/signal/query/inbox
  kind: query
  operation: webrtc.signal.inbox
  handler: python://uriwebrtc.handlers:signal_inbox
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

import time
from typing import Any

_ROOMS: dict[str, dict[str, Any]] = {}
_SIGNALS: dict[str, list[dict[str, Any]]] = {}
_MAX_SIGNALS = 500


def _room_id(context: dict[str, Any]) -> str:
    params = context.get("params") or {}
    return params.get("session") or params.get("room") or "rdp-chat"


def session_start(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    room = payload.get("room") or _room_id(context)
    entry = {
        "room": room,
        "status": "ready",
        "signaling": "http-relay",
        "data_channel": "uri-envelope",
    }
    _ROOMS[room] = entry
    return {"ok": True, "webrtc": entry, "note": "Session ready; use signal/post + signal/inbox for SDP/ICE relay."}


def data_send(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    room = payload.get("room") or _room_id(context)
    envelope = payload.get("envelope") or {}
    _ROOMS.setdefault(room, {"room": room, "status": "ready"})
    return {
        "ok": True,
        "room": room,
        "envelope": envelope,
        "received": True,
        "hint": "Forward envelope to chat://local/uri/command/execute for execution.",
    }


def signal_post(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    room = payload.get("room") or _room_id(context)
    from_peer = str(payload.get("from") or "").strip()
    signal_type = str(payload.get("type") or "").strip().lower()
    data = payload.get("data")
    if not room or not from_peer or signal_type not in {"offer", "answer", "ice"}:
        return {"ok": False, "error": "room, from, type (offer|answer|ice) required"}
    inbox = _SIGNALS.setdefault(room, [])
    sig_id = len(inbox) + 1
    row = {
        "id": sig_id,
        "room": room,
        "from": from_peer,
        "type": signal_type,
        "data": data,
        "at": time.time(),
    }
    inbox.append(row)
    if len(inbox) > _MAX_SIGNALS:
        _SIGNALS[room] = inbox[-_MAX_SIGNALS:]
    _ROOMS.setdefault(room, {"room": room, "status": "signaling"})
    return {"ok": True, "id": sig_id, "room": room}


def signal_inbox(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    room = payload.get("room") or _room_id(context)
    since = max(0, int(payload.get("since") or 0))
    if not room:
        return {"ok": False, "error": "room required"}
    inbox = _SIGNALS.get(room, [])
    pending = [s for s in inbox if int(s.get("id") or 0) > since]
    next_id = int(inbox[-1]["id"]) if inbox else since
    return {"ok": True, "room": room, "signals": pending, "since": since, "next": next_id}
```

```yaml markpact:tests
tests:
- id: webrtc.signal.inbox_query
  uri: webrtc://local/session/default/signal/query/inbox
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: webrtc.signal.inbox
- id: webrtc.session.start_command
  uri: webrtc://local/session/default/command/start
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: webrtc.session.start
  payload: {}
```

```yaml markpact:flow id=webrtc-smoke
flow:
  id: webrtc-smoke
  description: Use case — smoke webrtc:// routes from uriwebrtc manifest.
defaults:
  approved: true
  dry_run: true
do:
- webrtc://local/session/default/command/start: {}
- webrtc://local/session/default/data/command/send: {}
- webrtc://local/session/default/signal/command/post: {}
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/uriwebrtc.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'webrtc://local/session/default/command/start' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#webrtc-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e uriwebrtc`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``webrtc://`` (4 capability).
```

