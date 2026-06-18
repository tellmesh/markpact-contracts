# UriPack Showcase: urimail

Pełny Markpact: definicje z `manifest.yaml`, kod handlerów, testy, flow i instrukcja
materializacji do `.markpact/{id}/` oraz uruchomienia procesów ``scheme://``.

Źródło runtime: `urimail/urimail/manifest.yaml` · repo `urimail`

```yaml markpact:pack
apiVersion: urisys.io/v1
kind: UriPack
metadata:
  id: urimail-showcase
  version: '1'
  language: python
description: Mail mock/mailpit/smtp automation for urisys-node.
schemes:
- urimail
capabilities:
- id: mail-status
  uri: urimail://{account}/query/status
  kind: query
  operation: mail.status
  handler: python://urimail.handlers:status
  side_effects: false
  approval: not_required
- id: mail-inbox-unread
  uri: urimail://{account}/inbox/query/unread
  kind: query
  operation: mail.inbox.unread
  handler: python://urimail.handlers:inbox_unread
  side_effects: false
  approval: not_required
- id: mail-message-compose
  uri: urimail://{account}/message/command/compose
  kind: command
  operation: mail.message.compose
  handler: python://urimail.handlers:message_compose
  side_effects: true
  approval: required
- id: mail-message-send
  uri: urimail://{account}/message/command/send
  kind: command
  operation: mail.message.send
  handler: python://urimail.handlers:message_send
  side_effects: true
  approval: required
- id: mail-message-publish_post
  uri: urimail://{account}/message/command/publish-post
  kind: command
  operation: mail.message.publish_post
  handler: python://urimail.handlers:message_publish_post
  side_effects: true
  approval: required
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

import json
import os
import smtplib
import urllib.error
import urllib.request
from email.message import EmailMessage
from typing import Any


def _mail_cfg(context: dict[str, Any]) -> dict[str, Any]:
    return context.get("config", {}).get("mail") or {}


def _driver(context: dict[str, Any]) -> str:
    return str(_mail_cfg(context).get("driver") or os.environ.get("URISYS_MAIL_DRIVER") or "mock")


def _draft_state(context: dict[str, Any]) -> dict[str, Any]:
    account = context.get("params", {}).get("account", "local")
    drafts = context.setdefault("state", {}).setdefault("mail_drafts", {})
    return drafts.setdefault(account, {"to": "", "subject": "", "body": ""})


def _real_allowed(context: dict[str, Any]) -> bool:
    return bool(context.get("allow_real") or os.environ.get("URISYS_ALLOW_REAL") == "1")


def _mailpit_api(context: dict[str, Any]) -> str:
    cfg = _mail_cfg(context)
    return str(cfg.get("mailpit_api") or os.environ.get("URISYS_MAILPIT_API") or "http://127.0.0.1:8025/api/v1")


def _mailpit_messages(context: dict[str, Any]) -> list[dict[str, Any]]:
    url = _mailpit_api(context).rstrip("/") + "/messages"
    with urllib.request.urlopen(url, timeout=10) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    if isinstance(data, dict) and isinstance(data.get("messages"), list):
        return data["messages"]
    if isinstance(data, list):
        return data
    return []


def status(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    del payload
    cfg = _mail_cfg(context)
    return {
        "driver": _driver(context),
        "mailpit_api": _mailpit_api(context),
        "smtp_host": cfg.get("smtp_host") or os.environ.get("URISYS_SMTP_HOST") or "127.0.0.1",
        "smtp_port": int(cfg.get("smtp_port") or os.environ.get("URISYS_SMTP_PORT") or "1025"),
        "supports": ["mock", "mailpit", "smtp"],
    }


def inbox_unread(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    driver = payload.get("driver") or _driver(context)
    limit = int(payload.get("limit") or 20)
    if driver == "mailpit" and _real_allowed(context):
        try:
            messages = _mailpit_messages(context)
            unread = [m for m in messages if not m.get("Read")][:limit]
            return {
                "driver": driver,
                "count": len(unread),
                "messages": [
                    {
                        "id": m.get("ID"),
                        "from": (m.get("From") or {}).get("Address"),
                        "subject": m.get("Subject"),
                        "snippet": m.get("Snippet"),
                    }
                    for m in unread
                ],
            }
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, KeyError) as exc:
            return {"ok": False, "error": f"mailpit unread failed: {exc}", "driver": driver}
    sample = [
        {"id": "mock-1", "from": "boss@example.com", "subject": "Weekly report", "snippet": "Please review..."},
        {"id": "mock-2", "from": "team@example.com", "subject": "Standup notes", "snippet": "Action items..."},
    ]
    return {"driver": "mock", "count": len(sample), "messages": sample[:limit]}


def message_compose(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    draft = _draft_state(context)
    draft["to"] = str(payload.get("to") or draft.get("to") or "")
    draft["subject"] = str(payload.get("subject") or payload.get("title") or draft.get("subject") or "")
    draft["body"] = str(payload.get("body") or payload.get("text") or payload.get("summary") or draft.get("body") or "")
    if context.get("dry_run"):
        return {"dry_run": True, "draft": dict(draft)}
    return {"composed": True, "draft": dict(draft)}


def message_send(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    driver = payload.get("driver") or _driver(context)
    draft = _draft_state(context)
    to_addr = str(payload.get("to") or draft.get("to") or "")
    subject = str(payload.get("subject") or draft.get("subject") or "")
    body = str(payload.get("body") or draft.get("body") or "")
    if not to_addr:
        return {"ok": False, "error": "payload.to is required for send-mail"}
    if context.get("dry_run"):
        return {"dry_run": True, "driver": driver, "to": to_addr, "subject": subject, "chars": len(body)}
    if driver in ("mailpit", "smtp") and _real_allowed(context):
        cfg = _mail_cfg(context)
        host = str(cfg.get("smtp_host") or os.environ.get("URISYS_SMTP_HOST") or "127.0.0.1")
        port = int(cfg.get("smtp_port") or os.environ.get("URISYS_SMTP_PORT") or "1025")
        msg = EmailMessage()
        msg["From"] = str(cfg.get("from_addr") or os.environ.get("URISYS_MAIL_FROM") or "urisys@local.test")
        msg["To"] = to_addr
        msg["Subject"] = subject
        msg.set_content(body)
        with smtplib.SMTP(host, port, timeout=15) as smtp:
            smtp.send_message(msg)
        return {"sent": True, "driver": driver, "to": to_addr, "subject": subject, "via": f"{host}:{port}"}
    return {"sent": True, "driver": "mock", "to": to_addr, "subject": subject, "mock": True}


def message_publish_post(payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    platform = str(payload.get("platform") or "linkedin")
    text = str(payload.get("text") or payload.get("body") or "")
    cfg = _mail_cfg(context)
    via = str(payload.get("via") or cfg.get("publish_via") or "mock").lower()
    if context.get("dry_run"):
        return {"dry_run": True, "platform": platform, "chars": len(text), "via": via}
    if via == "browser":
        try:
            from uribrowserdocker.handlers import publish_post as browser_publish_post
        except ModuleNotFoundError as exc:
            raise RuntimeError("publish_via=browser requires pip install uribrowser") from exc
        browser_ctx = dict(context)
        browser_ctx.setdefault("config", {})
        browser_cfg = dict(browser_ctx["config"].get("browser") or {})
        browser_cfg.setdefault("driver", "system-open")
        browser_ctx["config"] = {**browser_ctx["config"], "browser": browser_cfg}
        browser_ctx.setdefault("params", {"session": platform})
        out = browser_publish_post({"platform": platform, "text": text, **payload}, browser_ctx)
        return {"platform": platform, "via": "browser", **out}
    return {"published": True, "platform": platform, "mock": True, "chars": len(text)}
```

