# Fontes — Socioeconômico e demográfico

> Lote B da issue #123 · lacunas do IVET nº 1 (saúde, parcialmente) e o
> **contexto municipal** que sustenta o eixo territorial.
> Método, pesos e regras: [`../fontes_de_dados.md`](../fontes_de_dados.md).

**Achado central do lote**: o **IBGE é a espinha dorsal**. Três produtos seus
(SIDRA/Agregados v3, malhas territoriais e Censo por setor censitário) somam
**52 pontos** e cobrem simultaneamente contexto socioeconômico municipal,
grade espacial e resolução **abaixo do município** — que é o salto de
granularidade que o IVET mais precisa. Ao mesmo tempo, o lote expõe **dois
impedimentos duros** que precisam ser registrados antes de qualquer decisão de
arquitetura:

1. **BCB usa ODbL share-alike** → não pode ser materializado no Postgres.
2. **não existe pacote R oficial do IBGE** (a premissa da lista da issue está
   errada) → todo wrapper é comunitário e pode quebrar.

---

### IBGE — API de Agregados (SIDRA) + API de Localidades

| Campo | Valor |
|---|---|
| **URL** | `https://servicodados.ibge.gov.br/api/v3/agregados` · `.../api/v1/localidades/municipios` · `https://apisidra.ibge.gov.br/values/…` |
| **Mantenedor** | IBGE |
| **Licença** | dados abertos / domínio público (sem SPDX explícita por endpoint) |
| **Formato** | API REST (JSON e XML); downloads em CSV, XLSX, ODS, HTML, TSV |
| **Granularidade** | **município (N6)**, estado (N3), Brasil (N1), distrito/subdistrito; alguns agregados por setor censitário |
| **Periodicidade** | anual, mensal, decenal — varia por tabela (exposto em `periodicidade.frequencia/inicio/fim`) |
| **API/SDK oficial** | **sim (HTTP)** — API oficial. ⚠️ **não existe pacote R oficial do IBGE** (ver Correções) |
| **Cobertura temporal** | varia por tabela — desde 1970/1980 em séries de preços; tabelas de censo têm início próprio |
| **Cobertura geográfica** | nacional (5.570 municípios, 27 UFs) |
| **LGPD** | risco **baixo** — só agregados, sem microdados, sem identificadores |

**Verificação (2026-09-30)**:
- `servicodados.ibge.gov.br/api/v3/agregados/7060/metadados` → **200**, `periodicidade:{frequencia:"mensal",inicio:202001,fim:202608}`, `nivelTerritorial:{Administrativo:["N1","N6","N7"]}` — **N6 = município confirmado**.
- `servicodados.ibge.gov.br/api/v1/localidades/municipios` → **200** (2.470.036 bytes, lista completa).
- ⚠️ **Host `apisidra.ibge.gov.br` está atrás de Cloudflare**: `curl` de servidor
  recebeu **403 "Just a moment…"** em `/aggregados` e na raiz; só o caminho
  `/values/` respondeu, com `User-Agent` de navegador. Já a v3 em
  `servicodados` respondeu **200 sem qualquer desafio**.

**Relevância para o EduMaps:** fecha o maior buraco estrutural do IVET —
contexto socioeconômico municipal padrazinado e oficial: saúde (SUS, atenção
básica, estabelecimentos por 10 mil), renda e desigualdade (PMC, PNAD Contínua,
IDHM), saneamento e domicílios, mercado de trabalho e tipologia urbano-rural.
Tudo na **chave IBGE de município**, que é a junção natural com `school_network`
e com o SIOPE. É o que permite materializar contexto municipal **sem sair de
geometria agregada**.

**Indicador derivado possível:**
- **IVS-M** (Índice de Vulnerabilidade Socioeconômica Municipal): z-score composto de renda per capita, IDHM, taxa de pobreza, formalidade do emprego, densidade demográfica, proporção de domicílios sem coleta de lixo/água/esgoto;
- densidade de oferta de saúde (SUS) por 10 mil habitantes;
- proporção de domicílios **sem água encanada / sem esgoto / sem lixo** na área de influência da escola;
- componente "contexto comunitário" do IVET, separando vulnerabilidade **escolar** de vulnerabilidade **do território**.

