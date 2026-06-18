# UriPack Showcase: urihim

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `urihim/urihim/manifest.yaml` · repo `urihim`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: urihim-showcase
  version: '1'
  language: python
description: Human input mock (mouse/keyboard) for urisys-node.
schemes:
- him
capabilities:
- id: him-mouse-status
  uri: him://{host}/mouse/query/status
  kind: query
  operation: him.mouse.status
  handler: python://urihim.handlers:mouse_status
  side_effects: false
  approval: not_required
- id: him-mouse-move
  uri: him://{host}/mouse/command/move
  kind: command
  operation: him.mouse.move
  handler: python://urihim.handlers:mouse_move
  side_effects: true
  approval: required
- id: him-mouse-click
  uri: him://{host}/mouse/command/click
  kind: command
  operation: him.mouse.click
  handler: python://urihim.handlers:mouse_click
  side_effects: true
  approval: required
- id: him-mouse-scroll
  uri: him://{host}/mouse/command/scroll
  kind: command
  operation: him.mouse.scroll
  handler: python://urihim.handlers:mouse_scroll
  side_effects: true
  approval: required
- id: him-keyboard-type
  uri: him://{host}/keyboard/command/type
  kind: command
  operation: him.keyboard.type
  handler: python://urihim.handlers:keyboard_type
  side_effects: true
  approval: required
- id: him-keyboard-hotkey
  uri: him://{host}/keyboard/command/hotkey
  kind: command
  operation: him.keyboard.hotkey
  handler: python://urihim.handlers:keyboard_hotkey
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
import shutil
import subprocess


def _state(context):
    s = context.setdefault('state', {})
    return s.setdefault('him', {'mouse': {'x': 0, 'y': 0}, 'keys': []})


def _real_allowed(context):
    return bool(context.get('allow_real') or os.environ.get('URISYS_ALLOW_REAL') == '1')


def _wayland_session() -> bool:
    return bool(os.environ.get('WAYLAND_DISPLAY'))


def _ydotool_available() -> bool:
    return shutil.which('ydotool') is not None


def _xdotool_available() -> bool:
    return shutil.which('xdotool') is not None and bool(os.environ.get('DISPLAY'))


def _driver(context):
    configured = context.get('config', {}).get('him', {}).get('driver')
    if configured:
        return configured
    env_driver = os.environ.get('URISYS_HIM_DRIVER', '').strip()
    if env_driver:
        return env_driver
    if not _real_allowed(context):
        return 'mock'
    if _wayland_session() and _ydotool_available():
        return 'ydotool'
    if _xdotool_available():
        return 'xdotool'
    return 'pyautogui'


def _pyautogui(context):
    if not _real_allowed(context):
        raise PermissionError('real HIM control requires context.allow_real=true or URISYS_ALLOW_REAL=1')
    try:
        import pyautogui  # type: ignore
        return pyautogui
    except Exception as exc:
        raise RuntimeError('real HIM control requires: pip install pyautogui') from exc


_YDOTOOL_BUTTON = {'left': '0xC0', 'right': '0xC1', 'middle': '0xC2'}
# Linux input event codes (subset) for ydotool key sequences
_YDOTOOL_KEY = {
    'return': 28,
    'enter': 28,
    'tab': 15,
    'escape': 1,
    'esc': 1,
    'space': 57,
    'backspace': 14,
    'ctrl': 29,
    'control': 29,
    'shift': 42,
    'alt': 56,
    'super': 125,
    'meta': 125,
    'page_down': 109,
    'pagedown': 109,
    'page_up': 104,
    'pageup': 104,
}


def _run_ydotool(context, *args: str) -> None:
    if not _real_allowed(context):
        raise PermissionError('real HIM control requires context.allow_real=true or URISYS_ALLOW_REAL=1')
    if not _ydotool_available():
        raise RuntimeError('real HIM on Wayland requires: apt install ydotool (+ ydotoold)')
    subprocess.run(['ydotool', *args], check=True, capture_output=True, text=True)


def _run_xdotool(context, *args: str) -> None:
    if not _real_allowed(context):
        raise PermissionError('real HIM control requires context.allow_real=true or URISYS_ALLOW_REAL=1')
    if not _xdotool_available():
        raise RuntimeError('real HIM on X11 requires: apt install xdotool and DISPLAY')
    env = os.environ.copy()
    display = context.get('display') or env.get('DISPLAY')
    if display:
        env['DISPLAY'] = str(display)
    subprocess.run(['xdotool', *args], check=True, capture_output=True, text=True, env=env)


