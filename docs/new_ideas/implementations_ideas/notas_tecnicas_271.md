# Nota técnica 271: a carga que não parece em horas (#572)

Achado QI-02 da quarta avaliação da P3
(`docs/personas/publicos/avaliacoes/2026-11-24-p3-salario-rede-municipal.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #574 (merge `317719e`).

## O problema

- **QI-02 (incomoda).** As contas por 40 horas (salário total e base, e a
  contagem do piso da #563) fazem salário ÷ carga × 40, supondo a carga em
  horas semanais.
- Em Taubaté (2026), 94% dos pagamentos do magistério têm carga 18, com
  salário total médio de R$ 7.172: "por 40 horas" daria R$ 15,9 mil. A
  carga parece estar em aulas ou numa jornada parcial.

## Decisões

- **B1, a regra:** a carga não parece em horas quando a maioria dos
  pagamentos do magistério do município no ano tem carga abaixo de 20.
  Medido em todos os município-ano: só Taubaté 2026 entra (94,1%); Cuiabá
  2025, com carga mais comum 23, tem 1,8% abaixo de 20 e não entra.
- **A1, vazio e não número errado:** nesse município e ano,
  `salario_40h_magisterio`, `salario_base_40h_magisterio` e
  `prof_magisterio_base_abaixo_piso` ficam vazios; o salário sem conversão
  (`salario_medio_magisterio`) fica, com a nova `carga_comum_municipio`.
  "Vazio, nunca zero", e nunca um número inflado.
- **Onde vem a marca:** `salario_rede` (#571) ganhou `carga_suspeita`. Na
  base, o valor por município do ano entra na consulta por um `VALUES`
  montado no Perl, com códigos de 6 dígitos e números validados.
- **Na tela:** o texto do salário da rede (painel e tela da base) diz que a
  carga não parece ser em horas e que as contas por 40 horas não valem ali.
- **Hoje é preventivo:** Taubaté não tem escola na base. A regra protege o
  próximo município com folha por escola e carga em aulas.

## Validação

- **Docker local:** o painel da Secretaria de Taubaté com o aviso; Ubatuba
  sem mudança (carga 31, salário por 40 horas nas 47 escolas).
- **Testes:** Perl, 211 arquivos (carga 18 → vazio, com o salário sem
  conversão; carga 40 → `carga_comum_municipio` 40); vitest, 1.445. CI do
  PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- Os dois achados da quarta rodada da P3 entregues; segue a #429 (bairro).
