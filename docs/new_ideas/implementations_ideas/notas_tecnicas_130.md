# Nota técnica 130 — #137 (reconciliação de código): B canônico, A/D em quarentena

A **#137** já tinha entregado os entregáveis **1** (fórmula `ivet-v1.0`
documentada) e **2** (decisão de leitura **territorial**) — só documentação, em
`docs/analises/ivet.md` (commit `e9b7069`). Esta nota cobre a **ação de código**
que fechou a *origem incerta* dos índices: declarar **B** canônico e pôr **A** e
**D** em quarentena, sem tocar em fórmula. PR **#257**, merge `200d9c6`.

## O problema

O achado central da #137: **o IVET não existe como número** e havia **quatro**
sistemas de score concorrentes, com definições sobrepostas e nenhuma fonte única:

| # | Sistema | Onde | Produz | Status |
|---|---------|------|--------|--------|
| A | `clean.censo_escolas_scores` (view) | `scores_view.sql` | 11 scores, 0–10 | morto (sem consumidor) |
| B | `clean.mv_escolas_scores` (MV) | `escolas_scores.sql` | 6 scores, 0–10 | **canônico** (ranking/similaridade/cluster) |
| C | `Model::Indicator::School::*` (Perl) | `SchoolQuality` | 8 indicadores, 0–1 | vivo (escolas semelhantes) |
| D | `CensoEscolas::_compute_score` | `ResultSet/CensoEscolas.pm` | 4 scores, 0–1 | morto (só sandbox) |

A decisão de qual é o canônico já estava no doc (§3). O que faltava era
**fixá-la no código**, para que a resposta não dependa de ler o markdown.

## O que foi feito (PR #257)

**`data_pipeline`** — change `quarantine_censo_escolas_scores`
(deploy/revert/verify com `DO … RAISE EXCEPTION`, padrão #160):

- `COMMENT ON VIEW clean.censo_escolas_scores` → **DEPRECATED** (A);
- `COMMENT ON MATERIALIZED VIEW clean.mv_escolas_scores` → **índice canônico do
  produto** (B), com ponteiro para `docs/analises/ivet.md`.

O comentário vive **na própria base**, não só no repo: quem inspecionar o schema
vê a decisão. O `revert` restaura os textos anteriores (a view não tinha
comentário; a MV tinha o texto de `escolas_scores.sql`).

**`backend`** — só cabeçalhos/comentários, **sem mudança de comportamento**:

- `CensoEscolas.with_all_scores` + os 4 scores (`with_internet_score` etc.) →
  `DEPRECATED` (D); o único consumidor restante é `sandbox/censo.pl`;
- `Schema::Result{,Set}::CensoEscolasScores` → aviso `DEPRECATED` (A);
- `Model::Domain::SchoolQuality` e `Model::Indicator` → declarados **camada de
  análise (C)**, *não* o índice canônico.

**`docs/analises/ivet.md`** — nova §3.1 ("onde a decisão está fixada") e §6
(ações executadas + follow-ups); **`memory.md`**.

## O que foi deliberadamente **não** feito

A reconciliação **de fórmula** entre B e C — fazer C derivar de B, ou unificar os
coeficientes. Isso:

1. é **decisão de produto** (muda o que "escola semelhante" significa e o
   ranking, se B mudar);
2. **conflita com o alvo `ivet-v1.0`**, que ainda vai decidir as dimensões
   territoriais (#125/#126/#127) e os pesos (§4 do doc).

Registrado como follow-up no §6. O PR entrega o que é *seguro e verificável*
agora: **uma** definição canônica em vez de quatro concorrentes.

## Validação

- Ciclo Sqitch completo **local**: deploy → verify → `revert --to
  osm_mobilidade_completude` → redeploy (imagem `leaflet-sqitch` reconstruída;
  o `docker compose up` sozinho não a reconstrói).
- `prove -l t/dbic/scores.t` **PASS**; `t/02-models/school/rank.t` **PASS**.
- `t/02-models/domain/quality.t` **falha pré-existente** (`ige > 1`, bug de
  normalização da família do `iqd`) — confirmada **idêntica** em `git stash`,
  portanto **não é regressão** deste PR.
- `perl -c` OK nos 5 arquivos.

## Deploy

- **Dev real**: `rex prepare` + `rex -H database.edumaps deploy_db_dev`
  (user `edumaps`, pass `change_me` — é o que o backend usa de facto, via
  `edu_maps.conf`: `postgresql://edumaps:change_me@Database/edumaps_dev`).
  Head em `database.edumaps` = `quarantine_censo_escolas_scores`; comentários
  confirmados na base.
- **Stack local**: imagens `backend`/`minion`/`sqitch` reconstruídas e `up -d`;
  md5 do `Indicator.pm` no container == working tree.

## Follow-ups (não neste ciclo)

- Remoção definitiva do código morto A/D.
- Alinhar o *fallback* em memória de `Profile` (C) ao espaço canônico de B — hoje
  o caminho primário (embedding, derivado de B) e o *fallback* (C) usam espaços
  de features **diferentes**, o que é uma inconsistência latente.
- Entregáveis **3/4/5** da #137 (pipeline reprodutível), bloqueados por **#135**
  (DVC) e pelo dataset da Fase 0 (#124).
