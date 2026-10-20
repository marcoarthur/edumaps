# Isócrona escolar (piloto ES #278 · expansão Sudeste #295)

Extração e carga da **área de influência por tempo de deslocamento** que
alimenta os componentes `acesso_isocrona` (15 min a pé) e
`acesso_auto_45min` (45 min de carro) do bloco C do IVET
(`docs/analises/ivet.md` §4.5.5). Tabela de destino:
`clean.isocrona_escolar` (grão: escola × tempo × célula H3).

**Status**: piloto no **Espírito Santo** (2.897 escolas, 2026-10-19) e
expansão **ES re-run + MG** (16.797 escolas, 2026-10-20) com tiles do
Sudeste e setores da região. Fora do Sudeste o componente é `NA` no IVET
(#154: ausência nunca vira 0).

## Arquivos

| arquivo | papel |
|---|---|
| `extrair_isocronas.py` | pede as isócronas ao Valhalla e arealiza a população por célula H3 (H3 + shapely; 8 threads) |
| `carregar.sql` | carga idempotente em `clean.isocrona_escolar` (temp table + DELETE/INSERT) |
| `piloto_es.sh` | driver de ponta a ponta: exporta → extrai → carrega → resume |

O driver roda do repo, mas **exporta/carrega via `ssh root@database.edumaps`**
(o host local não alcança o Postgres do LXC). Os artefatos do piloto (CSVs,
extract OSM, tiles) ficam **fora do repo**, em `~/Code/Data/osm/`.

## Pré-condição: Valhalla auto-hospedado (fora do repo)

O motor **não** é parte do deploy (os hosts LXC não têm Docker); roda em
Docker no host local `ubaxala`:

```bash
cd ~/Code/Data/osm
# extract de ES a partir do Geofabrik Sudeste (osmium)
osmium extract -b -42.0,-21.5,-39.6,-17.7 sudeste-latest.osm.pbf -o es.osm.pbf
# tiles + config (valhalla.json com listen em tcp://0.0.0.0:8002)
./build_valhalla.sh                       # defaults: es.osm.pbf → valhalla/
docker run -d --name valhalla-es -p 8002:8002 \
  -v "$PWD/valhalla:/tiles" --entrypoint bash \
  ghcr.io/gis-ops/docker-valhalla/valhalla:latest \
  -lc 'valhalla_service /tiles/valhalla.json'
curl -s localhost:8002/status   # deve listar "isochrone" em available_actions
```

Para a expansão (#295) usa-se o **extract do Sudeste inteiro** (ES+MG+RJ+SP,
já baixado como `sudeste-latest.osm.pbf`) — os tiles precisam cobrir a região
toda, senão a isórona de 45 min é truncada na fronteira estadual:

```bash
./build_valhalla.sh sudeste-latest.osm.pbf valhalla_sudeste
docker run -d --name valhalla-sudeste -p 8003:8003 \
  -v "$PWD/valhalla_sudeste:/tiles" --entrypoint bash \
  ghcr.io/gis-ops/docker-valhalla/valhalla:latest \
  -lc 'valhalla_service /tiles/valhalla.json'
```

(O diretório de tiles precisa de permissão 777: o container não roda como
root e o build falha com `Permission denied`.)

## Rodando o piloto

```bash
# piloto original (ES, setores só do ES, tiles só do ES)
VALHALLA=http://localhost:8002 UF=ES bash db/isocrona/piloto_es.sh

# expansão regional: mesma rodada cobre ES re-run + MG sob tiles do Sudeste
export SETORES_UFS=ES,MG,RJ,SP          # setores da REGIÃO (corrige a borda)
VALHALLA=http://localhost:8003 UF=MG \
  TRABALHO=~/Code/Data/osm/piloto_mg bash db/isocrona/piloto_es.sh
```

Passos: (1) exporta as escolas do universo do IVET (Censo 2025, ativas, com
lat/long e cobertas pelo job MapBiomasRisco) e os setores censitários da
região; (2) pede a isócrona de **15 min a pé** e **45 min de transporte** de
cada escola e soma a população das células; (3) carrega; (4) resume contagens.

Ambientes do driver:

| variável | padrão | papel |
|---|---|---|
| `SETORES_UFS` | `$UF` | UFs de onde saem os setores. A **região inteira** é o que corrige o viés de fronteira: célula em UF vizinha precisa dos setores (população) e das estradas (tiles) dela. |
| `SNAPSHOT` | hoje | `dt_snapshot` da carga. **Todas as UFs de uma rodada precisam do mesmo valor** — a view nacional do IVET filtra por `max(dt_snapshot)` e um snapshot divergente faz a UF antiga sumir do painel. |
| `TILESET_BUILD_DATE` | `$SNAPSHOT` | data de build dos tiles, para a proveniência. |
| `TRABALHO` | `~/Code/Data/osm/piloto` | diretório dos artefatos (use um por UF). |

Para uma UF fora do Sudeste: baixar o extract da região (Geofabrik),
construir tiles cobrindo a UF **e as vizinhas**, subir um container e rodar
com `UF=<UF>` e `SETORES_UFS` da região (o driver não cria tiles). BA, por
exemplo, exige o extract do Nordeste (#295).

## Decisões de design

- **Grade H3 por isócrona**: r9 (~0,105 km²) para 15 min a pé (18–25 células por
  escola) e r7 (~5,16 km²) para 45 min de carro (76–313). Medido pela sonda
  `sonda_h3.py` (fora do repo): r9 para o carro daria 10–15 mil células/escola.
  A resolução é gravada por linha (`resolucao_h3`) — o comentário antigo do
  schema dizia "r10 ≈ 1 km", e r10 ≈ 15 ha, não 1 km.
- **Arealização**: `populacao_grade = Σ_setor pop_total × (área da interseção /
  área do setor)`. Setor sem `pop_total` não contribui (#154); se **nenhum**
  setor intersectado tem população, a célula fica `NULL`, não 0.
- **Ausência ≠ 0 (#154)**: escola sem rede de ruas no ponto (`400` do
  Valhalla) **não vira linha** — o IVET lê `NULL` e o componente sai do
  denominador. Nenhuma escola do ES caiu nesse caso.
- **Proveniência gravada por carga**: `tileset_origin`,
  `tileset_build_date`, `engine`/`engine_version` (medido em `GET /status`) e
  `dt_snapshot` — o IVET usa o snapshot mais recente.
- **Fronteira estadual (viés corrigido na expansão)**: os dois primeiros
  loads exportavam setores só da UF-alvo e usavam tiles só de ES — célula em
  UF vizinha ficava `NULL` e a estrada que cruza a fronteira não existia.
  Corrigido carregando **setores da região** (`SETORES_UFS`) e usando **tiles
  da região inteira** (extract Sudeste). Resta a borda com UF fora do
  Sudeste (MG↔BA), resolvida quando o extract do Nordeste entrar (#295).

## Resultado do piloto (2026-10-19)

| medida | valor |
|---|---|
| escolas carregadas | 2.897 de 2.897 (100%; nenhuma sem rede) |
| linhas | 711.815 (15 min: 44.836 ≈ 15 células/escola; 45 min: 666.979 ≈ 224) |
| células com população | 97,3% (19.546 NULL por setor desconhecido — #154) |
| `Σ pop` a pé 15 min | p50 = 4.325 · p90 = 19.871 · p99 = 40.590 · máx = 60.984 |
| `Σ pop` de carro 45 min | p50 = 168.496 · p99 = 1.765.458 |

O **teto provisório** do componente (`IVET_TETO_ACESSO_15MIN` = 40.000) veio do
p99 da coluna de 15 min e está registrado no card e em
`docs/analises/ivet-coeficientes.md` §5.1.

## Resultado da expansão ES+MG (2026-10-20, #295)

Mesma rodada, snapshot único `2026-10-20`, setores da região
(`SETORES_UFS=ES,MG,RJ,SP`) e tiles do **Sudeste inteiro** (1.546 tiles,
`valhalla-sudeste` :8003). O MG exigiu **retomada** (`--retomar`): o primeiro
run morreu por SIGKILL silencioso (provável OOM) a 9.455/13.900 — a escrita
incremental do CSV preservou tudo.

| medida | valor |
|---|---|
| escolas carregadas | 16.796 (MG 13.899 + ES 2.897; 1 MG sem rede → `NULL`, #154) |
| linhas | 4.788.919 (15 min: 297.893 · 45 min: 4.491.026) |
| células com população | **99,72%** (era 97,3% no piloto ES) |
| escolas >20% células `NULL` | **5** (eram 125) · >50%: 1 (eram 10) · média 0,30% |
| `Σ pop` a pé 15 min | p50 = 5.390 · p90 = 20.996 · **p99 = 39.339** · máx = 60.984 |
| `Σ pop` de carro 45 min | p50 = 169.471 · p90 = 4.567.800 · **p99 = 4.889.715** |

**Tetos recalibrados** (`IVET_TETO_ACESSO_15MIN` = 40.000 mantido — p99
39.339; `IVET_TETO_ACESSO_45MIN` **1.750.000 → 5.000.000** — p99 triplicou
com MG). Restam as 5 escolas de borda **MG↔BA**: BA fica de fora até o
extract do Nordeste (mesma #295).

## Limitações (pós-expansão)

- Cobertura ainda parcial (ES+MG); os tetos do componente são
  **provisórios** (p99 do que está carregado) e recalibram a cada ampliação
  da cobertura. RJ/SP já têm tiles e setores prontos (rodar é só tempo);
  BA exige extract Nordeste + tiles próprios.
- Isócrona de transporte = **carro** (`costing: auto`), não transporte
  coletivo — o Valhalla sem dados de transit não modela ônibus/trem.
- População é do **Censo 2022** por setor censitário; a precisão da
  arealização cai em setores gigantes rurais (mesma ressalva do Tier 3 de
  `docs/analises/influencia.md`).
