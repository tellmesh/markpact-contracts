# UriContract: urikvm

```yaml markpact:contract
apiVersion: urisys.io/v1
kind: UriContract
metadata:
  id: urikvm.contract
  version: 1.0.0
scheme: kvm
queries:
  - id: kvm.monitor.list
    pattern: kvm://{host}/monitor/query/list
  - id: kvm.monitor.screenshot
    pattern: kvm://{host}/monitor/{monitor}/query/screenshot
commands:
  - id: kvm.task.click_text
    pattern: kvm://{host}/task/command/click-text
    side_effects: true
    requires_approval: true
  - id: kvm.task.type_text
    pattern: kvm://{host}/task/command/type-text
    side_effects: true
    requires_approval: true
uses:
  - him://
  - ocr://
  - llm://
```
