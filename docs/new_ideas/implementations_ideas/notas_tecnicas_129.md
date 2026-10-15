# Nota técnica 129 — #170 (fechamento): limpeza do MapBiomas pós-#241

Fecha a **#170** como **superseded**. A investigação mostrou que a issue estava
**obsoleta**: o trabalho que ela pedia já tinha sido feito na **#241** (fase P3 da
#156, `CLOSED`), por **decisão explícita do developer** registrada em
`docs/specs/2026-10-13-ingestao-real-plano.md` §8. O que sobrou — e foi entregue
aqui (PR #256, merge `d63363c`) — são as **pendências que não dependem dos dados**.

## Por que a #170 estava obsoleta

O corpo da issue diz "O job `MapBiomas.pm` tem 13 linhas de código". Hoje tem
**310**. A #241 reescreveu-o para ler a **estatística oficial da Coleção 10** do
MapBiomas (`MAPBIOMAS_BRAZIL-COL.10-BIOME_STATE_MUNICIPALITY.xlsx`, 78 MB,
bucket público, **sem token**), via **GDAL** (driver XLSX), no grão
**município × classe × ano** (biomas somados), anos **2015–2024**. O defeito
apontado (baixar malha do IBGE e tratar página web como GPKG) deixou de existir.

Critério a critério:

| # | Critério | Situação |
|---|---|---|
| 1 | URL real verificada | ✅ `HEAD` → **HTTP 200**, `…spreadsheetml.sheet`, **78.609.681 bytes** (feito nesta investigação) |
| 2 | Fonte é MapBiomas, não IBGE | ✅ #241 |
| 3 | Script R de areolização | ⛔ **superado** — a tabela vem da estatística oficial, sem R |
| 4 | Areolização sobre área de influência da escola | ⛔ **superado** — grão é município (a issue nova é a **#255**) |
| 5 | GDAL/`sf` documentados | ✅ GDAL (#238); `sf` **não** é usado no `analysis/` |

O comentário de 2026-10-13 na issue (que ainda falava de `sf` e de "decisão de
produto pendente") é **anterior à #241** e foi superado por ela.

## O que foi entregue no PR #256

1. **Teste de integração robusto** (`t/05-tasks/mapbiomas_loader.t`). O subteste
   usava o geocode `4300002` como órfão, mas ele ("Área Operacional Lagoa dos
   Patos") **está** na `malha_municipio` real (5.573 linhas) → o subteste
   **falhava localmente** (6 linhas em vez de 4) e só passava no CI, cujo fixture
   tem 18 municípios. Passou a usar um geocode inexistente (`9999999`),
   eliminando a dependência de dados.
2. **Comentário do job** (`MapBiomas.pm`) — corrigida a crença de que as lagoas
   4300001/4300002 seriam órfãs (a mesma que gerou o bug do teste: na malha
   nacional elas **existem**; só num recorte que as omita é que viram órfãs).
3. **Verify que morde** (`data_pipeline/verify/mapbiomas_cobertura.sql`). Era o
   anti-padrão da **#160**: `SELECT 1` preguiçoso (0 linhas = `ok` para o Sqitch
   1.6.1) e ainda checava `collection9` e classes `'3.1'/'3.2'` — esquema que
   **nunca vigorou**. Passou a `DO … RAISE EXCEPTION`, verificando **só a
   estrutura** (colunas/nulabilidade, PK, FK), porque num banco fresco a tabela é
   legitimamente vazia — os dados vêm do job, não da migration.
4. **Docs** — `docs/analises/fontes/meio-ambiente.md` registra a decisão (#241) e
   aponta a areolização escolar para a #255; `new_data_sources.Rmd` corrige
   "Coleção 9" → "Coleção 10" e a nota de areolização.

## Decisões de design relevantes

- **Verify de migration não verifica dados.** A `mapbiomas_cobertura` é criada
  vazia pela migration; quem a popula é o job. Um verify que exigisse linhas
  derrubaria o gate de CI (banco fresco). A estrutura é o que a migration promete.
- **Editar o *corpo* de um verify de change já deployada é seguro.** O
  `change_id` do Sqitch é o SHA-1 dos **metadados** (nome, `requires`, pai) — não
  do conteúdo dos scripts. Confirmado empiricamente: após a edição,
  `sqitch status dev_docker` → *Nothing to deploy (up-to-date)* e a cadeia inteira
  passou no `sqitch verify`. (Não vale para `requires`/reordenação — aí muda o id.)
- **Grão município é decisão, não lacuna.** A visão do produto é por escola
  (`risco_hidrico_escola`, `frequencia_queimada_no_raio_500m`…), mas a decisão §8
  foi usar a estatística oficial municipal. O recorte por escola virou a #255,
  **não** um defeito da carga atual.

## Validação

- `prove -l t/05-tasks/mapbiomas_loader.t` → **13/13 PASS** contra a malha real.
- CI (`backend-tests`) → **PASS** (8m13s).
- `sqitch verify dev_docker` → **Verify successful** (cadeia inteira).
- `sqitch status dev_docker` → **Nothing to deploy (up-to-date)**.
- Verify negativo (nulabilidade errada em `area_ha`) → **RAISE** confirmado.

## Deploy

- `rex prepare` (3 hosts) — o fix do `.gitignore` da #254 eliminou o **código 23**
  do rsync (o `pgdata.bak-*/` já não quebra o `prepare`).
- `deploy_db_dev` → aplicou **`osm_mobilidade_completude`**, que estava
  **pendente** em `database.edumaps`/`edumaps_dev` (o ciclo #131 não correu
  `deploy_db_dev`). Agora up-to-date.
- `deploy_backend_dev` + `deploy_minion_dev` (master key presente, 64 chars).
- Imagens Docker locais `sqitch`/`backend`/`minion` reconstruídas; `md5sum` do
  `MapBiomas.pm` idêntico local ↔ `backend.edumaps` ↔ contentor.

## Pendências que ficam

- **#255** — cobertura do solo por **área de influência da escola** (raster 30 m).
- **Carga real** da `mapbiomas_cobertura` (78 MB → ~690k linhas) — a tabela segue
  vazia até o job rodar.
