# IVET — fundamentação dos coeficientes na literatura (#139)

> **Ficha por indicador**, **mapa "escolha de peso → referência"**, **registro das
> divergências** e **fila de revisão**. Complementa [`ivet.md`](ivet.md) (a
> fórmula) e o card `analysis/edumapsr/inst/ivet-card.yml` (o contrato).
>
> **Regra de leitura (issue #139):** cada referência é declarada com
> **metodologia**, **data de vigência** e **população de referência**. Importar
> um coeficiente sem as três é erro de leitura — a literatura é de outro
> contexto (IDEB/Prova Brasil), com metodologia e população próprias.

## 1. Fontes

| Rastro | Trabalho | Metodologia | Vigência | População de referência |
|---|---|---|---|---|
| **Z:10456** | Colucci (2014), *O impacto na ponderação do peso da Prova Brasil e do indicador de rendimento no perfil das escolas municipais…*, dissertação, USP | **DEA** (1 input: investimento/aluno; 2 outputs: nota Prova Brasil + indicador de rendimento) sob **5 padrões de ponderação** | **2011** (Censo Escolar 2011 + FINBRA 2011) | **17.124** escolas públicas **municipais** do fundamental (10.157 após exclusões) |
| **Z:10673** | Maia, Bueno & Sato (2021), *Assessing the educational performance of different Brazilian school cycles using data science methods*, PLOS ONE 16(3) | Regressão linear/penalizada (Lasso/Ridge/Elastic Net) + **GBM**; **normalização z-score**; importância de variável | **2017** (IDEB, Censo Escolar, FINBRA, RAIS) | escolas públicas (**estadual + municipal**), 5.570 municípios, 66.040 IDEB |
| **Z:10454** | *A sensibilidade do Ideb a variáveis educacionais avaliada por um modelo matemático* (2015), PUC-SP | modelo matemático de sensibilidade do IDEB | 2015 | **não lido** — ver fila de revisão (§5) |
| **Z:10453** | PUC-SP (instituição / referência de autoria dos trabalhos acima) | — | — | — |

> ⚠️ **As fontes não estão no repositório.** O storage do Zotero não existe no
> host (só o `zotero.sqlite`, sem os anexos PDF). O texto de **Z:10673** foi lido
> do *full text* público (PLOS ONE, CC BY) e o de **Z:10456** do repositório
> BDTD/USP (resumo + caracterização). **Z:10454** ficou por ler.

## 2. Ficha por indicador

O IVET é uma **média ponderada de dimensões de topo** (blocos), cada uma a média
dos seus **componentes** normalizados a `[0,1]`, direção **maior = mais
vulnerável** (`ivet-v1.2`, [`ivet.md`](ivet.md) §4.1). A ficha abaixo liga cada
escolha à referência — ou marca **"sem lastro"** quando é decisão de
implementação do projeto.

### Bloco A — escola

| campo | valor |
|---|---|
| Fórmula | reconciliação do **sistema B canônico** (`clean.mv_escolas_scores`) invertido para a direção do IVET (§4.4.1) |
| Normalização | por componente (infraestrutura binária; docentes/gestão por proporção) |
| Peso | igual entre os componentes disponíveis |
| Fonte | Censo Escolar (INEP) |
| **Referência** | **sem lastro direto.** As variáveis de estrutura escolar (água, energia, biblioteca, laboratório…) vêm de **Z:10673** (categorias *Basic Structure*, *Environmental Diversity*, *School Structure*, *Technology*), mas a **escolha dos componentes e a normalização são do projeto** |

### Bloco B — socioeconômico

| campo | valor |
|---|---|
| Fórmula | arealização do setor censitário sobre a área de influência (peso = área de interseção) |
| Normalização | proporções diretas (`pct_*`); renda invertida ("mais renda = menos vulnerável") |
| Peso | igual entre os componentes disponíveis |
| Fonte | Censo 2022 por setor (IBGE) |
| **Referência** | **Z:10673** sustenta que o **status socioeconômico é o preditor mais relevante** do desempenho (GDP per capita, gasto, salário docente entre os três maiores em todos os ciclos) — daí o bloco existir e a **direção invertida** da renda. A **composição** (instrução + renda + saneamento) é do projeto |

### Bloco C — acesso/mobilidade

| campo | valor |
|---|---|
| Fórmula | `risco_sinistros` = `clamp(sinistros_12m/pop × 1e5 / 500)`; `exposicao_frota` = `clamp((frota/pop) / 1)`; `acesso_isocrona` = `1 − clamp(pop_acessível_15min/40.000)` |
| Normalização | **clamp** (saturação linear) — ver §4 (divergência) |
| Peso | igual entre os componentes disponíveis |
| Fonte | RENAEST + RENAVAM (`analytics.mobilidade_escola`) + isócrona H3 (`clean.isocrona_escolar`, piloto ES) |
| **Referência** | **construto padrão de segurança viária** (lastro externo). A **OMS** trata *registered vehicles* como indicador de *road safety* (**WHO GHO, IMRID 194**) e a **GSRRS 2023** dá a taxa de mortes **por 100 mil habitantes e por 100 mil veículos**; o **ITF/IRTAD** (*Road Safety Annual Report 2024*) lista **frota de veículos** e **população** explicitamente como *exposure data* e publica as mortes **por 10.000 veículos registados**. Logo `risco_sinistros` usa a forma-padrão da taxa e `exposicao_frota` (veíc/hab) é medida de **exposição**. ⚠️ A literatura mede **mortes**; a RENAEST dá **sinistros** (superset/morbidade) — decisão de produto. O **acesso** (`acesso_isocrona`) é o construto original de C: 15 min a pé é o limiar canônico de "bairro de 15 minutos" e a ponte para população alcançável (`influencia.md` §Tier 2) — em **piloto no ES** desde 2026-10-19 (`ivet.md` §4.5.5) |

### Bloco D — saúde

| campo | valor |
|---|---|
| Fórmula | `distancia_ubs` = `clamp(dist/5)`; `cobertura_aps` = `1 − clamp(equipes10k/8)` |
| Normalização | clamp; a provisão é **invertida** ("mais provisão = menos vulnerável") |
| Peso | igual entre `distancia_ubs` e `cobertura_aps` |
| Fonte | CNES + SISAB/PMMB |
| **Referência** | A **direção invertida** segue o princípio de Z:10673 (mais recurso = melhor). A **provisão** ancora na **PNAB** (Portaria nº 2.436/2017; Portaria de Consolidação nº 2/2017, Anexo XXII): 1 equipe por **2.000–3.500 pessoas** (média 3.000, máx. 4.000) = **2,86–5,0 equipes/10 mil**; o **p50 medido (3,30)** cai exatamente na média recomendada. O teto do IVET (**8/10 mil = p90**) é **escolha de produto** acima da faixa normativa. A **distância (5 km)** não tem limiar na literatura → decisão de produto. Ver **§5** |

### Bloco E — segurança

| campo | valor |
|---|---|
| Fórmula | taxa por 100 mil de homicídio doloso (teto 50), latrocínio (5) e lesão seguida de morte (5) |
| Normalização | `clamp(taxa100k / teto)` — **contagem nunca entra crua** |
| Peso | igual entre os três |
| Fonte | SINESP (`clean.brazilcrime_municipio`) |
| **Referência** | **OMS/PAHO** tratam taxa **> 10 homicídios/100 mil** como *violência epidêmica* (World report on violence and health, 2002). **Atlas da Violência 2026** (Ipea/FBSP; dados 2024): municípios > 100 mil — mediana 20,2, média 24,0, **referência nacional 23,4**/100 mil; 46 municípios **> 40**/100 mil. O teto do IVET (**50**) fica entre a referência nacional e o topo da distribuição (p90 medido = 46,3; p99 = 103,5) — **decisão de produto** ancorada nesses marcos. A regra "**contagem nunca crua**" é do projeto (o defeito do `iqd`). Ver **§5** |

### Bloco F — meio ambiente

| campo | valor |
|---|---|
| Fórmula | `risco_fogo` = `clamp(freq/teto)`; `vegetacao_natural` = `1 − clamp(fracao)`; `carbono_solo` = `1 − clamp(carbono/teto)` |
| Normalização | clamp; **fogo entra direto**; **vegetação e carbono invertidos** ("mais = menos vulnerável", como a renda do bloco B) |
| Peso | igual entre os componentes disponíveis |
| Fonte | MapBiomas Fogo + Carbono do Solo (`clean.mapbiomas_escola_risco`); cobertura Coleção 11 (`clean.v_mapbiomas_escola_grupos`) |
| **Referência** | **exposição a risco** (fogo): a fumaça de incêndio é risco respiratório documentado para **crianças e escolas** (CDC, *Health Effects of Wildfire Smoke in Children*, 2021; EPA, *Protecting Children from Wildfire Smoke and Ash*, 2018; Wildfires, 2003 — *missed school*), o que sustenta medir o **fogo no entorno** da escola. **Meio ambiente** (vegetação + solo): os **índices brasileiros de vulnerabilidade/fragilidade ambiental** (Ross, 1994; família AHP — ex. *Tarumã-Mirim*, 2025) combinam **uso e cobertura da terra** (vegetação natural) com **solos**; a cobertura da terra é apontada como a variável de **influência predominante**. ⚠️ É **lastro de construto** (existe a família de índices), **não de coeficiente**: tetos de fogo/carbono são **calibração empírica** (§5) |

### Bloco G — recursos

| campo | valor |
|---|---|
| Fórmula | FUNDEB/aluno, despesa em educação/aluno, autonomia fiscal (%) |
| Normalização | clamp; **invertida** ("mais recurso = menos vulnerável") |
| Peso | igual entre os disponíveis |
| Fonte | SIOPE/SICONFI |
| **Referência** | **Z:10673**: o **gasto/educação e o GDP per capita** estão entre os preditores mais relevantes — sustenta o bloco e a **direção invertida**. Os **tetos** são calibração empírica |

### Agregação

| campo | valor |
|---|---|
| Fórmula | `ivet = média ponderada das dimensões disponíveis`; `ivet_blocos_territoriais_minimos() = C+D+E` |
| Peso | **igual entre as dimensões** (`W=1`) — default reprodutível |
| Dimensão ausente | fica **fora** do numerador e do denominador (`NA`, #154) |
| **Referência** | **Z:10456** (ver §3) — sustenta que a **escolha de peso é uma escolha metodológica**, e por isso o projeto fixa **peso igual** por default e exige **justificativa registrada + nova versão** para qualquer ponderação diferente |

## 3. Mapa "escolha de peso → referência" (Z:10456)

**Z:10456** (Colucci, 2014) é o caso concreto: aplica **DEA** com **1 input**
(investimento/aluno) e **2 outputs** (nota Prova Brasil, indicador de rendimento)
sobre **17.124 escolas municipais (2011)** e varia a **ponderação dos outputs**
em **cinco padrões** (50-50, 80-20, 90-10, …). Resultado: **as escolas
classificadas como eficientes mudam de eixo geográfico** (do Nordeste para
Sudeste/Sul) conforme o peso muda. Isto é, **a ponderação altera o ranking**, não
só o valor.

Nota de contexto: o próprio IDEB é `Prova Brasil × indicador de rendimento`, com
**50-50** na ponderação do MEC — ou seja, o índice que serve de referência já
embute uma escolha de peso.

| escolha do IVET | regra | referência | leitura |
|---|---|---|---|
| **Peso entre dimensões** | `W = 1` (igual) por default | **Z:10456** | o peso **muda o resultado**; logo o default é o **mais reprodutível** (igual), e qualquer ponderação diferente **exige justificativa + nova versão** (`ivet-v1.3`, …) |
| **Peso dentro do bloco** | média dos componentes disponíveis | **Z:10456** + **Z:10673** | Z:10673 mostra que a **importância das variáveis é heterogênea** (difere por ciclo e região) — não há peso "natural"; a média é a escolha neutra |
| **Componente ausente** | fora do denominador (`NA`, #154) | **Z:10456** (por contraste) | a literatura pondera **todos** os outputs; o IVET **não penaliza** o território por falta de dado — divergência deliberada (§4) |
| **Ordem de agregação** | componente → dimensão → IVET (média de médias) | **Z:10673** | a análise por **categorias** (Basic Structure, Environmental Diversity, …) sustenta agregar **por blocos temáticos** antes do índice final |
| **Normalização** | `clamp(x/teto)` | **Z:10673** (parcial) | Z:10673 usa **z-score**; o IVET usa **clamp com teto** — divergência deliberada (§4) |

## 4. Registro das divergências

Divergir da literatura é permitido; **divergir sem dizer por quê** é o defeito.

1. **Normalização — z-score (Z:10673) × clamp (IVET).** Z:10673 padroniza por
   z-score porque o objetivo é **predição** (a escala é livre). O IVET publica um
   índice **em `[0,1]`** e comparável entre territórios: o `clamp(x/teto)` com
   **teto documentado** é mais interpretável e **satura** o extremo (não deixa um
   outlier puxar a cauda). Divergência **deliberada**.
2. **Componente ausente — 0 (literatura) × `NA` (IVET).** Na literatura, todos os
   outputs existem para todas as DMUs. No IVET, o dado territorial pode faltar
   (célula suprimida, fonte ausente). Tratar ausência como **0** penalizaria o
   território por falta de dado; o IVET usa **`NA` fora do denominador** (#154).
   Divergência **deliberada** e registrada.
3. **⚠️ Inconsistência interna do card — corrigida nesta entrega.** O card dizia
   `componente_ausente: vira 0 dentro da dimensao`, mas a **implementação**
   (`ivet_componente_*` → `ivet_bloco_*` → `ivet_agregar`) **preserva `NA`** e o
   deixa **fora** do denominador. O texto do card foi corrigido para
   `fica fora do denominador da dimensao (NA, #154) — nunca 0`, alinhando o
   contrato à #154.
4. **Bloco C sem lastro.** É um **proxy** de exposição viária (decisão de
   produto, 2026-10-18), não uma dimensão de acesso — a literatura do acervo não
   mede mobilidade. Registrado em `ivet.md` §4.5.5. **Fila de revisão**.
5. **Tetos — de "sem lastro" a parcialmente ancorados (§5).** O confronto com
   p90/p99 foi refeito e o lastro da literatura foi buscado: **E** ancora em
   OMS/PAHO + Atlas da Violência 2026; **D/provisão** ancora na PNAB. Os
   restantes (`5 km`, `latrocínio`/`lesão` = 5, `sinistros` = 500, `frota` = 1,
   tetos de G) seguem **calibração empírica declarada como decisão de produto** —
   não há coeficiente de literatura para eles no acervo. Mudar um teto exige
   registro e nova versão da fórmula.
6. **Bloco B é a exceção com lastro forte.** Z:10673 sustenta a **presença** e a
   **direção** do bloco socioeconômico; a composição fina (instrução × renda ×
   saneamento) continua decisão do projeto.

## 5. Lastro dos tetos

Todo teto é o valor em que a **vulnerabilidade satura em 1**. Esta seção
confronta cada teto com a **distribuição medida em `edumaps_dev`** (2026-10-18)
e com o **lastro** disponível — literatura, norma, ou **decisão de produto**
registrada. Nada sai da fila (§6) sem uma das duas coisas.

Percentis medidos: **E** = média municipal 2021–2023 (5.570 municípios; a
supressão de célula 1–4 vira `NULL` — 23.185 células); **D** = 145.723 escolas
(distância) e 5.533 municípios (equipes/10 mil); **G** = por município; **F** =
fogo/carbono **nacional** em 156.816 escolas (ano 2020, raio 1 km, censo 2025) e
vegetação em 2.967 escolas do **ES** (ano 2024) — as duas metades do F cobrem
amostras **disjuntas** (`ivet.md` §4.5.4).

| bloco | componente (unidade) | teto | p50 | p90 | p99 | lastro |
|---|---|---|---|---|---|---|
| B | renda do responsável (R$) | 2.424 | — | — | — | **produto** — 2 salários mínimos de jul/2022 |
| C | `risco_sinistros` (/100 mil) | 500 | 60 | 429 | 988 | **produto** (≈ p90) — a *taxa por 100 mil hab* é a forma-padrão OMS/WHO e ITF/IRTAD; teto empírico (ver §5.1) |
| C | `exposicao_frota` (frota/hab) | 1 | — | 0,89 | 1,05 | **produto** (≈ p90) — *frota* é **exposição** explícita no IRTAD (veíc/hab ≈ motorization rate) |
| C | `acesso_isocrona` (hab a pé/15 min) | 40.000 | 4.325 | 19.871 | 40.590 | **produto** (≈ p99) — **provisório**, medido no **piloto do ES** (#278, 2.897 escolas, 2026-10-19); recalibrar na expansão nacional. Direção **invertida**: mais população alcançável = menos vulnerável |
| D | `distancia_ubs` (km) | 5,0 | 0,54 | 7,25 | 38,75 | **produto** — 5 km é o limiar "acesso difícil" da própria view; 13,4% das escolas acima |
| D | `cobertura_aps` (equipes/10 mil) | 8 | **3,30** | 8,39 | 12,39 | **PNAB**: 2.000–3.500 pessoas/equipe (média 3.000, máx. 4.000) = **2,86–5,0** equipes/10 mil. O teto 8 = p90 é **acima** da faixa normativa → decisão de produto |
| D | `presenca_ubs` (UBS/10 mil), `efetividade_vagas_aps` (%) | 8 / 100 | — | — | — | **produto** — fora do default |
| E | `homicidio_doloso` (por 100 mil) | 50 | ~0 | 46,3 | 103,5 | **OMS/PAHO**: > **10**/100 mil = *violência epidêmica*. **Atlas 2026**: referência nacional **23,4** (2024), 46 municípios **> 40**. Teto 50 ≈ p90 ≈ 2× a referência nacional → decisão de produto ancorada |
| E | `latrocinio`, `lesao_corporal_seguida_de_morte` (por 100 mil) | 5 | 0 | 0 | ~0 | **produto** — eventos raros (p90 = 0); o teto evita que **um único caso** sature |
| F | `risco_fogo` (freq. média 1985–2020) | **2,463** | 0,006 | 0,320 | 2,463 | **produto** (p99 nacional) — a fumaça de incêndio é risco à **criança na escola** (CDC 2021; EPA 2018); teto = p99 nacional (156.816 escolas) |
| F | `vegetacao_natural` (fração) | — | 0,104 | 0,356 | 0,903 | **produto** — a cobertura da terra é a variável de **influência predominante** nos índices de vulnerabilidade ambiental (Ross 1994; AHP); sem teto (proporção), invertida |
| F | `carbono_solo` (tC/ha) | **705,98** | 233,6 | 485,7 | 705,98 | **produto** (p99 nacional) — **solos** entram nos índices de vulnerabilidade ambiental (Ross 1994; AHP); teto = p99 nacional ⚠️ varia por bioma e o bruto tem negativo (nodata) |
| G | `fundeb_por_aluno` | 10.000 | — | 9.336 | — | **produto** (≈ p90) |
| G | `despesa_educ_por_aluno` | 15.000 | — | 14.521 | — | **produto** (≈ p90) |
| G | `autonomia_fiscal_pct` | 50 | 13,2 | 30,9 | — | **produto** (≈ 1,6 × p90) |

> Os percentis foram calculados direto no banco. A conferência bateu com as
> anotações do card (E p90 = 46,3; D distância p90 = 7,25; D equipes p90 = 8,39;
> C sinistros p90 = 429, p99 = 988).
>
> ⚠️ **Divisão inteira** é uma armadilha aqui: `equipe_esf + ativas_ff` e
> `sinistros_12m`, divididos por `populacao_estimada` (todos `integer`), dão 0
> sem `::numeric`.

### 5.1 O que a literatura sustenta — e a escolha que fica aberta

- **D-provisão (equipes/10 mil).** A PNAB fixa a população adscrita (2.000–3.500,
  média 3.000, máx. 4.000), dando a faixa normativa **2,86–5,0 equipes/10 mil**.
  O teto do IVET (**8**) está **acima** da faixa: o município *típico* (p50 =
  3,30, exatamente a média da PNAB) fica com vulnerabilidade ≈ **0,59**. É uma
  leitura **relativa** (posição na distribuição), coerente com o p90; uma leitura
  **normativa** usaria 5 (topo da faixa) e zeraria quem cumpre a PNAB. ✅
  **Decidido (2026-10-18): manter 8** (leitura relativa/≈p90) — sem nova versão
  da fórmula.
- **E-homicídio (por 100 mil).** Dois marcos documentados: **> 10 = epidemia**
  (OMS) e a **referência nacional 23,4** (Atlas 2026). O teto **50** não é nenhum
  dos dois: ≈ o p90 (46,3). Alternativas registradas: **40** (o corte "muito
  alto" do Atlas, ≈ p90) ou **25** (≈ a referência nacional, saturando metade dos
  municípios acima da média nacional). ✅ **Decidido (2026-10-18): manter 50**
  (≈p90) — sem nova versão da fórmula.
- **D-distância (5 km).** A busca não encontrou **limiar numérico** na literatura
  (os estudos de acesso rural descrevem barreiras, não um km de corte). O 5 km
  vem da própria view ("acesso difícil > 5 km"). Decisão de produto — 13,4% das
  escolas acima (p90 = 7,25 km).
- **C (exposição viária).** O **construto** tem lastro externo: a OMS trata
  **veículos registados** como indicador de segurança viária (WHO GHO) e a
  **GSRRS 2023** dá a taxa de mortes por **100 mil habitantes e por 100 mil
  veículos**; o **ITF/IRTAD** lista **frota** e **população** como *exposure
  data* e publica mortes **por 10.000 veículos registados**. Logo `exposicao_frota`
  (veíc/hab) é medida de **exposição** consagrada e `risco_sinistros` (por 100
  mil hab) usa a forma-padrão da taxa. O acervo do projeto **não** tem literatura
  de trânsito. Os **tetos** (500 sinistros; 1 veíc/hab) seguem **empíricos**
  (≈ p90) — decisão de produto. ⚠️ **Desfecho diferente**: a literatura mede
  **mortes** (*fatalities*); a RENAEST mede **sinistros** (acidentes), um
  superset — mais sensível, mas não comparável 1:1 às taxas internacionais.
- **C (acesso, isócrona).** O **acesso** é o construto original de C e o mais
  direto: população que a escola alcança a pé em 15 min, pela **rede real** de
  ruas (Valhalla sobre OSM), não por raio em linha reta. Entra **invertido**
  (mais alcance = menos vulnerabilidade), como a renda no bloco B. O acervo
  **não** tem literatura de trânsito; o limiar de 15 min a pé é o "bairro de
  15 minutos" adotado como decisão de arquitetura (`influencia.md` §Tier 2) e
  o **teto 40.000** é **empírico-provisório** (p99 do piloto do ES) — recalibrar
  com a expansão nacional.
- **F (meio ambiente).** O **construto** tem lastro externo em **duas frentes**.
  (1) *Fogo*: a **fumaça de incêndio** é risco respiratório documentado para
  **crianças e escolas** — o CDC (2021) revisa os efeitos e trata do ambiente
  escolar; o EPA (2018) orienta a proteção da criança; e o estudo das queimadas
  do sul da Califórnia (2003) mediu **dias de aula perdidos**. (2) *Cobertura
  do solo*: os índices brasileiros de **vulnerabilidade/fragilidade ambiental**
  (Ross, 1994; família AHP) combinam **uso e cobertura da terra** com **solos**,
  apontando a cobertura da terra como a variável de **influência predominante**.
  ⚠️ É lastro de **construto**, não de **coeficiente**: os tetos de fogo
  (**2,463**) e carbono (**705,98**) são **calibrados no p99 nacional** (156.816
  escolas; `clean.mapbiomas_escola_risco`, 2026-10-19), sem lastro de literatura
  para o **valor** (decisão de produto). ⚠️ O acervo do projeto **não** tem
  literatura de meio ambiente — o lastro é **externo**.
- **G.** Sem lastro temático no acervo (a literatura lida é de desempenho
  escolar). Tetos empíricos, decisão de produto.

**Referências desta seção:** OMS/PAHO, *World report on violence and health*
(2002) — limiar > 10 homicídios/100 mil; Ipea & FBSP, *Atlas da Violência 2026*
(Cerqueira & Bueno, coord.; dados 2024); Ministério da Saúde, **Portaria nº
2.436/2017** e **Portaria de Consolidação nº 2/2017, Anexo XXII** (PNAB); **WHO**
— Global Health Observatory, *Road safety: registered vehicles* (IMRID 194) e
*Global Status Report on Road Safety 2023*; **ITF/OECD** — *IRTAD Road Safety
Annual Report 2024* (§5.1, bloco C).

## 6. Fila de revisão

Indicadores que entram em produção **sem lastro** e devem ser revistos **antes**
de virarem número publicável (ordem de risco):

| # | item | situação | onde |
|---|---|---|---|
| 1 | **Bloco C** (mobilidade) | ✅ **proxy confirmado** — a exposição viária (sinistros/frota) tem lastro externo OMS/ITF-IRTAD (§5.1); resta **substituir pela isócrona** quando houver motor de roteamento (infra) | `ivet.md` §4.5.5 · §5.1 |
| 2 | **Tetos de todos os blocos** | ✅ feito — cada teto confrontado com p50/p90/p99 e com um lastro (norma / literatura / decisão de produto) | §5 |
| 2b | **Escolha do teto de D (provisão) e E (homicídio)** | ✅ **decidido** (2026-10-18) — **D = 8** (relativo, ≈p90) e **E = 50** (≈p90) **mantidos**; leitura de posição na distribuição. Nova versão da fórmula fica **dispensada** (tetos inalterados) | §5.1 |
| 3 | **Bloco E** (segurança) | ✅ feito — OMS/PAHO (>10 = epidemia) + Atlas 2026 (23,4 nacional); a *escolha* do teto segue | §5.1 |
| 4 | **Bloco D** (saúde) | ✅ feito — PNAB: 2.000–3.500 pessoas/equipe (média 3.000) | §5.1 |
| 5 | **Bloco F** (meio ambiente) | ✅ feito — 3 componentes (fogo + vegetação natural + carbono do solo), peso igual; lastro **de construto** externo (fumaça × escola; Ross/AHP); **tetos calibrados no p99 nacional** (fogo 2,463 · carbono 705,98) | `ivet.md` §4.5.4 · §5.1 |
| 6 | **Z:10454** | aberto — ler o trabalho (sensibilidade do IDEB por modelo matemático) e incorporar | §1 |

**Regra da fila:** um indicador novo (vindo de `docs/funcionalidades/analise/`)
entra nesta fila **no momento em que é especificado**, e só sai quando a ficha
(§2) tiver a referência — ou o registro explícito de que é decisão de produto.

## 7. Referências

### 7.1 Do acervo (Zotero)

- **Z:10456** — Colucci, L. (2014). *O impacto na ponderação do peso da Prova
  Brasil e do indicador de rendimento no perfil das escolas municipais do ensino
  fundamental consideradas eficientes pela técnica DEA…*. Dissertação, USP.
  DOI `10.11606/D.96.2014.tde-18072014-145200`.
- **Z:10673** — Maia, J. S. Z.; Bueno, A. P. A.; Sato, J. R. (2021). *Assessing
  the educational performance of different Brazilian school cycles using data
  science methods*. PLOS ONE 16(3): e0248525. DOI `10.1371/journal.pone.0248525`.
- **Z:10454** — *A sensibilidade do Ideb a variáveis educacionais avaliada por um
  modelo matemático* (2015), PUC-SP. (por ler)
- **Z:10453** — PUC-SP (instituição).

### 7.2 Normas e relatórios (§5)

- **PNAB** — Brasil, Ministério da Saúde, **Portaria nº 2.436/2017** (Política
  Nacional de Atenção Básica) e **Portaria de Consolidação nº 2/2017, Anexo
  XXII**: 1 equipe de SF/AB por **2.000–3.500 pessoas** (média 3.000, máx.
  4.000). Vigência 2017→.
- **OMS/PAHO** — *World report on violence and health* (2002): taxa **> 10
  homicídios por 100 mil habitantes** caracteriza **violência epidêmica**.
- **Atlas da Violência 2026** — Cerqueira, D.; Bueno, S. (coord.). Brasília:
  Ipea; FBSP, 2026 (dados 2024). Municípios > 100 mil: referência nacional
  **23,4** homicídios/100 mil; 46 municípios > **40**/100 mil.
- **OMS / WHO (trânsito)** — World Health Organization, *Global Health
  Observatory: Road safety — registered vehicles* (IMRID 194) e *Global Status
  Report on Road Safety 2023* (mortalidade **por 100 mil habitantes** e **por
  100 mil veículos**). §5.1 (C).
- **ITF/OECD (trânsito)** — International Transport Forum, ***IRTAD* Road
  Safety Annual Report 2024**: **frota de veículos** e **população** constam como
  *exposure data* e as mortes saem **por 10.000 veículos registados** — base do
  proxy de exposição viária do bloco C (§5.1).
- **MapBiomas** — *Coleção 11 da Série Anual de Mapas de Uso e Cobertura da
  Terra do Brasil* (cobertura do solo, #255); *MapBiomas Fogo* (frequência de
  fogo 1985–2020); *Carbono Orgânico do Solo*. Fontes do bloco F (§5.1).
- **CDC (fumaça × criança)** — Centers for Disease Control and Prevention,
  *Health Effects of Wildfire Smoke in Children and Public Health Tools: A
  Narrative Review* (2021): revisa os efeitos respiratórios em crianças e trata
  do **ambiente escolar**.
- **EPA (fumaça × criança)** — U.S. Environmental Protection Agency,
  *Protecting Children from Wildfire Smoke and Ash* (2018).
- **Ross (1994)** — Ross, J. L. S. *Análise empírica da fragilidade dos
  ambientes naturais e antropizados*. Revista do Departamento de Geografia (USP),
  n. 8, 1994. Base da família de **índices de vulnerabilidade/fragilidade
  ambiental** (AHP) que combina **uso e cobertura da terra** com **solos** —
  lastro de construto do bloco F (§5.1).
