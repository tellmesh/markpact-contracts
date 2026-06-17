# UriContract: urillm vision

```yaml markpact:contract
apiVersion: urisys.io/v1
kind: UriContract
metadata:
  id: urillm.vision.contract
  version: 1.0.0
scheme: llm
queries:
  - id: llm.vision.analyze
    pattern: llm://{host}/vision/query/analyze
```
