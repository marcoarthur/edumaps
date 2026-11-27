# Nota técnica 286: o custo até o piso (#605, #606, #607)

Um PR: #609. Achados QD-01, QD-03 e QD-04 da sétima avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-26-p2-custo-do-piso.md`).
Fecha a rodada: os quatro achados estão entregues (QD-02 na nota 285).

## O problema

- A pergunta do orçamento ("quanto custa pôr essa gente no piso?") só se
  respondia baixando o CSV da lista do ano e montando a conta numa
  planilha (QD-01).
- A frase do perfil usava a carga mais comum e a base mediana de todas as
  cargas; com cargas variadas, a base ficava acima do piso proporcional
  dito (Cuiabá 2025) (QD-03).
- Na lista, a base mensal e a base por 40 h eram medianas separadas; em 40
  das 1.559 linhas de Cuiabá elas não fechavam pela carga (QD-04).

## Decisões (developer: as recomendadas do plano)

- **A diferença da regra:** por pessoa, piso × carga ÷ 40 − base do mês
  típico (base por 40 h × carga ÷ 40), cada termo arredondado ao centavo.
  É a mesma conta na contagem (`salario_rede`, por grupo da
  `mv_salario_rede_md` × n) e na lista (por pessoa): os totais batem ao
  centavo. Sem migração.
- **Mensal e anual:** o total por mês, por situação, e "em 13 salários,
  cerca de R$ X no ano" (aproximado, em mil ou milhões), pelo piso do ano
  da folha; o texto diz que ficam de fora férias, encargos e gratificações
  e que não é o custo legal da adequação.
- **Onde:** a frase do piso (painel e base), o resumo e duas colunas da
  lista do ano, os CSV (`piso_proporcional`, `diferenca_mensal` na lista;
  `abaixo_piso_diferenca_mensal` na folha por município).
- **#607 pela derivação:** a base mensal da lista passa a ser a do mês
  típico, da mesma mediana da base por 40 h (`base_mensal_tipica`); cada
  linha fecha. O nome antigo do CSV só existiu localmente (a lista ainda
  não foi ao LXC).
- **#606 pela carga:** a mediana do perfil é só de quem tem a carga mais
  comum, com a base do mês típico; a frase diz quantos a têm ("30 horas
  (1.512 de 1.559)"). Cuiabá 2025: R$ 2.012,14 contra o proporcional de
  R$ 2.433,89 (era R$ 3.380,70).

## Resultado

- Cuiabá 2026: R$ 1.027.436,19 por mês (R$ 939.298,66 dos temporários,
  R$ 88.137,53 dos efetivos), cerca de R$ 13,4 milhões no ano.

## Testes

- `t/04-api/city_piso_lista.t` e `t/04-api/base_analise.t`: a diferença
  por pessoa e por situação, o total igual ao do painel, o perfil com
  cargas variadas, as colunas dos CSV.
- Vitest: o texto do custo, os valores aproximados, painel, lista e base.
- Uma rodada local da suíte Perl falhou num teste não identificado; duas
  rodadas seguintes e o CI passaram.

## Pendente

- LXC: `deploy_backend_dev` e `deploy_frontend_dev` (roteiro).
