# Nota técnica 69 — Perfil da Escola: painel analítico do gestor (R → Perl → SPA)

**Data**: 2026-09-28
**PR**: #106 (`feat/analytics-school-profile`) · **Issue**: #105
**Áreas**: analytics (`analysis/edumapsr`), backend (`backend/`), frontend
(`frontend/edumaps`), docs

## Contexto

O gestor de uma escola específica não tinha um lugar único para ver um
diagnóstico acionável: era preciso orquestrar 3–4 endpoints e montar features
de similaridade/cluster na mão. A issue #105 propôs um `POST /school_profile`
na camada analítica, devolvendo diagnóstico + posição relativa + benchmarking
justo + sinais de atenção num payload só.

O checklist do issue pedia "sem mudanças em `backend/`/`frontend/`" (o
frontend ficaria para outra issue). Decisão explícita do usuário neste ciclo:
**incluir a ponte no backend e o painel na SPA**, e manter a SPA falando só
`/api/*` (o backend como fachada), em vez de a SPA chamar `/analytic-api`
direto.

## Arquitetura entregue

```
clean.censo_escolas/matriculas/docentes + ideb + inse  (+ school_indicators/similarity_pairs)
        │  (DataSource: uma query agregada, binds $1/$2)
        ▼
school_profile_model ── analyze_school_profile() ──► analysis_result
        │                                                   │
        │                                        render_json (tabelas)
        │                                                   │
        ▼                                                   ▼
  analytics.school_profile (UPSERT)              POST /school_profile (Plumber)
                                                            │
                                          Analytics::Client#run_school_profile
                                                            │
                              GET /api/school/:cod_inep/profile (Perl)
                                                            │
                                        /escola/perfil (Svelte 5 + Leaflet stack)
```

Principais pontos:

- **Modelo semântico novo** (`school_profile_model`): uma linha por indicador
  (formato longo) com `escola`, `municipio`, `rede`, `brasil`, e a
  distribuição do cluster (`cluster_p25/p50/p75/media/n`); mais os blocos
  `peers` e `flags_meta`.
- **`analysis_registry` ganhou `model_class`**: perfis multimodais não
  consomem `school_indicator_model`. `run_analysis()` valida a classe
  declarada na entrada; `test-architecture.R` passou a montar o fixture pelo
  `model_class`. As 3 análises plotly seguem sem declarar nada (default).
- **Sinais de atenção**: v1 fiel ao issue — `atencao = quartil_no_cluster == 1`
  (quartil inferior do cluster). O refinamento por direção do indicador (alguns
  são "quanto menor, melhor") ficou documentado como evolução.

## Decisões de dados (o que o banco dev mostrou)

- `clean.school_indicators` tem **214.192 linhas** (todas as escolas) mas
  apenas **2.821 com `cluster_id`** e **27 com `cluster_label`**. Ou seja, na
  prática o **fallback kmeans é o caminho comum**, não a exceção.
- `analytics.similarity_pairs` **não existe** no dev — os peers caem no
  **Gower restrito ao município**.
- `analytics.ranking_escola` e `analytics.clustering_metadata` vazios.
- `clean.inse` usa `id_escola` (não `co_entidade`) e `media_inse`; não há
  `co_entidade` — o join é por `id_escola`.

Decisões derivadas: cluster de fallback **restrito ao município** (não
clusterizar 214k escolas por request); fallback usa apenas as features que a
**própria escola** tem preenchidas, garantindo que ela nunca seja excluída do
kmeans/Gower por faltar IDEB/INSE.

## Performance: de ~21s para ~1,7–2,4s

O primeiro deploy funcional levava **~21s** por request. `EXPLAIN ANALYZE`
mostrou que o custo não era o disco (agregados simples ~0,1–0,4s), mas:

1. **`max(nu_ano_censo)` sobre `censo_escolas`** (sem índice) → seq scan
   nacional (~6s). Resolvido: o ano passou a ser resolvido **uma vez**, via
   `censo_matriculas` (PK com `nu_ano_censo` na frente), e entra na query como
   bind `$2`.
2. **LATERAL do IDEB por escola** (180.540 probes de índice) + sort de 814k
   linhas (~4s). Resolvido: `DISTINCT ON (id_escola)` restrito ao **ano mais
   recente do IDEB** (edição nacional), num subselect set-based.
3. **Frame municipal reconstruía a população nacional** para o fallback de
   cluster/peers. Resolvido: filtro `co_municipio` antes dos joins.
4. **`co_entidade` (bigint) dos peers** virava notação científica no JSON.
   Resolvido com cast `::text` no DataSource.

Resultado: escola típica (sem cluster persistido) **~1,7–2,4s**; escola com
cluster persistido ~3,4s (percentis sobre 2.821 escolas). O `<2s` pleno para o
caso persistido exige **pré-computar** percentis de cluster e médias de
referência — está nos "próximos passos" do issue e não entrou neste ciclo.

## Integração e contrato

- O backend **não cria rota nova no R**: usa o `Analytics::Client` (motor
  `http`/`pipe`) e a rota pública `GET /api/school/:cod_inep/profile`.
  `co_entidade` inexistente → **400** (erro de cliente do serviço); serviço
  analítico fora → **503**; a mensagem é higienizada (sem path/linha do Perl).
- `GET /api/school/:cod_inep/profile` responde em ~2s na primeira chamada; o
  `Analytics::Client` **cacheia** a resposta (24h, `analytics.analysis_cache`),
  então chamadas seguintes para a mesma escola são instantâneas.
- A SPA normaliza tabelas que o Plumber pode serializar como objeto único
  (`asArray`) e formata proporções/quantis no `transformProfileData.js`.

## Testes

- **R**: 348 passam. A única falha (`test-cluster.R:154`) foi confirmada
  **pré-existente** rodando o `main` no mesmo host. `R CMD check` só com o
  ERROR conhecido de `Author`/`Maintainer`.
- **Backend**: `t/04-api/school/profile.t` (stub do helper `analytics`; cobre
  200/400/503/404 e não-vazamento de path) + subteste do client no mock
  Plumber.
- **Frontend**: 353 testes / 65 arquivos; novos testes de componente, page
  (MSW) e transform.

## Deploy e validação

`rex prepare` → `deploy_analytics_dev` → `deploy_backend_dev` →
`deploy_frontend_dev`. Bundle `index-DAS1-W4A.js` confirmado com os
marcadores da rota. Validação visual do developer em
`http://ubatexu.lan:8080/escola/perfil?inep=23165669` (PASS); API ponta a
ponta via `ubatexu.lan:8080` (200/400/404).

## Pendências e próximos passos

- Pré-computar percentis de cluster e médias de referência (Brasil/rede) para
  fechar `<2s` no caso persistido (batch, seguindo o padrão de
  `compute_and_save_school_chart`).
- Refinar os sinais de atenção por **direção** do indicador.
- Atualizar o texto do issue #105 quanto ao escopo (backend/frontend entraram).
- Revisar `docs/indice.md` (passada do Tech Lead).
