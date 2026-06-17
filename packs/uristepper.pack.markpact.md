# UriPack Markpact: uristepper (mock lab pack)

Markpact pack for local-lab validation. Production runtime is the `uristepper-docker` OCI image.

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uristepper-pack
  version: 0.1.0
  language: python
description: Stepper motor URI pack (mock handlers for markpact validate; real driver in uristepper-docker image).
schemes: [stepper]
capabilities:
  - id: stepper.status
    uri: stepper://{device}/axis/{axis}/query/status
    kind: query
    operation: status
    handler: markpact://self/python/status
    side_effects: false
    approval: not_required
  - id: stepper.move_relative
    uri: stepper://{device}/axis/{axis}/command/move-relative
    kind: command
    operation: move_relative
    handler: markpact://self/python/move_relative
    side_effects: true
    approval: required
policy:
  default: deny_mutations_without_approval
runtime:
  default_environment: mock
  supports: [mock, local, docker]
```

```python markpact:handler id=status
from __future__ import annotations


def handle(payload, context):
    params = context.get("variables") or {}
    return {
        "ok": True,
        "device": params.get("device", "machine-01"),
        "axis": params.get("axis", "x"),
        "enabled": True,
        "position_steps": 0,
        "driver": "mock",
    }
```

```python markpact:handler id=move_relative
from __future__ import annotations


def handle(payload, context):
    if not context.get("approved"):
        return {"ok": False, "error": "approval_required"}
    steps = int(payload.get("steps") or 0)
    return {
        "ok": True,
        "moved": not context.get("dry_run"),
        "steps": steps,
        "direction": payload.get("direction", "cw"),
        "driver": "mock",
    }
```

```yaml markpact:tests
tests:
  - id: stepper_status
    uri: stepper://machine-01/axis/x/query/status
    context:
      environment: mock
    expect:
      ok: true
      operation: status
      result_contains:
        device: machine-01
        axis: x
  - id: stepper_move_dry_run
    uri: stepper://machine-01/axis/x/command/move-relative
    payload:
      steps: 100
      direction: cw
      speed_sps: 200
    context:
      approved: true
      dry_run: true
      environment: mock
    expect:
      ok: true
      operation: move_relative
      result_contains:
        moved: false
```
