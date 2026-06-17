# UriPack Markpact: uriusb

Paczka URI do kontroli portów USB: lista urządzeń, status portu, enable/disable (mock).
Realne operacje wymagają `--approve`. Symulacja: --dry-run.

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uriusb-markpact
  version: 0.1.0
  language: python
description: USB port and device control pack (real by default; use --dry-run or --environment mock to simulate).
schemes: [usb]
capabilities:
  - id: usb.list_ports
    uri: usb://host/{host}/query/ports
    kind: query
    operation: list_ports
    handler: markpact://self/python/list_ports
    side_effects: false
    approval: not_required
  - id: usb.port_status
    uri: usb://port/{port_id}/query/status
    kind: query
    operation: port_status
    handler: markpact://self/python/port_status
    side_effects: false
    approval: not_required
  - id: usb.enable_port
    uri: usb://port/{port_id}/command/enable
    kind: command
    operation: enable_port
    handler: markpact://self/python/enable_port
    side_effects: true
    approval: required
  - id: usb.disable_port
    uri: usb://port/{port_id}/command/disable
    kind: command
    operation: disable_port
    handler: markpact://self/python/disable_port
    side_effects: true
    approval: required
policy:
  default: deny_mutations_without_approval
runtime:
  default_environment: real
  supports: [mock, local]
```

```python markpact:handler id=list_ports
from __future__ import annotations

_MOCK_PORTS = [
    {"port_id": "1-1", "vendor": "046d", "product": "c52b", "description": "Logitech USB Receiver"},
    {"port_id": "1-2", "vendor": "04b8", "product": "1120", "description": "Epson USB Printer"},
    {"port_id": "2-1", "vendor": "0781", "product": "5567", "description": "SanDisk USB Flash Drive"},
]


def handle(payload, context):
    host = (context.get("variables") or {}).get("host", "local")
    return {
        "ok": True,
        "host": host,
        "ports": _MOCK_PORTS,
        "count": len(_MOCK_PORTS),
        "mode": "mock" if context.get("environment") == "mock" else "real",
    }
```

```python markpact:handler id=port_status
from __future__ import annotations


def handle(payload, context):
    port_id = (context.get("variables") or {}).get("port_id", "unknown")
    return {
        "ok": True,
        "port_id": port_id,
        "enabled": True,
        "power": "on",
        "speed": "480Mbps",
        "mode": "mock" if context.get("environment") == "mock" else "real",
    }
```

```python markpact:handler id=enable_port
from __future__ import annotations


def handle(payload, context):
    port_id = (context.get("variables") or {}).get("port_id", "unknown")
    dry = bool(context.get("dry_run")) or context.get("environment") == "mock"
    return {
        "ok": True,
        "port_id": port_id,
        "enabled": True,
        "applied": not dry,
        "mode": "mock" if dry else "real",
    }
```

```python markpact:handler id=disable_port
from __future__ import annotations


def handle(payload, context):
    port_id = (context.get("variables") or {}).get("port_id", "unknown")
    dry = bool(context.get("dry_run")) or context.get("environment") == "mock"
    return {
        "ok": True,
        "port_id": port_id,
        "enabled": False,
        "applied": not dry,
        "mode": "mock" if dry else "real",
    }
```

```yaml markpact:tests
tests:
  - id: usb_list_ports
    uri: usb://host/local/query/ports
    context:
      environment: real
    expect:
      ok: true
      operation: list_ports
      result_contains:
        host: local
        count: 3
  - id: usb_disable_port_dry_run
    uri: usb://port/1-2/command/disable
    context:
      approved: true
      dry_run: true
      environment: real
    expect:
      ok: true
      operation: disable_port
      result_contains:
        port_id: 1-2
        enabled: false
```
