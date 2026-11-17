# Nota técnica 224: a ajuda refaz os seis índices, com teste (#477)

Achados RQ-01 e RQ-02 da décima segunda avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-17-p4-partes-dos-indices.md`).
Um PR: #478 (merge `189be08`).

## O problema

- **RQ-01 (atrapalha).** A expressão R da ajuda da base que refaz a
  capacidade gestora, publicada na #476, terminava em
  `/ (0.7 + 0.2 * !is.na(p3) + 0.1 * !is.na(...))`.
  - Em R, `!` tem precedência menor que `*` e `+`. A expressão é lida como
    `0.2 * !(is.na(p3) + 0.1 * !is.na(...))`, e o divisor sai errado.
  - Na BA e na MG, só 6.593 de 32.016 escolas batiam com o índice, com
    erro de até 4,1 pontos.
  - **A base estava certa.** O teste da #476 refazia o índice em Perl, com a
    conta certa; a expressão da ajuda nunca foi executada.
- **RQ-02 (atrapalha).** A infraestrutura (27 itens em quatro grupos) e a
  sustentabilidade (quatro partes) não se decompunham pela base: 11 itens da
  primeira e nenhum da segunda. A ajuda ainda dizia que nenhum índice se
  refazia.

## Decisões (developer, 2026-11-17)

- **Um bloco R único** na ajuda, "Refazer os seis índices no R", com uma
  linha `refeito_<índice>` por índice, no lugar das quatro expressões
  soltas.
- **Um teste que executa a ajuda**, no `testthat`, contra uma amostra fixa
  da base.
- **Só as partes** da infraestrutura e da sustentabilidade, sem os 16 itens
  que faltam no bloco Infraestrutura. A fórmula não muda, e a versão não
  sobe.

## O que foi construído

- **Ajuda `base-de-analise.md`:**
  - a seção "Refazer os seis índices no R", com um bloco `within(base, …)`.
    A gestora usa `tem_aluno_gestor` e `tem_acesso` (lógicos sem `!` na
    conta);
  - cada seção de partes aponta para o bloco;
  - as partes da infraestrutura e da sustentabilidade, com os itens.
- **Teste `test-ajuda-base-indices.R`:**
  - lê os blocos ` ```r ` da ajuda e escolhe o que cria `refeito_`;
  - roda o bloco sobre `fixtures/base-indices-amostra.csv` (176 escolas da
    BA e da MG, `indices-v6`, com os casos de borda: parte racial vazia,
    privadas, sem matrícula, sem salas, sem docentes, alimentação vazia,
    meio ponto de área verde, federais);
  - compara cada `refeito_*` com o `indice_*` (diferença menor que 0,006);
  - confere que a amostra é da `indices-v6`. Quando a fórmula mudar, a
    amostra é gerada de novo, e o teste avisa;
  - é pulado sem `docs/` (imagem `analytic`). No CI ele roda.
  - Com a expressão antiga, falha em 116 de 176 escolas.
- **Base de análise (`BaseAnalise.pm`):**
  - `@INFRA_PARTES` (`infra_basico`, `infra_salas_equipamentos`,
    `infra_acessibilidade`, `infra_tecnologia`, de 0 a 1) e
    `@SUSTENTABILIDADE` (`energia_renovavel`, `reciclagem_lixo`,
    `area_verde_plantio`, `educacao_ambiental`) no fim do bloco Índices;
  - lidas da própria escola (`e`), com os mesmos `COALESCE(…, 0)` e `OR` da
    MV, por dois helpers (`_itens`, `_ou`). Como no índice, item sem
    resposta conta como ausente.

## Validação

- Perl: suíte inteira, 196 arquivos, 1730 testes; subtest novo em
  `base_analise.t`. R: `testthat` inteiro. CI do PR verde, com o teste novo
  executado.
- BA e MG (32.016 escolas): o bloco da ajuda refaz os seis índices em todas.
- Modelo do IDEB dos anos iniciais (7.446 escolas públicas): `infra_basico`
  +0,26 (p = 0,01), `infra_salas_equipamentos` −0,004 (p = 0,95).

## O que fica

- Toda expressão de código numa ajuda deveria ser executada por um teste.
  A da infraestrutura básica (`with(base, …)`) e a do mapa (`sf`) ainda não
  são.

## LXC

- Só `deploy_backend_dev` (e o `deploy_analytics_dev` leva o teste). Sem
  change e sem recálculo. Conferência da base no roteiro
  `docs/admin/deploy-lxc-2026-11-16.md`.
