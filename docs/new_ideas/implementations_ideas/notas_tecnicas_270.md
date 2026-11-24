# Nota técnica 270: o salário do magistério da rede inteira (#571)

Achado QI-01 da quarta avaliação da P3
(`docs/personas/publicos/avaliacoes/2026-11-24-p3-salario-rede-municipal.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #573 (merge `2278a68`).

## O problema

- **QI-01 (atrapalha).** O salário do magistério saía só por escola, na
  base. Onde o SIOPE só traz o total da Secretaria (Taubaté), nem a base nem
  o painel davam um salário médio, embora o SIOPE traga o salário e a carga
  de cada pessoa nessas linhas.

## Decisões

- **A conta:** `salario_rede` (`EduMaps::BaseAnalise`), por município e
  ano, com toda a folha do magistério, nas escolas e no total da
  Secretaria, por pessoa e mês, sem dezembro (13º). Sai a mediana do
  salário total e do base, a carga mais comum e o número de pessoas.
- **B1, sem conversão para 40 horas:** é o que se paga por mês, e não
  depende da carga estar em horas. A conversão espera a #572 (Taubaté,
  carga 18, daria R$ 15,5 mil "por 40 h").
- **A1, painel e tela da base:** no painel da escola (a escola contra a
  rede) e no da Secretaria (onde é o único salário), e na tela da base, por
  município do recorte, dentro da cobertura da folha.
- **Nos dados:** Taubaté 2026, total R$ 6.975 e base R$ 2.669 (carga
  18); Ubatuba 2026, R$ 7.186 e R$ 5.572 (carga 31); Cuiabá 2025, R$ 5.554
  e R$ 5.049 (carga 23); Alta Floresta 2024, R$ 6.136 e R$ 4.734 (carga 40).

## Validação

- **Docker local:** o painel da Secretaria de Taubaté com a linha do
  magistério na rede; a tela da base de SP com Taubaté e Ubatuba.
- **Testes:** Perl, 211 arquivos (a rede com a Secretaria, sem dezembro, no
  painel e na cobertura); vitest, 1.444. CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- #572 (a conversão por 40 horas supõe horas) segue aberta.
