# Reavaliação: P6 depois da região, do recorte no CSV e do destaque (2026-11-16)

Terceira rodada da P6 (terceiro setor e jornalismo de dados), depois de
cinco entregas da P4 que a P6 também usa:

| Entrega | O quê |
|---|---|
| #443 | base de análise por escola |
| #444 | aviso do cruzamento entre anos |
| #445 | região no ranking |
| #448 | região na base e recorte no CSV |
| #449 | destacar um município |

- **Avaliou:** só a P6, a pedido do developer. As outras personas ficam como
  estavam.
- **Material:**
  - as ajudas `rankings.md`, `base-de-analise.md` e
    `fontes-e-metodologia.md`;
  - a stack local com os dados reais, só leitura;
  - **o trabalho que ele faria:** duas pautas de um veículo regional do
    Nordeste, com as três perguntas do perfil.
- ⚠️ Simulação: não substitui um jornalista de verdade.
- Feita a pedido do developer. Issues **#452**, **#453** e **#454**, abertas
  com a aprovação dele.

## As perguntas do perfil

1. **"Quais redes mais melhoraram (ou pioraram) no IDEB?"** Pauta: as redes
   do Nordeste que mais subiram no IDEB anos iniciais de 2021 para 2023.
   - Link `/ranking?aba=redes&regiao=NE&ordem=variacao&minimo=10`: 383 redes
     com pelo menos 10 escolas.
     - O topo é Coruripe (AL, +3,06), Vargem Grande (MA, +2,62) e União dos
       Palmares (AL, +2,54).
     - As 10 primeiras e as 4 últimas (Orobó-PE, −1,06) têm a marca de salto
       atípico, com a faixa medida na região (−0,65 a +1,41).
   - Com o mínimo 3, o topo é Parnaguá (PI, 4 escolas, +3,54). A marca e o
     mínimo ajustável evitam a manchete sobre uma rede de 4 escolas.
   - O destaque (`&destaque=2702306`) dá a frase pronta: "Coruripe: 2ª de 383
     redes pelo valor de 2023 e 1ª pela variação", e o link abre na linha.
   - **Mas:**
     - o CSV ordenado pela variação traz só a posição pelo valor (VJ-02);
     - 105 das 383 redes aparecem sem variação, sem motivo na tela. Entre
       elas está a capital São Luís (MA, 97 escolas): em 2021 só 9 escolas
       tinham IDEB (VJ-03).
2. **"Onde estão as escolas sem infraestrutura básica?"** Pauta: escolas sem
   água, energia, esgoto ou banheiro no Piauí.
   - A base do PI (4.017 escolas, bloco de infraestrutura) abre direto no R.
     - Sem água potável: 204. Sem banheiro: 75.
     - Rural 11,6% contra urbana 3,8%.
     - Os municípios com mais escolas sem um desses itens: Luzilândia (32 de
       51) e Cabeceiras do Piauí (16 de 20).
   - **Mas a base só traz energia e esgoto "da rede pública"** (VJ-01). Quem
     conta `in_esgoto_rede_publica = 0` como "sem esgoto" publica **2.725
     escolas (68%)**. No Censo carregado, as escolas sem esgoto nenhum são
     **179**; na energia, 43 fora da rede contra 10 sem energia.
     - O dicionário diz "na rede pública", e é exatamente por isso que o
       erro é plausível: a coluna que a pauta pede não existe.
   - "Onde" pede mapa, e a base não traz as coordenadas (VJ-04). O Censo
     carregado tem latitude e longitude para 3.196 das 4.017 escolas do PI.
3. **"Posso citar este número, e com qual fonte?"**
   - Sim, para o ranking: a linha de fonte da página dá o órgão, o ano e a
     data da carga, e o CSV leva o recorte em cada linha.
   - Para a base: a versão vai em cada linha, e o dicionário dá a fonte e o
     link.
   - **Ressalva:** o IDEB, o número da pauta 1, aparece como "carga não
     registrada" na linha de fonte (VJ-05).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P6 | adotaria (comparação de redes) | **adotaria** (mantido; agora também com a base de análise) | a pauta das redes sai com link, destaque, salto atípico e recorte no arquivo; a de infraestrutura sai da base sem SQL, mas com uma armadilha que leva a uma manchete errada (VJ-01) |

