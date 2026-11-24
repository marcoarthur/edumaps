# Reavaliação: P4 cruza o salário do professor com o IDEB (2026-11-24)

Trigésima nona rodada da P4 (academia), no modo autônomo autorizado pelo
developer (até 25/11, 9h). A anterior (2026-11-24, gasto por aluno em
Cuiabá) teve o veredito **adotaria**, e o QM-01 virou a #561 (gasto dos
meses completos), entregue. Desde então: o salário base e o piso (#563,
#575), a carga fora de horas (#572) e a folha por município (#580).

- **Avaliou:** só a P4.
- **Material:** a base da rede municipal de Cuiabá (blocos Etapas,
  Matrículas, Docência, Desempenho, INSE e Remuneração, folha de 2025) e o
  dicionário; a ajuda da base.
- **A pergunta dela:** "o salário do professor se associa ao IDEB da
  escola, controlando o nível socioeconômico?" (uma variação da pergunta do
  perfil sobre o que explica o IDEB).
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A base:** 50 escolas municipais com IDEB dos anos iniciais, salário
   por 40 horas e INSE. O dicionário explica o salário total e o base por
   40 horas, sem dezembro, e a carga mais comum do município (23, em
   horas). As cargas médias por escola vão de 19 a 27 horas.
2. **O modelo:** IDEB dos anos iniciais contra o salário total por 40
   horas (em R$ mil) e o INSE: +0,13 de IDEB por R$ 1.000, controlando o
   INSE (que pesa +1,68 por ponto). Com o salário base, +0,19. É uma
   associação pequena, em 50 escolas.
3. **Os anos:** o IDEB é de 2023, o INSE também, a lista de escolas é do
   Censo 2025 e a folha é de 2025 (a de 2023 não está carregada).
   - A tela avisa que o IDEB e o Censo são de anos diferentes (#514) e diz
     o ano do INSE.
   - Do ano da folha, nada: o salário de 2025 explicando um IDEB de 2023
     só aparece se ela ler o nome do arquivo (`-siope2025`) e a coluna
     `ano_siope`. No artigo, isso é uma limitação a declarar; sem o aviso,
     passa.

## O que funciona para ela

- O salário total e o base por 40 horas, sem dezembro, com a carga dita.
- Os anos de cada base no arquivo e no nome.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QF-01 | incomoda | **O aviso de anos diferentes não fala da folha.** Ele compara o IDEB com o Censo e diz o ano do INSE, mas não o ano da folha do SIOPE. Num modelo com salário e IDEB, a folha pode ser de outro ano (aqui, dois anos depois) sem aviso na tela. Pedido: com os blocos Desempenho e Remuneração marcados, o aviso diz o ano da folha e a distância para o IDEB. | Cuiabá: IDEB 2023, folha 2025 (só há 2025 e 2026); o aviso fala só do Censo e do INSE | P4 |

## Veredito

**Adotaria** (mantido). A pergunta sai da base, com a ressalva dos anos
que ela mesma precisa notar (QF-01).

## Encaminhamento

Issue **#583** (QF-01), aberta no modo autônomo autorizado pelo developer.
