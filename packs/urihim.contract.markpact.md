# UriContract: urihim

```yaml markpact:contract
apiVersion: urisys.io/v1
kind: UriContract
metadata:
  id: urihim.contract
  version: 1.0.0
scheme: him
commands:
  - id: him.mouse.move
    pattern: him://{host}/mouse/command/move
    side_effects: true
    requires_approval: true
  - id: him.mouse.click
    pattern: him://{host}/mouse/command/click
    side_effects: true
    requires_approval: true
  - id: him.keyboard.type
    pattern: him://{host}/keyboard/command/type
    side_effects: true
    requires_approval: true
  - id: him.keyboard.hotkey
    pattern: him://{host}/keyboard/command/hotkey
    side_effects: true
    requires_approval: true
queries:
  - id: him.mouse.status
    pattern: him://{host}/mouse/query/status
```
