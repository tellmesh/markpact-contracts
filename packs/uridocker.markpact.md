# UriPack Markpact: uridocker

Paczka URI do kontroli kontenerów Docker (mock/dry-run).

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uridocker-markpact
  version: 0.1.0
  language: python
description: Docker container control pack (real by default; use --dry-run or --environment mock to simulate).
schemes: [docker]
capabilities:
  - id: docker.status
    uri: docker://container/{name}/query/status
    kind: query
    operation: status
    handler: markpact://self/python/status
    side_effects: false
    approval: not_required
  - id: docker.restart
    uri: docker://container/{name}/command/restart
    kind: command
    operation: restart
    handler: markpact://self/python/restart
    side_effects: true
    approval: required
policy:
  default: deny_mutations_without_approval
runtime:
  default_environment: real
  supports: [mock, local, docker]
```

```python markpact:handler id=status
from __future__ import annotations


def handle(payload, context):
    name = (context.get("variables") or {}).get("name", "unknown")
    return {
        "ok": True,
        "name": name,
        "state": "running",
        "image": "nginx:latest",
        "mode": "mock" if context.get("environment") == "mock" else "real",
    }
```

```python markpact:handler id=restart
from __future__ import annotations


def handle(payload, context):
    name = (context.get("variables") or {}).get("name", "unknown")
    dry = bool(context.get("dry_run")) or context.get("environment") == "mock"
    return {
        "ok": True,
        "name": name,
        "restarted": not dry,
        "mode": "mock" if dry else "real",
    }
```

```yaml markpact:tests
tests:
  - id: docker_status
    uri: docker://container/web/query/status
    context:
      environment: real
    expect:
      ok: true
      operation: status
      result_contains:
        name: web
        state: running
  - id: docker_restart_dry_run
    uri: docker://container/web/command/restart
    context:
      approved: true
      dry_run: true
      environment: real
    expect:
      ok: true
      operation: restart
      result_contains:
        name: web
        restarted: false
```
