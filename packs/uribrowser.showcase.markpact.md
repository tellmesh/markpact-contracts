# UriPack Showcase: uribrowser

One file that presents the whole package: **definitions** (capabilities + proto
types), **implementation** (handlers), **validation** (tests), **use cases** and
**integrations** (embedded flows), plus **docs**. Compile with
`urisys markpact compile`, inspect with `urisys markpact analyze`.

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uribrowser-showcase
  version: 0.1.0
  language: python
description: Browser pack showcase — definitions, use cases and integrations in one Markpact.
schemes: [browser]
uses: [shell://, kvm://, env://]
capabilities:
  - id: browser.open_page
    uri: browser://{session}/page/open
    kind: command
    operation: browser.page.open
    handler: markpact://self/python/open_page
    command_type: browser.v1.OpenPageCommand
    success_event_type: browser.v1.PageOpenedEvent
    side_effects: true
    approval: required
  - id: browser.get_dom
    uri: browser://{session}/page/dom
    kind: query
    operation: browser.page.dom
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

```proto markpact:proto path=browser/v1/browser.proto
syntax = "proto3";

package browser.v1;

message OpenPageCommand {
  string session_id = 1;
  string url = 2;
  bool wait_until_loaded = 3;
}

message PageOpenedEvent {
  string session_id = 1;
  string url = 2;
  string title = 3;
}

message GetDomQuery {
  string session_id = 1;
}

message DomSnapshot {
  string session_id = 1;
  string html = 2;
}
```

```python markpact:handler id=open_page
from __future__ import annotations

_SESSIONS = {}


def handle(payload, context):
    variables = context.get("variables") or {}
    session = variables.get("session", "default")
    url = payload.get("url", "about:blank")
    title = payload.get("title") or ("Example" if "example" in url else "Mock page")
    _SESSIONS[session] = {"session": session, "url": url, "title": title}
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
    return {"ok": True, "session": session, "title": "Mock DOM", "html": "<html><body>DOM</body></html>"}
```

```yaml markpact:tests
tests:
  - id: browser_open_success
    uri: browser://default/page/open
    payload:
      url: https://example.com
    context:
      approved: true
      dry_run: true
      environment: real
    expect:
      ok: true
      operation: browser.page.open
      result_contains:
        session: default
        url: https://example.com
```

```yaml markpact:flow id=open-and-read
flow:
  id: open-and-read
  description: Use case — open a page and read its DOM (browser scheme only).
defaults:
  approved: true
  dry_run: true
do:
  - browser://default/page/open:
      url: https://example.com
  - browser://default/page/dom
```

```yaml markpact:flow id=install-and-verify
flow:
  id: install-and-verify
  description: Integration — install Chromium via shell, open health page, confirm on desktop.
defaults:
  approved: true
  dry_run: true
do:
  - env://runtime/query/health
  - shell://apt-get:
      args: ["install", "-y", "chromium-browser"]
  - browser://chrome/page/open:
      url: http://localhost:8101/health
  - kvm://local/task/command/click-text:
      text: OK
```

```markdown markpact:docs
## Definitions
`browser://` capabilities with proto-typed payloads (`browser.v1.*`).

## Use cases
`urisys markpact analyze` lists embedded flows; `open-and-read` is a single-scheme use case.

## Integrations
`install-and-verify` spans `env://`, `shell://`, `browser://`, `kvm://` — all declared under `uses:`.
```
