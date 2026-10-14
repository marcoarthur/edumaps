# Nota técnica 127 — #228 (SQL + R): rótulos do Censo vêm do dicionário

## Resumo

Fecha o restante da **#228**. A camada **backend** já tinha ido nos PRs #247 e
#249 (helper `CensoLabels.pm`); faltavam as camadas **SQL** e **R**, que ainda
reescreviam `1 => 'Federal'` / `1 => 'Urbana'` à mão. Agora **as três camadas
leem a mesma fonte**: `clean.censo_data_dictionary` (curado na #134, nota 119).

O PR #251 (merge `14a72c4`) entrega duas changes Sqitch novas, dois datasources
R e o script legado `city_analytics.R`.

## O problema

Os rótulos de `tp_dependencia` (1 Federal … 4 Privada) e `tp_localizacao`
(1 Urbana, 2 Rural) estavam corretos, mas **duplicados**:

- **SQL**: `deploy/badge_functions.sql` (o `typification_badge`),
  `deploy/analytics_rede_escolas.sql` e `deploy/rede_escolas_etapas.sql`
  (a MV `analytics.mv_rede_escolas`), além dos COMMENTs de
  `censo_escolar_2025.sql`.
- **R**: `model-datasource-postgres-city-source.R` e
  `model-datasource-postgres-school-evolution-source.R` (dois `switch()`), e
  `backend/templates/rscripts/city/city_analytics.R` (um `case_when`).

É conhecimento repetido: se o dicionário mudar, os mapas fixos divergem sem
avisar. Agravante: o mapeamento de volta (rótulo do IDEB → código) existia em
mais de um ponto.

## A decisão: um helper canônico, lido pelas três camadas

Em vez de injetar o domínio em cada query, o banco ganha **um helper único**:

- `clean.censo_label(tabela, coluna, código)` → rótulo do código (NULL se
  desconhecido);
- `clean.censo_code(tabela, coluna, rótulo)` → código do rótulo,
  **case-insensitive** (necessário porque `clean.ideb_notas_escolas.rede` guarda
  o rótulo capitalizado `Federal`… e a MV precisa voltar ao código);
- `clean.censo_labels(tabela, coluna)` → domínio completo (`{código: rótulo}`).

Todos leem a **linha vigente** do dicionário (`year_deprecated IS NULL`, maior
`year_introduced`). SQL e R passam a chamar o helper **no próprio `SELECT`** —
a lógica de rótulo sai de todos os consumidores.

**Ícones ficam no código.** O dicionário guarda só texto; `dep_icon`/`loc_icon`
não são rótulos e continuam onde estavam.

## As duas changes Sqitch

Nenhuma change já deployada pode ser editada (editar `requires`/reordenar muda
o `change_id` e parte a cadeia — ver AGENTS). Então vão **duas changes novas**:

1. **`censo_label`** (`[censo_data_dictionary_inep]`): cria os três helpers e
   reaponta os `COMMENT ON COLUMN` das colunas enum para o dicionário.
2. **`censo_labels_consumers`** (`[censo_label badge_functions
   rede_escolas_etapas]`): redefine `clean.typification_badge` e **recria**
   `analytics.mv_rede_escolas` (o `CREATE MATERIALIZED VIEW` popula na hora,
   portanto a MV sai preenchida). O `refresh_rede_escolas()` foi redefinido.

## A armadilha das matviews (duas vezes)

O gate `column_descriptions` (change na linha 51 do plano) exige que **toda**
coluna das tabelas-alvo tenha descrição — e `analytics.mv_rede_escolas` está
na lista. Como a change nova faz `DROP`+`CREATE` da MV, ela **apaga** os
comentários que `column_descriptions` adicionou muito antes. A change nova
**reemite os 34** `COMMENT ON COLUMN`. Sem isso, o `verify` global falha — foi
exatamente o que o CI pegou (1 erro entre 117 changes).

Segunda armadilha, já documentada no AGENTS e que reapareceu: o `verify` novo
checava as colunas da MV por `information_schema.columns`, que **não lista
matviews** (retornava "0 de 8"). Corrigido para `pg_attribute`.

## Camada R e template

Nos datasources, os `switch()` saem e o rótulo entra no `SELECT` com
`COALESCE(clean.censo_label(...), 'Outra'/'Desconhecida')`. No
`city_analytics.R`, o `case_when` sai e resta só o indicador derivado
(`ratio_aluno_docente`) no `mutate`. O `clean.censo_label` é sempre o do schema
`clean` (a fonte canônica é única), independente do `schema` da query de
escolas.

## Validação

- **Gate de CI** (`db/fixtures/ci_db.sh up` + `verify`, banco fresco na porta
  5433): deploy das **117 changes** OK e `verify` **successful**. O workflow
  `backend-tests` fechou verde em ~10 min.
- **Revert** testado: `sqitch revert … --to cnpj_municipio` e, depois, o
  `column_descriptions` continuou ok (os comentários são restaurados).
- **R**: parse dos 3 arquivos; integração real contra `edumaps_dev` (rótulos
  corretos) e `testthat` (`censo-dictionary`, `city-summary`,
  `school-evolution`) sem falhas.
- **Deploy dev**: `rex prepare` + `deploy_db_dev` + `deploy_analytics_dev` +
  `deploy_backend_dev`. No produto, a MV tem **0** colunas sem comentário e
  `typification_badge` devolve `{"label_principal":"Estadual", …}`.
- **Imagens Docker locais** (`sqitch`, `backend`, `minion`, `analytic`)
  reconstruídas; `sqitch` exit 0; md5 confere host↔contentor.

## Fora de escopo

`report-catalog.R` e `report-roteiros.R` usam `"Municipal"`/`"Estadual"` como
**identificadores de negócio** em recortes de relatório — não são mapa
código→rótulo. `eduBR` é repositório somente-leitura.

## Contexto do dia

- **#250 (PR #250, merge `043481f`)** — otimização da fase de CNPJ do job CGU
  2025: o `_mapa_cnpj_uex` consultava **todas** as UEx, mas o `resolver` só usa
  o CNPJ quando o SIAFI não mapeia. Extraído `_mapa_siafi` e derivado **antes**
  de resolver CNPJs; **behavior-preserving**. (~37 h → ~6 h.)
- **A CGU 2025 falhou** (`2859903`, 15:35): `[STALL] Sem progresso há 603s`. O
  watchdog olha `data/ingestao` inteiro e a assinatura cita arquivos de **outras**
  ingestões; durante a resolução de CNPJ (lenta, APIs externas 503/500) nenhum
  arquivo muda → **falso positivo**. O job não reescreveu o `cgu_orfaos.csv`
  (mtime 13/10), então o **#240 segue não medido**: os 74,6% são o baseline
  pré-#250. Fica para o próximo ciclo investigar o stall e remedir.
