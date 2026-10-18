# Nota técnica 147 — #139: fundamentação dos coeficientes do IVET na literatura

Esta nota documenta a **fundamentação dos coeficientes do IVET na literatura** —
o artefato que faltava para defender e revisar o número. PR **#277** (branch
`docs/analytics-ivet-coeficientes`, commit `81904f0`).

## O problema

Os coeficientes do IVET estavam **sem lastro na literatura**: a escolha de um
componente, de uma normalização, de um teto e da ordem de agregação eram
decisões de implementação que não estavam escritas em lugar nenhum, nem com a
referência que as sustenta. Sem isso, **não dá para defender o número** nem
revisá-lo — e a ausência de lastro **escala** quando as dimensões novas entram.

## O que foi entregue

Novo documento **`docs/analises/ivet-coeficientes.md`**, com os quatro
entregáveis da issue:

1. **Ficha por indicador** (blocos A–G + agregação) — fórmula, normalização,
   direção, peso, fonte e **referência**, ou a marca explícita **"sem lastro"**.
2. **Mapa "escolha de peso → referência"** (§3), com o caso **Z:10456** explícito.
3. **Registro das divergências** (§4) — seis divergências, cada uma com o *porquê*.
4. **Fila de revisão** (§5) — os itens sem lastro, em ordem de risco.

## As fontes (disciplina de leitura)

A issue exige declarar, para cada referência, **metodologia, vigência e
população** — importar um coeficiente sem as três é erro de leitura. O doc abre
com essa tabela:

| Rastro | Metodologia | Vigência | População |
|---|---|---|---|
| **Z:10456** (Colucci, 2014) | DEA (1 input, 2 outputs) sob 5 padrões de ponderação | 2011 | 17.124 escolas públicas municipais |
| **Z:10673** (Maia et al., 2021) | regressão + GBM; normalização z-score | 2017 | escolas públicas estaduais+municipais |
| **Z:10454** | modelo matemático de sensibilidade do IDEB | 2015 | **não lido** |

⚠️ **As fontes não estão no repositório.** O storage do Zotero não existe no host
(só o `zotero.sqlite`, sem os anexos). Z:10673 foi lido do *full text* público
(PLOS ONE, CC BY) e Z:10456 do repositório BDTD/USP. **Z:10454 ficou por ler** —
está na fila de revisão.

## O achado central (Z:10456) e o mapa do peso

Colucci aplica **DEA** a 17.124 escolas municipais (2011) e varia a **ponderação
dos dois outputs** (nota Prova Brasil e indicador de rendimento) em **cinco
padrões**. As escolas classificadas como eficientes **mudam de eixo geográfico**
(do Nordeste para Sudeste/Sul) conforme o peso muda. Isto é: **a ponderação
altera o ranking**, não só o valor.

O próprio IDEB (`Prova Brasil × indicador de rendimento`, 50-50 no MEC) já
embute uma escolha de peso. A resposta do IVET, sustentada por Z:10456:
**peso igual entre as dimensões por default** (o mais reprodutível), e qualquer
ponderação diferente **exige justificativa registrada + nova versão** da fórmula.

## Divergências registradas

1. **z-score (Z:10673) × clamp (IVET).** Z:10673 padroniza por z-score porque o
   objetivo é predição; o IVET publica em `[0,1]` e usa `clamp(x/teto)` — mais
   interpretável e com saturação do extremo. Deliberada.
2. **ausente=0 (literatura) × `NA` (IVET).** A literatura pondera todos os
   outputs; no IVET o dado territorial pode faltar, e tratar ausência como 0
   penalizaria o território. O IVET usa `NA` fora do denominador (#154).
3. **Inconsistência interna do card — corrigida.** O card dizia
   `componente_ausente: vira 0 dentro da dimensao`, mas a implementação preserva
   `NA`. Corrigido para `fica fora do denominador da dimensao (NA, #154) — nunca 0`.
4. **Bloco C sem lastro** — proxy de exposição viária (decisão de produto).
5. **Tetos sem lastro** — calibração empírica (p90/p99), não coeficientes.
6. **Bloco B é a exceção com lastro forte** (Z:10673 sustenta presença e direção).

## Fila de revisão

Sete itens entraram; um (o card) saiu resolvido nesta entrega. A regra da fila:
um indicador novo entra **no momento em que é especificado** e só sai quando a
ficha tiver a referência — ou o registro de que é decisão de produto.

## Validação e deploy

Suíte do IVET toda verde (card, escola, mobilidade, recursos, saúde, segurança,
socioeconômico). Card deployado em `analytic.edumaps`; imagem local `analytic`
reconstruída.

## O que fica

**#139 fechada.** Do IVET restam **F-exposição** e a **isócrona** de C — nenhum
bloqueia o agregado (destravado no PR #276). **#138** (similaridade/PgVector)
continua, por desenho, a esperar as dimensões novas.
