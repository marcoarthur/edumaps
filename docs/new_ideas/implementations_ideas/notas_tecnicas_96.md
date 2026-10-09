# Nota técnica 96 — honestidade dos jobs e-SIC e fecho de proveniência (#172 + #157)

## Resumo

Dois ciclos pequenos de "higiene de dados" que fecham lacunas de auditoria
medidas no produto:

- **#172 — todo job pendente de e-SIC agora falha de verdade**: os 4 stubs
  (`FNDE`, `MedidorConectada`, `SecretariasMunicipais`, `INEP`) passam de
  sucesso silencioso para `die` com motivo + referência ao tracker
  (`docs/admin/esic-requests.md`). O `CensoEscolar` era caminho morto
  (`clean.censo_escolas`/`censo_docentes` já carregados por outro caminho) e
  foi **removido**. Os comments das tabelas-fonte sem loader declaram
  **NÃO CARREGADA + motivo** (change Sqitch `comments_esic_pendente`).
- **#157 — proveniência fechada no produto**: `clean.import_metadata` passou
  de 25 registros (2 sem URL/licença/data) para **47 registros, zero NULL**,
  via backfill idempotente (`db/backfill_proveniencia.sql`). Licença do
  BrazilCrime corrigida (GPL-3 → **MIT + file LICENSE**, o que o CRAN
  declara), `source_url` das isocronas aponta para o tileset Geofabrik
  auto-hospedado, e as 3 views derivadas foram registadas.

Entrega: 5 commits, branch `fix/data-proveniencia-esic-172-157` → PR #196.

## Decisões de design

- **Falhar alto em vez de estruturar**: a #172 tem uma regra explícita —
  "enquanto o e-SIC não responder, escrever o loader é trabalho jogado fora".
  O padrão implementado é o mais barato que não é enganoso: `run()` morre com
  o motivo, o Runner converte em `ingest_failed` (já existia), o comment da
  tabela declara o estado, e o tracker mantém a lista viva. Nenhum loader
  novo foi escrito.
- **`inventario_*` não são alvos do FNDE (correção do mapeamento da issue)**:
  o corpo da #172 associou `inventario_fornecedores`/`inventario_anexos` ao
  job FNDE, mas são tabelas de **aplicação** do módulo gestor. A correção foi
  registada no próprio tracker (seção "Vínculo com os jobs") e os comments
  dessas tabelas não foram tocados. Manter um comment errado "aguardando
  e-SIC" em tabela de app seria trocar um silêncio por uma mentira.
- **Medição contra o produto, não contra `database.dev`**: a #157 foi escrita
  sobre o relatório `new_data_sources.Rmd`, que media `database.dev` (32
  registros, 9 sem proveniência, duplicata). No produto (`database.edumaps`),
  a realidade era outra: 25 registros, **2** NULL, **sem duplicata**, e ~19
  tabelas populadas **sem registro nenhum**. O backfill foi desenhado a partir
  da medição do produto (47 registros finais, zero NULL). A "duplicata" não
  exigiu ação — só registo da medição.
- **Proveniência nas fichas, não inventada**: cada tabela registada aponta a
  URL/luicença das fichas em `docs/analises/fontes/`. Onde a licença não é
  verificável, o valor é `não verificada (e-SIC INEP pendente — tracker)` —
  explícito, nunca nulo silencioso. `year_changed`/`year_deprecated` do
  dicionário: nulos = primeira edição, declarado na nota do registro.
- **Backfill é dado, não schema**: `db/backfill_proveniencia.sql` (INSERT …
  ON CONFLICT DO UPDATE, idempotente) não passa por Sqitch — `import_metadata`
  é tabela de auditoria, e a change de comments é o único objeto novo do
  pipeline de schema.

## Medições

- `prove -l t/05-tasks/esic_jobs.t t/05-tasks/ingestion_runner.t`: **15/15
  PASS**. O teste novo cobre o critério 1 da #172 (job pendente → `success=0`
  com motivo e tracker) e a ausência do CensoEscolar na lista (a lista é
  derivada do diretório — a remoção é auto-consistente).
- Verify `comments_esic_pendente`: passa com o comment honesto e **falha com
  regressão plantada** (comment sem "NÃO CARREGADA" → `RAISE EXCEPTION`).
- Produto (via SSH, `sudo -u postgres psql`): `sqitch.changes` confirma
  `comments_esic_pendente @ 2026-10-09 12:27`; `import_metadata` 47 linhas, 0
  com URL NULL, 0 com licença NULL; comment de `clean.sisab_aps` contém
  "NÃO CARREGADA".
- Relatório `new_data_sources.Rmd` regenerado contra o produto: **exit=0**
  (o HTML é gitignored; só o `.Rmd` versionado).

## Incidentes e armadilhas de ferramenta

- **`rex prepare` NÃO apaga arquivos removidos localmente**: após o sync, o
  `CensoEscolar.pm` continuava no host (e continuaria auto-descoberto como
  job). Removido à mão via SSH. Regra anotada no `memory.md`: deleção de
  arquivo exige remoção manual no host.
- **`docker compose build backend minion` estoura 10 min** (deps Perl);
  reexecutado em background.
- **O relatório tinha um fragmento órfão pré-existente** (3 linhas órfãs
  depois do fecho do vetor `Onde` no bloco `veredito`) que **quebrava o
  render** com erro de parse — o relatório "desatualizado" também não
  renderizava. Removido no ciclo.