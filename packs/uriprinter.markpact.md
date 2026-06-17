# UriPack Markpact: uriprinter

Paczka URI do kontroli drukarki: status, test strony, test dysz i czyszczenie głowicy.
Domyślnie real — symulacja: --dry-run lub --environment mock. Mutacje wymagają --approve..

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uriprinter-markpact
  version: 0.1.0
  language: python
description: Printer maintenance and control pack (real by default; use --dry-run or --environment mock to simulate).
schemes: [printer]
capabilities:
  - id: printer.status
    uri: printer://{device}/query/status
    kind: query
    operation: status
    handler: markpact://self/python/status
    side_effects: false
    approval: not_required
  - id: printer.print_test_page
    uri: printer://{device}/command/print-test-page
    kind: command
    operation: print_test_page
    handler: markpact://self/python/print_test_page
    side_effects: true
    approval: required
  - id: printer.nozzle_check
    uri: printer://{device}/command/nozzle-check
    kind: command
    operation: nozzle_check
    handler: markpact://self/python/nozzle_check
    side_effects: true
    approval: required
  - id: printer.clean_head
    uri: printer://{device}/command/clean-head
    kind: command
    operation: clean_head
    handler: markpact://self/python/clean_head
    side_effects: true
    approval: required
policy:
  default: deny_mutations_without_approval
runtime:
  default_environment: real
  supports: [mock, local]
```

```python markpact:handler id=status
from __future__ import annotations


def handle(payload, context):
    device = (context.get("variables") or {}).get("device", "default")
    return {
        "ok": True,
        "device": device,
        "online": True,
        "ink_level": "72%",
        "paper_ready": True,
        "mode": "mock" if context.get("environment") == "mock" else "real",
    }
```

```python markpact:handler id=print_test_page
from __future__ import annotations


def handle(payload, context):
    device = (context.get("variables") or {}).get("device", "default")
    dry = bool(context.get("dry_run")) or context.get("environment") == "mock"
    return {
        "ok": True,
        "device": device,
        "job_id": None if dry else "print-test-001",
        "queued": not dry,
        "mode": "mock" if dry else "real",
    }
```

```python markpact:handler id=nozzle_check
from __future__ import annotations


def handle(payload, context):
    device = (context.get("variables") or {}).get("device", "default")
    dry = bool(context.get("dry_run")) or context.get("environment") == "mock"
    return {
        "ok": True,
        "device": device,
        "nozzles_ok": True,
        "checked": not dry,
        "mode": "mock" if dry else "real",
    }
```

```python markpact:handler id=clean_head
from __future__ import annotations


def handle(payload, context):
    device = (context.get("variables") or {}).get("device", "default")
    dry = bool(context.get("dry_run")) or context.get("environment") == "mock"
    return {
        "ok": True,
        "device": device,
        "started": not dry,
        "mode": "mock" if dry else "real",
    }
```

```yaml markpact:tests
tests:
  - id: printer_status
    uri: printer://epson/query/status
    context:
      environment: real
    expect:
      ok: true
      operation: status
      result_contains:
        device: epson
        online: true
  - id: printer_nozzle_check_dry_run
    uri: printer://epson/command/nozzle-check
    context:
      approved: true
      dry_run: true
      environment: real
    expect:
      ok: true
      operation: nozzle_check
      result_contains:
        device: epson
        nozzles_ok: true
```
