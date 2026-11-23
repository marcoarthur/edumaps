# Nota técnica 255: posição da escola sem verde fixo (#541)

Achado P1-PN-01 da avaliação da P1
(`docs/personas/publicos/avaliacoes/2026-11-23-p1-painel-e-perfil.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #543 (merge `5eab253`).

## O problema

- **P1-PN-01 (atrapalha).** No painel da escola, "Acima de X% das outras
  escolas no município" saía sempre em verde (`text-green-600` fixo). O
  IDEB dos anos iniciais de uma escola de Cuiabá, 76ª de 81, vinha com
  "Acima de 4%" em verde, e para a diretora verde é "está bem".
- No primeiro lugar dividido (68 escolas com 100% de aprovação), "1ª de
  81" e "acima de 16%" pareciam se contradizer.

## Decisões

- **A1, sem cor de bom ou ruim:** o texto é cinza, e o selo já diz a
  posição e o total. É a mesma leitura não punitiva do ranking de redes,
  que mostra o contexto (INSE) em vez de pintar de pior ou melhor. A2 (cor
  pelo terço) pintaria a escola "mal" sem explicar, que é o que faz a P1
  desistir.
- **B1, empate nas pontas como lugar:**
  - no topo: "1º lugar, dividido com N escolas com o mesmo valor";
  - no fim: "Último lugar, dividido com N escolas…", no lugar de "acima
    de 0%" (ex.: as mais de 52 mil escolas com sustentabilidade 0);
  - todas empatadas: "Todas as N escolas têm o mesmo valor";
  - no meio, continua "empatada com N" e "Acima de X%".
- **Uma função só, `leituraPosicao`,** para o painel e a página da
  posição, que repetiam a frase em dois componentes.
- **Svelte 5:** `{@const}` só pode ser filho direto de um bloco. Na página
  da posição, dentro de uma `<div>` do snippet, ele virou uma função local
  `leitura(e)`.
- **A API não mudou:** `posicao`, `total`, `empate`, `abaixo` e
  `percentil` já bastavam.

## Validação

- **Docker local** (`/escola/panel?inep=51038510`): a 76ª de 81 fica em
  cinza, e a aprovação mostra "1º lugar, dividido com 67 escolas com o
  mesmo valor".
- **Testes:** vitest, 1.402 (seis casos da função e o painel com os dois
  casos); CI do PR verde (vitest e build).

## Pendências

- No LXC: `deploy_frontend_dev`.
- #542 (P1-PN-02, sinal de atenção do perfil sem o porquê) segue aberta.
