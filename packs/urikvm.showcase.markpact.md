# UriPack Showcase: urikvm

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `urikvm/urikvm/manifest.yaml` · repo `urikvm`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: urikvm-showcase
  version: '1'
  language: python
description: KVM monitor capture and OCR/LLM-assisted desktop tasks.
schemes:
- kvm
capabilities:
- id: kvm-monitor-list
  uri: kvm://{host}/monitor/query/list
  kind: query
  operation: kvm.monitor.list
  handler: python://urikvm.handlers:monitor_list
  side_effects: false
  approval: not_required
- id: kvm-display-info
  uri: kvm://{host}/display/query/info
  kind: query
  operation: kvm.display.info
  handler: python://urikvm.handlers:display_info
  side_effects: false
  approval: not_required
- id: kvm-monitor-screenshot
  uri: kvm://{host}/monitor/{monitor}/query/screenshot
  kind: query
  operation: kvm.monitor.screenshot
  handler: python://urikvm.handlers:screenshot
  side_effects: false
  approval: not_required
- id: kvm-task-click_text
  uri: kvm://{host}/task/command/click-text
  kind: command
  operation: kvm.task.click_text
  handler: python://urikvm.handlers:click_text
  side_effects: true
  approval: required
- id: kvm-task-type_text
  uri: kvm://{host}/task/command/type-text
  kind: command
  operation: kvm.task.type_text
  handler: python://urikvm.handlers:type_text
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
import base64
import io
import shutil
import time
from pathlib import Path
from typing import Any

from .display import allow_real, detect_display, ensure_screenshot_dir, run_cmd


def _profile(context):
    cfg = context.get('config', {}) or {}
    return cfg.get('kvm') or cfg


def display_info(payload, context):
    display = detect_display(context)
    res = run_cmd(['xdpyinfo'], {**context, 'display': display}, timeout=5)
    screen_line = None
    for line in res.stdout.splitlines():
        if 'dimensions:' in line:
            screen_line = line.strip()
            break
    return {
        'display': display,
        'available': res.returncode == 0,
        'dimensions': screen_line,
        'error': res.stderr.strip() if res.returncode != 0 else None,
    }


def _tiny_png() -> bytes:
    return bytes.fromhex(
        '89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489'
        '0000000a49444154789c636000000200015d0b2a0000000049454e44ae426082'
    )


def _store_screenshot(context, monitor, driver, mime, raw_bytes, width=None, height=None):
    entry = {
        'monitor': monitor,
        'driver': driver,
        'mime': mime,
        'base64': base64.b64encode(raw_bytes).decode('ascii'),
        'width': width,
        'height': height,
        'captured_at': time.time(),
    }
    context.setdefault('state', {})['latest_screenshot'] = entry
    return entry


def monitor_list(payload, context):
    monitors = _profile(context).get('monitors') or [{'id': 'primary', 'width': 1280, 'height': 720}]
    return {'monitors': monitors, 'driver': _profile(context).get('driver', 'mock')}


def screenshot(payload, context):
    monitor = context.get('params', {}).get('monitor', 'primary')
    profile = _profile(context)
    driver = profile.get('driver', 'mock')
    if driver in ('scrot', 'scrot/import') and not context.get('dry_run') and allow_real(context):
        out_dir = ensure_screenshot_dir(context)
        latest = out_dir / 'latest.png'
        tmp = Path('/tmp/urikvm-latest.png')
        res = run_cmd(['scrot', str(tmp)], context, timeout=10)
        if res.returncode != 0:
            res2 = run_cmd(['import', '-window', 'root', str(tmp)], context, timeout=10)
            if res2.returncode != 0:
                raise RuntimeError(res.stderr.strip() or res2.stderr.strip() or 'screenshot failed')
        if not tmp.exists() or tmp.stat().st_size < 128:
            raise RuntimeError('screenshot produced empty image')
        shutil.copy2(tmp, latest)
        tmp.unlink(missing_ok=True)
        raw = latest.read_bytes()
        entry = _store_screenshot(context, monitor, 'scrot/import', 'image/png', raw)
        return {
            'monitor': monitor,
            'driver': 'scrot/import',
            'path': str(latest),
            'display': detect_display(context),
            'mime': entry['mime'],
            'base64': entry['base64'],
            'captured': True,
        }
    if driver == 'mss' and not context.get('dry_run'):
        if not context.get('allow_real'):
            raise PermissionError('real screenshot requires context.allow_real=true')
        try:
            import mss  # type: ignore
            from PIL import Image  # type: ignore
        except Exception as exc:
            raise RuntimeError('mss driver requires: pip install mss pillow') from exc
        with mss.mss() as sct:
            shot = sct.grab(sct.monitors[1])
            img = Image.frombytes('RGB', (shot.width, shot.height), shot.rgb)
            buf = io.BytesIO()
            img.save(buf, format='PNG')
            png = buf.getvalue()
            entry = _store_screenshot(context, monitor, driver, 'image/png', png, shot.width, shot.height)
            return {
                'monitor': monitor,
                'driver': driver,
                'mime': entry['mime'],
                'base64': entry['base64'],
                'width': shot.width,
                'height': shot.height,
            }
    text = f'Mock screenshot {monitor} {time.time()} with buttons: Start OK Cancel'
    raw = text.encode('utf-8')
    entry = _store_screenshot(context, monitor, driver, 'text/plain', raw)
    return {'monitor': monitor, 'driver': driver, 'mime': entry['mime'], 'base64': entry['base64'], 'text': text}


