# UriPack Showcase: uristt

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `uristt/uristt/manifest.yaml` · repo `uristt`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uristt-showcase
  version: '1'
  language: python
description: Speech-to-text pack (mock MVP; browser passthrough + audio transcribe).
schemes:
- stt
capabilities:
- id: stt-session-start
  uri: stt://local/session/{session}/command/start
  kind: command
  operation: stt.session.start
  handler: python://uristt.handlers:session_start
  side_effects: true
  approval: required
- id: stt-session-transcript
  uri: stt://local/session/{session}/query/transcript
  kind: query
  operation: stt.session.transcript
  handler: python://uristt.handlers:session_transcript
  side_effects: false
  approval: not_required
- id: stt-audio-transcribe
  uri: stt://local/audio/command/transcribe
  kind: command
  operation: stt.audio.transcribe
  handler: python://uristt.handlers:audio_transcribe
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
- id: stt.session.transcript_query
  uri: stt://local/session/default/query/transcript
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: stt.session.transcript
- id: stt.session.start_command
  uri: stt://local/session/default/command/start
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: stt.session.start
  payload: {}
```

```yaml markpact:flow id=stt-smoke
flow:
  id: stt-smoke
  description: Use case — smoke stt:// routes from uristt manifest.
defaults:
  approved: true
  dry_run: true
do:
- stt://local/session/default/command/start: {}
- stt://local/session/default/query/transcript
- stt://local/audio/command/transcribe: {}
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/uristt.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'stt://local/session/default/command/start' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#stt-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e uristt`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``stt://`` (3 capability).
```

