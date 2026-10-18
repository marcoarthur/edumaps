# Nota técnica 146 — #137: bloco C (mobilidade) do IVET — o agregado destrava

Esta nota documenta a extração do bloco **C (acesso/mobilidade)** do IVET — o
**único bloco territorial que faltava**. Com ele, `ivet_blocos_territoriais_minimos()`
(C+D+E) fica satisfeita e **o agregado do IVET passa a ser publicável**. PR
**#276** (branch `feat/analytics-ivet-bloco-c`, commit `1da3398`).

## Contexto

O developer pediu "terminar o IVET". Levantado o estado:

- Blocos extraídos: **A** (escola), **B** (socioeconômico), **D** (saúde),
  **E** (segurança), **G** (recursos).
- **F** (meio ambiente): cobertura do solo extraída (#255), exposição a risco
  pendente.
- **C** (mobilidade): **não existia** — nem no card (`bloco_a/b/d/e/g`, sem
  `bloco_c`), nem em R (`R/` sem `ivet-mobilidade.R`).

Como os mínimos são **C+D+E**, era C que mantinha o agregado em `NA`.

## A decisão: C por proxy (produto, 2026-10-18)

A dimensão central de C é o **acesso** — isócrona / distância-tempo —, e
`clean.isocrona_escolar` está **vazia**: depende de um motor de roteamento
(**OSRM/Valhalla**) + um tileset OSM, ausente em todos os hosts. Os demais
componentes do C também estão vazios (`antt_od_municipio`, `snv_trecho_vmda`).

Decisão do developer: **C por proxy do que existe** — lido como **exposição
viária** (mudança de significado aceite explicitamente), com a isócrona como
ausente (`NA`, #154).

## O que foi feito

Fonte `analytics.mobilidade_escola` (view, uma linha por escola) +
`clean.populacao_municipal` como denominador. Grão **municipal** (a escola é o
ponto de observação; §1).

| componente | bruto (tabela) | normalização | direção |
|---|---|---|---|
| risco de sinistros | `sinistros_12m` (RENAEST) | `clamp(taxa100k / 500)` | mais sinistros = + |
| exposição da frota | `renavam_total_frota` (RENAVM) | `clamp((frota / pop) / 1)` | mais frota = + |

- Default `componentes = c("risco_sinistros", "exposicao_frota")`.
- **Fora do default**: `sinistros_fatais_12m` (RENAEST) — **0 em todas as
  escolas-município do dev**, é constante e não entra; `isocrona`, `antt_od` e
  `vmda` estão **vazios** e entram quando existirem, no mesmo bloco, sem nova
  fórmula.
- **Tetos** (produto, calibrados no dev a 2026-10-18, por município):
  `IVET_TETO_SINISTROS_100K` = 500 (p50 ≈ 60, p90 ≈ 429, p99 ≈ 988);
  `IVET_TETO_FROTA_POR_HAB` = 1 (p90 ≈ 0,89).
- **#154**: sem o dado, o componente é `NA` e fica **fora** do denominador da
  dimensão; `0` real (sem sinistros / sem frota) é `0`.

Funções: `ivet_bloco_mobilidade()`, `ivet_bloco_mobilidade_componentes()`,
`ivet_componente_risco_sinistros()`, `ivet_componente_exposicao_frota()`.

## O agregado destrava

Antes: sem C, `ivet_v1()` devolvia `ivet = NA` e `publicavel = FALSE`. Agora, com
C+D+E presentes, o agregado é calculado. O teste
`test-ivet-mobilidade.R` cobre explicitamente os dois casos (com e sem
mobilidade).

## Testes

`tests/testthat/test-ivet-mobilidade.R` — **28 PASS**: componentes diretos
(clamp e saturação), `0` real distinto de `NA`, `NA` preservado (#154), a média
das disponíveis, o subconjunto de componentes e o destrave do agregado. A
**suíte do IVET inteira** (card, escola, recursos, saúde, segurança,
socioeconômico) fica verde.

## Deploy

`rex prepare` + `rex -H analytic.edumaps deploy_analytics_dev`.

⚠️ **O pacote chama-se `edumapsAnalytics`** (não `edumapsr`) — o `library(edumapsr)`
falha; a validação usa `library(edumapsAnalytics)`. Validado no host:
`exists("ivet_bloco_mobilidade")` = TRUE e `ivet_bloco_mobilidade(25, 5000, 10000)`
= 0,5.

O `NAMESPACE` foi regenerado por `roxygen2`; o **`Collate` do `DESCRIPTION` é
mantido à mão** (roxygen não o regenera) — foi preciso acrescentar
`'ivet-mobilidade.R'` explicitamente.

## O que ainda falta no IVET

- **F-exposição** (ISH / declividade / queimada) — usa o pipeline de raster da
  #255 (MapBiomas Coleção 11). **Não bloqueia** o agregado.
- **Isócrona de C** — motor de roteamento (OSRM/Valhalla). **Não bloqueia** o
  agregado; quando existir, vira componente do C.
- **#138** (similaridade/PgVector) continua, por desenho, a esperar as dimensões
  novas do IVET; **#139** (coeficientes na literatura) segue aberta.