**Prioridade:** `[alta]` — 19 pontos

**Justificativa:** ⭐⭐⭐ + ⭐⭐ + ⭐⭐⭐ + ⭐⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐ + ⭐⭐⭐ = **19**.

**Rastro:** `apisidra.ibge.gov.br/home/ajuda` (parâmetros; **limite de 100.000
valores por consulta**) · `servicodados.ibge.gov.br/api/docs` (catálogo oficial:
Agregados 3.0, Localidades 1.0, Malhas 2.0/3.0/4.0) · endpoints 200 acima

**Riscos / cuidados:**
- **Fragilidade Cloudflare no `apisidra`** (verificada neste ambiente): usar a **v3
  em `servicodados` como caminho primário** e manter fallback.
- **Limite de 100.000 valores/consulta** — consultas "todos os municípios × todas
  as variáveis × todos os anos" estouram; particionar por período/classificação.
- **Tabela migra entre edições** (IPCA foi para a tabela 7060 em jan/2020):
  ancorar por `pesquisa`+`assunto` e gravar `tabela_id`/`periodicidade` na tabela
  de proveniência.
- **Notas metodológicas mudam com o tempo** (o IBGE já alterou PNAD Contínua ×
  Censo em alfabetização) — versionar junto com os dados.
- Nem toda tabela cobre todos os municípios: **ler `nivelTerritorial` antes** de
  assumir cobertura municipal.

---

### IBGE — Malhas territoriais

| Campo | Valor |
|---|---|
| **URL** | API: `https://servicodados.ibge.gov.br/api/v3/malhas/…` · download: `https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/` |
| **Mantenedor** | IBGE |
| **Licença** | dados abertos / domínio público (sem SPDX explícita) |
| **Formato** | API REST (GeoJSON, TopoJSON, SVG); download em Shapefile, **GeoPackage (.gpkg)**, GeoJSON, KML |
| **Granularidade** | país, região, UF, município, distrito, subdistrito, **setor censitário** |
| **Periodicidade** | anual (a cada revisão) |
| **API/SDK official** | **sim (HTTP)** — API oficial v3, sem autenticação |
| **Cobertura temporal** | desde 2000 (série `municipio_2000`); `municipio_2025` já publicado |
| **Cobertura geográfica** | nacional (território integral) |
| **LGPD** | sem risco — geometria pura, sem atributos de pessoas |

**Verificação (2026-09-30)**:
- `api/v3/malhas/estados/35?formato=application/vnd.geo+json` → **200**, 51.727 bytes, `FeatureCollection` válido.
- `api/v3/malhas/municipios/3550308?formato=application/vnd.geo+json` → **200**, 25.322 bytes, 1 feature com `codarea: "3550308"`.
- `geoftp.ibge.gov.br/.../malhas_municipais/` → **200**, diretórios `municipio_2000` … `municipio_2025`.

**Relevância para o EduMaps:** não é dado socioeconômico, é a **peça
habilitadora de quase todo o resto do lote**. É a grade espacial que permite
**arealizar** variáveis municipais (Censo por setor censitário, Ipeadata, saúde)
sobre a **área de influência real de cada escola**, em vez de repassar o valor
municipal uniforme a todas as escolas do município — que é a maior simplificação
atual do IVET. Complementa o OSM (que dá geometria de via, sem malha estatística
oficial).

**Indicador derivado possível:**
- **densidade demográfica por setor censitário** arealizada para o entorno da escola (população por km², não no município inteiro);
- grau de urbanização do entorno (`SITUACAO`/`CD_CONCURB` nos atributos);
- `AREA_KM2` como componente de isolamento / escola rural;
- base para índices **abaixo do município** — "o setor censitário da escola está
  em qual classe de vulnerabilidade?".

