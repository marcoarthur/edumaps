# Nota técnica 149 — #278: exposição a risco (bloco F) — Fogo + Solo

Esta nota documenta a extração da **exposição a risco** do bloco F do IVET
(**MapBiomas Fogo** e **MapBiomas Solo**) sobre a área de influência da escola.
Issue **#278**.

## Contexto

A #278 pedia completar o IVET (exposição a risco do F + a isócrona de C). A
decisão de produto (2026-10-18) foi começar pela **exposição a risco**, com
**queimada + carbono do solo**; a isócrona fica para depois (infra de roteamento).

## O que foi medido (e o que mudou o plano)

1. **O ISH/risco climático e a declividade NÃO estão no bucket público.** A ficha
   `fontes/meio-ambiente.md` projetava `risco_hidrico_escola` (Índice de Segurança
   Hídrica) e `declividade_terreno_escola` — mas o `mapbiomas-public` **não
   publica** esses produtos. O que existe é **Fogo** e **Solo** (carbono).
2. **Os rasters têm ~2 GB cada** e o host de ingestão tem ~3 GB livres → **não dá
   para baixar**. Leitura em *streaming* pelo GDAL via **`/vsicurl`** (HTTP range),
   com **recorte à AOI** (`terra::crop`) antes de extrair. Sem o recorte, a leitura
   polígono a polígono é lenta demais (medido: 539 buffers > 30 min, sem terminar).
3. **⚠️ O caminho do fogo importa.** `brasil/fire/frequency/…` e
   `brasil/fire/coverage-frequency-1/…` têm o **mesmo nome de arquivo**, mas
   unidades diferentes: `frequency/` dá valores `0, 115, 121, …, 3541` (não são
   anos); `coverage-frequency-1/` dá `0–35` (o nº de anos em que o pixel ardeu,
   1985–ANO) — **esse** é o produto. A URL foi corrigida e o erro documentado no
   cabeçalho do job.

## O que foi feito

- **Migration** `mapbiomas_escola_risco`: `clean.mapbiomas_escola_risco`
  (grão escola × ano do Censo × ano × raio) com
  `fogo_frequencia_media`, `fogo_frequencia_max`, `fogo_fracao_queimada` e
  `solo_carbono_medio`. Vazio ≠ zero (#154): sem interseção com um raster, a
  coluna é `NULL`; sem nenhum indicador, não há linha.
- **Job** `MapBiomasRisco` + **script R** `extract_mapbiomas_risco.R`
  (`terra::extract`, `weights=TRUE`; modo `--dados` testável).
- **Allowlist**: `…/mapbiomas-public/brasil` (fogo/solo — antes só
  `…/initiatives/brasil`).
- **Aplicação gradual** — `backend/script/ingestao/`:
  - `mapbiomas_risco.sh <UF> [ano] [raio] [região]` — roda **por região imediata**
    (lista de municípios via `--arg municipios=`), idempotente.
  - `regioes_do_estado.pl` — lista as regiões imediatas da UF
    (`clean.municipios_sp.nome_regiao_imediata`).
  - ⚠️ O nome da região vem do banco em **latin1**; o helper agora emite **UTF-8**
    (senão o filtro de região nunca casa).

## Dois defeitos de *chunking* corrigidos

A extração em blocos expôs um defeito nos dois jobs de raster (**#255** e
**#278**): o `DELETE` do recorte era por **ano × raio**, não por escola — cada
bloco (região) **apagaria os blocos anteriores**. Corrigido: o `DELETE` é
escopado às **co_entidades da carga** (`co_entidade = ANY(...) AND ano = ANY(...)
AND raio_m = ?`).

## Validação

Bloco **Vale do Paraíba / São José dos Campos** (SP, 2020, raio 1 km), rodado em
`backend.edumaps` pelo `script/ingestao/mapbiomas_risco.sh` (1459 s, um bloco):

| métrica | resultado |
|---|---|
| linhas | **684** (684 buffers) |
| com `fogo_*` / `solo_carbono_medio` | **684 / 684** |
| `fogo_frequencia_media` média | 0,068 |
| `fogo_frequencia_max` | **19** (≤ 36 ✓ — confirma a URL `coverage-frequency-1`) |
| `fogo_fracao_queimada` média | 0,039 |
| `solo_carbono_medio` média | 197 tC/ha (24–646) |
| proveniência | `ok`, `row_count_loaded=684` |

⚠️ Com a URL antiga (`frequency/`) o `fogo_frequencia_max` saía **1941** — o
sinal de que o produto estava errado.

## Pendências

- **Pesos do bloco F** — não definidos (fila de revisão de
  `ivet-coeficientes.md` §5). O F não é bloco mínimo (C+D+E), então não bloqueia
  o agregado.
- **Isócrona (C)** — OSRM/Valhalla (piloto de 1 UF cabe; nacional não).
- **Velocidade**: `/vsicurl` + crop dá ~1,8 s/buffer; o gargalo é ler a AOI de um
  raster de 2 GB por bloco. Acelerar exige baixar o raster uma vez num volume
  maior (ou um mosaico nacional menor).
