# Nota técnica 68 — Mapas sem tiles: troca do CDN de tiles (CARTO → OSM)

**Data**: 2026-09-28
**PR**: #104 (`fix/frontend-tiles-osm`)
**Área**: frontend (`frontend/edumaps` + `frontend/map_app` legado)

## Problema

O usuário relatou que os mapas Leaflet renderizados no frontend estavam
**todos sem os tiles**, com uma **tarja pedindo para definir a chave API**
("API key"). Ocorria tanto no deploy (`http://ubatexu.lan:8080`) quanto no
localhost.

## Diagnóstico

A tarja "defina sua chave API" é a assinatura típica de um servidor de
tiles que **exige chave de API** quando não recebe uma chave válida. Na raiz:

- `LeafletMap.svelte` (componente único de mapa do `edumaps`) usava o CDN
  público `https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png`
  como `tileUrl` default.
- O `edumaps` **não passa `tileUrl` custom em nenhum caller**
  (SimilarSchoolsSearch, SchoolMap, NetworkSchoolMap, ClusterSchoolMap usam
  todos o default), nem há override por env (`VITE_*` ausente). Logo, todos
  os mapas dependiam do CARTO.
- O legado `map_app/AnalBaseMap.svelte` também usava o mesmo CDN CARTO.

## Solução

Trocar o tile layer para o **OpenStreetMap** (`tile.openstreetmap.org`),
que **não exige chave**:

| Arquivo | Antes | Depois |
|---|---|---|
| `LeafletMap.svelte` | `https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png` + attribution CartoDB | `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png` + `© OpenStreetMap contributors` |
| `AnalBaseMap.svelte` (legado) | idem CARTO (`subdomains: 'abcd'`) | OSM (`subdomains: 'abc'`) |

Mudança de **1 linha por componente** — como não há `tileUrl` custom nos
callers, a troca do default corrige todos os mapas de uma vez.

## Validação

- **Unit tests** (docker `node:22-slim`): 26 arquivos / 138 testes ✅
  (inclui `LeafletMap.test.js`).
- **Deploy** (`rex prepare` + `deploy_frontend_dev`): bundle novo
  `index-CWm3qagX.js`; `grep cartocdn` → **0 ocorrências**; a única
  `tileUrl` presente é a OSM.
- **E2e Chrome CDP** (`:9333`, alvo `ubatexu.lan:8080`, fluxo "Buscar
  escolas similares"): 15/15 tiles OSM carregados (hosts
  `a/b/c.tile.openstreetmap.org`), **17 respostas HTTP 200 `image/png`**,
  0 falhas, `keyTexts: []`, `tileErrorCls: false` — tarja ausente.
- Rodada registrada em `docs/e2e/cobertura.md`.

## Decisões de design

1. **OSM no lugar de CARTO**: escolha do usuário. OSM segue sem chave,
   estável e já era usado pelo legado (`map_app` usava OSM em
   `Map.svelte`/`OSMBaseLayer.svelte`), então é o padrão consistente do
   projeto.
2. **Troca no default, não por caller**: mantém os mapas uniformes e evita
   regressões de "um mapa com provider X, outro com Y".
3. **`subdomains` ajustado** no legado (`abcd` → `abc`): OSM usa `a/b/c`;
   o default do Leaflet (`abc`) é suficiente; o campo foi mantido explícito
   por clareza.

## Lições / observações

- O sintoma "tarja exigindo chave de API" é um **sinal RÁPIDO** de que o
  tile provider da aplicação passou a exigir chave (ou a chave embutida
  expirou). Vale revisar os CDNs de tiles em qualquer futuro provider swap.
- Investigação e2e inicial não reproduzia o erro (tiles CARTO respondiam
  200 no ambiente de teste); a confirmação veio por **screenshots do
  usuário** + o direcionamento dele para a causa (URL do tile layer). Isso
  reforça: nem sempre o bug reproduz no ambiente de e2e — o relato do
  usuário + screenshots são evidência de primeira classe.