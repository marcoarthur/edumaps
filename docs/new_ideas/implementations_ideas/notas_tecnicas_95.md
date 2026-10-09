# Nota técnica 95 — SICONFI fase 2: despesa por função (DCA) e FUNDEB real (#193)

## Resumo

A fase 2 do SICONFI fecha o ciclo financeiro da plataforma: a despesa municipal
por função (DCA-Anexo I-E, DCASP anual) entra em `clean.siconfi_despesa` com
uma linha por função, e o **FUNDEB detalhado** (DCA-Anexo I-C, contas
`1.7.5.1.00.0.0` + `1.7.1.5.00.0.0`) passa a alimentar de verdade a view
`analytics.esforco_fiscal_educacao` — `fundeb_receita` deixa de ser `0` e o
esforço fiscal dos municípios fica mensurável (dependência do FUNDEB, autonomia
fiscal, custo por aluno com receitas reais).

Entrega: 2 changes Sqitch (`siconfi_despesa_dca` + `analytics_esforco_fiscal_fundeb`),
ramo `dca` no loader `SICONFI.pm`, 4 commits → PR #195 → merge `dea37e7`.

## Decisões de design

- **ALTER em vez de coluna inventada**: na fase 1 a despesa tinha sido
  modelada com uma coluna `coluna_despesa` que não existe na API DCA. A fase 2
  remove a coluna e fixa a PK real: `(codigo_ibge, exercicio, funcao,
  subfuncao, classificacao, dt_snapshot)` — 1 linha por função (`subfuncao=0`).
  Feito como **change nova** (`siconfi_despesa_dca`) sobre a tabela já
  deployada — o único caminho válido no Sqitch (nunca editar change deployada).
- **`receita_total` exclui `tipo_receita='fundeb'`**: o FUNDEB já está contido
  no agregado `transferencia` do RREO; somá-lo de novo no total inflaria a
  receita. A view expõe `fundeb_receita` separadamente (a parcela FUNDEB da
  receita) e calcula o total sem duplo-conto.
- **Último snapshot por chave, não por grupo** (`DISTINCT ON`): a família
  RREO/DCA tem snapshots de datas distintas (RREO carregado antes, DCA depois).
  Agrupando por `dt_snapshot`, RREO e DCA caem em grupos diferentes e o
  `WHERE receita_total > 0` descarta o grupo do FUNDEB (medido: fundeb=0 no SP
  2025 — ver Medições). Os CTEs `receitas`/`despesas_educ` agora escolhem o
  **último snapshot por (município, exercício, tipo, coluna)** e agregam por
  (município, exercício). Resultado: 1 linha por município/exercício, sem
  splintering.
- **Linha de função é o pai, não a soma dos filhos**: a DCA traz os valores
  "por função" e também desdobrados por subfunção. O loader só importa as
  linhas de função (`regex ^(\d{2}) - `), que são as do Anexo I-E agregado.
  Medido: SP 2024 função 12 = 23,29bi vs Σ subfunções 21,42bi (diff 8%) — o pai
  **não** é a soma dos filhos; importar o pai é a escolha correta.
- **`strict_zero` na paginação da DCA**: valores monetários `0` são legítimos
  (municípios sem despesa numa função); a paginação por `hasMore` não pode
  trocar "página vazia" por "fim".
- **ON CONFLICT nas PKs novas**: o loader é idempotente — re-rodar um
  exercício atualiza o snapshot em vez de duplicar linhas.

## Medições (estado do dado)

Validação com carga real **SP 2025** (exercício-alvo da issue):

- Despesa: função 12 paga = **23.539.735.254,36** — idêntico à âncora da API
  (payload real DCA). Empenhado 24.987.325.966,82.
