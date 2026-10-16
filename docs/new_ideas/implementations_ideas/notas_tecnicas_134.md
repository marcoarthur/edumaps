# Nota técnica 134 — #255/#137 (Tier 1): painel "Área de influência (IVET)"

A **camada** reusável da área de influência da escola
(`clean.escola_influencia`, metodologia `influencia-v1`) foi materializada no
ciclo anterior (NT_133, PR #260). Esta nota cobre o passo seguinte: **torná-la
visível** — um endpoint autenticado e um painel/mapa no módulo do gestor. É a
continuação direta do Tier 1; nenhuma mudança de schema.

## Contexto

O Tier 1 produzia **geometria** (buffers de 500/1000/2000 m por escola) mas não
havia como inspecioná-la. A #255 (zonal statistics do MapBiomas 30 m) e a
extração dos componentes territoriais B–F da #137 **consomem** essa camada; sem
uma leitura verificável, qualquer erro de projeção/área passaria despercebido
até virar coeficiente do IVET.

O painel serve a dois propósitos: (1) **validação visual** da camada (a
geometria materializada, o SRID, a área medida); (2) dar ao gestor a leitura da
sua própria escola — restrita por LGPD.

## O que foi feito

### Backend (leitura somente)

`backend/lib/EduMaps/Model/Influencia.pm` — três métodos, todos de leitura:

- `escola_localizacao($co_entidade, $nu_ano_censo?)` — ponto da escola
  (`latitude`/`longitude`) de `clean.censo_escolas`, para desenhar junto aos
  buffers.
- `geojson($co_entidade, $nu_ano_censo)` — `FeatureCollection` com um polígono
  por raio, ordenado do menor para o maior, cada um com `raio_m`, `tier`,
  `versao`, `area_km2` (medida) e `computado_em`.
- `status($co_entidade, $nu_ano_censo?)` — proveniência (versão, tier,
  `computado_em`, lista de raios) + localização + geometria. **Devolve `undef`**
  quando não há linha na camada.

`Controller/Gestor.pm#influencia` — guarda `_gestor_inep_ok` (o gestor só lê a
própria escola; LGPD, §4 de `docs/analises/influencia.md`) e responde **404**
`'Área de influência ainda não calculada para esta escola'` quando o modelo
devolve `undef`.

Rota `GET /api/gestor/:cod_inep/influencia` em `Plugin/API/Gestor.pm`, sob
`$auth`, após as rotas OSM.

### Frontend (Svelte 5 + Leaflet)

Em `frontend/edumaps/src/features/gestor/`:

- `constants/influencia.js` — raios, labels, cores e formatadores (+ teste).
- `api/gestorApi.js#getInfluencia` (+ teste).
- `components/InfluenciaMap.svelte` — desenha os polígonos do GeoJSON e o ponto
  da escola.
- `components/InfluenciaPanel.svelte` (+ `InfluenciaPanel.test.js`) — estado,
  proveniência e mapa.
- `mocks/influenciaFixtures.js` / `influenciaHandlers.js` — MSW, registados em
  `src/mocks/handlers.js`.
- `GestorPanel.svelte` — entrada NAV `#influencia` e `<InfluenciaPanel {inep} />`
  após `OsmPoisPanel`.

## Decisões de design

- **O mapa desenha a camada, não um círculo recalculado no cliente.** A
  geometria vem do banco via `ST_AsGeoJSON` — o que se vê é *a* geometria
  materializada, com o SRID **4674** já embutido no round-trip. Recalcular
  `L.circle(raio)` no cliente esconderia justamente o erro que o painel existe
  para pegar.
- **Área medida, não π·r².** `area_km2 = ST_Area(geom::geography)/1e6`. O raio
  de 500 m aparece como ≈ **0,7804 km²** (a aproximação poligonal do buffer), não
  0,7854 — a diferença é sinal de que a medida é real.
- **Ausência ≠ zero (#154).** Sem linha na camada, o endpoint devolve **404** e
  o painel diz "ainda não calculada" — nunca um buffer vazio nem zero implícito.
  É a mesma regra que rege o resto do produto.
- **Guarda LGPD no controller, não na query.** A leitura é restrita ao gestor da
  própria escola (`_gestor_inep_ok`), coerente com `docs/analises/influencia.md`
  §4; o IDOR é coberto por teste.
- **`nu_ano_censo` opcional; default = mais recente materializado.** A geometria
  de origem é anual (`clean.censo_escolas.nu_ano_censo`); hoje o snapshot é
  único (2025), mas o parâmetro já existe.

## Validação

- **Backend** `backend/t/04-api/gestor/influencia.t` — 5 subtestes:
  **401** (sem sessão), **403** (escola alheia), **404** (não calculada),
  **200** (com dados) e IDOR. Usa INEPs sintéticos `99000001`/`99000002` e limpa
  censo + influência + `clean.sessoes` + `clean.session_tracking` +
  `clean.gestores` (não polui a base). **PASS**.
- **Frontend**: feature gestor **48 arquivos / 482 verdes**; suíte completa
  **112 arquivos / 960 verdes**.
- **CI PR #261**: `vitest (jsdom + MSW)` PASS (2m6s) e `Perl contra o banco de
  fixtures` PASS (8m34s).
- **Endpoint real** (dev, INEP `33179107` = `0227006 EM LUIZ PAULO HORTA`/RJ):
  devolveu `tier=buffer`, `versao=influencia-v1`, raios **500/1000/2000** e **3
  polígonos**; área do raio de 500 m ≈ **0,7804 km²**.
- **Validação visual do developer** em
  `http://localhost:8080/gestor/painel?inep=33179107` (login descartável),
  **antes** do PR.

## Deploy

- `rex prepare` + `rex -H backend.edumaps deploy_backend_dev deploy_frontend_dev`
  (exit 0). md5 do modelo confere local↔produto; bundle novo
  (`index-DzPfpVB5.js`) contém "Área de influência (IVET)"; `edumaps-web` e
  `nginx` ativos.
- `deploy_minion_dev` **não** foi necessário (nenhum job/task mudou) e
  `deploy_db_dev` também não (a camada já fora deployada em #260).
- Imagens Docker locais `sqitch`/`backend`/`minion`/`frontend` reconstruídas
  antes do merge; md5 host↔container confere.

## Próximos passos (não nesta nota)

- **#255** — zonal statistics do MapBiomas 30 m sobre `clean.escola_influencia`
  (exige `sf`/`terra` + GDAL no `analytic`). O painel dá o insumo visual para
  conferir a arealização quando ela existir.
- **#137** — extração dos componentes B–F sobre a camada; entregáveis 4
  (vigência/retreino) e 5 (card do modelo).
- **Tier 2** (isócrona, OSRM/Valhalla auto-hospedado) e **Tier 3** (arealização
  por setor censitário) — upgrades incrementais que reusam o mesmo `tier`; o
  painel já os exibirá sem mudança de contrato.
