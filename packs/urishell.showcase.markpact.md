# UriPack Showcase: urishell

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `urishell/urishell/manifest.yaml` · repo `urishell`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: urishell-showcase
  version: '1'
  language: python
description: Subprocess shell commands on the automation host.
schemes:
- shell
capabilities:
- id: shell-run
  uri: shell://{command}
  kind: command
  operation: shell.run
  handler: python://urishell.handlers:shell_run
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
"""shell:// — subprocess on automation hosts."""

from __future__ import annotations

import os
import subprocess
from typing import Any


def _allow_real(context: dict[str, Any]) -> bool:
    return bool(context.get("allow_real") or os.environ.get("URISYS_ALLOW_REAL") == "1")


def _detect_display(context: dict[str, Any]) -> str | None:
    if context.get("display"):
        return str(context["display"])
    env = context.get("env_config") or {}
    display = env.get("display") or os.environ.get("DISPLAY")
    return str(display) if display else None


def _mock(command: str, payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    args = payload.get("args") or []
    return {
        "driver": "mock",
        "command": command,
        "args": args,
        "display": _detect_display(context),
        "ok": True,
    }


def shell_run(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    params = context.get("params") or {}
    command = str(params.get("command") or payload.get("command") or "")
    args = [str(a) for a in (payload.get("args") or [])]
    if not command:
        raise ValueError("shell command required")

    if context.get("dry_run") or not _allow_real(context):
        return _mock(command, payload, context)

    if command == "apt-get" and os.geteuid() != 0:
        args = [command, *args]
        command = "sudo"

    env = os.environ.copy()
    display = _detect_display(context)
    if display:
        env["DISPLAY"] = display
    xauth = context.get("xauthority")
    if xauth:
        env["XAUTHORITY"] = str(xauth)

    proc = subprocess.run(
        [command, *args],
        capture_output=True,
        text=True,
        env=env,
        timeout=float(payload.get("timeout_s") or 600),
    )
    return {
        "driver": "subprocess",
        "command": command,
        "args": args,
        "exit_code": proc.returncode,
        "stdout": (proc.stdout or "")[-4000:],
        "stderr": (proc.stderr or "")[-2000:],
        "ok": proc.returncode == 0,
    }
```

```yaml markpact:tests
tests:
- id: shell.run_command
  uri: shell://echo
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: shell.run
  payload: {}
```

```yaml markpact:flow id=shell-smoke
flow:
  id: shell-smoke
  description: Use case — smoke shell:// routes from urishell manifest.
defaults:
  approved: true
  dry_run: true
do:
- shell://echo: {}
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/urishell.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'shell://echo' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#shell-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e urishell`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``shell://`` (1 capability).
```

