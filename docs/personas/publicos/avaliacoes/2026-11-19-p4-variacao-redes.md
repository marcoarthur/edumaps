# Reavaliação: P4 e a variação do IDEB no ranking de redes (2026-11-19)

Vigésima terceira rodada da P4 (academia), a pedido do developer, depois da
entrega da vigésima segunda rodada:

| Entrega | O quê |
|---|---|
| #498 | perfil da rede contra a mesma rede no Brasil; grupos pelos níveis do INSE (RG-01, RG-02) |

- **Avaliou:** só a P4.
- **Material:**
  - a ajuda `rankings.md` ("Variação", "Salto atípico");
  - a aba **Redes municipais** de `/ranking` e a resposta
    `/api/ranking/redes` (IDEB dos anos iniciais; PA, RS e Brasil);
  - o código (`EduMaps::Model::Rank::School::redes_municipais`);
  - o banco local, só leitura.
- **O trabalho que ela faria:** escolher redes municipais que "mais
  melhoraram" o IDEB dos anos iniciais de 2021 para 2023, para entrevistar
  as secretarias, ordenando pela variação e conferindo o "salto atípico".
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Como a variação é calculada.** A ajuda diz que a variação é "a
   diferença para a edição anterior". No código, é a média das escolas com
   IDEB em 2023 menos a média das escolas com IDEB em 2021. As duas médias
   podem ter **escolas diferentes**: em 2021 muitas escolas ficaram sem IDEB
   (a ajuda avisa isso). A tela não diz quantas escolas estão nas duas
   edições.
2. **Mediu o efeito.** Comparou a variação da tela com a variação nas mesmas
   escolas (as que têm IDEB nas duas edições), nas 2.476 redes com pelo
   menos 3 escolas nas duas edições:
   - a diferença média é de 0,13 ponto;
   - em **279 redes** a diferença é de 0,3 ponto ou mais;
   - em **129 redes** o sinal troca: a tela mostra melhora e as mesmas
     escolas pioraram, ou o contrário (variação de pelo menos 0,1).
3. **Os casos.**

   | Rede | Escolas 2023 / 2021 / nas duas | Variação na tela | Nas mesmas escolas |
   |---|---|---|---|
   | São Sebastião da Boa Vista/PA | 14 / 10 / 4 | **+1,15** (salto atípico; 3ª do PA em variação) | +0,03 |
   | Santa Maria/RS | 36 / 19 / 16 | 0,00 | **+0,46** |
   | Óbidos/PA | 25 / 16 / 12 | +0,05 | −0,52 |
   | Paço do Lumiar/MA | 43 / 11 / 10 | +0,17 | +0,60 |

   - No ranking nacional, Parnaguá/PI lidera a variação (+3,54) com **uma**
     escola nas duas edições.
4. **O salto atípico.** Das 113 redes marcadas no Brasil, **29** ficariam
   dentro do limite se a variação fosse medida nas mesmas escolas. A ajuda
   diz que o salto "costuma vir de rede pequena ou de mudança fora do
   comum", mas boa parte vem da troca de escolas entre as edições.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem a variação do ranking de redes | a variação compara conjuntos diferentes de escolas e não diz quantas estão nas duas edições; em 129 redes o sinal troca (RF-01) |

## O que funciona

- **A posição pelo valor** da edição, por etapa e com o mínimo de escolas.
- **O contexto pelo INSE** (quinto de INSE no recorte).
- **O CSV com o recorte** em cada linha.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RF-01 | atrapalha | **A variação do ranking de redes compara escolas diferentes.** É a média das escolas com IDEB numa edição menos a das escolas com IDEB na anterior, e a tela não diz quantas estão nas duas. Pedido: a variação nas **mesmas escolas** (as que têm o indicador nas duas edições), com o número delas na tabela e no CSV, o mínimo de escolas valendo para esse número; o salto atípico sobre essa variação; a ajuda com a regra. | 2.476 redes (IDEB anos iniciais, 2021→2023): 279 com diferença ≥ 0,3 e 129 com sinal trocado; São Sebastião da Boa Vista/PA +1,15 na tela, +0,03 nas 4 escolas das duas edições; 29 de 113 saltos atípicos somem | P4, P2, P6 |

## Encaminhamento

Issue **#499** (RF-01), aberta com a aprovação do developer.

## Andamento

- 2026-11-19: #499 (PR #500) mergeado: RF-01 resolvido. A variação do
  ranking de redes é medida nas mesmas escolas (as que têm o dado nas duas
  edições), com o número delas na tela e no CSV; o mínimo, a posição pela
  variação e o salto atípico valem sobre ela. São Sebastião da Boa Vista/PA:
  de +1,15 (salto atípico) para +0,03 (4 escolas); Santa Maria/RS: de 0,00
  para +0,46; saltos atípicos no Brasil de 113 para 103. Fechamento em
  [`../ciclos/2026-11-19-ranking-variacao-pareada.md`](../ciclos/2026-11-19-ranking-variacao-pareada.md).
