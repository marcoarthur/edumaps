# Reavaliação: P4 mede o gasto com pessoal por aluno em Cuiabá (2026-11-24)

Trigésima oitava rodada da P4 (academia), a pedido do developer. A
anterior (2026-11-23, educação infantil por porte e região) teve o
veredito **adotaria**, e o QL-01 virou a #545 (rede distrital do DF,
entregue). Desde então, na folha:

| Entrega | O quê |
|---|---|
| #553 | o gasto do ano por fonte (Fundeb 70%, 30%, outras) na base |
| #554 | o fechamento da folha na tela da base (escolas, Secretaria, fora da lista) |
| #557 | o mês com a folha pela metade, na coluna `meses_folha_incompletos` |
| #558 | os meses por escola e os da Secretaria, na cobertura |

- **Avaliou:** só a P4.
- **Material:**
  - a base de análise da rede municipal de Cuiabá (blocos Etapas,
    Matrículas, Docência, INSE e Remuneração), folha de 2025, e o
    dicionário;
  - as ajudas da base e de financeiro e folha;
  - o painel financeiro de uma escola.
- **A pergunta dela:** "o gasto com pessoal por aluno é maior nas escolas
  que atendem alunos mais pobres?", em Cuiabá, o único município com um ano
  inteiro de folha por escola. Ela compara também a educação infantil com
  o ensino fundamental.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A base:** 171 escolas municipais, 167 com folha em 2025. O arquivo
   traz o ano da folha, os meses por escola e, agora, `meses_folha_incompletos`
   = "set, out" em todas. O dicionário explica: nesses meses a folha veio
   pela metade, e a causa pode ser a declaração ou a carga. Ela anota que a
   plataforma não esconde o problema.
2. **Quem é atingido, e como:**
   - as 81 escolas com ensino fundamental têm `meses_folha` = 12, mas em
     setembro e outubro sem os auxiliares e as merendeiras;
   - das 83 escolas só de educação infantil, 53 têm `meses_folha` = 10:
     a folha delas é só de auxiliares, que somem nesses meses. As outras 30
     têm 12 meses, também sem os auxiliares em setembro e outubro.
   - O erro não é aleatório: as creches perdem cerca de 2/12 do ano, e as
     escolas de fundamental só uma parte. Comparar o gasto por aluno da
     educação infantil com o do fundamental sai enviesado.
3. **Corrigir:** para anualizar, ela precisa do gasto dos 10 meses
   completos de cada escola (gasto × 12 / 10). A base só traz a soma do
   ano. A ajuda sugere a folha mês a mês do painel financeiro: são 167
   telas, uma a uma, sem arquivo. Para a pergunta, ela restringe às escolas
   com INSE (todas de fundamental, todas com 12 meses), e aceita o viés
   menor dos auxiliares.
4. **O resultado, nas 52 escolas com INSE:** a metade de INSE mais baixo
   tem R$ 6.368 de pessoal por aluno no ano (mediana), contra R$ 7.104 na
   metade mais alta. O salário do magistério para 40 horas é R$ 10.901 e
   R$ 11.290. Nada indica que a rede gasta mais onde os alunos são mais
   pobres. A comparação com a educação infantil fica de fora.
5. **Citar:** o arquivo tem a versão dos dados (Censo, INSE, folha). O
   fechamento da folha (R$ 489,5 mi declarados, R$ 17,1 mi na Secretaria)
   está na tela, não no arquivo; para citar, ela copia da tela. Foi a opção
   escolhida na #554 (A1, sem arquivo à parte), e ela registra sem pedir de
   novo.

## O que funciona para ela

- A ausência dita: os meses incompletos em toda linha, com o motivo no
  dicionário, sem a plataforma "corrigir" por conta própria.
- O gasto por fonte somando o gasto do ano, para conferir.
- A versão dos dados no arquivo, para refazer a conta.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QM-01 | atrapalha | **A base marca os meses incompletos, mas não deixa tirá-los da conta.** O gasto e as pessoas vêm só somados no ano. Sem o valor dos meses completos por escola, não dá para anualizar, e o viés não é aleatório: as creches perdem os meses inteiros, as escolas de fundamental só uma parte. A saída da ajuda (a folha mês a mês do painel) é uma tela por escola. Pedido: o gasto só dos meses completos e quantos são (ex.: `gasto_pessoal_meses_completos` e `meses_completos`), ou a folha por escola e mês para baixar, sem nomes nem CPF. | Cuiabá 2025: 53 das 83 escolas só de educação infantil com `meses_folha` = 10; as 81 de fundamental com 12, sem auxiliares e merendeiras em setembro e outubro | P4, P2, P5 |

## Veredito

**Adotaria** (mantido), com ressalva no gasto anual de 2025 em Cuiabá. A
pergunta sai para as escolas de fundamental. A comparação com a educação
infantil espera o QM-01.

## Encaminhamento

Issue **#561** (QM-01), aberta com a aprovação do developer.

## Andamento

- 2026-11-24: #561 (PR #562) mergeado: QM-01 resolvido.
  - A base traz `meses_completos` e `gasto_pessoal_meses_completos`, para
    anualizar com `gasto × 12 ÷ meses`. Em Cuiabá 2025, a educação
    infantil passa de R$ 14.668 para R$ 17.602 por aluno (mediana); o
    fundamental, de R$ 6.671 para R$ 6.922.
