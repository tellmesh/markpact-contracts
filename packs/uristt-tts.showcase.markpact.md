# UriPack Showcase: uristt-tts

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `uristt/uristt/manifest.tts.yaml` · repo `uristt`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uristt-tts-showcase
  version: '1'
  language: python
description: Text-to-speech pack (mock MVP).
schemes:
- tts
capabilities:
- id: tts-session-speak
  uri: tts://local/session/{session}/command/speak
  kind: command
  operation: tts.session.speak
  handler: python://uristt.handlers:tts_speak
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

_SESSIONS: dict[str, dict[str, Any]] = {}


def _session_id(context: dict[str, Any]) -> str:
    return (context.get("params") or {}).get("session", "main")


def session_start(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    sid = _session_id(context)
    entry = {
        "session": sid,
        "language": payload.get("language", "pl-PL"),
        "mode": payload.get("mode", "browser"),
        "status": "listening",
        "transcript": "",
    }
    _SESSIONS[sid] = entry
    return {"ok": True, "session": entry}


def session_transcript(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    sid = _session_id(context)
    session = _SESSIONS.setdefault(
        sid,
        {"session": sid, "language": "pl-PL", "mode": "browser", "status": "idle", "transcript": ""},
    )
    if payload.get("text"):
        session["transcript"] = str(payload["text"])
    if not session["transcript"]:
        session["transcript"] = payload.get("default_text") or "kliknij OK"
    return {
        "ok": True,
        "session": sid,
        "text": session["transcript"],
        "transcript": session["transcript"],
        "language": session.get("language", "pl-PL"),
        "engine": "mock-browser" if session.get("mode") == "browser" else "mock-local",
    }


def tts_speak(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    del context
    text = str(payload.get("text") or payload.get("transcript") or "").strip()
    if not text:
        return {"ok": False, "error": "missing text"}
    return {
        "ok": True,
        "text": text,
        "spoken": True,
        "engine": payload.get("engine", "mock"),
        "audio_url": None,
    }


def audio_transcribe(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    del context
    text = payload.get("text") or payload.get("transcript")
    if not text and payload.get("audio_b64"):
        text = "kliknij OK"
    if not text:
        text = "kliknij OK"
    return {
        "ok": True,
        "transcript": text,
        "language": payload.get("language", "pl-PL"),
        "engine": payload.get("engine", "mock"),
        "audio_received": bool(payload.get("audio_b64")),
    }
```

```yaml markpact:tests
tests:
- id: tts.session.speak_command
  uri: tts://local/session/default/command/speak
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: tts.session.speak
  payload: {}
```

```yaml markpact:flow id=tts-smoke
flow:
  id: tts-smoke
  description: Use case — smoke tts:// routes from uristt-tts manifest.
defaults:
  approved: true
  dry_run: true
do:
- tts://local/session/default/command/speak: {}
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/uristt-tts.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'tts://local/session/default/command/speak' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#tts-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e uristt`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``tts://`` (1 capability).
```

