# UriPack Markpact: uribrowser

Jednoplikowa paczka źródłowa URI dla przeglądarki. Ten plik można skompilować do runtime manifestu i handlerów przez `urisys markpact compile` albo ładować bezpośrednio przez `--markpact`.

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack

metadata:
  id: uribrowser-markpact
  version: 0.1.0
  language: python

description: Browser mock pack authored as a single Markpact file.
schemes:
  - browser

capabilities:
  - id: browser.open_page
    uri: browser://{session}/page/open
    kind: command
    operation: open_page
    handler: markpact://self/python/open_page
    command_type: browser.v1.OpenPageCommand
    success_event_type: browser.v1.PageOpenedEvent
    side_effects: true
    approval: required

  - id: browser.get_dom
    uri: browser://{session}/page/dom
    kind: query
    operation: get_dom
    handler: markpact://self/python/get_dom
    query_type: browser.v1.GetDomQuery
    result_type: browser.v1.DomSnapshot
    side_effects: false
    approval: not_required

policy:
  default: deny_mutations_without_approval

runtime:
  default_environment: real
  supports: [mock, local, docker]
```

```python markpact:handler id=open_page
from __future__ import annotations

_SESSIONS = {}


def handle(payload, context):
    variables = context.get("variables") or {}
    session = variables.get("session", "default")
    url = payload.get("url", "about:blank")
    title = payload.get("title") or ("Example" if "example" in url else "Mock page")
    html = payload.get("html") or f"<html><head><title>{title}</title></head><body>{url}</body></html>"
    _SESSIONS[session] = {"session": session, "url": url, "title": title, "html": html}
    return {
        "ok": True,
        "mode": "mock" if context.get("dry_run") or context.get("environment") == "mock" else "real",
        "session": session,
        "url": url,
        "title": title,
    }
```

```python markpact:handler id=get_dom
from __future__ import annotations


def handle(payload, context):
    variables = context.get("variables") or {}
    session = variables.get("session", "default")
    return {
        "ok": True,
        "session": session,
        "title": "Mock DOM",
        "html": "<html><body>DOM from Markpact handler</body></html>",
    }
```

```yaml markpact:tests
tests:
  - id: browser_open_requires_approval_success
    uri: browser://default/page/open
    payload:
      url: https://example.com
    context:
      approved: true
      dry_run: true
      environment: real
    expect:
      ok: true
      operation: open_page
      result_contains:
        session: default
        url: https://example.com

  - id: browser_dom_query_success
    uri: browser://default/page/dom
    context:
      environment: real
    expect:
      ok: true
      operation: get_dom
      result_contains:
        session: default
```

```markdown markpact:docs
## Użycie

Call:

    urisys --packs none --markpact markpacts/packs/uribrowser.markpact.md call browser://default/page/open --payload '{"url":"https://example.com"}' --approve --dry-run

Test:

    urisys markpact test markpacts/packs/uribrowser.markpact.md
```
