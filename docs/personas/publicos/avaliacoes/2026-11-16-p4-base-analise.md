# Reavaliação: P4 depois da base de análise (2026-11-16)

Terceira rodada da P4 (academia), depois da reavaliação P4/P6 de 2026-11-15
ter todos os achados entregues:

| Achado | O quê | Entrega |
|---|---|---|
| RV-01 | salto atípico no ranking de redes | #440 |
| RV-02 | base multi-indicador | #443 |
| RV-03 | versão dos dados no CSV do agrupamento | #441 |
| RV-04 | ordem crescente | #440 |
| RV-05 | porte do município no ranking | #442 |

- **Avaliou:** só a P4, a pedido do developer. P6 fica com "adotaria" (a
  rodada de 2026-11-15); P3 e P5 ficam como estavam.
- **Material:**
  - as fichas `analise/base-de-analise.md` e `analise/ranking.md`, e as
    ajudas `base-de-analise.md` e `rankings.md`;
  - a stack local com os dados reais, só leitura;
  - **o trabalho que ela faria:** baixar a base do ES com todos os blocos,
    abrir no R com `read.csv2()` (como a ajuda diz) e rodar o modelo da
    pergunta dela.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.
- Issues abertas com a aprovação do developer (2026-11-16): **#444**
  (BA-01, BA-03 e BA-04) e **#445** (BA-02, decisão de produto).

## As perguntas do perfil

1. **"Quanto da variação do IDEB se associa à infraestrutura, controlando por
   rede?"** Respondida com a base.
   - `base-analise-ES-censo2025-ideb2023-inse2023.csv`: 3.046 escolas, 47
     colunas.
   - `read.csv2()` lê o arquivo direto, com os números como números.
   - `lm(ideb_ai ~ infra + rede + inse_media)` roda em 822 escolas.
   - Os quatro anos de versão estão em toda linha, e o dicionário dá a fonte e
     o link de cada coluna.
   - Ausente é `NA`: 60 escolas sem registro de docentes, nunca 0. As
     proporções ficam entre 0 e 1.
2. **"Municípios de porte e região semelhantes têm oferta parecida?"**
   Parcial.
   - O ranking nacional com porte (10 a 20 mil habitantes, IDEB anos
     iniciais) compara 1.004 redes entre si.
   - O topo vem do CE e do primeiro quinto de INSE, uma leitura que ela não
     tinha antes.
   - Não há recorte por **região**: ou é uma UF, ou é o Brasil (BA-02).
3. **"Como o perfil docente muda entre regiões?"** Possível, mas trabalhoso:
   a base de docência sai uma UF por vez, então comparar as cinco regiões
   pede 27 downloads e a junção à mão. Isso é decisão de produto (o Brasil
   inteiro fica na assinatura), mas a pergunta é dela (BA-02).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria com ressalvas (exploração; ainda não base de artigo) | **adotaria** (base de artigo para um corte transversal de uma UF; séries e Brasil inteiro, não) | a base multi-indicador se cita e se refaz: versão em cada linha e no nome, dicionário com fonte e link, ausência como ausência, IDEB por etapa ao lado do Censo, sem SQL; o porte entra no ranking |

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| BA-01 | atrapalha | **Uma edição antiga do IDEB é cruzada com o Censo 2025 sem aviso.** A tela deixa escolher o IDEB de 2005 a 2023, mas o Censo carregado é só o de 2025. Com o IDEB 2019, a infraestrutura e a docência são as de 2025, e as escolas fechadas desde então saem: das 1.209 escolas do ES com IDEB 2019, 26 ficam fora. As colunas dizem os anos (`ano_censo` 2025, `ano_ideb` 2019), mas nada avisa que o cruzamento é entre anos diferentes. Para ela, isso é "número sem método" num modelo que pareceria longitudinal. | `/base-analise?uf=ES&blocos=infraestrutura,desempenho&ano_ideb=2019` | P4 |
| BA-02 | detalhe | **Sem recorte por região.** O ranking aceita UF ou Brasil, e a base, só UF. "Municípios de porte e região semelhantes" e "o perfil docente entre regiões" pedem a região (Nordeste, Sudeste…). No ranking, dá para baixar o Brasil e filtrar o CSV; na base, são até 9 downloads por região. | `/ranking`, `/base-analise` | P4 |
| BA-03 | detalhe | **O link da base não fixa a versão.** A URL guarda o recorte e os blocos, e não os dados: depois de uma carga nova do Censo, o mesmo link traz outra base. O arquivo diz o ano, mas a tela e a ajuda não dizem que o link traz sempre a carga mais recente e que é o arquivo que se guarda. | ajuda `base-de-analise.md` | P4 |
| BA-04 | detalhe | **O dicionário não dá a fórmula das proporções de docência.** "Proporção de docentes com licenciatura" não diz o denominador (o total de docentes, `qt_docentes`) nem que um docente que atua em mais de uma escola conta em cada uma. | `base-analise-dicionario-….csv` | P4 |

## Encaminhamento

Issues **#444** (itens 1 e 2) e **#445** (item 3), abertas com a aprovação do
developer em 2026-11-16.

### Proposta original

1. **BA-01 e BA-03 cabem num PR pequeno.**
   - BA-01: aviso na tela quando a edição do IDEB não é a mais recente ("a
     infraestrutura e a docência são do Censo 2025; escolas fechadas depois
     de 2019 não entram"), e a mesma frase no dicionário (coluna `ano_ideb`)
     e na ajuda.
   - BA-03: uma frase na tela e na ajuda.
2. **BA-04:** completar as descrições no catálogo da base. Cabe no mesmo PR.
3. **BA-02 é decisão de produto.**
   - O recorte por região no **ranking** é barato: o nacional já existe, e a
     região só filtra.
   - Na **base**, uma região passa do limite de "uma UF por vez": o Sudeste
     tem cerca de 70 mil escolas. Fica com a decisão da base nacional e da
     assinatura.
4. **Séries históricas** (vários Censos) continuam fora, por decisão. O
   BA-01 só pede que o cruzamento entre anos seja dito.
