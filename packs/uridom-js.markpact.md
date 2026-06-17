# UriPack Markpact: uridom-js

Przykład jednoplikowej paczki JS dla strony WWW. Ten plik jest dokumentacją/źródłem dla przyszłego `urisys-js`; obecny runtime Python wykonuje tylko handler Python.

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: uridom-js-markpact
  version: 0.1.0
  language: js
schemes: [dom]
capabilities:
  - id: dom.set_text
    uri: dom://element/{selector}/command/set-text
    kind: command
    operation: set_text
    handler: markpact://self/js/set_text
    side_effects: true
    approval: required
```

```js markpact:handler id=set_text
export async function handle(payload, context) {
  const selector = decodeURIComponent(context.variables.selector);
  const element = document.querySelector(selector);
  if (!element) return { ok: false, error: `Element not found: ${selector}` };
  element.textContent = payload.text ?? "";
  return { ok: true, selector, text: element.textContent };
}
```

```markdown markpact:docs
JS Markpact może być kompilowany przez przyszły `urisys-js` do modułu ESM i rejestrowany w `uricore-js`.
```
