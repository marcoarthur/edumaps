# Nota técnica 133 — #255/#137 (Tier 1): camada de influência da escola

A **metodologia** da área de influência (`influencia-v1`) foi decidida em
2026-10-15 (`docs/analises/influencia.md`, §7). Esta nota cobre o seu **Tier 1**:
a materialização da camada reusável `clean.escola_influencia` — o pré-requisito
comum da **#255** (zonal statistics do MapBiomas 30 m) e dos blocos territoriais
**B–F** do **#137**.

## Contexto

O IVET é um índice **territorial**: os coeficientes descrevem o *entorno* da
escola. Até agora esse entorno **nunca existia como geometria** — o dado
territorial entrava no grão **município** e era repassado uniforme; só o OSM tinha
recorte por escola, num buffer de 500 m pontual. Sem uma geometria canônica, a
**#255** não tinha sobre o que rodar o *zonal statistics* e a **#137** (entregável
3, metade de extração) não tinha de onde puxar o componente.

A metodologia aprovada é **híbrida Tier 0–3**: ponto (0), **buffer** (1),
isócrona (2) e setor censitário (3). O Tier 1 é o mais barato e não cria
dependência externa (nem roteador, nem raster ainda) — por isso foi o primeiro.

## O que foi feito

### Change Sqitch `escola_influencia`

`data_pipeline/deploy/escola_influencia.sql` (append no plano;
`requires: quarantine_censo_escolas_scores, censo_escolar_2025`):

- **Tabela** `clean.escola_influencia(co_entidade, nu_ano_censo, tier, raio_m,
  geom geometry(Polygon,4674), versao, computado_em)` — PK
  `(co_entidade, nu_ano_censo, tier, raio_m)`; `CHECK tier IN ('buffer',
  'isocrona')`, `raio_m > 0`, `ST_IsValid(geom)`; GiST em `geom` e índice
  `(nu_ano_censo, tier, raio_m)`.
- **Função** `clean.refresh_escola_influencia(p_raios integer[] DEFAULT
  ARRAY[500,1000,2000], p_co_entidades bigint[] DEFAULT NULL)`, idempotente
  (UPSERT), devolve as linhas afetadas. `p_co_entidades` permite refresh
  incremental e testes determinísticos.

### Task Minion `refresh_influencia`

`backend/lib/EduMaps/Task/Influencia.pm` — registra a task e um helper; a task
chama a função SQL (com ou sem raios explícitos). Registrado na lista de plugins
em `backend/lib/EduMaps.pm`.

## Decisões de design

- **Buffer em metros via `geography`.** `ST_Buffer(geometry::geography, raio_m)`
  usa o overload de `geography`, que trabalha **em metros**; o de `geometry`
  trabalharia em **graus**. Verificado empiricamente: o SRID **4674** é
  preservado no *round-trip* `geometry → geography → geometry`, e a área de um
  buffer de 500 m dá ~780.700 m² (≈ π·500² menos a aproximação poligonal).
- **`raio_m` (metros) e `co_entidade`, não `raio_km`/`escola_id`.** Alinha com o
  que já existe: `clean.school_osm_feature.raio` é inteiro em metros e a chave
  do pipeline é `co_entidade` (+ `nu_ano_censo`). A proposta original (§5)
  usava `raio_km`/`escola_id`.
- **`nu_ano_censo` na PK** porque a geometria de origem (`clean.censo_escolas`) é
  anual; hoje o snapshot é único (2025), mas o grão certo é anual.
- **POPULAÇÃO FORA DA MIGRATION.** A migration é só DDL; quem popula é o job.
  Motivo: em base recém-deployada (gate de CI) o censo pode estar vazio — o
  `verify` checa **estrutura**, nunca volume (senão o gate de CI quebraria).
- **Buffer é a geometria; a arealização é computada.** Tier 3 (setor) é
  interseção/peso por área — não precisa de coluna nova. Tier 2 (isócrona) reusa
  o mesmo `tier`.
- **Tamanho medido (dev):** 156.816 escolas × 3 raios = **470.448** buffers,
  **~352 MB**; refresh global ~30 s, refresh de uma escola instantâneo.

## Validação

- `backend/t/escola_influencia.t` — 5 subtestes (14 asserts): materialização
  (tier/raio/SRID 4674/versão/polígono), área métrica, corte do raio (**400 m
  dentro, 600 m fora**), idempotência (segundo refresh não duplica) e rejeição de
  raio inválido. **PASS**.
- `backend/t/05-tasks/influencia.t` — wiring: task registrada no Minion e helper
  instalado. **PASS**.
- `t/01-app` — **PASS** (o plugin novo não quebra o boot).
- Deploy local (`dev_docker`): `sqitch deploy` aplicou só `escola_influencia`
  (o resto já estava); `SELECT clean.refresh_escola_influencia()` materializou os
  470.448 buffers.

## Deploy

- `rex prepare` + `rex -H database.edumaps deploy_db_dev` (change Sqitch) +
  `rex -H backend.edumaps deploy_backend_dev deploy_minion_dev` (task).
- Imagens Docker locais `sqitch`, `backend` e `minion` reconstruídas.

## Próximos passos (não nesta nota)

- **#255** — zonal statistics do MapBiomas 30 m sobre `clean.escola_influencia`
  (exige `sf`/`terra` + GDAL no `analytic`).
- **#137** — extração dos componentes territoriais B–F sobre a camada; entrega
  4 (vigência/retreino) e 5 (card do modelo).
- **Tier 2** (isócrona, OSRM/Valhalla auto-hospedado) e **Tier 3** (arealização
  por setor censitário) — upgrades incrementais sobre o mesmo `tier`.