- FUNDEB: 8.065.438.177,73 + 117.028.677,98 = **8.182.466.855,71** (exato).
- View `analytics.esforco_fiscal_educacao` (SP 2025): `fundeb_receita`
  8,18bi; `receita_total` 43.422.262.196,92 = propria 30,10bi + transferencia
  10,12bi + outros 3,20bi — **fechado** por query com a mesma regra
  latest-snapshot (sem duplicar fundeb). `despesa_educ_por_aluno` 9.369,59
  (2.512.355 matrículas), `dependencia_fundeb_pct` 18,84%, `autonomia_fiscal_pct`
  69,32%. 1 linha por município/exercício (SP 2025 e 2026 lado a lado).
- Antes do fix `DISTINCT ON`, o mesmo SP 2025 mostrava `fundeb_receita=0`
  (RREO e DCA em snapshots diferentes).
- `prove -l t/05-tasks/siconfi_loader.t`: **17/17 PASS** (8 subtests fase 2:
  mappers DCA contra payloads reais 2024/2025, paginação, idempotência com BD
  real). Diagramas: `valida.pl` 4794 colunas, 0 entidades/colunas inválidas, 0
  FKs falsas.

## Incidência de processo (transparência)

Para reaplicar o corpo corrigido da view, um `sqitch revert` **sem alvo** foi
executado no banco local (Docker `ubaxala`) — e o Sqitch reverte **todo o
plano** por padrão. O replay esbarrou nos dois problemas históricos do plano
(`import_metadata_fase0` fora de ordem → lote "out of order"; `raw_countries`
com FDW remoto `/vsicurl` sem rede no container) e **destruiu as tabelas
gerenciadas do sandbox local**. O remote `database.edumaps` nunca foi tocado.

Recuperação integral via **dump/restore do remote** (`pg_dump -Fc --no-owner`
→ `DROP SCHEMA … CASCADE` → `pg_restore --no-owner --no-privileges`):
116/116 relações conferidas local vs remote, função SQL que falhou no restore
(registro `search_path` sem o schema do tipo `geography`) recriada
byte-idêntica, registry sqitch restaurado **coerente** e o `deploy` local
aplicou só as 2 changes novas, sem out-of-order. O banco local passou a
espelhar o remote.

**Lição registrada em `memory.md`**: nunca reaplicar corpo de change já
deployada com revert — o caminho Sqitch é `rework`/change nova. O AGENTS já
exige isso; o ciclo quase seguiu pela rota proibida e perdeu o sandbox por
isso. O `docs/diagramas/02-censo-desempenho` ganhou de brinde uma correção de
tipo (`distancia_euclidiana` numeric→double) que o banco restaurado revelou.

## Pendência registada (follow-up)

- Exercício **2026** no remote só tem RREO (SP) — despesa DCA 2026 e FUNDEB
  2026 inexistentes. O SP 2025 completo só existe no banco local (carga local
  RREO 2025 + DCA 2025). Rodar o job DCA em malha no remote é o próximo passo
  natural do ciclo.
- `analysis/reports/new_data_sources.Rmd` segue a medir `database.dev` (com
  `siconfi_despesa` vazia) — regenerar o relatório contra `database.edumaps`.
- `sqitch verify` global permanece com 45 "Out of order" (facto histórico,
  não corrigível sem reverter a reordenação — AGENTS).

## Deploy e validação

- `rex prepare` + `deploy_db_dev` (`database.edumaps`) + `deploy_backend_dev` /
  `deploy_minion_dev` (`backend.edumaps`). Detalhe de operação: a task
  `deploy_minion_dev` é do host `backend.edumaps` — rodá-la em
  `database.edumaps` falha com "which carton" (host sem stack Perl).
- Remote conferido: sqitch up-to-date em `analytics_esforco_fiscal_fundeb`,
  `clean.siconfi_despesa` sem `coluna_despesa`, md5 do `SICONFI.pm` idêntico ao
  working tree.
- Imagens locais `sqitch backend minion` reconstruídas após o merge; stack
  local (backup restaurado) serve o código novo.