_XDOTOOL_BUTTON = {'left': '1', 'middle': '2', 'right': '3'}
_XDOTOOL_SCROLL = {'up': '4', 'down': '5'}


def _ydotool_key_sequence(keys: list[str]) -> list[str]:
    """Build ydotool key args: code:1 press, code:0 release (inner keys first)."""
    normalized = [k.strip().lower() for k in keys if k.strip()]
    if not normalized:
        return []
    modifiers = []
    main = normalized[-1]
    for part in normalized[:-1]:
        code = _YDOTOOL_KEY.get(part)
        if code is None:
            raise RuntimeError(f'ydotool hotkey: unknown modifier {part!r}')
        modifiers.append(code)
    main_code = _YDOTOOL_KEY.get(main)
    if main_code is None:
        raise RuntimeError(f'ydotool hotkey: unknown key {main!r}')
    seq: list[str] = []
    for code in modifiers:
        seq.append(f'{code}:1')
    seq.append(f'{main_code}:1')
    seq.append(f'{main_code}:0')
    for code in reversed(modifiers):
        seq.append(f'{code}:0')
    return seq


def mouse_status(payload, context):
    st = _state(context)
    return {'driver': _driver(context), **st['mouse']}


def mouse_move(payload, context):
    x = int(payload.get('x', 0))
    y = int(payload.get('y', 0))
    driver = _driver(context)
    if driver == 'pyautogui':
        if context.get('dry_run'):
            return {'dry_run': True, 'x': x, 'y': y}
        _pyautogui(context).moveTo(x, y)
    elif driver == 'ydotool':
        if context.get('dry_run'):
            return {'dry_run': True, 'x': x, 'y': y, 'driver': driver}
        _run_ydotool(context, 'mousemove', '--absolute', str(x), str(y))
    elif driver == 'xdotool':
        if context.get('dry_run'):
            return {'dry_run': True, 'x': x, 'y': y, 'driver': driver}
        _run_xdotool(context, 'mousemove', '--sync', str(x), str(y))
    st = _state(context)
    st['mouse'].update({'x': x, 'y': y})
    return {'x': x, 'y': y, 'driver': driver}


def mouse_click(payload, context):
    x = payload.get('x')
    y = payload.get('y')
    button = payload.get('button', 'left')
    clicks = int(payload.get('clicks', 1))
    driver = _driver(context)
    if driver == 'pyautogui':
        if context.get('dry_run'):
            return {'dry_run': True, 'x': x, 'y': y, 'button': button, 'clicks': clicks}
        pg = _pyautogui(context)
        if x is not None and y is not None:
            pg.click(int(x), int(y), clicks=clicks, button=button)
        else:
            pg.click(clicks=clicks, button=button)
    elif driver == 'ydotool':
        if context.get('dry_run'):
            return {'dry_run': True, 'x': x, 'y': y, 'button': button, 'clicks': clicks, 'driver': driver}
        if x is not None and y is not None:
            _run_ydotool(context, 'mousemove', '--absolute', str(int(x)), str(int(y)))
        code = _YDOTOOL_BUTTON.get(button, _YDOTOOL_BUTTON['left'])
        for _ in range(clicks):
            _run_ydotool(context, 'click', code)
    elif driver == 'xdotool':
        if context.get('dry_run'):
            return {'dry_run': True, 'x': x, 'y': y, 'button': button, 'clicks': clicks, 'driver': driver}
        if x is not None and y is not None:
            _run_xdotool(context, 'mousemove', '--sync', str(int(x)), str(int(y)))
        btn = _XDOTOOL_BUTTON.get(button, _XDOTOOL_BUTTON['left'])
        for _ in range(clicks):
            _run_xdotool(context, 'click', btn)
    st = _state(context)
    if x is not None and y is not None:
        st['mouse'].update({'x': int(x), 'y': int(y)})
    return {'clicked': True, 'x': st['mouse']['x'], 'y': st['mouse']['y'], 'button': button, 'clicks': clicks, 'driver': driver}


