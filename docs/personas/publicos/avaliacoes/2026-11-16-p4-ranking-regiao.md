# Reavaliação: P4 depois do recorte por região (2026-11-16)

Quarta rodada da P4 (academia), depois da #445 (PR #447): região no ranking
de redes, combinável com o porte. A base de análise segue uma UF por vez,
por decisão de produto.

- **Avaliou:** só a P4, a pedido do developer. As outras personas ficam como
  estavam.
- **Material:**
  - a ficha `analise/ranking.md` e as ajudas `rankings.md` e
    `base-de-analise.md`;
  - a stack local com os dados reais, só leitura;
  - **o trabalho que ela faria:**
    - o ranking da região com porte;
    - para a pergunta das regiões, baixar a docência das 27 UFs (como a
      ajuda orienta), juntar no R e comparar as regiões.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.
- Feita a pedido do developer. Issues **#448** e **#449**, abertas com a
  aprovação dele.

## As perguntas do perfil

1. **"Quanto da variação do IDEB se associa à infraestrutura, controlando por
   rede?"** Respondida desde a terceira rodada (base da UF no R), sem mudança.
2. **"Municípios de porte e região semelhantes têm oferta parecida?"**
   Respondida.
   - `/ranking?aba=redes&regiao=NE&porte=10_20mil` (IDEB anos iniciais 2023):
     519 redes de 9 UFs (BA 161, MA 84, CE 61…), 65 fora pelo mínimo de
     escolas e 17 saltos atípicos.
   - A faixa do salto atípico é medida na região (−0,84 a +1,56; no Brasil
     do mesmo porte, −0,73 a +1,43).
   - Os quintos de INSE também são da região: as médias dos quintos ficam
     entre 5,05 e 5,31, sem gradiente. É uma leitura que ela não tinha com o
     Brasil inteiro, onde o Nordeste se concentra nos quintos de baixo.
   - O Sul do mesmo porte (143 redes, topo no PR com 8,14) contrasta com o
     topo do Nordeste (CE, perto de 10).
3. **"Como o perfil docente muda entre regiões?"** Respondida, com trabalho
   manual.
   - As 27 UFs com o bloco de docência e o porte saem em 22 s (24 MB), com o
     cabeçalho idêntico. `read.csv2()` + `rbind` dão 180.540 escolas e 17
     colunas.
   - Os 1.768 registros sem docentes chegam como `NA`, nunca 0.
   - Licenciatura ponderada pelos docentes (escolas públicas): N 0,866;
     NE 0,810; SE 0,921; S 0,910; CO 0,934.
   - Com o porte, a diferença do Nordeste se concentra nos municípios de até
     20 mil habitantes: 0,752, contra 0,908 nos de mais de 100 mil.
   - O `lm(prop_licenciatura ~ regiao + log(populacao) + rede)` roda direto.
   - **Mas** a base não tem a região: ela digitou o mapa das 27 UFs para as
     cinco regiões (RG-01).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria (corte transversal de uma UF) | **adotaria** (mantido; agora também para comparar regiões no ranking) | a pergunta de porte e região tem resposta direta e com método (posição, INSE e salto atípico medidos no recorte); a de perfil docente entre regiões se faz com os downloads por UF, como a ajuda diz, em minutos e sem SQL |

## O que funciona

- **Região × porte** num link, com a nota dizendo que a comparação é dentro
  da região.
- **Junção das UFs sem surpresa:**
  - as colunas são as mesmas em todas as UFs;
  - a versão está em cada linha;
  - ausência continua sendo ausência.
- **O link antigo** `nacional=1` continua abrindo o Brasil, então as
  citações antigas não quebram.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RG-01 | detalhe | **A base de análise não traz a região.** A identificação tem a UF e o código IBGE, mas não a região. Para a junção que a própria ajuda sugere, a pesquisadora precisa de um mapa UF → região escrito à mão (27 entradas), e é aí que o erro entra. Pedido: coluna `regiao` (Norte, Nordeste…) na identificação; custo baixo e sem mudar a regra de uma UF por vez. | `base-analise-*-censo2025.csv`, script R da rodada | P4 |
| RG-02 | detalhe | **O CSV do ranking não diz o recorte nas colunas.** A posição, o quinto de INSE e a "média dos municípios do mesmo quinto" valem só dentro do recorte (UF, região, Brasil, porte). O recorte está só no nome do arquivo. Quem junta os CSVs de duas regiões mistura quintos de recortes diferentes sem aviso. Pedido: colunas `recorte` e `porte_filtro` (ou equivalente), como a versão já viaja na linha da base. | `ranking-redes-ideb_anos_iniciais-NE-10_20mil-2023-min3.csv` | P4, P6 |
| RG-03 | detalhe | **Não dá para achar um município na lista de redes.** "Municípios semelhantes **ao meu**": ela precisa saber o porte do município, escolher a região e procurar na tabela com Ctrl+F entre 519 linhas. Pedido: um campo de município que leva à linha dele (ou o destaca) e já sugere a região e o porte. | `/ranking?aba=redes&regiao=NE&porte=10_20mil` | P4, P2 |

## Encaminhamento

Issues abertas com a aprovação do developer (2026-11-16): **#448** (RG-01 e
RG-02) e **#449** (RG-03).

### Proposta original

Os três são detalhes; a P4 continua em **adotaria**.

1. **RG-01 e RG-02 cabem num PR pequeno.** Uma coluna na identificação da
   base (com a linha no dicionário) e as colunas de recorte no CSV do
   ranking.
2. **RG-03** é uma melhoria de tela no ranking (campo de município com
   destaque e sugestão de recorte), num PR separado.

## Andamento

- 2026-11-16: #448 (PR #450) mergeado: RG-01 e RG-02 resolvidos (região na
  base de análise; recorte em cada linha dos CSVs do ranking, também no de
  escolas). Fechamento em
  [`../ciclos/2026-11-16-regiao-base-csv.md`](../ciclos/2026-11-16-regiao-base-csv.md).
  Fica #449 (RG-03).
- 2026-11-16: #449 (PR #451) mergeado: RG-03 resolvido (destacar um
  município, com a posição ou o motivo da ausência e a sugestão de recorte).
  Fechamento em
  [`../ciclos/2026-11-16-destaque-municipio.md`](../ciclos/2026-11-16-destaque-municipio.md).
  Nenhum achado desta avaliação fica aberto.
- 2026-11-16: quinta rodada da P4: **adotaria** (mantido). Consolidação em
  [`2026-11-16-p4-indices-e-cobertura.md`](2026-11-16-p4-indices-e-cobertura.md),
  com os achados novos RX-01 e RX-02.
