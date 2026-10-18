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

### Bloco C — mobilidade (proxy de exposição viária)

| campo | valor |
|---|---|
| Fórmula | `risco_sinistros` = `clamp(sinistros_12m/pop × 1e5 / 500)`; `exposicao_frota` = `clamp((frota/pop) / 1)` |
| Normalização | **clamp** (saturação linear) — ver §4 (divergência) |
| Peso | igual entre os componentes disponíveis |
| Fonte | RENAEST + RENAVM (`analytics.mobilidade_escola`) |
| **Referência** | **sem lastro na literatura do acervo.** Nenhum dos quatro trabalhos mede exposição viária; é um **proxy** decidido pelo produto (2026-10-18) enquanto a isócrona não existe (`ivet.md` §4.5.5). **Fila de revisão** (§5) |

### Bloco D — saúde

| campo | valor |
|---|---|
| Fórmula | `distancia_ubs` = `clamp(dist/5)`; `cobertura_aps` = `1 − clamp(equipes10k/8)` |
| Normalização | clamp; a provisão é **invertida** ("mais provisão = menos vulnerável") |
| Peso | igual entre `distancia_ubs` e `cobertura_aps` |
| Fonte | CNES + SISAB/PMMB |
| **Referência** | **sem lastro na literatura do acervo.** A **direção invertida** segue o mesmo princípio da renda (Z:10673: mais recurso = melhor), mas os **tetos (5 km, 8/10 mil)** são calibração empírica do dev, não da literatura |

### Bloco E — segurança

| campo | valor |
|---|---|
| Fórmula | taxa por 100 mil de homicídio doloso (teto 50), latrocínio (5) e lesão seguida de morte (5) |
| Normalização | `clamp(taxa100k / teto)` — **contagem nunca entra crua** |
| Peso | igual entre os três |
| Fonte | SINESP (`clean.brazilcrime_municipio`) |
| **Referência** | **sem lastro na literatura do acervo.** A regra "**contagem nunca crua**" é do projeto (o defeito do `iqd`), e os tetos são calibração empírica (p90) |

### Bloco F — meio ambiente (parcial)

| campo | valor |
|---|---|
| Fórmula | cobertura do solo por fração de classe (MapBiomas 30 m); exposição a risco **pendente** |
| Normalização | grupos nível 1 (vegetação natural, agropecuário, …) |
| Peso | **não definido** (bloco não entra na fórmula até a exposição a risco existir) |
| Fonte | MapBiomas Coleção 11 (`clean.mapbiomas_escola`) |
| **Referência** | **sem lastro.** Bloco em construção (#255); pesos em aberto |

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
5. **Tetos sem lastro.** Todos os tetos (`5 km`, `8/10 mil`, `50/5/5`, `500`,
   `1`) são **calibração empírica do dev** (p90/p99), não coeficientes da
   literatura. São **parâmetros de produto** — mudá-los exige registro e nova
   versão da fórmula.
6. **Bloco B é a exceção com lastro forte.** Z:10673 sustenta a **presença** e a
   **direção** do bloco socioeconômico; a composição fina (instrução × renda ×
   saneamento) continua decisão do projeto.

## 5. Fila de revisão

Indicadores que entram em produção **sem lastro** e devem ser revistos **antes**
de virarem número publicável (ordem de risco):

| # | item | o que falta | onde |
|---|---|---|---|
| 1 | **Bloco C** (mobilidade) | confirmar o proxy de exposição viária ou substituir pela isócrona | `ivet.md` §4.5.5 |
| 2 | **Tetos de todos os blocos** | confrontar com p90/p99 e com a literatura de cada tema | card `IVET_TETO_*` |
| 3 | **Bloco E** (segurança) | buscar referência para os tetos de taxa/100 mil | `ivet.md` §4.5.1 |
| 4 | **Bloco D** (saúde) | referência para os tetos de acesso/provisão | `ivet.md` §4.5.3 |
| 5 | **Bloco F** (meio ambiente) | definir componentes e pesos (exposição a risco) | `ivet.md` §4.5.4 |
| 6 | **Z:10454** | ler o trabalho (sensibilidade do IDEB por modelo matemático) e incorporar | §1 |

**Regra da fila:** um indicador novo (vindo de `docs/funcionalidades/analise/`)
entra nesta fila **no momento em que é especificado**, e só sai quando a ficha
(§2) tiver a referência — ou o registro explícito de que é decisão de produto.

## 6. Referências

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