**Prioridade:** `[alta]` — 17 pontos

**Justificativa:** ⭐⭐⭐ + ⭐⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐ + ⭐⭐⭐ = **17** (endereça
a lacuna de forma indireta, como infraestrutura de arealização, por isso ⭐ em
vez de ⭐⭐⭐). **Prioridade alta também por custo baixo**: são downloads
pequenos (25 KB por município em GeoJSON). Sem malha atualizada, todo indicador
novo entra só no nível municipal e o IVET **não ganha resolução** — que é
exatamente o ganho buscado.

**Rastro:** endpoints 200 acima · `servicodados.ibge.gov.br/api/docs/malhas?versao=3`
(formatos e parâmetros `periodo`, `qualidade`, `intrarregiao`)

**Riscos / cuidados:**
- ⚠️ **A API v3 entrega malha *simplificada*** (documentada como ideal para web).
  Para arealização de precisão, usar o **download GPKG/SHP do Geoftp**.
- **Erro de documentação em fonte secundária**: o guia `open-geodata/br_ibge_api`
  cita `?resolucao=`, que **não existe** na v3. Seguir a doc oficial.
- **Divisão político-administrativa muda** (criação/emancipação de municípios;
  updates de mesorregião/microrregião até 21/12/2023): versionar a malha por
  `periodo` e manter **tabela de vigência de `cod_municipio`**, senão a junção
  com Censo e SIDRA quebra silenciosamente.
- `servicodados` apresentou **instabilidade intermitente** neste ambiente →
  retry com backoff no ETL.
- Preferir **GPKG** a Shapefile (limite de 2 GB do SHP e perda de tipo de campo);
  medir `AREA_KM2` do atributo em vez de recalcular.

---

### IBGE — Censo Demográfico 2022: agregados por setor censitário

| Campo | Valor |
|---|---|
| **URL** | `https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/` · panorama https://censo2022.ibge.gov.br/panorama/downloads.html |
| **Mantenedor** | IBGE |
| **Licença** | dados abertos / domínio público |
| **Formato** | CSV (.zip) e XLSX por agregado; malha com atributos em GPKG e SHP; dicionário em XLSX. ⚠️ **não há API REST** |
| **Granularidade** | **setor censitário** (unidade mínima), além de município, distrito, subdistrito e **bairro** |
| **Periodicidade** | **decenal** (próxima edição: 2032) |
| **API/SDK oficial** | não (apenas FTP/download); leitura em R trivial, sem SDK oficial |
| **Cobertura temporal** | 2022 (+ divulgações posteriores: 11/07/2025 e 17/04/2025) |
| **Cobertura geográfica** | nacional — **316.574 setores censitários**, 5.565 municípios (100% do território) |
| **LGPD** | restrição de difusão **já aplicada pelo IBGE** com supressão de células pequenas; só agregados. Risco residual baixo, mas a granularidade de setor exige desenho de proteção no produto final |

**Verificação (2026-09-30)**: `ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/`
→ **200**, com subdiretórios `Agregados_por_Setor_csv`, `_xlsx`,
`Agregados_por_Municipio_csv`, **`Agregados_por_Bairro_csv`**, `malha_com_atributos/`.
Arquivos presentes: `_alfabetizacao_BR`, `_basico_BR_20260520`,
`_caracteristicas_domicilio1/2/3_BR`, `_cor_ou_raca_BR`, `_demografia_BR`,
`_domicilios_indigenas_BR`, `_domicilios_quilombolas_BR`, `_obitos_BR`.
Malha com atributos: `BR_setores_CD2022.zip`, **748 MB**. Nota metodológica
06/2024 (IBGE): *"No arquivo agregado por setores, o IBGE optou pela restrição de
dados como forma de proteção dos dados dos informantes"*. Página institucional:
*"mais de 3.000 variáveis"*, periodicidade **decenal**.

