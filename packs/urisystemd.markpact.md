# UriPack Markpact: urisystemd

Minimalna jednoplikowa paczka `systemd://` w trybie mock/dry-run.

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: urisystemd-markpact
  version: 0.1.0
  language: python
schemes: [systemd]
capabilities:
  - id: systemd.status
    uri: systemd://unit/{unit}/query/status
    kind: query
    operation: status
    handler: markpact://self/python/status
    side_effects: false
    approval: not_required
  - id: systemd.restart
    uri: systemd://unit/{unit}/command/restart
    kind: command
    operation: restart
    handler: markpact://self/python/restart
    side_effects: true
    approval: required
runtime:
  default_environment: real
```

```python markpact:handler id=status
from __future__ import annotations


def handle(payload, context):
    unit = (context.get("variables") or {}).get("unit", "unknown.service")
    return {"ok": True, "unit": unit, "active_state": "active", "mode": "mock" if context.get("environment") == "mock" else "real"}
```

```python markpact:handler id=restart
from __future__ import annotations


def handle(payload, context):
    unit = (context.get("variables") or {}).get("unit", "unknown.service")
    return {
        "ok": True,
        "unit": unit,
        "restarted": False if context.get("dry_run", True) else True,
        "mode": "mock" if context.get("dry_run") or context.get("environment") == "mock" else "real",
    }
```

```yaml markpact:tests
tests:
  - id: systemd_status
    uri: systemd://unit/docker.service/query/status
    context:
      environment: real
    expect:
      ok: true
      operation: status
      result_contains:
        unit: docker.service
  - id: systemd_restart_dry_run
    uri: systemd://unit/docker.service/command/restart
    context:
      approved: true
      dry_run: true
      environment: real
    expect:
      ok: true
      operation: restart
      result_contains:
        unit: docker.service
```
