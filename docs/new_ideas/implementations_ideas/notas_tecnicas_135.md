# Nota técnica 135 — #137 (Tier 3, fatia 1): bloco B por arealização do setor censitário

Esta nota cobre a **primeira fatia** da #137 (IVET versionado): o bloco
**B (socioeconômico)** lido do **setor censitário do Censo 2022**, *arealizado*
sobre a área de influência da escola (`influencia.md`, Tier 3). O núcleo puro do
IVET (`R/ivet.R`) já existia; faltava a **extração** dos componentes
socioeconômicos e o mapeamento componente → dimensão. PR **#262** (merge
`facb26b`).

## Contexto

A #137 define um índice **territorial** com sete blocos (A–G). O Tier 1
(`clean.escola_influencia`, `influencia-v1`) já entrega a **geometria** do
entorno (buffer 500/1000/2000 m). O passo natural é **medir o território** com o
que o Censo publica na menor unidade: o setor censitário.

O bloco B é o primeiro consumidor Tier 3 e serve de molde para os demais: uma
change Sqitch que materializa o cruzamento escola × setor e uma função R pura que
mapeia os componentes brutos para a dimensão do IVET.

## O que foi feito

### Banco — change `escola_entorno_socioeconomico`

- `clean.escola_entorno_socioeconomico`, grão
  `(co_entidade, nu_ano_censo, raio_m)`, populada por
  `clean.refresh_escola_entorno_socioeconomico(p_raios integer[], p_co_entidades
  bigint[])` — idempotente (UPSERT), com filtro opcional por escola (teste /
  refresh incremental).
- **Arealização**: cada setor que intersecta o buffer entra com
  **peso = área de interseção geodésica**. O componente é a média ponderada das
  proporções/valores do setor; `pop_total` é estimado por
  `Σ(pop_setor · w / area_setor)` (densidade × área).