**Relevância para o EduMaps:** é a **fonte mais próxima da lacuna "saúde,
contexto domiciliar e vulnerabilidade"**, e a única que permite resolução **abaixo
do município**. Traz população (sexo, idade, **cor ou raça**), alfabetização,
condições domiciliares (água, esgoto, lixo, moradia), domicílios indígenas e
quilombolas, óbitos informados e — via **Pesquisa Urbanística do Entorno** —
capacidade de circulação da via e características urbanísticas, que tocam as
lacunas de **segurança, mobilidade e conectividade**. Cruza naturalmente com o
OSM: o setor dá a área, o OSM dá as vias e serviços.

**Indicador derivado possível:**
- IVS por setor censitário (sanitário + domiciliar + demográfico), **arealizado** para a área de influência da escola;
- proporção de domicílios sem água/esgoto/lixo no entorno escolar;
- taxa de analfabetismo de adultos e população em idade escolar por setor;
- proporção de população negra/parda e de domicílios chefiados por mulheres — insumo direto de equidade;
- densidade demográfica por setor → pressão demográfica sobre a rede;
- densidade de favelas e comunidades urbanas (publicação de 11/07/2025).

**Prioridade:** `[alta]` — 16 pontos

**Justificativa:** ⭐⭐⭐ + ⭐⭐⭐ + ⭐⭐⭐ + ⭐⭐ + ⭐ + ⭐⭐⭐ = **16**. **Perde 1
ponto em periodicidade**: decenal não acompanha o ciclo de gestão escolar — mas
é a fotografia mais recente disponível e cobre exatamente as carências listadas.

**Rastro:** `ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/`
**200** · nota metodológica 06/2024 do IBGE · página institucional do Censo 2022

**Riscos / cuidados:**
- **Arquivos grandes**: malha com atributos com **748 MB** comprimidos. Planejar
  ingestão incremental e PostGIS de staging separado.
- ⚠️ **Supressão de células pequenas**: onde o IBGE suprime, o valor vem vazio.
  **Nunca tratar vazio como zero** — escola rural em setor de baixa população
  aparecerá "sem dado". Implementar limiar mínimo de habitantes e tratar
  "supresso" como estado **distinto** de zero.
- **Decenal**: envelhece rápido e vira snapshot. Use como **covariável estrutural**
  (urbanização, condições domiciliares), não como série de monitoramento. Para
  variação, cruzar com Censo 2010 e PNAD Contínua (SIDRA).
- **Risco de reidentificação ao cruzar em setor censitário**, mesmo sobre dados
  "agregados": agregar setores vizinhos (ZOT) ou aplicar k-anonimato antes de
  publicar/expor.
- **Não há API**: o ETL depende dos nomes de arquivo, que **mudam entre revisões**
  (ex.: `..._BR_20260520.zip`). Parser por **glob**, nunca por nome fixo.
- **Divergência Censo 2022 × PNAD Contínua em alfabetização** (Nota 03/2024) — não
  misturar as duas bases no mesmo indicador sem ajuste.

---

### IPEA — Ipeadata

| Campo | Valor |
|---|---|
| **URL** | `http://www.ipeadata.gov.br/api/odata4/` · portal http://www.ipeadata.gov.br/ |
| **Mantenedor** | IPEA — Instituto de Pesquisa Econômica Aplicada |
| **Licença** | *"Os dados disponibilizados no Ipeadata são de uso público. Sua reprodução e utilização em tabelas, gráficos, mapas, estudos e textos são permitidas, desde que o Ipeadata seja citado."* — permissiva na prática, **mas não é licença aberta formal (SPDX)** |
| **Formato** | API REST **OData v4** (JSON); XML via `$metadata`; Excel |
| **Granularidade** | **município**, microrregião, mesorregião, estado, país, região metropolitana, bacia hidrográfica |
| **Periodicidade** | anual, mensal e diária (varia por série) |
| **API/SDK oficial** | **sim** — API oficial + **`ipeadatar` (CRAN, mantido pelo próprio IPEA, MIT)** + `ipeadatapy` (Python) + Excel |
| **Cobertura temporal** | desde 1980/1990 (varia por série) |
| **Cobertura geográfica** | nacional, com base Regional de recorte municipal |
| **LGPD** | sem risco relevante — séries agregadas, sem dados pessoais |

