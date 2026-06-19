# markpact-contracts

Extracted UriPack Markpact contracts from [tellmesh/urisys](https://github.com/tellmesh/urisys).

Kontrakty są walidowane i uruchamiane przez **urisys**; runtime to **uricontrol** (`uri_control` + `uri_control.edge`) + **uriresolver** (resolver examples w `packs/examples/`).

Mapa ekosystemu: [urisys/docs/MESH.md](https://github.com/tellmesh/urisys/blob/main/docs/MESH.md)

## Warstwy kontraktów

| Warstwa | Pliki | Źródło prawdy |
|---------|-------|----------------|
| **UriPack (thin)** | `packs/*.markpact.md` | `manifest.yaml` → `generate_pack_markpacts.py` |
| **UriContract (docker/lab)** | `packs/*.contract.markpact.md` | `urisys markpact gen-contract` |
| **urisys-node HTTP** | `urisys-node.contract.markpact.md` | ręczny transport binding |
| **urisys-node capabilities** | `urisys-node.capabilities.markpact.md` | `urisys-node/urisysnode/manifest.yaml` |
| **Legacy** | `uri-packs/`, `packs/legacy/` | **deprecated** — nie używać |

## Validate

```bash
cd ../urisys
bash ../markpact-contracts/scripts/validate-all.sh
python3 scripts/generate_pack_markpacts.py --check
python3 scripts/check_contract_drift.py
python3 scripts/check_flow_uri_patterns.py
```

## Publish (markpact.com portal)

Requires `MARKPACT_TOKEN`:

```bash
MARKPACT_TOKEN=... bash scripts/publish-all.sh
```

## Ekosystem TellMesh

Orchestrator: **[urisys](https://github.com/tellmesh/urisys)** · Mapa: **[MESH.md](https://github.com/tellmesh/urisys/blob/main/docs/MESH.md)** · Model: **[ECOSYSTEM.md](https://github.com/tellmesh/urisys/blob/main/docs/ECOSYSTEM.md)**

| Pole | Wartość |
|------|---------|
| **Warstwa** | Kontrakty / przykłady |
| **Orchestrator** | [urisys](https://github.com/tellmesh/urisys) |
| **Rola** | Markpact packs, resolver examples, transport binding |

Runtime edge: **`uri_control.edge`** w pakiecie **`uricontrol`** (legacy PyPI `uricore` / `urisysedge` usunięty 2026-06).
Resolver intencji: **`uriresolver`** (`uri_resolver`) + transport w **`uritransport`**; policy gate: **`uriguard`** (`uri_guard`).

<!-- end-ecosystem -->
