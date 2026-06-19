# UriPack Markpacts

## Canonical location (thin, generated)

```text
tellmesh/{pack}/markpacts/{pack}.markpact.md
```

Generated from `manifest.yaml` — **no duplicated handler code** (`python://` refs only).

```bash
cd tellmesh/urisys
python3 scripts/generate_pack_markpacts.py
python3 scripts/generate_pack_markpacts.py --check          # CI drift
python3 scripts/generate_pack_markpacts.py --aggregate      # copy here
```

## Unpack + run → `.markpact/`

```bash
cd tellmesh/urikvm
export TELLMESH_ROOT=~/github/tellmesh
PACK=markpacts/urikvm.markpact.md

urisys markpact run "$PACK" --as flow --approve --dry-run   # smoke flow
urisys markpact run "$PACK" --as pack                        # list routes
urisys markpact run "$PACK" --as service --port 8794         # HTTP scheme://
urisys markpact run "$PACK" --as interface                 # explain URIs
urisys markpact run "$PACK" --as adapter                   # wire JSON
```

Unpack layout (cwd):

```text
.markpact/{id}/{hash}/
├── manifest.yaml
├── flows/
├── tests.yaml
└── urisys_markpact_*/*.py   # only for markpact:// inline handlers
```

## Modes (`markpact:run` block)

| Mode | Role |
|------|------|
| `pack` | register manifest → list routes |
| `service` | `POST /uri/call` — proces `scheme://` |
| `flow` | embedded `{scheme}-smoke` flow |
| `interface` | human/CLI route catalog |
| `adapter` | integration wire (routes + uses + ABI) |

## UriContract (docker / lab)

Generated from pack `manifest.yaml`:

```bash
cd tellmesh/urisys
urisys markpact gen-contract ../uribrowser/uribrowserdocker/manifest.yaml \
  --out ../uribrowser/markpacts/uribrowser.contract.markpact.md --force
python3 scripts/check_contract_drift.py
```

`urisys-node`: HTTP transport in `urisys-node.contract.markpact.md`; capability routes (`node://`, `app://`) in `urisys-node.capabilities.markpact.md` from `urisys-node/urisysnode/manifest.yaml`.

**Deprecated:** `uri-packs/` and `legacy/` — use promoted pack manifests instead.

## Legacy

Thick `*.showcase.markpact.md` (embedded handlers) live in [`legacy/`](legacy/) — **draft only**, do not regenerate.

The only active showcase at pack root: `uribrowser.showcase.markpact.md` (manual integration demo with `run-flow`).

Use `{pack}.markpact.md` in each repo instead.
