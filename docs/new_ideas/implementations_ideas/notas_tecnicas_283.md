# Nota técnica 283: a marca do piso na folha detalhada (#598)

Um PR: #600. Achado QB-02 da quinta avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-25-p2-piso-por-vinculo.md`).
Segue a #597 (nota 282): a contagem dizia quantos e quem; faltava conferir
os casos na lista.

## O problema

- A folha detalhada do mês (da escola e do total da Secretaria, #585)
  buscava só pelo nome, em páginas de 100. Os 1.559 abaixo do piso de
  Cuiabá não tinham marca nem filtro: o tribunal pede nome a nome.

## Decisões (developer: as recomendadas do plano)

- **A regra da marca é a da contagem da rede**: a mediana do base por 40 h
  nos meses da pessoa em **toda a folha do município** (escolas e
  Secretaria), sem dezembro, 3 meses ou mais. Quem passou um mês na
  Secretaria e o resto numa escola fica marcado nas duas listas.
- **Por consulta, sem tabela nova** (`EduMaps::BaseAnalise->piso_pessoas`):
  a marca tem CPF e não pode ir para `analytics` (SELECT automático do
  `edumaps_leitor`). A consulta parte só das pessoas da lista do mês:
  0,29 s na maior lista (Secretaria de Cuiabá); a resposta inteira, com
  13.019 linhas, em 1,08 s.
- **Vazio ≠ falso**: sem piso no ano, carga fora de horas (#572) ou fora do
  magistério, `base_40h_ano` e `abaixo_piso_ano` vêm vazios; com menos de 3
  meses, a marca é falsa (como na contagem).
- **O filtro de situação é o da linha** (a declarada no mês, a que a coluna
  mostra), não a do ano (#597). Para ~2% das pessoas as duas diferem.
- **Os filtros aparecem também na lista da escola** (antes só acima de 100
  linhas), quando há alguém marcado ou mais de uma situação. A nota conta
  pessoas (CPF mascarado e nome), não linhas.
- Sem CSV da lista filtrada: fora do pedido do QB-02.

## Resultado

- Cuiabá, Secretaria, abril de 2026: 1.504 pessoas marcadas (mais que os
  1.421 "só na Secretaria" da contagem: entram as que também passaram por
  escola; saem as que não receberam em abril).

## Testes

- `t/04-api/school/folha_piso.t` (novo, INEP `60059801`).
- Vitest: `SchoolPayrollPage.test.js` (contagem por pessoa, coluna, filtros,
  sem a conta).

## Pendente

- LXC: `deploy_backend_dev` e `deploy_frontend_dev` (roteiro).
