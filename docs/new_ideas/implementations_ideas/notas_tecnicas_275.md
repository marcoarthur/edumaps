# Nota técnica 275: o aviso de anos com o ano da folha (#583)

Achado QF-01 da trigésima nona avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-24-p4-salario-ideb.md`, o
salário do professor e o IDEB em Cuiabá). Modo autônomo autorizado pelo
developer (até 25/11, 9h). Um PR: #584 (merge `9c9bee4`), só frontend.

## O problema

- **QF-01 (incomoda).** O aviso de anos diferentes da tela da base (#514)
  comparava o IDEB com o Censo e dizia o ano do INSE, mas não o da folha
  do SIOPE. Em Cuiabá, o IDEB é de 2023 e a folha, de 2025 (só há 2025 e
  2026): o salário explicava um desempenho de dois anos antes sem aviso.

## Decisões

- **O aviso ganha o ano da folha** quando os blocos Desempenho e
  Remuneração estão marcados e os anos diferem: "A folha do SIOPE é de
  2025, dois anos depois do IDEB (2023): num modelo, o salário e o gasto
  são de outro ano que o desempenho."
- **Também quando só a folha difere:** a frase do Censo só aparece quando o
  Censo difere do IDEB.
- **O que ela mediu** (para o registro): nas 50 escolas com IDEB dos anos
  iniciais, +0,13 de IDEB por R$ 1.000 de salário total por 40 horas,
  controlando o INSE; +0,19 com o salário base.

## Validação

- **Docker local:** a tela da base de Cuiabá (Desempenho + Remuneração,
  folha 2025) com o aviso do Censo e da folha.
- **Testes:** vitest, 1.456. CI do PR verde.

## Pendências

- No LXC: `deploy_frontend_dev`.
