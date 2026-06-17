# UriPack Showcase: uriocr

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `uriocr/uriocr/manifest.yaml` · repo `uriocr`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uriocr-showcase
  version: '1'
  language: python
description: OCR text extraction from latest screenshot or image id (mock/tesseract).
schemes:
- ocr
capabilities:
- id: ocr-latest-text
  uri: ocr://{host}/image/latest/query/text
  kind: query
  operation: ocr.latest.text
  handler: python://uriocr.handlers:latest_text
  side_effects: false
  approval: not_required
- id: ocr-image-text
  uri: ocr://{host}/image/{image_id}/query/text
  kind: query
  operation: ocr.image.text
  handler: python://uriocr.handlers:image_text
  side_effects: false
  approval: not_required
policy:
  default: deny_mutations_without_approval
runtime:
  default_environment: real
  supports:
  - mock
  - local
  - docker
```

```python markpact:source path=handlers.py
from __future__ import annotations

import base64
import io
import re


def _ocr_cfg(context):
    return context.get('config', {}).get('ocr', {})


def _driver(context):
    if context.get('dry_run') or not context.get('allow_real'):
        return 'mock'
    return _ocr_cfg(context).get('driver', 'mock')


def _mock_boxes(context):
    cfg = _ocr_cfg(context)
    return cfg.get('mock_boxes') or [
        {'text': 'Start', 'x': 100, 'y': 120, 'w': 80, 'h': 30},
        {'text': 'OK', 'x': 320, 'y': 240, 'w': 60, 'h': 30},
        {'text': 'Cancel', 'x': 400, 'y': 240, 'w': 90, 'h': 30},
    ]


def _latest_screenshot(context):
    return context.get('state', {}).get('latest_screenshot') or {}


def _png_bytes(context):
    shot = _latest_screenshot(context)
    raw = base64.b64decode(shot.get('base64') or '')
    if shot.get('mime') == 'image/png' and raw:
        return raw
    return None


def _tesseract_boxes(png_bytes, lang='eng'):
    try:
        import pytesseract  # type: ignore
        from PIL import Image  # type: ignore
    except Exception as exc:
        raise RuntimeError('tesseract driver requires: pip install pytesseract pillow, and system tesseract-ocr') from exc
    img = Image.open(io.BytesIO(png_bytes))
    data = pytesseract.image_to_data(img, lang=lang, output_type=pytesseract.Output.DICT)
    boxes = []
    n = len(data.get('text') or [])
    for i in range(n):
        text = (data['text'][i] or '').strip()
        if not text:
            continue
        try:
            conf = float(data['conf'][i])
        except (TypeError, ValueError):
            conf = -1.0
        if conf < 0:
            continue
        boxes.append({
            'text': text,
            'x': int(data['left'][i]),
            'y': int(data['top'][i]),
            'w': int(data['width'][i]),
            'h': int(data['height'][i]),
            'confidence': conf / 100.0,
        })
    return boxes


def _merge_word_boxes(boxes):
    if not boxes:
        return boxes
    merged = []
    current = dict(boxes[0])
    for box in boxes[1:]:
        same_line = abs(box['y'] - current['y']) <= max(current.get('h', 0), box.get('h', 0))
        close_x = box['x'] <= current['x'] + current.get('w', 0) + 12
        if same_line and close_x:
            current['text'] = f"{current['text']} {box['text']}".strip()
            right = max(current['x'] + current['w'], box['x'] + box['w'])
            bottom = max(current['y'] + current['h'], box['y'] + box['h'])
            current['x'] = min(current['x'], box['x'])
            current['y'] = min(current['y'], box['y'])
            current['w'] = right - current['x']
            current['h'] = bottom - current['y']
            current['confidence'] = max(current.get('confidence', 0.0), box.get('confidence', 0.0))
        else:
            merged.append(current)
            current = dict(box)
    merged.append(current)
    return merged


def _extract_text(context):
    driver = _driver(context)
    if driver == 'tesseract':
        png = _png_bytes(context)
        if not png:
            raise RuntimeError('tesseract OCR requires a PNG screenshot in state.latest_screenshot')
        lang = _ocr_cfg(context).get('lang', 'eng')
        boxes = _merge_word_boxes(_tesseract_boxes(png, lang=lang))
        if not boxes:
            return {'text': '', 'boxes': [], 'driver': driver, 'warning': 'no text detected'}
        return {'text': ' '.join(b['text'] for b in boxes), 'boxes': boxes, 'driver': driver}
    boxes = _mock_boxes(context)
    return {'text': ' '.join(b['text'] for b in boxes), 'boxes': boxes, 'driver': driver}


def latest_text(payload, context):
    data = _extract_text(context)
    return {'image_id': 'latest', **data}


def image_text(payload, context):
    image_id = context.get('params', {}).get('image_id')
    data = _extract_text(context)
    return {'image_id': image_id, **data}
```

```yaml markpact:tests
tests:
- id: ocr.latest.text_query
  uri: ocr://local/image/latest/query/text
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: ocr.latest.text
```

```yaml markpact:flow id=ocr-smoke
flow:
  id: ocr-smoke
  description: Use case — smoke ocr:// routes from uriocr manifest.
defaults:
  approved: true
  dry_run: true
do:
- ocr://local/image/latest/query/text
- ocr://local/image/demo/query/text
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/uriocr.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'ocr://local/image/latest/query/text' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#ocr-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e uriocr`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``ocr://`` (2 capability).
```

