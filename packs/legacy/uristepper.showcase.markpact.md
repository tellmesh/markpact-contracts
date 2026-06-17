# UriPack Showcase: uristepper

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `uristepper/uristepper/manifest.yaml` · repo `uristepper`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uristepper-showcase
  version: '1'
  language: python
description: Stepper motor URI pack (mock + rpi-gpio-step-dir drivers).
schemes:
- stepper
capabilities:
- id: stepper-status
  uri: stepper://{device}/axis/{axis}/query/status
  kind: query
  operation: stepper.status
  handler: python://uristepper.handlers:status
  side_effects: false
  approval: not_required
- id: stepper-enable
  uri: stepper://{device}/axis/{axis}/command/enable
  kind: command
  operation: stepper.enable
  handler: python://uristepper.handlers:enable
  side_effects: true
  approval: required
- id: stepper-disable
  uri: stepper://{device}/axis/{axis}/command/disable
  kind: command
  operation: stepper.disable
  handler: python://uristepper.handlers:disable
  side_effects: true
  approval: required
- id: stepper-stop
  uri: stepper://{device}/axis/{axis}/command/stop
  kind: command
  operation: stepper.stop
  handler: python://uristepper.handlers:stop
  side_effects: true
  approval: required
- id: stepper-home
  uri: stepper://{device}/axis/{axis}/command/home
  kind: command
  operation: stepper.home
  handler: python://uristepper.handlers:home
  side_effects: true
  approval: required
- id: stepper-move_relative
  uri: stepper://{device}/axis/{axis}/command/move-relative
  kind: command
  operation: stepper.move_relative
  handler: python://uristepper.handlers:move_relative
  side_effects: true
  approval: required
- id: stepper-move_absolute
  uri: stepper://{device}/axis/{axis}/command/move-absolute
  kind: command
  operation: stepper.move_absolute
  handler: python://uristepper.handlers:move_absolute
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

from functools import lru_cache

from .drivers import make_driver


def _device_profile(context: dict) -> dict:
    return context.get("device_profile") or context.get("config", {}).get("device_profile") or {}


def _device_axis(context: dict) -> tuple[str, str, dict, dict]:
    params = context.get("params", {})
    device = params.get("device")
    axis = params.get("axis")
    profile = _device_profile(context)
    axes = profile.get("axes", {})
    cfg = axes.get(axis, {})
    safety = profile.get("safety", {}).get(axis, {})
    if not cfg:
        raise RuntimeError(f"Axis not configured: {axis}")
    return device, axis, cfg, safety


@lru_cache(maxsize=16)
def _driver(driver_name: str, state_path: str = ""):
    # state_path is part of the cache key so tests and multi-instance runtimes do not share mock state accidentally.
    return make_driver(driver_name)


def _enforce_safety(payload: dict, safety: dict) -> None:
    if "steps" in payload and int(payload["steps"]) > int(safety.get("max_single_move_steps", 1000000)):
        raise RuntimeError("steps exceeds safety.max_single_move_steps")
    if "speed_sps" in payload and float(payload["speed_sps"]) > float(safety.get("max_speed_sps", 1000000)):
        raise RuntimeError("speed_sps exceeds safety.max_speed_sps")
    if "position" in payload:
        min_pos = safety.get("min_position_steps")
        max_pos = safety.get("max_position_steps")
        pos = int(payload["position"])
        if min_pos is not None and pos < int(min_pos):
            raise RuntimeError("position below safety.min_position_steps")
        if max_pos is not None and pos > int(max_pos):
            raise RuntimeError("position above safety.max_position_steps")


def _dry_or_driver(context: dict, cfg: dict):
    if context.get("dry_run"):
        return None
    return _driver(cfg.get("driver", "mock"), __import__("os").environ.get("URISYS_STATE_PATH", ""))


def status(payload: dict, context: dict) -> dict:
    device, axis, cfg, safety = _device_axis(context)
    drv = _dry_or_driver(context, cfg)
    if drv is None:
        return {"dry_run": True, "device": device, "axis": axis, "driver": cfg.get("driver", "mock"), "safety": safety}
    return drv.status(device, axis, cfg) | {"safety": safety}


def enable(payload: dict, context: dict) -> dict:
    device, axis, cfg, safety = _device_axis(context)
    drv = _dry_or_driver(context, cfg)
    if drv is None:
        return {"dry_run": True, "device": device, "axis": axis, "enabled": True}
    return drv.enable(device, axis, cfg)


def disable(payload: dict, context: dict) -> dict:
    device, axis, cfg, safety = _device_axis(context)
    drv = _dry_or_driver(context, cfg)
    if drv is None:
        return {"dry_run": True, "device": device, "axis": axis, "enabled": False}
    return drv.disable(device, axis, cfg)


def stop(payload: dict, context: dict) -> dict:
    device, axis, cfg, safety = _device_axis(context)
    drv = _dry_or_driver(context, cfg)
    if drv is None:
        return {"dry_run": True, "device": device, "axis": axis, "stopped": True}
    return drv.stop(device, axis, cfg)


def move_relative(payload: dict, context: dict) -> dict:
    device, axis, cfg, safety = _device_axis(context)
    _enforce_safety(payload, safety)
    steps = int(payload["steps"])
    direction = payload.get("direction", "cw")
    speed_sps = float(payload.get("speed_sps", safety.get("default_speed_sps", 200)))
    if direction not in ("cw", "ccw"):
        raise RuntimeError("direction must be cw or ccw")
    drv = _dry_or_driver(context, cfg)
    if drv is None:
        return {"dry_run": True, "device": device, "axis": axis, "steps": steps, "direction": direction, "speed_sps": speed_sps}
    return drv.move_relative(device, axis, cfg, steps, direction, speed_sps)


def move_absolute(payload: dict, context: dict) -> dict:
    device, axis, cfg, safety = _device_axis(context)
    _enforce_safety(payload, safety)
    position = int(payload["position"])
    speed_sps = float(payload.get("speed_sps", safety.get("default_speed_sps", 200)))
    drv = _dry_or_driver(context, cfg)
    if drv is None:
        return {"dry_run": True, "device": device, "axis": axis, "position": position, "speed_sps": speed_sps}
    return drv.move_absolute(device, axis, cfg, position, speed_sps)


def home(payload: dict, context: dict) -> dict:
    device, axis, cfg, safety = _device_axis(context)
    direction = payload.get("direction", safety.get("home_direction", "ccw"))
    speed_sps = float(payload.get("speed_sps", safety.get("home_speed_sps", 100)))
    drv = _dry_or_driver(context, cfg)
    if drv is None:
        return {"dry_run": True, "device": device, "axis": axis, "homed": True, "direction": direction, "speed_sps": speed_sps}
    return drv.home(device, axis, cfg, direction, speed_sps)
```

```yaml markpact:tests
tests:
- id: stepper.status_query
  uri: stepper://mock/axis/x/query/status
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: stepper.status
- id: stepper.enable_command
  uri: stepper://mock/axis/x/command/enable
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: stepper.enable
  payload: {}
```

```yaml markpact:flow id=stepper-smoke
flow:
  id: stepper-smoke
  description: Use case — smoke stepper:// routes from uristepper manifest.
defaults:
  approved: true
  dry_run: true
do:
- stepper://mock/axis/x/query/status
- stepper://mock/axis/x/command/enable: {}
- stepper://mock/axis/x/command/disable: {}
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/uristepper.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'stepper://mock/axis/x/query/status' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#stepper-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e uristepper`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``stepper://`` (7 capability).
```