def keyboard_type(payload, context):
    text = payload.get('text', '')
    driver = _driver(context)
    if driver == 'pyautogui':
        if context.get('dry_run'):
            return {'dry_run': True, 'text': text}
        _pyautogui(context).write(text)
    elif driver == 'ydotool':
        if context.get('dry_run'):
            return {'dry_run': True, 'text': text, 'driver': driver}
        _run_ydotool(context, 'type', text)
    elif driver == 'xdotool':
        if context.get('dry_run'):
            return {'dry_run': True, 'text': text, 'driver': driver}
        _run_xdotool(context, 'type', '--delay', '12', '--', text)
    _state(context)['keys'].append({'type': 'text', 'text': text})
    return {'typed': text, 'chars': len(text), 'driver': driver}


def mouse_scroll(payload, context):
    amount = int(payload.get('amount', payload.get('clicks', -3)))
    x = payload.get('x')
    y = payload.get('y')
    driver = _driver(context)
    if driver == 'pyautogui':
        if context.get('dry_run'):
            return {'dry_run': True, 'amount': amount, 'x': x, 'y': y}
        pg = _pyautogui(context)
        if x is not None and y is not None:
            pg.moveTo(int(x), int(y))
        pg.scroll(amount)
    elif driver == 'ydotool':
        if context.get('dry_run'):
            return {'dry_run': True, 'amount': amount, 'x': x, 'y': y, 'driver': driver}
        if x is not None and y is not None:
            _run_ydotool(context, 'mousemove', '--absolute', str(int(x)), str(int(y)))
        key = 'page_down' if amount < 0 else 'page_up'
        steps = max(1, abs(amount) // 3)
        for _ in range(steps):
            _run_ydotool(context, 'key', *_ydotool_key_sequence([key]))
    elif driver == 'xdotool':
        if context.get('dry_run'):
            return {'dry_run': True, 'amount': amount, 'x': x, 'y': y, 'driver': driver}
        if x is not None and y is not None:
            _run_xdotool(context, 'mousemove', '--sync', str(int(x)), str(int(y)))
        btn = _XDOTOOL_SCROLL['down' if amount < 0 else 'up']
        repeats = max(1, abs(amount))
        _run_xdotool(context, 'click', '--repeat', str(repeats), btn)
    st = _state(context)
    if x is not None and y is not None:
        st['mouse'].update({'x': int(x), 'y': int(y)})
    return {'scrolled': True, 'amount': amount, 'x': st['mouse']['x'], 'y': st['mouse']['y'], 'driver': driver}


def keyboard_hotkey(payload, context):
    keys = payload.get('keys', [])
    if isinstance(keys, str):
        keys = [k.strip() for k in keys.split('+') if k.strip()]
    driver = _driver(context)
    if driver == 'pyautogui':
        if context.get('dry_run'):
            return {'dry_run': True, 'keys': keys}
        _pyautogui(context).hotkey(*keys)
    elif driver == 'ydotool':
        if context.get('dry_run'):
            return {'dry_run': True, 'keys': keys, 'driver': driver}
        seq = _ydotool_key_sequence(keys)
        _run_ydotool(context, 'key', *seq)
    elif driver == 'xdotool':
        if context.get('dry_run'):
            return {'dry_run': True, 'keys': keys, 'driver': driver}
        combo = '+'.join(k.strip().lower().replace('control', 'ctrl') for k in keys if k.strip())
        _run_xdotool(context, 'key', combo)
    _state(context)['keys'].append({'type': 'hotkey', 'keys': keys})
    return {'hotkey': keys, 'driver': driver}
```

```yaml markpact:tests
tests:
- id: him.mouse.status_query
  uri: him://local/mouse/query/status
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: him.mouse.status
- id: him.mouse.move_command
  uri: him://local/mouse/command/move
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: him.mouse.move
  payload: {}
```

```yaml markpact:flow id=him-smoke
flow:
  id: him-smoke
  description: Use case — smoke him:// routes from urihim manifest.
defaults:
  approved: true
  dry_run: true
do:
- him://local/mouse/query/status
- him://local/mouse/command/move: {}
- him://local/mouse/command/click: {}
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/urihim.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'him://local/mouse/query/status' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#him-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e urihim`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``him://`` (6 capability).
```

