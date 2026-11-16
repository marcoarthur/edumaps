---
titulo: "Base de análise: indicadores por escola para baixar"
publico: [comunidade]
modulo: comunidade
nivel: basico
status: ativo
relacionadas: [rankings, fontes-e-metodologia]
funcionalidade: ../../funcionalidades/analise/base-de-analise.md
ultima_revisao: 2026-11-16
---

# Base de análise: indicadores por escola para baixar

> **Para quem:** quem quer cruzar indicadores das escolas numa planilha ou num programa de estatística
> **Tempo de leitura:** ~3 min

## Em 30 segundos
A página **Base de análise** (botão na página inicial, ou `/base-analise`)
gera uma planilha com **uma linha por escola em funcionamento** e os
indicadores que você escolher. Cada arquivo diz de que ano são os dados, e o
**dicionário** explica cada coluna. Não precisa de login.

## Passo a passo
1. **Recorte:** escolha a **UF** (a base sai uma UF por vez). Se quiser,
   restrinja a um **município** e a uma **rede** (pública, municipal,
   estadual, federal ou privada). A página mostra quantas escolas entram.
2. **Indicadores:** a **identificação** (INEP, nome, município, UF, região,
   rede, localização urbana ou rural, latitude e longitude) vem sempre.
   Marque os blocos que quiser:
   - **Etapas oferecidas:** se a escola oferece creche, pré-escola, anos
     iniciais (`oferece_ai`), anos finais (`oferece_af`), ensino médio
     (`oferece_em`, inclusive integrado e normal), EJA e educação
     profissional, e se tem classe especial exclusiva (1 = sim, 0 = não);
   - **Infraestrutura:** água, energia, esgoto, lixo, banheiro, biblioteca,
     laboratórios, quadra, internet e rampas (1 = tem, 0 = não tem), e se a
     escola **não tem** água, energia ou esgoto (`_inexistente`, 1 = não
     tem);
   - **Docência:** número de docentes e as proporções com licenciatura,
     mestrado, doutorado, concursados e sem especialização;
   - **IDEB e SAEB por etapa:** IDEB, notas e aprovação nos anos iniciais
     (`_ai`), nos anos finais (`_af`) e no ensino médio (`_em`), na edição que
     você escolher;
   - **Nível socioeconômico (INSE):** a média e o nível, da edição mais
     recente do SAEB;
   - **Porte do município:** a população estimada pelo IBGE e a classe de
     tamanho.
3. **Baixar:** **Baixar base (CSV)** gera a planilha; **Baixar dicionário das
   colunas** gera a lista das colunas com a descrição, a fonte, o ano e o
   link oficial. O endereço da página guarda as escolhas, então o link
   reabre a mesma base. Mas o link traz sempre a **carga mais recente**:
   depois de uma carga nova do Censo, o mesmo link dá outros números. Para
   citar, guarde o **arquivo**: os anos estão no nome e nas últimas colunas.

## Entendendo os números
- **Ausência é célula vazia, nunca zero.** Escola sem IDEB numa etapa (porque
  não oferece a etapa ou não teve nota publicada) fica com a célula vazia.
  Para separar os dois casos, marque **Etapas oferecidas**: `oferece_ai = 1`
  com `ideb_ai` vazio é "oferece e não teve nota".
- **Quem fica sem IDEB.** O IDEB só é publicado para as escolas com
  participação suficiente no SAEB, e a falta não é aleatória: as escolas
  pequenas, as rurais e as sem infraestrutura ficam de fora com muito mais
  frequência.
  - **Exemplo:** entre as escolas públicas da BA e do ES que oferecem anos
    iniciais, 12,7% das que não têm algum item básico (água, energia,
    esgoto ou banheiro) têm IDEB 2023, contra 44,3% das completas.
  - **O efeito:** um modelo do IDEB que use só as escolas com nota quase não
    vê as escolas sem infraestrutura, e a associação some por seleção.
  - **Antes de modelar,** compare quem tem IDEB entre os grupos. No R:
    `base$tem_ideb <- !is.na(base$ideb_ai)` e
    `with(subset(base, oferece_ai == 1), tapply(tem_ideb, in_agua_inexistente, mean))`.
- **Versão dos dados:** as últimas colunas (`ano_censo`, `ano_ideb`,
  `ano_inse`, `ano_populacao`) repetem em toda linha o ano de cada base, e o
  nome do arquivo também leva os anos (ex.:
  `base-analise-ES-censo2025-ideb2023.csv`). Guardado ou renomeado, o arquivo
  continua dizendo de onde veio.
- **Edição antiga do IDEB:** só o Censo Escolar mais recente está
  carregado. Com uma edição antiga (ex.: 2019), o IDEB é cruzado com a lista
  de escolas, a infraestrutura e a docência do Censo mais recente, e as
  escolas fechadas depois daquela edição não entram. A página e o dicionário
  avisam; para uma série de anos, cada ano precisaria do seu Censo.
- **"Rede pública = 0" não quer dizer "sem".** `in_energia_rede_publica = 0`
  pode ser gerador ou energia renovável; `in_esgoto_rede_publica = 0` pode
  ser fossa; `in_agua_potavel = 0` pode ser água não potável. Para contar as
  escolas **sem** o serviço, use `in_agua_inexistente`,
  `in_energia_inexistente` e `in_esgoto_inexistente`. No Piauí, por exemplo,
  2.725 escolas têm esgoto fora da rede pública, e 179 não têm esgoto
  nenhum.
- **Coordenadas:** `latitude` e `longitude` em graus decimais, com 6 casas,
  como a escola declarou ao Censo Escolar, sem verificação. Cerca de 4 em 5
  escolas têm; nas outras, a célula fica vazia. Para um mapa, no R:
  `sf::st_as_sf(na.omit(base[, c("inep", "latitude", "longitude")]),
  coords = c("longitude", "latitude"), crs = 4326)`; no Python, com
  `geopandas.points_from_xy(base.longitude, base.latitude)`.
- **Docência:** as proporções são sobre o total de docentes da escola
  (`qt_docentes`). Na contagem do Censo Escolar, quem dá aula em mais de uma
  escola conta em cada uma.
- O arquivo usa `;` como separador e vírgula decimal: abre direto no Excel.
  No R, `read.csv2()`; no Python, `pandas.read_csv(sep=";", decimal=",")`.
- Os indicadores são os publicados pelo INEP e pelo IBGE, sem correção.

## Limitações conhecidas
- Uma UF por vez. A base de uma região ou do Brasil inteiro, as séries de
  vários anos e o acesso por API não estão nesta página; para uma região,
  baixe as UFs dela (as colunas são as mesmas, e a coluna `regiao` já vem
  em cada linha) e junte os arquivos. O
  [ranking das redes](rankings.md) já aceita a região.
- O INSE vem só da edição mais recente do SAEB.

## Veja também
- [Rankings de redes e de escolas](rankings.md)
- [Fontes e metodologia](fontes-e-metodologia.md)
