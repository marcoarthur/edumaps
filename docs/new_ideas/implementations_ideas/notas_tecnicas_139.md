# Nota técnica 139 — #137 (fatia A): pin da transformação, vigência e card do IVET

Esta nota documenta a **fatia A** do #137: transformar o IVET em **produto
versionado** — fixar (pin) a transformação `raw`→`clean`→`analytics` que o
índice consome, definir o **critério de vigência/retreino** e publicar o **card
do índice**. PR **#269** (merge `7b757db`).

Entregáveis do #137 fechados aqui: **3** (parte de versionamento), **4** e **5**.
Fora de escopo (fatias B/C): extração C–G e reconciliação B↔C.

## Contexto

O lockfile de datasets (`data_pipeline/datasets.lock.json`, #135) fixava só a
**ponta de entrada** (`raw`) — respondia *"de qual versão dos dados veio este
número?"*. Faltava a outra ponta: o **código** que transforma o `raw` nas
camadas derivadas que o IVET lê (`clean`). Sem isso, um número podia mudar
porque a *definição* de uma função/matview mudou — e o lockfile não acusava.

## 1. Pin da transformação — `backend/lib/EduMaps/Ingestion/DatasetsLock.pm`

- `@DERIVED_STEPS`: registry **declarado** (não auto-descoberto) das camadas
  derivadas que o IVET consome:
  | tabela derivada | objeto que a define | kind |
  |---|---|---|
  | `clean.escola_influencia` | `clean.refresh_escola_influencia` | function |
  | `clean.escola_entorno_socioeconomico` | `clean.refresh_escola_entorno_socioeconomico` | function |
  | `clean.mv_escolas_scores` | `clean.mv_escolas_scores` | matview |
- `_catalog()` fotografa o schema `clean` (`pg_class` p/ relkind + viewdef,
  `pg_proc` p/ `pg_get_functiondef`).
- `build_transformations()` produz `{table_name, method, kind, row_count,
  def_sha256}`, ordenado por `table_name`. A chave é o `sha256` da **definição**
  do objeto (não das linhas) + o `row_count` observado.
- `transform_version` = `sha256` do JSON canônico de `{version,
  transformations}`; `dataset_version` **continua** `sha256{version, tables}`
  (compatível). `LOCK_VERSION` 1 → 2.
- `diff()`/`--verify` cobrem as duas pontas; CLI ganha
  `--print-transform-version`.

### Bug real encontrado no deploy do pin

`DBD::Pg` devolve o texto de `pg_get_functiondef` com a flag **utf8 ligada**
(string "wide"), e o `Digest::SHA` recusa hashear wide chars
(`Wide character in subroutine entry`). `build_transformations()` agora
normaliza para **bytes UTF-8** antes de hashear (`utf8::is_utf8 ? encode(...)`),
de forma determinística; há teste de regressão com string acentuada.

## 2. Vigência e retreino — `analysis/edumapsr/R/ivet.R`

- `ivet_lock()` (interno) lê o lockfile; `ivet_transform_version()` expõe a nova
  chave.
- `ivet_v1()` passa a carimbar `dataset_version` **e** `transform_version`
  (parâmetro novo **no fim** da assinatura, sem quebrar chamadas posicionais).
- `ivet_vigencia(resultado, lock_path)` compara o resultado com o lockfile
  corrente nas três dimensões — `formula`, `dataset_version`,
  `transform_version` — e devolve `vigente` + os `motivos` da não-vigência.
  `!vigente` ⇒ o número precisa ser **recalculado** antes de ser lido.

## 3. Card do índice

- `analysis/edumapsr/inst/ivet-card.yml`: ficha legível por máquina (fórmula,
  leitura, blocos, componentes do bloco B, subcomponentes de saneamento, teto de
  renda, proveniência e vigência).
- `ivet_card()` lê o card (`system.file("ivet-card.yml", ...)` por default).
- **Teste de contrato** `test-ivet-card.R`: falha se o card divergir de
  `ivet_versao()`, `ivet_blocos()`, `ivet_blocos_territoriais_minimos()`,
  `ivet_bloco_socioeconomico_componentes()` ou `IVET_TETO_RENDA`. O card não
  pode descrever uma fórmula que o código não implementa.

## Lockfile regenerado

Gerado contra o dev (`database.edumaps`), agora `version: 2`, 49 tabelas + 3
transformações:

```
dataset_version   a33c32ab…d1375d
transform_version 4b66f4c2…9c8198
clean.escola_entorno_socioeconomico  function  470.448 linhas
clean.escola_influencia              function  470.448
clean.mv_escolas_scores              matview   180.540
```

O `--write` roda no `backend.edumaps` (o `ubaxala` não tem rota para
`172.19.198.3`); o arquivo é copiado de volta para o repo. `--verify` contra a
mesma base ficou **sem deriva**.

## Validação

| Checagem | Resultado |
|---|---|
| `backend/t/05-tasks/datasets_lock.t` | **48/48** (inclui wide/UTF-8 e deriva da transformação) |
| `analysis/edumapsr` `test_local(filter="ivet")` | **98/98** (`test-ivet.R`, `test-ivet-socioeconomico.R`, `test-ivet-card.R`) |
| `datasets_lock.pl --write` + `--verify` no dev | sem deriva |

## Deploy

`rex prepare` + `deploy_db_dev` + `deploy_backend_dev` + `deploy_minion_dev` +
`deploy_analytics_dev`. md5 do código/deploy confere nos 3 hosts
(`DatasetsLock.pm`, `datasets_lock.pl`, `datasets.lock.json`, `ivet.R`,
`ivet-card.R`). Imagens locais `sqitch`/`backend`/`minion`/`analytic`
reconstruídas e `docker compose up -d`; md5 dentro do container confere e o
`edumaps-sqitch` saiu 0.

## Decisões de desenho

- **Registry declarado, não auto-descoberto**: o catálogo tem centenas de
  funções; pinar só as que o IVET lê é explícito e auditável. Camada nova que o
  índice consumir entra em `@DERIVED_STEPS`.
- **Hash da definição, não do conteúdo**: fixa o código sem custo e sem depender
  da ordem física dos registos; o `row_count` cobre a materialização.
- **`dataset_version` inalterado na semântica**: o pin da transformação é uma
  chave irmã, não substitui a da entrada.
- **Card no código, com teste de contrato**: evita o slide desatualizado.

## Pendências

- Fatias **B/C** do #137: extração C–G e reconciliação B↔C. O IVET segue **sem
  materialização no banco** (`with_vulnerability_score` continua `die`).
- **#268**: o conteúdo de renda no produto exige re-executar o loader + o refresh
  do entorno (~5–6 h); até lá `renda_resp_media` é `NULL` e o bloco B agrega
  instrução+saneamento.