**Verificação (2026-09-30)**:
- `$metadata` → **200**, EDMX OData v4 (entidades: Metadados, Paises, Temas, Territorios, Valores, ValoresStr).
- `Metadados` → **200**, 7.355.020 bytes, **3.606 séries**: Macroeconômico 2.099 / Social 1.103 / Regional 404.
- `Territorios` → **200**, **19.668 territórios**, incluindo **5.597 "Municípios"**.
- `ValoresSerie(SERCODIGO='PMC12_IVVNN12')` → **200**, 319 observações mensais (jan/2000 → jul/2026).
- `Metadados?$top=1&$format=json` → **HTTP 400** → confirma **ausência de paginação**.
- CRAN `ipeadatar` v0.2.1, **MIT**, mantenedor `@ipea.gov.br`, repo `github.com/ipea/ipeadatar` — **é oficial do IPEA**.

**Relevância para o EduMaps:** excelente camada macro e de bem-estar sobre
saúde, renda, desigualdade e desenvolvimento humano, sem coletar nada. Entre as
séries mais acessadas estão **IDHM, Gini, taxa de desemprego e taxa de pobreza** —
o núcleo de um índice de vulnerabilidade. Funciona como **terceira fonte de
validação cruzada**: quando SIDRA e Censo divergirem, o Ipeadata dá o terceiro
ponto. Traz séries já consolidadas e códigos claros (ex.: `PRECOS12_IPCA12`), o
que reduz muito a curadoria.

**Indicador derivado possível:**
- **IVS-M IPEA**: combinação de IDHM, Gini, pobreza e desemprego municipal, a cruzar com o do SIDRA para consistência;
- desigualdade de renda (Gini) municipal; razão IDHM por UF para localizar o município na distribuição estadual;
- bases Regionais por bacia hidrográfica e região administrativa.

**Prioridade:** `[média]` — 18 pontos, rebaixada

**Justificativa:** soma bruta 18, **rebaixada de `[alta]` para `[média]`** por
três fatores verificados: (a) licença é "uso público com citação", **sem SPDX** —
sinal de que o IPEA não oferece garantia forte de abertura; (b) a API é
**somente HTTP, sem HTTPS**; (c) **não aceita paginação** — toda consulta de
`Metadados` baixa 7,3 MB, o que torna ineficiente qualquer carga incremental.

**Rastro:** endpoints 200 acima · `ipeadata.gov.br/princ_i.aspx` (texto oficial
de uso) · CRAN `ipeadatar`

**Riscos / cuidados:**
- ⚠️ **Somente HTTP, sem TLS** — verificar integridade por checksum; considerar
  espelhar localmente.
- **Sem paginação** → cache local (SQLite/Parquet) no pipeline R.
- ⚠️ **Cobertura municipal não é uniforme entre séries**: existem 5.597
  municípios como territórios, mas a série de teste retornou `NIVNOME` vazio
  (agregado nacional). **Auditar série a série** (`Valores` filtrado por
  `TERCODIGO`) — esta é a lacuna que motivou o rebaixamento.
- Guardar a regra "citar Ipeadata" nos créditos do produto.
- **Codificação das séries não é documentada** — manter dicionário de metadados;
  `available_series()`/`search_series()` do `ipeadatar` é a forma correta.
- `ipeadatar` está em **ciclo experimental**: evitar acoplar o IVET a colunas
  específicas do pacote.

---

### Banco Central do Brasil — SGS / DASFN / SFN

