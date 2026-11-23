# Nota técnica 259: taxa bruta de matrícula, não o indicador oficial (#549)

Achado QJ-01 da terceira avaliação da P5
(`docs/personas/publicos/avaliacoes/2026-11-23-p5-meta1-pernambuco.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #551 (merge `910fd41`).

## O problema

- **QJ-01 (atrapalha).** A "taxa de atendimento" (#533, #535 e #547) soma
  as matrículas na etapa, de qualquer idade e de qualquer município, e
  divide pelas crianças da idade que moram no município. É uma taxa
  bruta de matrícula.
- O indicador oficial da meta 1 do PNE é o percentual das crianças da
  idade que frequentam creche ou escola, de pesquisa domiciliar. Os dois
  diferem, e nada dizia isso.
- O "abaixo da meta" (em PE, 174 de 185 municípios na creche) podia ser
  contestado pelo município fiscalizado com o número oficial.

## Decisões

- **Chamar a conta pelo nome, em todo lugar:**
  - o quadro da comparação de redes passou a "Matrículas na educação
    infantil por criança da idade";
  - "Taxa bruta de matrícula" na nota do ranking, no seletor, no rótulo
    do indicador, no cartão de `/fontes` e no dicionário da base.
- **Um aviso só, repetido:** "Não é o indicador oficial da meta 1 do PNE,
  que mede o percentual das crianças da idade que frequentam creche ou
  escola, em pesquisa domiciliar: os números podem diferir."
- **A1, o número no lugar da meta:** a marca passou a "abaixo de 50%" ou
  "abaixo de 100%". A tela não afirma que o município está abaixo da meta
  oficial. As vagas que faltam viraram "estimativa por esta conta".
- **B1, CSV estável:** os nomes das colunas não mudam. A coluna `metodo`
  diz, em toda linha, "taxa bruta de matrícula (…), não é o indicador
  oficial do PNE". Sem `;` no texto, porque é o separador.
- **Depois de ver a tela:** o texto do topo do ranking ainda dizia "quem
  está mais longe da meta aparece primeiro". Passou a "comparada à meta 1
  do PNE: a menor taxa aparece primeiro".
- **Nenhuma conta mudou.**

## Validação

- **Docker local:** Vitória de Santo Antão e o ranking de PE com os textos
  novos.
- **Testes:**
  - Perl, 1.852 (o rótulo do indicador e o dicionário);
  - vitest, 1.410 (os textos, a marca e a coluna `metodo`);
  - CI do PR verde (Perl, vitest e build).

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- #550 (as fontes dentro do CSV do ranking) segue aberta.
