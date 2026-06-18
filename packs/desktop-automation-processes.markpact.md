# UriProcess Pack: desktop-automation-flows

Procesy z [`tellmesh/examples/39_system_automations`](../../tellmesh/examples/39_system_automations) —
opisane jako **URI Flow Contract** (graf intencji, bez handlerów użytkownika).

Ten Markpact opisuje procesy jako flow URI. Nie zawiera implementacji GUI, OCR, LLM, RDP, shell ani browser.
Każdy krok jest wywołaniem URI rozwiązywanym przez runtime resolver.

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack

metadata:
  id: desktop-automation-processes
  version: 0.1.0
  language: none

description: >
  Runtime-independent process pack for GUI, RDP, browser and desktop automation.
  The pack exposes process:// commands backed by urisys flow runner.

schemes:
  - process

requires:
  schemes:
    - him
    - kvm
    - ocr
    - llm
    - rdp
    - browser
    - shell
    - env

uses:
  packs:
    - urihim
    - urikvm
    - uriocr
    - urillm
    - urirdp
    - uribrowser
    - urishell
    - urienv

capabilities:
  - id: process.gui-open-software-center
    uri: process://desktop/gui-open-software-center/command/run
    kind: command
    operation: process.gui_open_software_center
    handler: urisys://flow/gui-open-software-center
    side_effects: true
    approval: required

  - id: process.llm-guided-gui-click
    uri: process://desktop/llm-guided-gui-click/command/run
    kind: command
    operation: process.llm_guided_gui_click
    handler: urisys://flow/llm-guided-gui-click
    side_effects: true
    approval: required

  - id: process.rdp-kvm-smoke
    uri: process://rdp/rdp-kvm-smoke/command/run
    kind: command
    operation: process.rdp_kvm_smoke
    handler: urisys://flow/rdp-kvm-smoke
    side_effects: true
    approval: required

  - id: process.install-update-verify-browser
    uri: process://system/install-update-verify-browser/command/run
    kind: command
    operation: process.install_update_verify_browser
    handler: urisys://flow/install-update-verify-browser
    side_effects: true
    approval: required

policy:
  default: deny_mutations_without_approval

runtime:
  default_environment: mock
  supports:
    - mock
    - local
    - docker
    - rdp
    - server
  expose:
    - pack
    - service
    - flow
    - interface
    - adapter
```

```yaml markpact:run
scheme: process
default: flow

modes:
  - pack
  - service
  - flow
  - interface
  - adapter

service:
  port_hint: 8799
  path: /uri/call

flow:
  ids:
    - gui-open-software-center
    - llm-guided-gui-click
    - rdp-kvm-smoke
    - install-update-verify-browser

uses:
  - urihim
  - urikvm
  - uriocr
  - urillm
  - urirdp
  - uribrowser
  - urishell
  - urienv

adapter:
  call: POST /uri/call
  events: GET /events
```

```yaml markpact:flow id=gui-open-software-center
flow:
  id: gui-open-software-center
  profile: uri-flow/v1
  description: Open Software Center via keyboard and click Updates.

defaults:
  approved: true
  dry_run: true
  environment: mock

do:
  - him://local/keyboard/command/hotkey:
      keys: ["super"]

  - him://local/keyboard/command/type-text:
      text: Software

  - him://local/keyboard/command/key:
      key: Return

  - id: screenshot
    uri: kvm://local/monitor/primary/query/screenshot
    save_as: screenshot

  - id: ocr
    uri: ocr://local/image/${screenshot.result.image_id}/query/text
    after: screenshot

  - kvm://local/task/command/click-text:
      text: Updates

expect:
  ocr_contains:
    - OK
```

```yaml markpact:flow id=llm-guided-gui-click
flow:
  id: llm-guided-gui-click
  profile: uri-flow/v1
  description: Screenshot, OCR, LLM vision analyze, then click Install.

defaults:
  approved: true
  dry_run: true
  environment: mock

do:
  - id: screenshot
    uri: kvm://local/monitor/primary/query/screenshot
    save_as: screenshot

  - id: ocr
    uri: ocr://local/image/${screenshot.result.image_id}/query/text
    after: screenshot

  - llm://local/vision/query/analyze:
      target_text: Install

  - kvm://local/task/command/click-text:
      text: Install

expect:
  min_vision_confidence: 0.0
```

```yaml markpact:flow id=rdp-kvm-smoke
flow:
  id: rdp-kvm-smoke
  profile: uri-flow/v1
  description: RDP session status, prepare target, screenshot, OCR, click OK.

defaults:
  approved: true
  dry_run: true
  environment: mock

do:
  - rdp://local/session/query/status

  - rdp://local/session/command/prepare-target

  - id: screenshot
    uri: kvm://local/monitor/primary/query/screenshot
    save_as: screenshot

  - id: ocr
    uri: ocr://local/image/${screenshot.result.image_id}/query/text
    after: screenshot

  - kvm://local/task/command/click-text:
      text: OK

expect:
  ocr_contains:
    - OK
```

```yaml markpact:flow id=install-update-verify-browser
flow:
  id: install-update-verify-browser
  profile: uri-flow/v1
  description: Update package index, install Chromium, open health page, click OK.

defaults:
  approved: true
  dry_run: true
  environment: mock

do:
  - id: env_check
    uri: env://runtime/query/health
    operation: env.health
    kind: query

  - id: apt_update
    uri: shell://apt-get
    payload:
      args: ["update"]
    after: env_check

  - id: install_chromium
    uri: package://chromium/command/install
    payload:
      args: ["install", "-y", "chromium-browser"]
    after: apt_update

  - id: open_health
    uri: browser://chrome/page/open
    payload:
      url: http://localhost:8101/health
    after: install_chromium

  - id: screenshot
    uri: browser://chrome/page/active/screenshot
    after: open_health

  - id: desktop_ok
    uri: kvm://local/task/command/click-text
    payload:
      text: OK
    after: screenshot

expect:
  opened_url_contains: health
```

```yaml markpact:tests
tests:
  - id: process.install_update_verify_browser.requires_approval
    uri: process://system/install-update-verify-browser/command/run
    context:
      approved: false
      dry_run: true
      environment: mock
    payload: {}
    expect:
      ok: false
```

```markdown markpact:docs
## URI Flow Contract

Portable process description as a graph of URI calls. Does not define transport, language or runtime.

Source flows: `tellmesh/examples/39_system_automations/07–10-*.uri.flow.yaml`

## Layering

1. **This pack** — what happens (URI sequence)
2. **Runtime resolver** — where/how (`targets`, platform profile)
3. **marksync** — sync + `generated/{platform}/…`

## Profile model

    URI Flow = process graph of intent
    UriPack  = capability catalog
    resolver = runtime / transport / platform decision
    handler  = concrete execution

## Requires (auto from analyze)

    urisys markpact analyze desktop-automation-processes.markpact.md

Each flow reports `requires.schemes` — quick check whether an environment exposes kvm, ocr, shell, etc.

## Portability note

`shell://apt-get` is runtime-independent but platform-specific (Debian/Ubuntu).
For cross-distro processes prefer domain URIs (`package://chromium/command/install`) mapped by resolver profile.

## Runtime envelope

Process call:

    POST /uri/call
    {"uri":"process://desktop/llm-guided-gui-click/command/run","payload":{},"context":{"approved":true,"dry_run":true,"environment":"mock"}}

Internal step (same envelope, different uri):

    {"uri":"kvm://local/task/command/click-text","payload":{"text":"Install"},"context":{...}}
```
