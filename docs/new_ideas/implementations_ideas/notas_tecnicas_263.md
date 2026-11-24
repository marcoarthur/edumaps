# Nota técnica 263: o mês com a folha pela metade (#557)

Achado QT-01 da terceira avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-24-p2-folha-fundeb-cuiaba.md`,
o secretário de Cuiabá presta contas da folha do Fundeb). Issue aberta com a
aprovação do developer; plano aprovado com as opções A1 e B1. Um PR: #559
(merge `6b76a37`).

## O problema

- **QT-01 (atrapalha).** Em setembro e outubro de 2025, a folha de Cuiabá só
  traz o magistério: 3,2 mil registros contra 9,7 mil, 115 escolas contra
  168, sem auxiliares educacionais nem merendeiras. A folha das escolas cai
  de R$ 43 mi para R$ 22 mi por mês.
- Nada avisava: o gráfico mostrava a queda, mas a cobertura e a base
  tratavam 2025 como ano completo, e o gasto anual ficava abaixo do da
  contabilidade da prefeitura.

## Decisões

- **A regra, medida em todos os município-ano carregados:** um mês é
  incompleto quando tem menos categorias de profissionais que o habitual do
  ano (a moda) ou menos da metade dos registros do mês mediano.
  - Pelo número de registros e de categorias, não pelo valor: dezembro, com
    o 13º, e janeiro, mais baixo antes dos contratos do ano (69% da mediana
    em Cuiabá, com as 4 categorias), não viram alarme.
  - Marca Cuiabá 2025 (setembro e outubro), Cuiabá 2026 (junho) e Taubaté
    2026 (julho). Ubatuba e Alta Floresta, nada.
  - Os meses de Cuiabá 2026 que foram para a Secretaria não são marcados:
    os registros estão lá. É a #558.
- **A1, três lugares:**
  - a cobertura da folha (tela da base e `/fontes`), que já vem de
    `cobertura_siope`: "12 meses (setembro e outubro incompletos)";
  - o painel financeiro, com os números do mês e de um mês típico;
  - a coluna `meses_folha_incompletos` na base (ex.: `set, out`), para a
    planilha levar o aviso.
- **B1, só marcar:** os totais e as médias continuam sendo o que foi
  declarado. A causa não se sabe (a declaração do município ao SIOPE ou a
  carga), e o texto não afirma nenhuma. Conferir exige baixar de novo os
  meses do SIOPE, com permissão.
- **Depois de ver a tela:**
  - o painel de uma escola com folha só em janeiro e fevereiro de 2026
    avisava de junho. O aviso passou a listar só os meses da série
    mostrada;
  - o ano com só o total da Secretaria escondia o mês incompleto (Taubaté).
    Passou a "só o total da Secretaria; julho incompleto".

## Validação

- **Docker local:**
  - painel da EMEB Zeferino (Cuiabá) em 2025 com o aviso acima dos
    gráficos; em 2026, sem aviso;
  - `/fontes` e a tela da base com os meses incompletos de Cuiabá e
    Taubaté;
  - a base de Cuiabá 2025 com `set, out` nas 167 escolas com folha.
- **Testes:**
  - Perl, 209 arquivos (maio sem uma categoria marcado; janeiro mais baixo
    e dezembro com o 13º não; a cobertura, a coluna e o painel);
  - vitest, 1.430;
  - CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- Conferir no SIOPE se setembro e outubro de 2025 de Cuiabá estão
  incompletos na fonte (download com permissão).
- #558 (a cobertura conta como por escola o mês da Secretaria) segue
  aberta.