| Campo | Valor |
|---|---|
| **URL** | CKAN: `https://dadosabertos.bcb.gov.br/` · SGS: `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados` · OData: `https://olinda.bcb.gov.br/olinda/servico/…` |
| **Mantenedor** | Banco Central do Brasil |
| **Licença** | ⚠️ **Open Data Commons Open Database License (ODbL)** — copyleft **share-alike** (predominante no portal) |
| **Formato** | API REST (JSON, CSV), OData, XML, HTML, PDF/ZIP |
| **Granularidade** | **nacional e estadual** na maior parte; alguns conjuntos (**SCR** — Sistema de Informações de Créditos) trazem agregados **por município** |
| **Periodicidade** | mensal (SGS), diária (cotações, Pix); **limite de volume em séries históricas diárias desde 26/03/2025** |
| **API/SDK oficial** | sim (HTTP) — SGS, OData e CKAN |
| **Cobertura temporal** | desde 1990/2000 (varia por código de série) |
| **Cobertura geográfica** | nacional / estadual |
| **LGPD** | sem risco relevante — séries agregadas do SFN |

**Verificação (2026-09-30)**: `api.bcb.gov.br/dados/serie/bcdata.sgs.4380/dados?formato=csv&dataInicial=01/01/2025&dataFinal=31/01/2025`
→ **200**, CSV `"data";"valor"`, datas em `DD/MM/YYYY`. Metadados do conjunto
`canaisatendimento` no portal → **"Licença: Open Data Commons Open Database
License (ODbL)"**; filtro `?license_id=odc-odbl` confirma ODbL como predominante.
Conjunto **SCR.data**: crédito agregado mensal **por município** em CSV.
`olinda.bcb.gov.br` responde (erro de entidade inexistente → serviço ativo).

**Relevância para o EduMaps:** atende à vertente **"investimentos"** de forma
indireta. O **SCR** é o mais interessante: volume e número de contratos de
crédito **por município**, como proxy de formalização econômica e capacidade
financeira local. O **DASFN**, embora real, é apenas um **catálogo de links**
para os dados abertos de cada instituição do SFN — não contém indicadores.

**Indicador derivado possível:**
- capacidade de investimento público municipal: FUNDEB por aluno, participação do município na dívida;
- formalização financeira municipal: **valor de crédito contratado por habitante (SCR)**;
- juros/inflação nacional como covariável de contexto.

**Prioridade:** `[baixa]` — 12 pontos, rebaixada por licença

**Justificativa:** soma bruta 12, mas incide **rebaixamento obrigatório por
licença restritiva**: a **ODbL é copyleft share-alike** — incorporar as séries a
uma base derivada (o Postgres do EduMaps) impõe abrir **aquela base** sob ODbL,
o que é **incompatível** com o modelo de produto. Some-se a granularidade
predominantemente estadual/nacional.

**Rastro:** `dadosabertos.bcb.gov.br` (metadados com licença ODbL) · API SGS 200

**Riscos / cuidados:**
- ⚠️ **ODbL share-alike** — risco jurídico principal. **Não materializar dados
  do BCB no Postgres do EduMaps.** Usar só como valor de referência em
  relatório, com citação.
- **Granularidade insuficiente**: só o SCR chega a município, e apenas para
  crédito — não substitui saúde, segurança ou conectividade.
- **DASFN é catálogo de links**, não dataset — use para descoberta e avalie a
  licença de cada instituição individualmente.
- **Limite de volume** desde 26/03/2025 em séries históricas diárias: não faça
  full scan.
- **Datas em `DD/MM/YYYY`** — a API retorna 400 em formato ISO.
- **Endpoints OData mudam** (verificado: `CotacaoDolarDia` não existe mais) —
  fixar conjunto e versão na tabela de proveniência.

---

### World Bank — API de Indicadores