```yaml markpact:tests
tests:
- id: mail.status_query
  uri: urimail://demo/query/status
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: mail.status
- id: mail.message.compose_command
  uri: urimail://demo/message/command/compose
  context:
    approved: true
    dry_run: true
    environment: mock
  expect:
    ok: true
    operation: mail.message.compose
  payload: {}
```

```yaml markpact:flow id=urimail-smoke
flow:
  id: urimail-smoke
  description: Use case — smoke urimail:// routes from urimail manifest.
defaults:
  approved: true
  dry_run: true
do:
- urimail://demo/query/status
- urimail://demo/inbox/query/unread
- urimail://demo/message/command/compose: {}
```

```markdown markpact:docs
## Materializacja (unpack → `.markpact/`)

```bash
export TELLMESH_ROOT=/home/tom/github/tellmesh
PACK=markpact-contracts/packs/urimail.showcase.markpact.md

# 1) unpack: manifest + flows + proto → .markpact/{pack_id}/
urisys markpact materialize "$PACK"

# 2) pojedyncze URI (scheme {scheme}://)
urisys --packs none --markpact "$PACK" call 'urimail://demo/query/status' --approve --dry-run

# 3) osadzony flow use-case
urisys markpact run-flow "$PACK#urimail-smoke" --approve --dry-run

# 4) HTTP serve (proces URI {scheme}://)
urisys --packs none --markpact "$PACK" serve --port 8789
```

## Wymagania

- Handler refs: ``python://…`` — wymaga ``pip install -e urimail`` lub ``TELLMESH_ROOT``.
- Mock: ``--dry-run`` / ``environment: mock``.
- Integracje: ``uses:`` + ``urisys markpact run-flow`` ładuje sibling packi.

## Schemat URI

Wszystkie trasy: ``urimail://`` (5 capability).
```

