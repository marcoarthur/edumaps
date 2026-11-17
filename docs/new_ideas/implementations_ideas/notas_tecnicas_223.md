# Nota técnica 223: capacidade gestora sem o zero imposto (#475)

Achados RR-01 e RR-02 da décima primeira avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-17-p4-gestora.md`).
Um PR: #476 (merge `ed2b4a0`).

## O problema

- **RR-01 (detalhe).** Na `score_capacidade_gestora`, a parte "gestores por
  aluno" (20%) era `CASE WHEN qt_gest_bas > 0 AND qt_mat_bas > 0 THEN … ELSE 0`.
  As 1.774 escolas com gestor e sem matrícula (Censo 2025) recebiam 0 nessa
  parte. É o padrão da #467 em pequena escala: a ausência vira nota baixa.
- **RR-02 (detalhe).** A parte "acesso ao cargo" (10%) conta concurso,
  eleição e processo seletivo. Na privada, o gestor é escolhido pela
  mantenedora, e o Censo não tem essa categoria. Nenhuma das 42.454
  privadas pontua, e toda privada perdia até 1 ponto por construção.
- Nas públicas, o 0 é dado real: 90.729 escolas têm 0 (sobretudo municipais,
  com gestor indicado). Média da parte: federal 8,33, estadual 5,33,
  municipal 2,72.

## Decisões (developer, 2026-11-17)

- **Fórmula, não só texto,** nas duas: a parte que não se aplica fica vazia,
  e o peso dela vai para as outras, como a parte racial da diversidade
  (#471). O índice inteiro vazio sem matrícula (padrão da #467) foi
  descartado: a escola tem gestor, e 80% do índice existe.
- **As partes na base de análise,** como nas #469, #471 e #473.
- **Versões:** `indices-v6` e `ivet-v1.8` (mesma agregação, insumo muda).

## O que foi construído

- **Change `escolas_scores_gestora`** (apaga e recria a MV a partir da
  `escolas_scores_turnos`; só o CTE `score_gestao` muda):
  - uma subconsulta calcula as cinco partes, com `parte_gestores_aluno` NULL
    sem matrícula e `parte_acesso_cargo` NULL com `tp_dependencia = 4`;
  - o índice é `(Σ peso·parte presente) ÷ (0,7 + 0,2·[gestores_aluno] + 0,1·[acesso])`;
  - `tp_dependencia` vem da subconsulta do cadastro, que já existia para os
    colegiados; `IS DISTINCT FROM 4` deixa a escola sem cadastro como
    pública;
  - o verify recalcula a fórmula para toda escola com gestor e aceita
    `indices-v6` ou posterior. Nenhum verify antigo dependia da fórmula
    da gestora.
- **Registro e textos:** `$INDICES_VERSAO`, `@INDICES_HISTORICO`, `%METODO`
  (o acesso "só na rede pública"), ajudas `rankings.md`,
  `base-de-analise.md` e `fontes-e-metodologia.md`, funcionalidades e
  `docs/analises/ivet.md`.
- **Base de análise:** `gestores_formacao`, `prop_gestores_espec_gestao`,
  `alunos_por_gestor` (bruto, matrículas ÷ gestores; a parte é
  `mínimo(1, 200 ÷ alunos_por_gestor)`), `orgaos_colegiados` (de 5) e
  `prop_acesso_cargo_selecao`, no fim do bloco Índices, com a junção a
  `clean.censo_gestor` só quando o bloco é escolhido. A ajuda traz a
  expressão em R que refaz o índice.

## Validação

- Perl: suíte inteira, 196 arquivos, 1729 testes; subtest novo em
  `t/04-api/base_analise.t` (pública com matrícula, privada, sem matrícula:
  índice refeito pelas partes). R: `testthat` inteiro. CI do PR verde.
- Sqitch no banco de fixtures: deploy, `revert --to escolas_scores_turnos`,
  `deploy --verify` e o verify global.
- Local (Censo 2025, 180.540 escolas com gestor):
  - média da capacidade gestora: públicas 5,46 → 5,47, privadas 4,26 → 4,75;
  - as 1.774 escolas sem matrícula: 3,16 → 4,15;
  - `ranking.pl --source mv`, `refresh_school_embeddings` e `refresh_ivet`
    (`ivet-v1.8`, 180.540 escolas) refeitos.

## LXC

- `deploy_db_dev` (sexta change dos índices), `deploy_backend_dev`,
  `bin/ranking.pl --source mv`, `refresh_school_embeddings`,
  `deploy_analytics_dev` e `refresh_ivet`. Passos e números esperados no
  roteiro `docs/admin/deploy-lxc-2026-11-16.md`.
