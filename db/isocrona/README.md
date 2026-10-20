# Isócrona escolar (piloto ES — #278)

Extração e carga da **área de influência por tempo de deslocamento** que
alimenta o componente `acesso_isocrona` do bloco C do IVET
(`docs/analises/ivet.md` §4.5.5). Tabela de destino:
`clean.isocrona_escolar` (grão: escola × tempo × célula H3).

**Status**: piloto no **Espírito Santo** (2.897 escolas, 2026-10-19). Fora do
piloto o componente é `NA` no IVET (#154: ausência nunca vira 0).

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
./build_valhalla.sh
docker run -d --name valhalla-es -p 8002:8002 \
  -v "$PWD/valhalla:/tiles" --entrypoint bash \
  ghcr.io/gis-ops/docker-valhalla/valhalla:latest \
  -lc 'valhalla_service /tiles/valhalla.json'
curl -s localhost:8002/status   # deve listar "isochrone" em available_actions
```

## Rodando o piloto

```bash
VALHALLA=http://localhost:8002 UF=ES bash db/isocrona/piloto_es.sh
```

Passos: (1) exporta as escolas do universo do IVET (Censo 2025, ativas, com
lat/long e cobertas pelo job MapBiomasRisco) e os setores censitários da UF;
(2) pede a isócrona de **15 min a pé** e **45 min de transporte** de cada
escola e soma a população das células; (3) carrega; (4) resume contagens.

Para outra UF: exportar o extract com `osmium`, reconstruir os tiles, subir um
container novo e rodar com `UF=MG` (o driver não cria tiles).

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
- **45 min de carro cruza a fronteira** do ES (MG/BA), mas só os setores do ES
  estão carregados; células de borda sem setor ficam com
  `populacao_grade = NULL`. Isso afeta só a coluna de 45 min (extraída e
  armazenada, ainda fora da fórmula).

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

## Limitações do piloto (a documentar na expansão)

- Cobertura de uma UF; o teto do componente é **provisório** (p99 do piloto)
  e é recalibrado quando o acesso passa a nacional.
- Isócrona de transporte = **carro** (`costing: auto`), não transporte
  coletivo — o Valhalla sem dados de transit não modela ônibus/trem.
- População é do **Censo 2022** por setor censitário; a precisão da
  arealização cai em setores gigantes rurais (mesma ressalva do Tier 3 de
  `docs/analises/influencia.md`).
