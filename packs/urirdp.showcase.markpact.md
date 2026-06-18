# UriPack Showcase: urirdp

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `urirdp/urirdp/manifest.yaml` · repo `urirdp`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: urirdp-showcase
  version: '1'
  language: python
description: RDP session and X11 display queries for urirdp-docker.
schemes:
- rdp
capabilities:
- id: rdp-session-status
  uri: rdp://{host}/session/query/status
  kind: query
  operation: rdp.session.status
  handler: python://urirdp.handlers:status
  side_effects: false
  approval: not_required
- id: rdp-session-display
  uri: rdp://{host}/session/query/display
  kind: query
  operation: rdp.session.display
  handler: python://urirdp.handlers:display
  side_effects: false
  approval: not_required
- id: rdp-display-status
  uri: rdp://{host}/display/query/status
  kind: query
  operation: rdp.display.status
  handler: python://urirdp.handlers:display_status
  side_effects: false
  approval: not_required
- id: rdp-session-prepare_target
  uri: rdp://{host}/session/command/prepare-target
  kind: command
  operation: rdp.session.prepare_target
  handler: python://urirdp.handlers:prepare_target
  side_effects: true
  approval: required
- id: rdp-session-dismiss_target
  uri: rdp://{host}/session/command/dismiss-target
  kind: command
  operation: rdp.session.dismiss_target
  handler: python://urirdp.handlers:dismiss_target
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

import os
import subprocess
import time
from pathlib import Path
from typing import Any

from urirdp.display import allow_real, base_env, detect_display, run_cmd


def _service_status(name: str) -> dict[str, Any]:
    try:
        res = subprocess.run(['pgrep', '-a', name], text=True, capture_output=True, check=False)
        return {'running': res.returncode == 0, 'processes': [x for x in res.stdout.splitlines() if x.strip()]}
    except Exception as exc:
        return {'running': False, 'error': str(exc)}


def status(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    return {
        'host': context.get('params', {}).get('host'),
        'xrdp': _service_status('xrdp'),
        'xrdp_sesman': _service_status('xrdp-sesman'),
        'display': detect_display(context),
        'rdp_port': int(os.environ.get('RDP_PORT', '3389')),
        'uri_port': int(os.environ.get('URISYS_RDP_PORT', '8795')),
        'hint': 'Connect with an RDP client, then run kvm://... calls against the active X session.',
    }


def display(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    display_name = detect_display(context)
    res = run_cmd(['xdpyinfo'], {**context, 'display': display_name}, timeout=5)
    return {
        'display': display_name,
        'available': res.returncode == 0,
        'xdpyinfo_first_lines': res.stdout.splitlines()[:8],
        'error': res.stderr.strip() if res.returncode != 0 else None,
    }


def display_status(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    display_name = detect_display(context)
    socket_path = Path('/tmp/.X11-unix') / f"X{display_name.lstrip(':')}"
    display_exists = socket_path.exists()
    xdpyinfo_ok = False
    if display_exists:
        xdpyinfo_ok = run_cmd(['xdpyinfo'], context, timeout=5).returncode == 0

    screenshot_ok = False
    if allow_real(context) and xdpyinfo_ok:
        probe = Path('/tmp/urirdp-probe.png')
        shot = run_cmd(['scrot', str(probe)], context, timeout=10)
        screenshot_ok = shot.returncode == 0 and probe.exists() and probe.stat().st_size >= 128
        probe.unlink(missing_ok=True)

    return {
        'display': display_name,
        'display_exists': display_exists,
        'xdpyinfo_ok': xdpyinfo_ok,
        'screenshot_ok': screenshot_ok,
        'ready': display_exists and xdpyinfo_ok,
    }


def _dismiss_stale_targets(context: dict[str, Any]) -> int:
    """Close bootstrap or stale zenity dialogs blocking the RDP desktop."""
    if context.get('dry_run') or not allow_real(context):
        return 0
    closed = 0
    for title in ('Automation Target', 'TellMesh Demo'):
        res = run_cmd(['xdotool', 'search', '--name', title], context, timeout=5)
        for wid in res.stdout.splitlines():
            wid = wid.strip()
            if not wid:
                continue
            run_cmd(['xdotool', 'windowclose', wid], context, timeout=3)
            closed += 1
    if closed == 0:
        res = run_cmd(['xdotool', 'search', '--class', 'Zenity'], context, timeout=5)
        for wid in res.stdout.splitlines()[:4]:
            wid = wid.strip()
            if not wid:
                continue
            run_cmd(['xdotool', 'windowclose', wid], context, timeout=3)
            closed += 1
    if closed:
        time.sleep(0.5)
    return closed


def dismiss_target(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    display_name = detect_display(context)
    if context.get('dry_run') or not allow_real(context):
        return {'dismissed': True, 'driver': 'mock', 'display': display_name, 'closed': 0}
    closed = _dismiss_stale_targets(context)
    return {'dismissed': True, 'display': display_name, 'closed': closed}


def prepare_target(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    display_name = detect_display(context)
    kind = str(payload.get('kind') or 'info')
    text = str(payload.get('text') or 'OK')
    if context.get('dry_run') or not allow_real(context):
        return {'prepared': True, 'driver': 'mock', 'display': display_name, 'text': text, 'kind': kind}

    _dismiss_stale_targets(context)
    env = base_env(context)
    if kind == 'form':
        subprocess.Popen(
            [
                'zenity', '--forms',
                '--title=TellMesh Demo',
                '--text=Fill the form',
                '--add-entry=Name',
                '--ok-label=Submit',
                '--width=420',
                '--height=220',
            ],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(2.0)
        run_cmd(['xdotool', 'search', '--name', 'TellMesh Demo', 'windowactivate'], context, timeout=5)
        return {'prepared': True, 'display': display_name, 'kind': 'form', 'driver': 'zenity-forms'}

    subprocess.Popen(
        [
            'zenity', '--info',
            '--title=Automation Target',
            f'--text={text}',
            '--no-wrap',
            '--width=320',
            '--height=120',
        ],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(1.5)
    run_cmd(['xdotool', 'search', '--name', 'Automation Target', 'windowactivate'], context, timeout=5)
    return {'prepared': True, 'display': display_name, 'text': text, 'driver': 'zenity', 'kind': kind}
```

```yaml markpact:tests
tests:
- id: rdp.session.status_query
  uri: rdp://local/session/query/status
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: rdp.session.status
- id: rdp.session.prepare_target_command
  uri: rdp://local/session/command/prepare-target
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: rdp.session.prepare_target
  payload: {}
```

```yaml markpact:flow id=rdp-smoke
flow:
  id: rdp-smoke
  description: Use case — smoke rdp:// routes from urirdp manifest.
defaults:
  approved: true
  dry_run: true
do:
- rdp://local/session/query/status
- rdp://local/session/query/display
- rdp://local/display/query/status
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/urirdp.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'rdp://local/session/query/status' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#rdp-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e urirdp`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``rdp://`` (5 capability).
```

