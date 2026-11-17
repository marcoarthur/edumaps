# Nota técnica 220: partes do índice de capacitação docente na base (#469)

Achados RW-01 e RW-02 da oitava avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-17-p4-indices-v3.md`).
Um PR: #470 (merge `6302a35`).

## O problema

- **RW-01 (atrapalha).** O índice de capacitação docente soma quatro partes:
  superior completo (30%), pós-graduação (30%), concursados (20%) e formação
  continuada (20%). Ele não se associava ao IDEB dos anos iniciais
  (p = 0,56), mas duas proporções da base se associavam em sentidos opostos:
  licenciatura com +0,34 e efetivos com −0,30.
  - A base não trazia o superior completo, a pós com especialização nem a
    formação continuada.
  - Sem elas, não dava para separar nem refazer o índice citado.
- **RW-02 (detalhe).** A ajuda dava os pesos, mas não dizia que eles são uma
  escolha do EduMaps.

## O que foi construído

- **Três colunas no fim do bloco Docência,** depois de
  `prop_sem_especializacao`, para não mudar a posição das antigas:
  - `prop_superior`;
  - `prop_pos_graduacao`: especialização, mestrado ou doutorado;
  - `prop_formacao_continuada`: soma das 18 `qt_doc_bas_espec_*`.

  As três usam as expressões da MV, com o limite a 1. Em 2.751 escolas, a
  soma das pós passa o total de docentes, porque o Censo conta de novo o
  docente que tem mais de uma.
- **Dicionário:** as três colunas e `prop_efetivos` dizem qual parte do
  índice são.
- **Ajuda da base:** traz a fórmula em R para refazer o índice:
  `round(10 * (0.3*prop_superior + 0.3*prop_pos_graduacao + 0.2*pmin(prop_efetivos, 1) + 0.2*prop_formacao_continuada), 2)`.
- **Pesos normativos (RW-02):** uma frase no dicionário dos seis `indice_*`
  e em "O que cada índice mede" (`rankings.md`). O `%METODO` da tela do
  ranking não mudou.
- **A fórmula do índice não muda** (`indices-v3`).

## Armadilha

- **`LEAST(1, NULL)` é 1 no Postgres:** o `LEAST`/`GREATEST` ignora os
  nulos.
  - Na primeira versão, as 315 escolas sem docentes da BA e do ES saíam com
    100% de superior e de pós.
  - Agora a expressão é `CASE WHEN d.qt_doc_bas > 0 THEN LEAST(1, …) END`
    (`_ate_um` em `BaseAnalise.pm`), e `t/04-api/indices_sem_registro.t`
    confere as partes vazias.
  - A MV usa o mesmo `LEAST(1, x / NULLIF(…))`, mas desde a
    `escolas_scores_sem_registro` as CTEs filtram `qt_doc_bas > 0`, então não
    chegam ao `NULL`.
  - **Regra:** um `LEAST` ou `GREATEST` sobre uma divisão por `NULLIF`
    precisa de guarda.

## Validação

- Perl: suíte inteira, 196 arquivos, 1726 testes. CI do PR verde.
- Na BA e no ES, com 19.152 escolas:
  - o índice refeito pelas partes bate em 18.837 de 18.837 escolas (no
    máximo 0,01, arredondamento);
  - as 315 escolas sem o índice têm as partes vazias.
- **Modelo do IDEB dos anos iniciais** (4.155 escolas, R² 0,384; com rede,
  localização, UF e INSE):
  - superior: +0,25 (p = 0,004);
  - pós: +0,16 (p = 0,04);
  - efetivos: −0,33 (p < 0,001);
  - formação continuada: 0,01 (p = 0,88).

## LXC

- Só o `deploy_backend_dev`. A conferência está no roteiro
  `docs/admin/deploy-lxc-2026-11-16.md`.
