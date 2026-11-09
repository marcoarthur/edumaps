# Nota técnica 182: DataTable sem adivinhar snippet pelo nome

PR #357 (2026-11-09). Item do backlog registrado desde a #351.

## Problema

O `DataTable` (componente compartilhado em `shared/ui`) aceitava em
`columns[].render` tanto uma função que devolve texto quanto um snippet do
Svelte 5, e decidia qual era pelo nome da função:
`col.render.name?.startsWith('snippet')`. O nome não define o tipo, e o build
minificado pode renomear funções. Falhava nos dois sentidos:

- um snippet com nome encurtado era chamado como função comum e a célula
  mostrava lixo (ou quebrava);
- uma função comum chamada `snippet…` era passada ao `{@render}` e quebrava.

Nenhuma tela usava snippet ainda (as duas tabelas, folha de pagamento e
comparação de redes, usam só texto), então o bug estava latente.

## Decisão

Duas propriedades, sem inferência: `render(row)` devolve texto e `cell` é um
snippet (`{#snippet celula(row)}`), renderizado com `{@render col.cell(row)}`.
Se as duas vierem, vale o `cell`. Quem só usa `render` não muda nada.

## Testes

Três casos novos em `DataTable.test.js` (snippet via `cell`, função chamada
`snippet…` tratada como texto, `cell` com prioridade). Os três falham com o
componente antigo. Suíte do frontend: 127 arquivos, 1.154 testes; build ok.
