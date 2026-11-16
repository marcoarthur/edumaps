# Nota técnica 215: a diversidade discente usa a educação especial em classe comum (#459)

Achado ao escrever o método dos índices (#457, nota 214). Um PR: #460 (merge
`6dea752`). Decisões do developer: a opção A (`qt_mat_esp_cc`) e o IVET em
`ivet-v1.4`.

## O erro

- O `score_diversidade_discente` tem um componente de 20% que devia medir a
  inclusão de alunos com deficiência. Ele somava `qt_mat_bas_d`,
  `qt_mat_bas_dm` e `qt_mat_bas_dv`.
- O loader do Censo rotulou essas colunas como "Deficiência", mas elas são
  **turnos**: diurno, matutino e vespertino. A change `censo_turno_comments`
  corrigiu os comentários e não corrigiu o índice.
- **Efeito:** o componente valia 0,976 em média, contra 0,056 de educação
  especial real. Quase toda escola ganhava 2 pontos.
- O erro só apareceu quando a tela passou a dizer como o índice é calculado.

## A correção

- **A fórmula:** `0.20 · LEAST(1, qt_mat_esp_cc / qt_mat_bas) · 10`, com a
  educação especial **em classe comum**. É o mesmo formato das outras
  proporções.
- **Por que a opção A:** o índice mede diversidade **entre os alunos da
  escola**, e a inclusão em classe comum é o que mede isso. Com o total de
  educação especial (`qt_mat_esp`, opção B), as 1.774 escolas só de classe
  especial ganhariam os 2 pontos inteiros.
- **A change:** `escolas_scores_diversidade_esp`. A `escolas_scores` está
  deployada e não se edita (AGENTS.md).
  - **Deploy:** faz `DROP` e `CREATE` da MV. Nenhuma view do banco depende
    dela, o que foi medido em `pg_depend`. Repõe:
    - os 7 índices;
    - os comentários, inclusive os que outras changes tinham posto
      (`column_descriptions`, `quarantine_censo_escolas_scores`);
    - o `GRANT SELECT` ao `edumaps_leitor`, que a MV tinha.
  - **Revert:** recria a definição antiga, com os comentários e o GRANT de
    antes.
  - **Verify:** é um `DO $$ … RAISE` (#160). Falha se a definição citar
    `qt_mat_bas_dm/dv` ou não citar `qt_mat_esp_cc`, ou se perder o GRANT ou
    o índice pk.
- **Testes na base do CI:**
  - deploy, verify, `revert --to analytics_cluster_execucoes` e redeploy
    passaram;
  - rodado à mão contra a definição antiga, o verify falha ("ainda soma os
    turnos").

## Consumidores

| Consumidor | O que foi feito |
|---|---|
| `analytics.ranking_escola` | `bin/ranking.pl --source mv` (45 s, 6 índices) |
| `analytics.school_embedding` | `refresh_school_embeddings` (177.501 vetores) |
| `View::ClusterEscola` (k-means ao vivo) | nada: lê a MV |
| Agrupamento por indicadores (#427) | nada: usa `school_indicators`, não a MV |
| IVET | `ivet-v1.4` e `refresh_ivet` (180.540 linhas) |

- **O IVET:**
  - **Versão:** a agregação é a mesma, mas o insumo mudou, e os resultados
    também. Pela regra de versão citável, sobe para `ivet-v1.4`, em
    `ivet_versao()`, no card (com uma nota no componente), nos testes e em
    `docs/analises/ivet.md`.
  - **Recálculo:** o primeiro `refresh_ivet` saiu `ivet-v1.3`, porque o
    contêiner `analytic` ainda tinha o pacote antigo. Reconstruída a imagem,
    saiu `ivet-v1.4`.
  - **Publicáveis:** nenhum, como antes, porque faltam os blocos
    territoriais mínimos (#295).
- **Os jobs do IVET de 09 e 10/11:** tinham falhado como "stuck in queue",
  porque eram anteriores ao worker da fila `analytics` (#423). Agora rodam
  em cerca de 1,5 min.

## Efeito (stack local, Censo 2025, 180.540 escolas)

- **Índice:** a média foi de 6,00 para 4,16, e a mediana de 6,10 para 4,22.
  A diferença por escola vai de −1,77 a +2,00: as escolas com muita inclusão
  sobem.
- **Ranking de diversidade por município:**
  - no Brasil, 134.450 escolas mudam de posição (17,9 posições em média);
  - em Vitória, mudam 173 de 180, e o topo passa a ser das escolas de EJA.
- **Escolas semelhantes:** numa amostra de 200 escolas, 177 têm outra lista
  de 3, e 20 uma lista totalmente nova.
- **Textos:**
  - o método na tela (`%METODO`) e a ajuda dizem a inclusão corrigida e que
    as notas de antes de 16/11/2026 não são comparáveis;
  - o comentário da MV aponta a `ivet-v1.4`.

## Deploy

**LXC.** A ordem está no roteiro `docs/admin/deploy-lxc-2026-11-16.md`:

1. `deploy_db_dev`, conferido pelo verify da change;
2. `bin/ranking.pl --source mv`;
3. `refresh_school_embeddings`;
4. `deploy_analytics_dev` e `refresh_ivet`, com `ivet-v1.4`.

**Stack local.** As imagens `sqitch`, `backend`, `minion`,
`minion-analytics`, `frontend` e `analytic` foram reconstruídas, e o sqitch
está em dia.