def click_text(payload, context):
    runtime = context['runtime']
    host = context.get('params', {}).get('host', 'local')
    text = payload.get('text') or payload.get('target_text')
    if not text:
        raise ValueError('payload.text is required')
    if payload.get('skip_screenshot'):
        shot = {'ok': True, 'result': context.get('state', {}).get('latest_screenshot')}
    else:
        shot = runtime.call(f'kvm://{host}/monitor/primary/query/screenshot', {}, {**context, 'approved': True})
    if not shot.get('ok'):
        return {'clicked': False, 'reason': 'screenshot failed', 'screenshot': shot}
    ocr = runtime.call(f'ocr://{host}/image/latest/query/text', {}, context)
    llm_result = runtime.call(
        f'llm://{host}/vision/query/analyze',
        {'goal': f'click {text}', 'target_text': text, 'ocr': ocr.get('result') or {}, 'tokens': (ocr.get('result') or {}).get('tokens')},
        context,
    )
    action = (llm_result.get('result') or {})
    if action.get('action') != 'click' and not action.get('x'):
        action = {'action': 'click', 'x': 160, 'y': 120, 'target_text': text}
    click = runtime.call(
        f'him://{host}/mouse/command/click',
        {'x': action.get('x', 160), 'y': action.get('y', 120), 'button': payload.get('button', 'left')},
        {**context, 'approved': True},
    )
    click_body = click.get('result') or {}
    clicked = bool(click.get('ok'))
    return {
        'clicked': clicked,
        'target_text': text,
        'reason': None if clicked else (click.get('error') or click_body.get('reason') or 'click failed'),
        'x': action.get('x'),
        'y': action.get('y'),
        'screenshot': shot.get('result'),
        'ocr': ocr.get('result'),
        'llm': action,
        'analysis': action,
        'click': click_body,
        'pipeline': {
            'screenshot': {'ok': bool(shot.get('ok')), 'result': shot.get('result')},
            'ocr': {'ok': bool(ocr.get('ok')), 'result': ocr.get('result')},
            'llm': {'ok': bool(llm_result.get('ok')), 'result': action},
            'him': {'ok': bool(click.get('ok')), 'result': click_body},
        },
    }


def type_text(payload, context):
    runtime = context['runtime']
    host = context.get('params', {}).get('host', 'local')
    text = payload.get('text', '')
    return runtime.call(f'him://{host}/keyboard/command/type', {'text': text}, {**context, 'approved': True})
```

```yaml markpact:tests
tests:
- id: kvm.monitor.list_query
  uri: kvm://local/monitor/query/list
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: kvm.monitor.list
- id: kvm.task.click_text_command
  uri: kvm://local/task/command/click-text
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: kvm.task.click_text
  payload: {}
```

```yaml markpact:flow id=kvm-smoke
flow:
  id: kvm-smoke
  description: Use case — smoke kvm:// routes from urikvm manifest.
defaults:
  approved: true
  dry_run: true
do:
- kvm://local/monitor/query/list
- kvm://local/display/query/info
- kvm://local/monitor/primary/query/screenshot
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/urikvm.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'kvm://local/monitor/query/list' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#kvm-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e urikvm`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``kvm://`` (5 capability).
```

