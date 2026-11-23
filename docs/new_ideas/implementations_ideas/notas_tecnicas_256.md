# Nota técnica 256: sinal de atenção com os números (#542)

Achado P1-PN-02 da avaliação da P1
(`docs/personas/publicos/avaliacoes/2026-11-23-p1-painel-e-perfil.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #544 (merge `47d9601`).

## O problema

- **P1-PN-02 (atrapalha).** O perfil abria com sinais como "Proporção de
  docentes com licenciatura no quartil inferior do grupo de referência":
  jargão e nenhum número.
- Na escola do exemplo (Cuiabá), 94% dos docentes têm licenciatura, acima
  do município (85%) e do Brasil (80%). Ela só fica atrás das escolas
  parecidas, que têm mediana de 100%. Lida sozinha, a frase levava a
  diretora a dizer "estamos mal em licenciatura".

## Decisões

- **A1, a frase no frontend.** `fraseSinal` (`transformProfileData.js`)
  monta a frase com a tabela comparada e o resumo do grupo, que o perfil
  já recebe.
  - Os sinais só aparecem nessa tela, e a formatação dos números em PT-BR
    já está no frontend.
  - O motor R e o cache não mudam, então a regra continua 9 e não há
    perfil para recalcular no LXC.
  - A `mensagem` do motor fica como reserva, para quando faltar número.
- **A frase:** "{indicador}: {escola} nesta escola. Nas {n} escolas
  parecidas do município, metade tem {mediana} ou mais (ou menos). A
  escola está {melhor|pior|igual} que o município ({x}) e o Brasil ({y})."
  - "Metade tem" é a mediana dita no dia a dia, sem "ou mais" no teto de
    100%.
  - O n é o número de escolas do grupo com o dado (o mesmo da mediana).
    Pode ser 29 num grupo de 30.
  - Percentual sem casa decimal; os demais números com uma.
- **B1, sempre os dois lados:** a escola vê se está melhor ou pior que o
  município e o Brasil, no sentido do indicador. A frase é honesta nas
  duas direções.
- **Svelte 5, de novo:** o `{@const}` foi para logo depois do `{#each}`,
  e não dentro do `<li>` (a mesma lição da #541).

## Validação

- **Docker local** (`/escola/perfil?inep=51038510`): "Docentes com
  licenciatura: 94% nesta escola. Nas 29 escolas parecidas do município,
  metade tem 100%. A escola está melhor que o município (85%) e o Brasil
  (80%)."
- **Testes:** vitest, 1.407; CI do PR verde (vitest e build).

## Pendências

- No LXC: `deploy_frontend_dev`.
