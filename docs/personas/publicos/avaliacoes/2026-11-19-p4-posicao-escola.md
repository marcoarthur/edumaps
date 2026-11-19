# Reavaliação: P4 e a posição da escola (2026-11-19)

Vigésima sexta rodada da P4 (academia), a pedido do developer, depois da
entrega da vigésima quinta rodada:

| Entrega | O quê |
|---|---|
| #504 | lista de escolas pelo IDEB só com escolas em funcionamento, com a cobertura da etapa e o método (RD-01, RD-02) |

- **Avaliou:** só a P4.
- **Material:**
  - a página `/escola/ranking?inep=…` (aberta pelo cartão da escola na
    busca) e a resposta `/api/school/:inep/ranking`;
  - a tabela pré-calculada `analytics.ranking_escola` e o código
    (`EduMaps::Model::Rank::School::rank`, `_rank_from_ideb`);
  - a lista de escolas do município (`/ranking`, #504), para comparar;
  - o banco local, só leitura.
- **O trabalho que ela faria:** descrever onde uma escola de estudo de caso
  fica no município, no estado e no Brasil ("acima de X% das escolas"),
  num indicador do Censo e num do IDEB.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.
- Conferido sem achado: a tabela pré-calculada dos seis índices está em dia
  com a MV (`indices-v6`, nenhuma diferença de valor).

## O que ela fez

1. **O "acima de X%" com empate.** A página mostra "Nº de T" e "Acima de
   P% das escolas", com P = (T − N)/(T − 1). A posição é um `RANK()`: as
   escolas empatadas recebem a melhor posição do empate, e o "acima de"
   conta as empatadas como se estivessem abaixo.
   - **Sustentabilidade** só tem 9 valores possíveis. As 52.164 escolas com
     a nota mínima (0) aparecem como "128.377º de 180.540, acima de 29% das
     escolas" no Brasil; uma escola de Salvador com 0 aparece como "767º de
     1.432, acima de 46% das escolas". Nenhuma delas está acima de outra.
   - **Taxa de aprovação dos anos iniciais:** 14.508 das 43.481 escolas
     (33%) têm 100% e aparecem todas como "1º de 43.481, acima de 100% das
     escolas"; em Salvador, 36 escolas são "1º".
   - **Infraestrutura** (135 valores) e **capacitação docente** (2.775
     escolas em 1º no Brasil) também têm empates grandes.
2. **O IDEB conta escolas fora de funcionamento.** Os indicadores do IDEB
   não estão na tabela pré-calculada; a posição sai de um cálculo na hora
   sobre a tabela do IDEB, sem a situação no Censo.
   - A escola 29190231 aparece "1º de 257" no município; a lista do mesmo
     indicador (#504) tem 247 escolas em funcionamento. No Brasil, "de
     41.295", com as escolas paralisadas, extintas e fora do Censo.
3. **Sem ajuda.** Nenhuma página de ajuda explica a posição da escola: o
   que é o total (escolas com o indicador, não todas), como o empate entra
   e o que quer dizer "acima de".

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem a posição da escola | o "acima de X%" conta as empatadas como abaixo, e a escola com a nota mínima aparece "acima de 29%" (RC-01); a posição do IDEB conta escolas fora de funcionamento e não tem ajuda (RC-02) |

## O que funciona

- **Os três escopos** (município, estado, Brasil) e o **filtro de rede**.
- **A tabela pré-calculada** dos índices, em dia com a MV.
- **Indicador indisponível** marcado no seletor, em vez de posição vazia.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RC-01 | atrapalha | **"Acima de X% das escolas" conta as empatadas como abaixo.** Com `RANK()`, as empatadas recebem a melhor posição, e o percentil (T − N)/(T − 1) diz que a escola está acima delas. Pedido: "acima de" só as escolas com valor menor, e o empate dito ("empatada com N escolas"); na posição, o empate visível (ex.: "1º, empatada com 14.507"). | Sustentabilidade 0: 52.164 escolas "128.377º de 180.540, acima de 29%"; aprovação dos anos iniciais 100%: 14.508 escolas "1º, acima de 100%" | P4, P1, P6 |
| RC-02 | detalhe | **A posição do IDEB conta escolas fora de funcionamento e nada a explica.** O IDEB é calculado na hora sobre a tabela do IDEB, sem a situação no Censo (diferente da lista do #504); nenhuma ajuda explica a posição. Pedido: só escolas em funcionamento, como a lista; e uma ajuda (ou a explicação na página) do total, do empate e do "acima de". | 29190231: "1º de 257" no painel, 247 na lista do município | P4, P1 |

## Encaminhamento

Issue **#506** (RC-01 e RC-02 juntas), aberta com a aprovação do
developer.
