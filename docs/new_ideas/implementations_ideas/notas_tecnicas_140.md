# Nota técnica 140 — #137 (fatia B/C): reconciliação B↔C no bloco A do IVET

Esta nota documenta a **reconciliação B↔C** do bloco **A (escola)** do IVET
(#137) — a primeira parte das fatias B/C. PR **#270** (merge `c328423`). A
extração **C–G** dos blocos territoriais **não** entrou neste ciclo e tem um
bloqueio de infraestrutura mapeado abaixo.

## Contexto

O IVET tinha **quatro** sistemas de score concorrentes (§2 da
[`docs/analises/ivet.md`](../../analises/ivet.md)): o **B**
(`clean.mv_escolas_scores`, canônico, 0–10) e o **C**
(`EduMaps::Model::Indicator::School::*`, camada de análise, 0–1) sobrepunham-se
sem fórmula reconciliada. O bloco A existia como dimensão da fórmula, mas sem
**de onde** vem cada coeficiente. A decisão de produto (2026-10-17): B é a
fonte do bloco A; a reconciliação vive **só no IVET** e **não** altera os
consumidores de B (ranking, similaridade, cluster).

## O que foi feito

### `analysis/edumapsr/R/ivet-escola.R` (novo)

- `ivet_componente_score(score, teto = 10)` — o sistema B mede "quanto melhor,
  maior" em 0–10; o IVET mede vulnerabilidade. Componente invertido:
  `1 − clamp(score / teto, 0, 1)`.
- `ivet_componente_indicador(x)` — sistema C (`[0,1]`, maior = melhor)
  invertido e **clampado**; corrige o `iqd`, que viola `[0,1]` (razão
  aluno/docente crua, §2.3).
- `ivet_bloco_escola_componentes(...)` — devolve os **10** componentes: os 6 de
  B (`capacidade_atendimento`, `infraestrutura`, `capacitacao_docente`,
  `diversidade_discente`, `capacidade_gestora`, `sustentabilidade`) + os 4
  opcionais de C (`acessibilidade_c`←`iai`, `tecnologia_c`←`itd`,
  `oferta_c`←`ioc`, `qualificacao_docente_c`←`iqd`).
- `ivet_bloco_escola(..., componentes = IVET_BLOCO_A_COMPONENTES)` — a dimensão
  A. **Default = só B** (o canônico); C só entra por escolha explícita. Usa
  `ivet_agregar()`: componente `NA` fica fora do denominador (#154); sem
  nenhum componente a dimensão é `NA`, nunca 0.

### Card e testes

- `inst/ivet-card.yml`: seção `bloco_a` (fonte, escala, normalização, default,
  sistema C, componentes com `sistema`/`no_default`) — e a lista de testes.
- `tests/testthat/test-ivet-escola.R` (novo, 40 asserções): inversão, clamp,
  `iqd`, `NA` preservado, default = B, seleção explícita de C.
- `tests/testthat/test-ivet-card.R`: contrato do bloco A (nomes dos componentes
  batem com o código; C marcado `no_default`).

### Docs

- `docs/analises/ivet.md`: **§4.4.1** (decisão + tabela de mapeamento), §4.2
  (status do bloco A), §4.5 (direção → §4.4.1), §6 (entregável 3 + follow-ups).
- `docs/funcionalidades/plataforma/fontes-de-dados.md`: nova capacidade —
  "definição canônica de um índice em vez de várias, sem mexer no que o gestor
  já vê".

## Estado das fatias B/C — o bloqueio da mobilidade

Medido em `database.edumaps` (2026-10-17):

| Bloco | Fonte | Estado |
|---|---|---|
| A. Escola | `clean.mv_escolas_scores` | ✅ reconciliado (este PR) |
| B. Socioeconômico | `clean.escola_entorno_socioeconomico` | ✅ feito (ciclo anterior) |
| **C. Mobilidade** | `clean.isocrona_escolar` = 0; `analytics.mobilidade_escola.isocronas_por_tempo`/`antt_od_*` vazios | 🔴 **bloqueado** |
| D. Saúde | `analytics.acessibilidade_saude` (145.734) | ✅ dado pronto |
| E. Segurança | `clean.brazilcrime_municipio` (61.192) + `clean.renaest_sinistro` (2,27 M) | ✅ dado pronto |
| F. Meio ambiente | `clean.mapbiomas_cobertura` (690.340, município) | 🟡 parcial (#255 p/ 30 m por influência) |
| G. Recursos | `analytics.esforco_fiscal_educacao` (5.525) | ✅ dado pronto |

**Consequência dura**: `ivet_blocos_territoriais_minimos()` = {mobilidade,
saude, seguranca} (`R/ivet.R`). Como **C** não existe, o IVET agregado continua
**`NA`** mesmo com D e E prontos (§4.3). C depende do **Tier 2** — isócrona
OSRM/Valhalla auto-hospedado (`influencia.md` §146) —, que é projeto de infra,
não de extração. Decisão do developer (2026-10-17): manter mobilidade `NA` e
adiar.

## Decisões de desenho

- **B é a fonte do bloco A; C é opcional e fora do default.** Evita multiplicar
  as definições concorrentes que o #137 veio resolver.
- **Reconciliação só no IVET**: `mv_escolas_scores`, `Rank::School` e `Profile`
  ficam intactos — sem regressão no que o gestor já vê.
- **A correção do `iqd` mora na camada que o consome** (o componente é
  clampado), sem tocar o indicador de origem.
- **Sem bump de fórmula**: nada mudou nos pesos/agregador do `ivet_v1()` nem no
  default do bloco B; o que entrou foi a *extração* do bloco A (que já era uma
  dimensão). `ivet-v1.2` permanece.

## Validação e deploy

| Checagem | Resultado |
|---|---|
| `testthat::test_local(filter="ivet")` | **149/149** (eram 98) |
| md5 em `analytic.edumaps` | confere |
| md5 dentro do `edumaps-analytic` (`/pkg/R/…`) | confere |
| `edumaps-sqitch` no `up -d` | saiu **0** |

`rex prepare` + `deploy_analytics_dev`; imagem local `analytic` reconstruída e
`docker compose up -d`.

## Pendências

- **Extração C–G**: D, E, G com dado pronto (fórmula R + ligação); F parcial
  (#255); **C bloqueado** (Tier 2 isócrona).
- **#268**: conteúdo de renda no produto (loader + refresh do entorno, ~5–6 h).
- Discutir se a **isócrona (#125)** vira pré-requisito antes de seguir a
  extração, já que o agregado fica `NA` sem C.
