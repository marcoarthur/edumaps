# Reavaliação: P4 refaz o ranking de redes pela base de análise (2026-11-20)

Vigésima sétima rodada da P4 (academia), a pedido do developer, depois da
entrega da vigésima sexta rodada:

| Entrega | O quê |
|---|---|
| #507 | posição da escola com o empate dito e o IDEB só com escolas em funcionamento (RC-01, RC-02) |

- **Avaliou:** só a P4.
- **Material:**
  - o ranking de redes municipais (`/ranking`, IDEB anos iniciais 2023, BA,
    MG e Brasil) e a resposta `/api/ranking/redes`;
  - a base de análise da BA, rede municipal, blocos "IDEB e SAEB",
    "Etapas", "INSE" e "Porte", edições 2023 e 2021
    (`base-analise-BA-municipal-censo2025-ideb2023-inse2023.csv`);
  - as ajudas de rankings, de comparação de redes e da base de análise;
  - o banco local, só leitura, para medir o Brasil.
- **O trabalho que ela faria:** citar o ranking de redes num artigo e
  refazer a conta pela base de análise, como a ajuda de comparação de redes
  sugere ("para refazer as contas … baixe a base de análise").
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Refez a média de cada rede da BA** pela base: média simples do
   `ideb_ai` das escolas municipais, com o mínimo de 3 escolas, o INSE médio
   e a variação nas mesmas escolas (base de 2021 contra a de 2023).
   - 331 das 348 redes batem até a quarta casa: média, número de escolas,
     INSE, variação e escolas da variação.
   - 17 não batem. Em todas, o ranking tem escolas que a base não tem:
     Salvador 255 escolas no ranking, 246 na base (e 246 na lista de escolas
     do mesmo indicador, #504); Ribeira do Pombal 21 contra 20, média 5,686
     contra 5,705.
   - Uma rede só entra no ranking por causa dessas escolas: na base, ela fica
     abaixo do mínimo de 3.
2. **Procurou a explicação.** A ajuda de comparação de redes diz, num
   parágrafo sobre a contagem das escolas, que "o ranking de redes é outra
   conta: a média das escolas com IDEB naquela edição, inclusive as que
   fecharam depois". A ajuda de **rankings**, onde ela lê o que é o "valor
   da rede", não diz; o CSV de redes não traz uma coluna que separe essas
   escolas; e a base, que exclui as escolas fora de funcionamento, não deixa
   refazer a conta.
3. **Mediu o Brasil** (IDEB anos iniciais 2023, redes com 3 escolas ou
   mais):
   - 108 das 3.065 redes têm escolas que não estão em funcionamento na rede
     municipal do Censo 2025: 140 escolas (113 paralisadas ou extintas, 23
     fora do Censo, 4 hoje de outra rede);
   - 24 redes mudam a média em 0,1 ponto ou mais, e 12 ficariam abaixo do
     mínimo de 3 escolas;
   - **Mário Campos (MG):** 5 escolas, média 5,68, **216º de 302** em MG.
     Uma delas está paralisada e teve IDEB 3,0; as 4 em funcionamento têm
     média 6,35, o que daria **69º**.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem citar o ranking de redes | o valor da rede conta escolas paralisadas, extintas ou fora do Censo, que a base não traz: a conta não se refaz, e a ajuda de rankings não diz (RB-01) |

## O que funciona

- **A conta se refaz** em 331 das 348 redes da BA, inclusive a variação
  nas mesmas escolas e o INSE: o método da ajuda está certo.
- **A lista de escolas** de Salvador (246) bate com a base (246).
- **O nome do arquivo** da base diz a edição de cada fonte; com a de 2021,
  a base deixa refazer a variação.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RB-01 | atrapalha | **O ranking de redes conta escolas que não estão em funcionamento, e a conta não se refaz pela base.** O valor da rede é a média das escolas com IDEB na edição, inclusive as paralisadas, extintas ou fora do Censo mais recente; a base de análise e a lista de escolas (#504) só têm as em funcionamento. A ajuda de rankings não diz, e o CSV de redes não separa essas escolas. Pedido: o ranking de redes só com as escolas em funcionamento na rede municipal do Censo mais recente, como a lista e a base (posição, INSE, variação e mínimo de escolas); ou, se a decisão for manter a edição como foi, dizer na ajuda de rankings e no CSV quantas escolas da rede não estão mais em funcionamento, com um jeito de refazer a conta. | Mário Campos (MG): 216º de 302 com uma escola paralisada de IDEB 3,0; 69º só com as 4 em funcionamento. Brasil: 108 de 3.065 redes, 140 escolas, 24 redes com a média 0,1 ou mais diferente, 12 abaixo do mínimo. Salvador: 255 no ranking, 246 na base e na lista | P4, P2, P6 |

## Encaminhamento

Aguarda a aprovação do developer para virar issue.