| Campo | Valor |
|---|---|
| **URL** | `https://api.worldbank.org/v2/` · dados https://data.worldbank.org/country/brazil |
| **Mantenedor** | World Bank Group |
| **Licença** | **CC BY 4.0 + condições adicionais vinculantes**: atribuição obrigatória no formato *"[World Bank]: [Dataset name]: [Data source]"*, propagação de atribuição a sublicenças e **cláusula de arbitragem vinculante** |
| **Formato** | API REST (JSON/XML) v2; downloads em massa CSV/XLSX |
| **Granularidade** | ⚠️ **país/economia** — para o Brasil, uma única entidade (`BRA`). Bases subnacionais existem como bancos separados, **sem cobertura brasileira confirmada** |
| **Periodicidade** | anual |
| **API/SDK oficial** | sim (HTTP) — Indicators API v2 (v1 descontinuada); pacotes R comunitários (`WDI`, `wbdata`, `wbwdi`) |
| **Cobertura temporal** | desde 1960 para boa parte do WDI |
| **Cobertura geográfica** | **nacional** |
| **LGPD** | sem risco — agregados de país |

**Verificação (2026-09-30)**: `api.worldbank.org/v2/country/BRA/indicator/SP.POP.TOTL?format=json&per_page=5`
→ **200**, `lastupdated: "2026-07-13"`, `countryiso3code: "BRA"`, **66 registros —
uma entrada por ano, uma única entidade**. Páginas de termos confirmam CC BY 4.0
com condições adicionais e arbitragem.

**Relevância para o EduMaps:** **não endereça as lacunas do IVET**. Um indicador
nacional assume **o mesmo valor para todas as escolas do país** — logo, não
altera ranking, não correlaciona com variação local e não ajuda a priorização.
Todo o contexto socioeconômico municipal já está disponível em qualidade superior
no IBGE (SIDRA) e no IPEA, com granularidade e sem a complexidade de licença.

**Indicador derivado possível:** nenhum útil ao IVET. No máximo, painel de
contexto internacional para relatórios institucionais.

**Prioridade:** `[baixa]` — 11 pontos, rebaixada

**Justificativa:** soma bruta 11, mas aciona **rebaixamento obrigatório por
"ser só nacional sem desagregação"** — o critério é explícito e aqui é fatal: um
valor constante por país **não discrimina** nenhuma escola ou município.

**Rastro:** endpoint 200 acima · `worldbank.org/en/about/legal/terms-of-use-for-datasets` ·
`data.worldbank.org/summary-terms-of-use`

**Riscos / cuidados:**
- **Granularidade nacional** — o problema fatal.
- **Arbitragem vinculante** e obrigação de propagar atribuição em sublicenças —
  mais restritivo que uma CC BY 4.0 "pura"; revisar antes de redistribuir.
- **API v1 descontinuada** — usar apenas v2.
- Sem pacote R oficial; `wbwdi` declara não ser afiliado ao Banco Mundial.

---

### BrasilAPI

> 📌 **Reconciliação entre lotes**: esta fonte apareceu nos lotes **B** (aqui) e
> **H** ([`agregadores.md`](agregadores.md)) com prioridades diferentes. A
> divergência era de **finalidade**, não de fato. Registro consolidado:
> **para o pipeline do IVET, `[baixa]`** — o IBGE entrega oficialmente, sem
> limite de taxa e com estabilidade, tudo o que o BrasilAPI oferece de útil
> (principalmente a lista de municípios e o geocode por CEP). Ver a ficha completa
> em `agregadores.md` para o uso residual como lookup de `cod_ibge`.

| Campo | Valor |
|---|---|
| **URL** | https://brasilapi.com.br/ · docs https://brasilapi.com.br/docs |
| **Mantenedor** | comunidade open-source (projeto voluntário, ~11,1k estrelas; apoiado pela Vercel) |
| **Licença** | código **MIT**, mas os **Termos de Uso ainda estão "em elaboração"**; serviço em beta |
| **Formato** | API REST (JSON) |
| **Granularidade** | município e UF (via endpoints que reaproveitam o IBGE); CEP = logradouro |
| **Periodicidade** | irregular (espelha as fontes; sem calendário) |
| **API/SDK oficial** | HTTP apenas, sem SDK oficial |
| **Cobertura temporal** | n/a — catálogo de referência |
| **Cobertura geográfica** | nacional (delegada ao IBGE) |
| **LGPD** | sem risco direto, mas CEP/CNPJ são proxies de localização de pessoas |

