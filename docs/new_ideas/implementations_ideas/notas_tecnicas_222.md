# Nota técnica 222: lotação por sala e por turno no índice de atendimento (#473)

Achados RS-01 e RS-02 da décima avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-17-p4-oferta-e-turnos.md`).
Um PR: #474 (merge `976e9a3`). Ciclo em modo autônomo: o developer delegou a
avaliação, as decisões e o merge por 4 horas (2026-11-17), com aviso pelo
Telegram.

## O problema

- **RS-01 (atrapalha).** A parte "alunos por sala" (40%) do
  `score_capacidade_atendimento` era
  `GREATEST(0, 10·(1 − (qt_mat_bas/qt_salas_utilizadas)/50))`.
  - A conta divide todas as matrículas pelas salas, e a escola de dois ou
    três turnos parecia lotada.
  - No Censo 2025, 16.220 escolas ficavam com 0 nessa parte. Delas, 14.673
    (90%) usavam dois ou três turnos e tinham menos de 35 alunos por sala em
    cada turno.
  - A lotação por turno é parecida em todos os grupos, de 14 a 17 alunos.
- **Efeito na pergunta da P4,** "porte semelhante tem oferta parecida?": o
  índice caía de 5,42 (menos de 20 mil habitantes) para 4,36 (mais de 500
  mil). Cerca de 40% dessa diferença vinha dos turnos.
- **RS-02 (atrapalha).** As partes do atendimento não estavam na base.

## Decisões (autônomas)

- **Turnos:** matutino, vespertino e noturno com matrícula
  (`qt_mat_bas_dm`, `_dv`, `_n` maiores que 0), no mínimo 1. A escola só de
  tempo integral conta 1.
- **A mesma régua:** 0 com 50 ou mais alunos por sala e por turno.
- **`indices-v5` e `ivet-v1.7`;** as partes no fim do bloco Índices, como
  na #469 e na #471.
- **Limitação aceita:** a escola mista, com integral e meio período,
  divide os alunos do integral pelos turnos e subestima um pouco a
  lotação. Só mudaria a decisão para as escolas perto da régua.

## O que foi construído

- **Change `escolas_scores_turnos`:** só a parte da lotação muda. O verify
  refaz a fórmula do atendimento escola a escola.
- **Base:**
  - `alunos_sala_turno`;
  - `turnos`;
  - `etapas_regulares`: soma das `in_comum_*`, `in_eja` e
    `in_profissionalizante`, que não é a soma das `oferece_*`;
  - `prop_tempo_integral`;
  - `alimentacao`.

  Usam as expressões da MV. O dicionário traz a fórmula para refazer o
  índice.
- **Textos:** o `%METODO` do atendimento, as ajudas (rankings e base, com a
  fórmula em R), fontes, as funcionalidades e o `ivet.md` §2.2.

## Armadilhas

- **O verify da #459 proibia `qt_mat_bas_dm`/`dv` em toda a definição.** A
  intenção era impedir a diversidade de somar os turnos, mas agora o
  atendimento usa essas colunas para **contar** os turnos. A checagem passou
  a procurar `qt_mat_bas_d\M`: a coluna do diurno, palavra inteira, que a
  soma antiga sempre trazia e o código atual não usa. Testei que o padrão
  pega a soma antiga e não pega `qt_mat_bas_dm`.
  - **Regra:** verify de um defeito procura a assinatura do defeito, não
    o uso de uma coluna.
- **`$MAT::float8` de novo.** É a interpolação de pacote do Perl, já vista
  na #465. O teste de recomposição pegou.
  - **Regra:** `${VAR}` antes de `::`.
- **O `sqitch verify` global antes do PR** pegou o verify da #459 (a lição
  da #467, de novo).

## Validação

- **Suítes:** Perl inteira, 1728 testes; R `testthat`, 2246 testes. CI do PR
  verde na primeira rodada.
- **Sqitch no banco de fixtures:** deploy, `revert --to
  escolas_scores_cor_declarada`, `deploy --verify` e o verify global.
- **Índice de atendimento por porte** (escolas públicas):

  | Porte | Antes (`indices-v4`) | Agora (`indices-v5`) |
  |---|---|---|
  | menos de 20 mil | 5,42 | 6,20 |
  | 20 a 100 mil | 5,13 | 6,04 |
  | 100 a 500 mil | 4,66 | 5,75 |
  | mais de 500 mil | 4,36 | 5,57 |

  Os valores são os previstos na avaliação.
- **Base (SP, BA, RS, PA e GO):** o índice refeito pelas partes bate em
  71.360 de 71.360 escolas, e 247 têm 0 na parte de lotação.
- **Recálculos:**
  - `bin/ranking.pl --source mv`;
  - `refresh_school_embeddings` (121.875 atualizadas);
  - `refresh_ivet` (`ivet-v1.7`, 180.540 escolas).

## LXC

- `deploy_db_dev`, `deploy_backend_dev`, `bin/ranking.pl --source mv`,
  `refresh_school_embeddings`, `deploy_analytics_dev` e `refresh_ivet`.
- Passos no roteiro `docs/admin/deploy-lxc-2026-11-16.md`.
