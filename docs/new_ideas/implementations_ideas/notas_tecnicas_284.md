# Nota técnica 284: a lista do ano dos abaixo do piso (#601, #602)

Um PR: #603. Achados QC-01 e QC-02 da sexta avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-26-p2-resposta-tce-ponta-a-ponta.md`).
Segue a #598 (nota 283): a marca estava na folha de um mês e de um lugar;
faltava a lista do ano inteiro, para anexar ao ofício do tribunal.

## O problema

- A marca do piso (#598) vale para a lista de um mês, de uma escola ou da
  Secretaria. Quem não recebeu naquele mês, ou só numa escola, fica de
  fora (Cuiabá 2026: 55 dos 1.559 fora da lista de abril da Secretaria), e
  a lista não se baixa.
- Com os filtros, a ordenação valia só para as 100 linhas da página.

## Decisões (developer: as recomendadas do plano)

- **A mesma regra da contagem** (`salario_rede`): toda a folha do
  município, sem dezembro, 3 meses ou mais, mediana do base por 40 h abaixo
  do piso do ano. O teste confere que o total é o do painel.
- **Por consulta, sem tabela nova** (`EduMaps::BaseAnalise->abaixo_piso_lista`):
  a lista tem nome e CPF, e não vai para `analytics`. Uma consulta sobre a
  folha do município e do ano: Cuiabá 2026 em 0,55 s.
- **Pública, como a folha por escola** (decisão de 2026-11-09), com **só o
  CPF mascarado** da fonte; o CPF usado para juntar os meses não sai.
- **Uma linha por pessoa**: situação do ano (a dos mais meses, empate no
  último, como a #597), carga mais comum, base mensal mediana, base por
  40 h, meses, se recebeu na Secretaria e as escolas (INEP e nome).
- **Rota do município**, não da escola: `/api/city/:codigo_ibge/piso`, JSON
  ou CSV (BOM, `;`, vírgula decimal, como os outros CSV). Sem piso no ano
  ou carga fora de horas semanais (#572): 404 com o motivo. Sem ano: o
  último com folha.
- **Página própria** (`/municipio/piso`), aberta pelo painel da Secretaria
  (quando há alguém abaixo) e pela base de análise. O payload financeiro da
  escola passou a trazer o código IBGE do município, que o link precisa.
- **#602:** a tabela comum aceita um `onsort`; a página ordena a lista
  filtrada inteira e só então fatia. Sem o `onsort`, a tabela segue
  ordenando o que recebe (o comportamento das outras telas não muda).

## Resultado

- Cuiabá 2026: 1.559 pessoas (1.417 temporários, 142 efetivos; 1.421 só na
  Secretaria, 138 com escola), iguais ao painel; CSV com 1.559 linhas.

## Testes

- `t/04-api/city_piso_lista.t` (novo, INEP `60060101`).
- Vitest: `PisoListaPage.test.js` (novo), ordenação entre páginas em
  `SchoolPayrollPage.test.js`, link em `SchoolFinance.test.js`.

## Pendente

- LXC: `deploy_backend_dev` e `deploy_frontend_dev` (roteiro).