**Verificação (2026-09-30)**: `api/ibge/uf/v1` → **200** (27 UFs). README oficial
declara: *"Estamos em beta e ainda elaborando os Termos de Uso, mas por enquanto
por favor não utilize formas automatizadas para fazer crawling ou full scan dos
dados da API"*.

**Relevância para o EduMaps:** **praticamente nenhuma** para as lacunas. O
catálogo é CEP, CNPJ, bancos, DDD, feriados, PIX, ISBN — nenhum indicador de
saúde, segurança, conectividade, investimento, mobilidade ou contexto
socioeconômico. O único conteúdo útil é a lista de municípios, que o **IBGE
entrega oficialmente e melhor**.

**Prioridade:** `[baixa]`

**Justificativa:** **redundante** para o problema. Usar o IBGE diretamente
elimina essa camada de risco com ganho zero de funcionalidade.

**Riscos / cuidados:**
- **Termos de uso indefinidos** — risco jurídico real; o próprio projeto declara
  que os termos estão sendo elaborados.
- **Proibição de crawling/scan completo** — inviabiliza ETL em lote.
- Sem SLA, hospedado em Vercel, risco de mudança de contrato.
- **Recomendação: dispensar do pipeline do IVET.**

---

## ⚠️ Correções à lista de candidatos da issue #123

| Item listado | Verificação | Correção |
|---|---|---|
| **"pacote IBGE oficial"** | ❌ **não existe** — `sidra`, `sidrar`, `SidraFacil`, `ibger` são todos comunitários; o README do `ibger` declara explicitamente não ser afiliado nem endossado pelo IBGE | Não prometer SDK oficial; considerar camada fina própria sobre `httr`/`jsonlite` na v3 |
| **SIDRA (`apisidra`) como endpoint primário** | ⚠️ **bloqueado por Cloudflare** para servidor (`curl` → 403 "Just a moment") | Usar **v3 em `servicodados.ibge.gov.br`** como caminho primário, com fallback |
| **"IBGE — malhas"** | ✅ existe e é API oficial v3 | Atenção: a v3 entrega malha **simplificada**; arealizar com o GPKG do Geoftp |
| **BrasilAPI como fonte socioeconômica** | ❌ não tem variável socioeconômica alguma | Dispensar; usar IBGE |

---

## Síntese do lote

| Fonte | Prioridade | Pontos | Motivo |
|---|---|---|---|
| **IBGE SIDRA / Agregados v3 + Localidades** | 🟢 `[alta]` | 19 | Contexto socioeconômico municipal oficial; chave IBGE = junção natural com a rede escolar. |
| **IBGE Malhas territoriais** | 🟢 `[alta]` | 17 | Habilitadora do arealização — sem ela o IVET não ganha resolução. |
| **IBGE Censo 2022 por setor censitário** | 🟢 `[alta]` | 16 | **Resolução abaixo do município** (316.574 setores) + 3.000 variáveis. |
| **IPEA Ipeadata** | 🟡 `[média]` | 18 | Terceira fonte de validação cruzada; API oficial do próprio órgão — mas HTTP sem TLS, sem paginação, licença sem SPDX. |
| **Banco Central (SGS/SCR)** | 🔴 `[baixa]` | 12 | **ODbL share-alike**: não pode entrar no Postgres. |
| **World Bank API** | 🔴 `[baixa]` | 11 | Só nacional — não discrimina escola nem município. |
| **BrasilAPI** | 🔴 `[baixa]` | — | Redundante com o IBGE; ToS indefinidos. |

**Conclusão do lote**: os **três produtos do IBGE** concentram 52 pontos e
formam a base de todo o resto do catálogo. A recomendação de implementação é
**IBGE primeiro, em um único effort**: malhas + agregados v3 + Censo por setor,
com `ipeadatar` como validação cruzada. O **BCB e o World Bank saem do escopo do
pipeline** (licença e granularidade, respectivamente).
