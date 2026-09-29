# Nota técnica 71 — Roadmap do Perfil da Escola: evolução, rede e /ask

**Data**: 2026-09-29
**PRs**: #112 (`school_evolution`), #113 (`/network_profile`), #114 (perfil no `/ask`)
**Issues**: #110, #109, #111 (roadmap do #105)
**Áreas**: analytics (`analysis/edumapsr`), backend, frontend

## Contexto

Depois do #105 (perfil on-demand) e do #107 (referências pré-computadas +
read-through), faltavam os itens 2–4 do roadmap do #105. Foram abertos issues
antes de codar e entregues em três ciclos independentes (branch → PR → merge),
por decisão do usuário.

## A — `school_evolution` (#110, PR #112)

Série histórica da escola para ampliar o painel atual.

- Fontes: `clean.ideb_notas_escolas` (IDEB por ano/etapa, 2005–2023) e
  `clean.inep_notas_desagregadas` (SAEB por ano, 2005–2023).
- R: `analyze_school_evolution()` pura + `school_evolution_model` +
  DataSource com binds; série longa em `data` e resumo por série
  (`n_anos`, `variacao`) em `tables$resumo`; `POST /school_evolution`.
- Registry: `model_class = "school_evolution_model"` (mesma extensão do #105);
  `test-architecture.R` generalizado.
- Backend: `GET /api/school/:cod_inep/evolution`.
- Frontend: nova seção "Evolução" no perfil, com uma série por
  (indicador, etapa) e barras proporcionais por ano. A evolução é buscada em
  paralelo ao perfil; falha dela não derruba o perfil.

## B — `/network_profile` (#109, PR #113)

Perfil agregado de uma rede (município, opcionalmente por dependência).

- Reusa a infra do #107: a média da rede é comparada à referência do Brasil
  (`analytics.school_profile_reference`) e a distribuição é por
  `clean.school_indicators.cluster_id`.
- R: `analyze_network_profile()` + `network_profile_model`; a população do
  recorte sai de `.profile_pop_body` (mesma whitelist de indicadores) com
  `co_municipio`/`tp_dependencia` como binds; `POST /network_profile`.
- Sem varredura nacional no request: a referência do Brasil é lida da tabela
  materializada (fallback live só se faltar).
- Frontend: página `/municipio/perfil?ibge=…` ("Rede vs. Brasil" e
  "Distribuição por cluster"), reusando o padrão da feature `network-compare`.

## C — Perfil no `/ask` (#111, PR #114)

O assistente agora responde perguntas sobre o perfil de uma escola.

- **View achatada** `analytics.school_profile_flat`, criada no
  self-provisioning do repository do perfil (`CREATE OR REPLACE VIEW`), que
  desmembra `profile_data -> 'tables' -> 'indicadores_comparados'` via
  `jsonb_array_elements`: uma linha por (escola, indicador) com
  `escola/municipio/rede/brasil/cluster`, `quartil_no_cluster`, `atencao` e
  `computed_at`.
- **Grants**: a view é criada depois do `GRANT ALL TABLES` inicial, então o
  próprio ensure faz `GRANT SELECT ... TO edumaps_leitor` (best-effort) — sem
  isso a role somente-leitura do chat não enxergaria a view nova.
- **Dicionário** (`inst/chat/dicionario.yml`): tabela na whitelist, colunas
  curadas, conexão (join por `co_entidade`) e termos ("perfil da escola",
  "sinais de atenção").
- **System prompt**: regra direcionando as perguntas para a view, filtrando a
  escola e o `nu_ano_censo` mais recente.
- Validação real: `POST /ask` gerou SQL sobre `analytics.school_profile_flat` e
  respondeu coerente (mestrado 3,12% e sem especialização 25% no quartil
  inferior; licenciatura 96,88% vs. município 79,53%; IDEB 4,7 vs. 5,28).

## Testes e validação

- R: 440 passam (única falha, `test-cluster.R:154`, **pré-existente**).
- Backend: `t/04-api/school/evolution.t`, `t/04-api/network/profile.t` e
  subtestes do `Analytics::Client`.
- Frontend: 369 testes / 69 arquivos.
- Deploy `ubatexu.lan`: rotas 200/400/404; bundles com as seções; validação
  visual do developer (evolução e rede) PASS.

## Processo e aprendizados

- O commit do item C foi feito sem querer direto na `main` local; o push
  falhou (branch inexistente) e o commit foi movido para
  `feat/analytics-ask-profile` com a `main` resetada antes de qualquer push —
  regra branch→PR→merge preservada.
- Reusar `.profile_pop_body`/whitelist e a referência do #107 manteve o
  `/network_profile` sem novo bespoke SQL pesado.

## Pendências

- Documentar no `api.json` os endpoints batch do #107
  (`/school_profile/reference|cluster|batch`) — os itens A/B/C já têm schemas.
- `docs/indice.md` (Tech Lead) sem passada recente.
- Ideia futura: usar `analytics.school_profile_flat` para respostas de ranking
  por cluster no chat (além do perfil individual).
