# Nota técnica 221: cor/raça sobre os declarados no índice de diversidade (#471)

Achados RT-01, RT-02 e RT-03 da nona avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-17-p4-regioes-e-diversidade.md`).
Um PR: #472 (merge `c63cde5`).

## O problema

- **RT-01 (atrapalha).** A parte racial (35%) do `score_diversidade_discente`
  era `1 − Σ(cor/qt_mat_bas)²` sobre branca, preta, parda, amarela e
  indígena.
  - A não declarada ficava fora da soma dos quadrados e dentro do
    denominador, então quem não declarava a cor parecia diverso.
  - A correlação entre a parte racial e a proporção não declarada era 0,77
    no Brasil e 0,78 nas cinco UFs.
  - Com mais de 80% não declarada, a parte racial valia 0,99.
- **RT-02 (atrapalha).** As partes do índice não estavam na base, então
  não dava para conferir nem separar os efeitos.
- **RT-03 (detalhe).** O dicionário não dizia por que o INSE é vazio em 63%
  da base.

## Decisões (developer, 2026-11-17)

- **Mínimo de 50% de matrículas com cor declarada.** Ficam abaixo dele
  15.080 escolas (8,4%). O mínimo de 30% deixaria 6.435, e o de 70%,
  31.098.
- **Abaixo do mínimo, a parte racial fica vazia e o peso é
  redistribuído:** o índice é `(0,25·gênero + 0,20·inclusão + 0,20·EJA) /
  0,65`. A escola segue no ranking. Deixar o índice inteiro vazio tiraria
  15 mil escolas.
- `indices-v4` e `ivet-v1.6`.

## O que foi construído

- **Change `escolas_scores_cor_declarada`:**
  - a CTE da diversidade calcula as quatro partes numa subconsulta;
  - a parte racial divide pelas declaradas e, abaixo de metade
    declarada, fica `NULL`;
  - o verify refaz a fórmula escola a escola.
- **Base:** cinco colunas no fim do bloco Índices do EduMaps:
  - `diversidade_racial`;
  - `prop_cor_nao_declarada`;
  - `equilibrio_genero`;
  - `prop_educacao_especial_cc`;
  - `prop_eja`.

  Usam as expressões da MV, por um `LEFT JOIN clean.censo_matriculas mt`
  que só entra com o bloco. O dicionário traz a fórmula para refazer o
  índice.
- **RT-03:** `$INSE_VAZIO` em `inse_media` e `inse_classificacao`.
- **Textos:**
  - o `%METODO` da diversidade cita a v4 e a v2;
  - as ajudas dos rankings e da base (com a fórmula em R), fontes e
    metodologia, as funcionalidades e o `ivet.md` §2.2.

## Duas armadilhas pegas pelo `sqitch verify` global (antes do PR)

- **Verify preso a uma versão:** o verify da `escolas_scores_sem_registro`
  exigia `VERSÃO indices-v3`, e cada versão nova o quebraria.
  - Passou a aceitar "v3 ou posterior":
    `indices-v([3-9]|[1-9][0-9]+)`.
  - O verify novo segue a mesma forma.
  - **Regra:** verify de versão aceita a sua versão e as posteriores.
- **`SELECT mm.*` numa MV:** o Postgres expande o `*` na definição guardada,
  e a definição passou a citar `qt_mat_bas_dm`/`dv` (turnos).
  - O verify da #459 proíbe essas colunas e falhou.
  - Troquei por colunas explícitas.
  - **Regra:** sem `*` em subconsulta de MV.

## Validação

- **Suítes:** Perl inteira; R `testthat` inteiro, 2.246 testes. CI do PR
  verde na primeira rodada.
- **Sqitch no banco de fixtures:** deploy, `revert --to
  escolas_scores_sem_registro`, `deploy --verify` e o verify global.
- **Local (SP, BA, RS, PA e GO; 72.151 escolas):**
  - **Correlação** entre a parte racial e a não declarada: 0,04 (era 0,78).
  - **Parte racial média por faixa de não declaração**
    (até 10%, 10% a 30%, 30% a 50%):

    | | até 10% | 10% a 30% | 30% a 50% |
    |---|---|---|---|
    | antes | 0,39 | 0,58 | 0,76 |
    | agora | 0,36 | 0,38 | 0,37 |

  - **Escolas sem a parte racial:** 5.874.
  - **Índice refeito pelas partes:** 71.360 de 71.360 escolas.
  - **Média do índice:** 3,72 no Brasil.
  - **No modelo do IDEB** (anos iniciais, escolas públicas), a diversidade
    continua negativa (−0,10), agora pela diversidade racial real (−0,58),
    com a inclusão positiva (+0,57). Não é artefato. As partes na base
    deixam a pesquisadora separar os efeitos.
- **Recálculos:**
  - `bin/ranking.pl --source mv`;
  - `refresh_school_embeddings` (126.738 atualizadas);
  - `refresh_ivet` (`ivet-v1.6`, 180.540 escolas).

## LXC

- `deploy_db_dev`, `deploy_backend_dev`, `bin/ranking.pl --source mv`,
  `refresh_school_embeddings`, `deploy_analytics_dev` e `refresh_ivet`.
  Passos no roteiro `docs/admin/deploy-lxc-2026-11-16.md`.
