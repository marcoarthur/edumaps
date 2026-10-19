# Nota técnica 154 — bloco F nacional: falha silenciosa, OOM e a calibração dos tetos

O bloco **F (meio ambiente)** do IVET dependia de uma corrida de ingestão nacional
que **nunca terminava**: o log dizia "FIM UF" com sucesso, mas UFs inteiras
(SP/RJ/PE) ficavam **sem dado**. Investigar revelou **três defeitos encadeados**
na extração de risco; corrigi-los (PR #288) permitiu **fechar o F no país** e,
com a amostra completa, **calibrar os tetos provisórios** no p99 nacional
(PR #289). Este ciclo fecha os dois lados.

Issues de contexto: **#278** (exposição a risco do F), **#137** (IVET como
produto versionado), **#154** (ausência ≠ 0).

## Entregas

| PR / commit | Merge | Escopo |
|---|---|---|
| **#288** | `a6c9731` | `a7ebaa0` `fix(backend)` sinal de morte conta como falha · `8cf932f` `fix(backend)` lotes de 400 buffers |
| **#289** | `4134346` | `a5dd193` `fix(analysis)` calibra tetos no p99 nacional · `1ffd560` `docs(analysis)` 2ª medição |

## 1. A falha silenciosa (três defeitos, um sintoma)

O sintoma era um só — **blocos pendentes sem erro** —, mas a causa era uma
corrente:

1. **OOM no R.** `terra::extract(weights=TRUE)` materializa ~35 mil células de
   30 m por buffer de 1 km; num bloco grande o `Rscript` era **morto pelo OOM
   killer** (`SIGKILL`).
2. **O exit code mentia.** O job só olhava `$? >> 8`; um filho morto por
   **sinal** dá `exit 0` quando o `dash` faz `exec` do `Rscript`. O bloco era
   marcado como bem-sucedido **sem que o R terminasse**.
3. **O CSV tinha nome fixo.** O CSV não era limpo antes do R; um R morto deixava
   o **CSV do bloco anterior** e o loader **relia dado velho** (o SC foi relido
   3×).

O invariante que expôs os blocos doentes foi **`CSV + Órfãos == Buffers
exportados`** (506/506 blocos saudáveis na 1ª passada) — barato de conferir e
imune ao exit code.

## 2. O fix: lotes de 400 + sinal + CSV limpo

- **`_abortar_se_morreu_por_sinal`** (`Base.pm`) checa `$? & 127` **antes** de
  `>> 8` e aborta com dica de `SIGKILL`/OOM/SEGV; usada em `run_r_script` e
  `run_perl_script` (saída do R logada). A duplicata legada em `Job.pm` recebeu o
  mesmo cheque inline.
- **`MapBiomasRisco`** exporta os buffers em **lotes de ≤ 400** (lote 1 no
  caminho base, seguintes `_l<N>.geojson`), roda o R por lote, faz `unlink` do
  CSV/órfãos antes de cada lote e confere **`linhas + órfãos == buffers`**
  (`conferir_lote`), morrendo se não fechar.

Sem mudança de matemática (a extração é a mesma, só fatiada) e sem migration.

## 3. A corrida nacional fechou

Reprocesso das UFs que faltavam, em `backend.edumaps`, com o código novo:

| UF | buffers | lotes | tempo | falhas |
|---|---|---|---|---|
| SC | — | — | já zerado | 0 |
| RJ | 5.846 | — | 1 h 10 min | 0 |
| PE | 2.136 | — | 5 min | 0 |
| SP | 11.147 | 28 | 23 min | 0 |

**Pendentes do F no país = 0.** `clean.mapbiomas_escola_risco` passou de 121.775
para **156.816 escolas** (censo 2025, raio 1 km, ano 2020). O guarda (2) é o que
garante o "blocos com falha: 0" em cada UF.

> **Throughput — o que *não* era.** A "lentidão superlinear" de
> `extract(weights=TRUE)` foi medida como **contenção de CPU** (experimentos
> paralelos + job), não patologia do `terra`: no experimento controlado, os
> mesmos 50 buffers deram **1,3 s** sem carga (contra 39,6 s sob contenção).
> `weights=TRUE` vs `FALSE` difere em **0,0004** no máximo — sem mudança no R.
> O agrupamento por paridade não trouxe ganho; a hipótese de sobreposição caiu.

## 4. Tetos calibrados no p99 nacional

Com a amostra completa (n = 156.816), os tetos provisórios (fogo = 1,
carbono = 500 — calibrados só no recorte SP/MG) foram trocados pelo **p99**:

| componente | antes | agora | p50 | p90 | p99 | máx |
|---|---|---|---|---|---|---|
| `risco_fogo` | 1 | **2,463** | 0,006 | 0,320 | 2,463 | 16,345 |
| `carbono_solo` (tC/ha) | 500 | **705,98** | 233,6 | 485,7 | 705,98 | 2.833,8 |

**Só as constantes** — sem mudança de fórmula nem de versão `ivet-v1.2`. A
direção dos componentes não muda: fogo entra direto (`freq/teto`), carbono e
vegetação entram invertidos (`1 − c/teto`).

## 5. Re-medição nacional

| | 1ª (provisório) | 2ª (p99 nacional) |
|---|---|---|
| publicáveis (C+D+E) | 145.732 | 145.732 |
| cobertura **F** | 46.923 (parcial) | **145.734** (nacional) |
| `ivet` p50 | 0,339 | **0,3441** |
| `ivet` p90 | 0,418 | 0,4082 |
| `ivet` máx | 0,634 | 0,6022 |

As duas medições ficam **muito próximas** (p50 +0,005): o F é **1 de 7** blocos
do agregado e a calibração move os componentes em **direções opostas** (o fogo
cai com o teto maior; o carbono sobe, porque `1 − c/teto` cresce quando o teto
cresce). A **vegetação natural** do F segue só no **ES**, logo o F nacional é
lido como **fogo+solo**.

## 6. Achado em aberto: 690 negativos de carbono

**690 linhas** de `clean.mapbiomas_escola_risco` têm `solo_carbono_medio < 0`
(mín **−211,05**) — artefato de nodata. Hoje elas saturam no **pior** carbono
(componente = 1,0), o que empurra 0,44% das escolas para cima. Não muda a
calibração (o p99 ignora a cauda inferior), mas é um viés de correção simples
(guardar negativo → `NA`, coerente com #154). **Fica para change própria** —
vencer a semântica sem alarde.

## 7. Validação

- **Backend**: `t/05-tasks/job_base_scripts.t` (novo, sinal vs exit code) e
  `mapbiomas_risco_loader.t` (lotes + guarda) **59/59 PASS**; vizinhos
  `mapbiomas_escola_loader.t` + `ingestion_runner.t` **64/64 PASS**; `perl -c` OK.
- **Análise**: suíte R `filter="ivet"` **verde** (389 asserções); a suíte completa
  só tem as **2 falhas pré-existentes** (`test-censo-dictionary.R:112`,
  `test-cluster.R:96`), reproduzidas na árvore limpa.
- **Deploy**: `rex prepare` + `deploy_backend_dev`, md5 local == remoto; o F fechou
  com 0 falhas. `rex prepare` + `deploy_analytics_dev`; md5 conferido e tetos
  novos confirmados no pacote instalado.
- **Imagens Docker locais** reconstruídas (`backend`, `minion`, `analytic`).

## Pendências herdadas

- **Carbono negativo** (690 linhas) — guardar → `NA` numa change própria (§6).
- **Mobilidade (C) / isócrona** segue `NA`: sem motor OSRM/Valhalla,
  `clean.isocrona_escolar` vazia.
- **`MapBiomasEscola.pm`** mantém cópia própria de `exportar_buffers` (mesma
  exposição a OOM, hoje protegida só pelo cheque de sinal).
- Filas **#168** (reduzir escopo), **#138** (reavaliar após IVET congelar),
  Fila 6 (**Z:10454**).
