# markpact-contracts

Extracted UriPack Markpact contracts from [tellmesh/urisys](https://github.com/tellmesh/urisys).

Kontrakty są walidowane i uruchamiane przez **urisys**; runtime to **uricore** + **urirouter** (resolver examples w `packs/examples/`).

Mapa ekosystemu: [urisys/docs/MESH.md](https://github.com/tellmesh/urisys/blob/main/docs/MESH.md)

## Validate

```bash
cd ../urisys
bash ../markpact-contracts/scripts/validate-all.sh
```

## Publish (markpact.com portal)

Requires `MARKPACT_TOKEN`:

```bash
MARKPACT_TOKEN=... bash scripts/publish-all.sh
```

## Ekosystem TellMesh

Orchestrator: **[urisys](https://github.com/tellmesh/urisys)** · Mapa: **[MESH.md](https://github.com/tellmesh/urisys/blob/main/docs/MESH.md)** · Model: **[ECOSYSTEM.md](https://github.com/tellmesh/urisys/blob/main/../docs/ECOSYSTEM.md)**

| Pole | Wartość |
|------|---------|
| **Warstwa** | Kontrakty / przykłady |
| **Orchestrator** | [urisys](https://github.com/tellmesh/urisys) |
| **Rola** | Markpact packs, resolver examples, transport binding |

Runtime edge: **`uri_control.edge`** w pakiecie **`uricore`** (legacy `urisysedge` usunięty 2026-06).
Router intencji: **`urirouter`** (`uri_router`) — resolve + HTTP/MQTT delegate.

<!-- end-ecosystem -->