- **Ausência ≠ zero (#154)**: setor com `supressao_celula_pequena` sai do
  numerador **e** do denominador; sem nenhum setor com dado o componente é
  `NULL`. `cobertura_pct` = fração da área efetivamente usada.
- `verify/` usa gate `DO $$ … RAISE EXCEPTION` (issue #160: um `SELECT` que
  devolve 0 linhas conta como sucesso no Sqitch 1.6.1).

### Fórmula — `analysis/edumapsr/R/ivet-socioeconomico.R`

- `ivet_bloco_socioeconomico(renda, pct_sem_instrucao, pct_fund_incomp,
  pct_preto_pardo, teto_renda, componentes)` — média dos componentes
  disponíveis via **`ivet_agregar()`** (a ausente fica fora do denominador), em
  `[0,1]`; **maior = mais vulnerável**.
- `ivet_bloco_socioeconomico_componentes()` e `ivet_componente_renda()`
  (normaliza `1 − clamp(renda/teto, 0, 1)`) + `ivet_componente_proporcao()`.
- `IVET_TETO_RENDA` = 2 salários mínimos de jul/2022 = **R$ 2.424**.

### Docs

- `docs/analises/ivet.md` §4.5 (extração, componentes, direção, #154) e §5/§6.
- `docs/analises/influencia.md` §8.1 — o Tier 3 ganha o primeiro consumidor.

## Decisões de design

- **Direção = vulnerabilidade** (maior = pior), coerente com o nome do índice.
  Consequência registrada: o bloco **A** (scores 0–10, maior = melhor) terá de
  ser **invertido** na reconciliação B↔C.
- **Estimador da proporção**: média ponderada por área **das proporções do
  setor** (e não razão de somas). Mantém consistência com `renda` e `pop`, e é o
  que `ivet.md` §4.5 documenta ("média ponderada dos setores").
- **Preto/pardo fora da dimensão por omissão**: usá-la como componente de
  vulnerabilidade é decisão de **equidade** que exige justificativa registrada e
  sobe a versão da fórmula (§4.3). Fica calculada e exposta.
- **`ivet_agregar()` e não `ivet_dimensao()`**: aqui `NA` significa "sem dado"
  (ausente fora do denominador), não "não tem o recurso". Em `ivet_dimensao()`
  `NA→0` vale para o bloco escolar.

## Validação

- `backend/t/escola_entorno_socioeconomico.t` — **7 subtests PASS** (SQL
  sintético: buffer fora de qualquer setor, cobertura zero, renda NULL ≠ 0,
  filtro por escola, raio inválido).
- `analysis/edumapsr/tests/testthat/test-ivet-socioeconomico.R` — **30
  asserções** (normalização, `NA` fora do denominador, direção, teto).
- `sqitch verify` — **PASS**.
- **E2E no produto** (20 escolas reais, 2026-10-16): buffers + entorno
  materializados (60 + 60). `pop_total` confere com a estimativa densidade × área
  (erro rel. máx. 0,5%); `pct_preto_pardo` confere com a média ponderada por área
  (erro abs. máx. **4,7e-5`). Amostra **removida no fim**; o produto voltou ao
  estado anterior (as duas tabelas a 0).
- CI do PR #262: `Perl contra o banco de fixtures` **PASS** (12m14s).

## Dois bugs encontrados fora dos testes sintéticos

Ambos passariam nos testes e só apareceram no dado real / no deploy:

1. **`cor_total` incluía `cor_sem_decl`** — coluna **sempre `NULL`** por decisão
  (#238). O `SUM` virava `NULL` e `pct_preto_pardo` saía `NULL` para **todas** as
  escolas. Corrigido: denominador = branca + preta + amarela + parda + indígena.
- (2) **`Collate`**: `R CMD INSTALL` no deploy falhou com
  `files in '…/R' missing from 'Collate' field: ivet-socioeconomico.R'`.

## Caveat de dados (#238) — bloco B sai `NA` no produto

O loader do setor (`EduMaps::Ingestion::Job::SetoresCenso2022`) carrega apenas
**básico (domicílios), demografia e cor/raça**. Por decisão do developer (#238),
`esc_*`, `rend_media`, `rend_per_capita` e `cor_sem_decl` ficam **`NULL`** — o
Censo 2022 não publica escolaridade/renda por setor. Medido no produto:
`count(rend_per_capita) = 0` em 468.097 setores.

Consequência: os componentes de **renda e instrução** saem `NULL` (ausência,
nunca 0 — #154) e a **dimensão B é `NA`** no produto; o único componente com dado
é **`pct_preto_pardo`**. Para o bloco B ter renda/instrução arealizadas é preciso
**estender o loader** (alfabetização e `caracteristicas_domicilio` estão nos
brutos do IBGE, mas não são carregados). Registrado em `ivet.md` §4.5.

## Deploy

`rex prepare` + `deploy_db_dev` + `deploy_analytics_dev` + `deploy_backend_dev`
(hosts LXC). No produto, a change foi **re-deployada** com
`sqitch revert db:pg://…/edumaps_dev --to escola_influencia` + deploy. O
`change_id` (`45f09208…`) **não** muda com a edição do corpo do script — só
`requires` e a ordem mudam o id. Imagens Docker locais `sqitch` e `analytic`
reconstruídas; a função R (`ivet_bloco_socioeconomico`) está presente na imagem e
no host `analytic.edumaps`.

## Próximos passos (não nesta nota)

- **Estender o loader do setor** para renda/instrução (#238) — sem isso o bloco B
  fica sem os componentes de renda e instrução.
- **Reconciliação de fórmula B↔C** (§6): decidir como o bloco A (maior = melhor)
  se inverte para a direção de vulnerabilidade.
- Extração dos blocos **C–G**; e2e real da camada (local tem buffers e 0 setores;
  produto tem setores e 0 buffers — exige popular um lado).