## O que funciona

- **A pauta das redes, do link ao parágrafo:**
  - região, ordem pela variação e mínimo de escolas;
  - salto atípico medido no recorte;
  - destaque com a frase da posição.
- **O arquivo leva o contexto:** recorte e mínimo em cada linha do ranking;
  região e versão em cada linha da base.
- **Fonte na tela:** órgão, ano e data da carga, e a página de fontes.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| VJ-01 | atrapalha | **A base não diz se a escola não tem esgoto, energia ou água; só se não tem da rede pública.** No PI, `in_esgoto_rede_publica = 0` dá 2.725 escolas, e as sem esgoto nenhum são 179 (energia: 43 contra 10). A pauta "escolas sem infraestrutura básica" sai errada por um fator de 15. O Censo carregado tem `in_agua_inexistente`, `in_energia_inexistente` e `in_esgoto_inexistente`. Pedido: incluir essas colunas no bloco de infraestrutura e dizer no dicionário e na ajuda que "rede pública = 0" não quer dizer "sem". | base do PI com infraestrutura; `clean.censo_escolas` | P6, P4, P5 |
| VJ-02 | detalhe | **O CSV ordenado pela variação traz só a posição pelo valor.** As linhas saem na ordem da variação, mas a coluna `posicao` é a posição pelo valor de 2023. Quem cita "a 1ª que mais melhorou" pelo arquivo erra. Pedido: coluna `posicao_variacao`. Junto: a variação arredondada a zero aparece como "−0" (Presidente Dutra-MA). | CSV de `/ranking?…&ordem=variacao` | P6, P4 |
| VJ-03 | detalhe | **Variação vazia sem motivo na tela.** 105 das 383 redes do Nordeste (mínimo 10) aparecem com "–", e a capital São Luís está entre elas: em 2021 só 9 escolas tinham IDEB. A ajuda explica, a nota da tabela não. Pedido: na nota, "N redes sem variação: tinham menos de M escolas com dado em 2021". | `/ranking?aba=redes&regiao=NE&ordem=variacao&minimo=10` | P6 |
| VJ-04 | detalhe | **A base não traz a localização da escola.** "Onde estão" pede mapa. O Censo carregado tem latitude e longitude (80% das escolas do PI). Pedido: `latitude` e `longitude` na identificação, ausentes como vazio. | base do PI | P6, P2 |
| VJ-05 | detalhe | **O IDEB aparece com "carga não registrada" na linha de fonte.** O número central da pauta das redes fica sem a data da carga. A regra de não inventar data está certa; falta registrar a próxima carga do IDEB em `import_metadata`. | linha de fonte de `/ranking` | P6, P4 |

## Encaminhamento

Issues abertas com a aprovação do developer (2026-11-16): **#452** (VJ-01 e
VJ-04), **#453** (VJ-02 e VJ-03) e **#454** (VJ-05).

### Proposta original

1. **VJ-01 primeiro** (atrapalha): as colunas "inexistente" na base, com o
   dicionário e a ajuda. Cabe junto com **VJ-04** (coordenadas), porque os
   dois mexem nas colunas da base.
2. **VJ-02 e VJ-03** num PR pequeno do ranking: a coluna no CSV, o "−0" e
   a nota da variação vazia.
3. **VJ-05** é operacional: registrar a carga do IDEB na próxima importação.
   Pode ficar como item do roteiro de carga, sem PR de código.

## Andamento

- 2026-11-16: #452 (PR #455) mergeado: VJ-01 e VJ-04 resolvidos (água,
  energia e esgoto inexistentes ao lado do serviço, com o aviso no
  dicionário; latitude e longitude na base). Fechamento em
  [`../ciclos/2026-11-16-infra-inexistente.md`](../ciclos/2026-11-16-infra-inexistente.md).
  Ficam #453 (VJ-02 e VJ-03) e #454 (VJ-05).
- 2026-11-16: #453 (PR #456) mergeado: VJ-02 e VJ-03 resolvidos
  (`posicao_valor` e `posicao_variacao` no CSV, "0" sem sinal, a nota conta
  as redes sem variação e diz o motivo). Fechamento em
  [`../ciclos/2026-11-16-variacao-csv.md`](../ciclos/2026-11-16-variacao-csv.md).
  Fica #454 (VJ-05, operacional).
