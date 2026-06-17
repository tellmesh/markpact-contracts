# UriContract: uriocr

```yaml markpact:contract
apiVersion: urisys.io/v1
kind: UriContract
metadata:
  id: uriocr.contract
  version: 1.0.0
scheme: ocr
queries:
  - id: ocr.latest.text
    pattern: ocr://{host}/image/latest/query/text
  - id: ocr.image.text
    pattern: ocr://{host}/image/{image_id}/query/text
```
