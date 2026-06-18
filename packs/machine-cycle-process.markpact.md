# UriProcess: machine-cycle

Procesowy Markpact dla istniejących UriPacków.

Ten plik opisuje tylko **CO** ma się wydarzyć — nie **GDZIE** ani **JAK**.
Resolver runtime jest ładowany osobno (`URISYS_RESOLVER_CONFIG`).

Profil: [urisys/docs/MARKPACT-PROFILE.md](../../urisys/docs/MARKPACT-PROFILE.md)

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: machine-cycle-process
  version: 0.2.0
  language: none

description: >
  Process-level contract that coordinates existing URI packs.
  Runtime target and transport are selected by external resolver.

schemes:
  - process

requires:
  schemes:
    - stepper
    - screen
    - tts
  capabilities:
    - stepper.status
    - stepper.enable
    - stepper.move_relative
    - stepper.stop
    - screen.frame
    - tts.session.speak

uses:
  packs:
    - uristepper
    - uriscreen
    - uristt-tts

capabilities:
  - id: machine-cycle.run
    uri: process://machine-cycle/command/run
    kind: command
    operation: machine_cycle.run
    handler: urisys://flow/machine-cycle
    side_effects: true
    approval: required
    risk:
      class: physical_process
      level: high
      requires:
        - approval
        - dry_run_supported
        - audit
        - resolver_policy
        - device_limits

policy:
  default: deny_mutations_without_approval

runtime:
  default_environment: mock
  supports:
    - mock
    - esp32
    - edge-linux
    - desktop-linux
    - windows
    - docker
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
    - machine-cycle

uses:
  - uristepper
  - uriscreen
  - uristt-tts
  - urishell

adapter:
  call: POST /uri/call
  events: GET /events
```

```yaml markpact:flow id=machine-cycle
flow:
  id: machine-cycle
  profile: uri-flow/v1
  description: >
    Cross-platform machine cycle:
    check status, optionally capture screen, move axis, verify and report.

requires_features:
  - linear
  - step_id
  - save_as
  - ref
  - expect

defaults:
  approved: true
  dry_run: true
  environment: mock
  deadline_ms: 30000

inputs:
  device:
    default: machine-01
  axis:
    default: x
  steps:
    default: 100
  speed_sps:
    default: 200

do:
  - id: before_status
    uri: stepper://${device}/axis/${axis}/query/status
    save_as: before

  - id: screen_before
    uri: screen://operator/monitor/primary/query/frame
    save_as: screen_before

  - id: enable_axis
    uri: stepper://${device}/axis/${axis}/command/enable
    payload: {}
    after: before_status

  - id: move_relative
    uri: stepper://${device}/axis/${axis}/command/move-relative
    payload:
      steps: ${steps}
      direction: cw
      speed_sps: ${speed_sps}
    after: enable_axis
    save_as: move

  - id: after_status
    uri: stepper://${device}/axis/${axis}/query/status
    after: move_relative
    save_as: after

  - id: speak_done
    uri: tts://local/session/default/command/speak
    payload:
      text: "Machine cycle completed"
    after: after_status

  - id: stop_axis
    uri: stepper://${device}/axis/${axis}/command/stop
    payload: {}
    after: speak_done

expect:
  transport_ok: true
  required_steps:
    - before_status
    - enable_axis
    - move_relative
    - after_status
    - stop_axis
```

```yaml markpact:tests
tests:
  - id: machine_cycle.requires_approval
    uri: process://machine-cycle/command/run
    context:
      approved: false
      dry_run: true
      environment: mock
    payload: {}
    expect:
      ok: false

  - id: machine_cycle.dry_run
    uri: process://machine-cycle/command/run
    context:
      approved: true
      dry_run: true
      environment: mock
    payload:
      device: machine-01
      axis: x
      steps: 100
      speed_sps: 200
    expect:
      ok: true
      operation: machine_cycle.run
```

```markdown markpact:docs
## Runtime idea

Process Markpact (CO) · resolver (GDZIE/JAK) · marksync (sync/generate).

Resolver example: `markpact-contracts/packs/examples/urisys.runtime.resolver.yaml`

```bash
export TELLMESH_ROOT=~/github/tellmesh
export URISYS_RESOLVER_CONFIG=markpact-contracts/packs/examples/urisys.runtime.machine-cycle-pololu.yaml
urisys markpact analyze markpact-contracts/packs/machine-cycle-process.markpact.md
urisys markpact run markpact-contracts/packs/machine-cycle-process.markpact.md --as flow --approve --dry-run
```
```
