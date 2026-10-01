# Fontes — Mobilidade

> Lote B da issue #123 · lacuna do IVET nº 5 (**mobilidade em escala**),
> com cruzamento com a nº 2 (**segurança**, medida por sinistros em trecho
> viário) e a nº 1 (**saúde**, por ambiente de deslocamento).
> Método, pesos e regras: [`../fontes_de_dados.md`](../fontes_de_dados.md).

**Achado central do lote**: existe **uma única matriz origem-destino nacional
verificada** — os bilhetes de passagem do **MONITRIIP/ANTT**, agregados em chave
município-município, com série mensal até agosto de 2026. É ela que fecha a lacuna
5 em escala nacional.

**Achado mais importante do lote**: o **custo de deslocamento escolar tem
granularidade de escola em apenas um município brasileiro verificado** — o Recife
publica, de forma agregada, o número de vagas de transporte escolar gratuito por
unidade educacional e por turno. Nenhuma fonte nacional chega perto. Isso é a
evidência de que o gargalo da lacuna 5 **não é a técnica de coleta, é a
publicação**: o dado existe nos DETRANs e nas secretarias de educação, e quase
nunca é publicado.

**Correção de premissa**: o "grande agregador" citado no enunciado — *Sistema de
Informações sobre Demandas de Transporte* — **não existe com esse nome**. A
entidade mais próxima é a **SIMU/SIMOB da ANTP**, questionário de 2014 sobre
frota, tarifa e semáforo, que **não é publicado como base consultável**. O
agregador que de fato cumpre a função (o GTFS) **não é alcançável** — ver ficha.

**Correção de premissa (segunda)**: a issue supõe que o DNIT publica malha
rodoviária aberta. **Não publica de forma utilizável**: o PNCT só existe em um
visualizador sem API, com página de download em **404** e rodapé "Todos os
Direitos Reservados". O caminho aberto real é a **camada de modelagem de VMDA
sobre o SNV, espelhada no INDE em domínio público** — descoberta via metadados
do INDE, não por documentação do DNIT.

---

### ANTT — MONITRIIP, bilhetes de passagem (matriz OD municipal nacional)

| Campo | Valor |
|---|---|
| **URL** | https://dados.antt.gov.br/dataset/monitriip-bilhetes-de-passagem · portal CKAN https://dados.antt.gov.br |
| **Mantenedor** | Agência Nacional de Transportes Terrestres (ANTT), Ministério dos Transportes |
| **Licença** | **CC BY 4.0**, declarada no catálogo CKAN da ANTT |
| **Formato** | CSV mensal, delimitador `;`, codificação **ISO-8859-1** (não é UTF-8). Colunas verificadas em payload: `mes_emissao_bilhete`; `mes_viagem`; `ponto_origem_viagem`; `ponto_destino_viagem`; `tipo_servico`; `tipo_gratuidade`; `media_valor_total`; `dp_valor_total`; `quantidade_bilhetes` |
| **Granularidade** | **par de municípios** (origem × destino), com desagregação por ponto de embarque e tipo de serviço |
| **Periodicidade** | **mensal**, com atraso de poucos meses |
| **API/SDK oficial** | **não há API de dados**. Existe a API CKAN de metadados (`/api/3/action/package_show`), sem autenticação, que entrega as URLs dos recursos |
| **Cobertura temporal** | mensal, **janeiro de 2019 a agosto de 2026** (94 arquivos publicados) |
| **Cobertura geográfica** | **nacional** — Modalidade rodoviária intermunicipal, statewide e interestadual |
| **LGPD** | ⚠️ **médio, mitigável**. Não há identificador de passageiro no cabeçalho verificado, mas `tipo_gratuidade` é **categoria sensível** (acompanhante de pessoa com deficiência — Lei 8.899/94 —, jovem de baixa renda, estudante, idoso) e cruza com `media_valor_total`. As células são pequenas (1 a 3 bilhetes) |

**Verificação (2026-09-30)**

| URL | Status |
|---|---|
| `https://dados.antt.gov.br` | **200** — CKAN, 106 conjuntos, todos em CC BY |
| `.../dataset/monitriip-bilhetes-de-passagem` | **200** — 94 recursos CSV mensais |
| `venda_passagem_08_2026.csv` | **200** — cabeçalho conferido campo a campo |

**Relevância para o EduMaps:** é a **única forma de medir deslocamento em escala
nacional** com granularidade municipal e periodicidade compatível com o ciclo de
gestão escolar. Permite medir **dependência territorial**: em que medida os alunos
de um município dependem de oferta de ônibus fora do município, e qual o custo
médio do deslocamento.

**Indicador derivado possível:**
- `iv_mobilidade_od_externo` — proporção de viagens com origem ou destino fora do
  município de origem, por município e mês.
- `iv_mobilidade_custo_deslocamento` — `media_valor_total` ponderada por
  `quantidade_bilhetes`.
- `iv_mobilidade_dependencia_transporte` — soma de `quantidade_bilhetes`
  normalizada pela população em idade escolar (IBGE/SIDRA).

**Prioridade:** `[alta]` — **16 pontos**

**Justificativa:** ⭐⭐⭐ lacuna 5 direta (3) · ⭐⭐⭐ granularidade municipal (3) ·
⭐⭐⭐ licença CC BY (3) · ⭐⭐ cobertura nacional (2) · ⭐⭐ periodicidade mensal (2)
· ⭐⭐⭐ complementa Censo/OSM/SIOPE (3) = **16**. **API (0)** e **pacote R (0)**:
não existe API de dados, apenas CSV com nomenclatura estável. **O rebaixamento
por risco LGPD não se aplica**, porque a mitigação é determinística e está
desenhada adiante.

**Rastro:** `https://dados.antt.gov.br/dataset/monitriip-bilhetes-de-passagem`
**200** · `https://dados.antt.gov.br` **200** · leitura: `readr::read_delim()`
com `delim = ";"` e `locale(encoding = "ISO-8859-1")` — **obrigatório**

**Riscos / cuidados:**
- 🔴 **Células pequenas são o risco real.** Supressão obrigatória para qualquer
  célula com `quantidade_bilhetes < 10` **antes** de qualquer agregação espacial
  ou cruzamento com o Censo Escolar.
- 🔴 **`tipo_gratuidade` fora da camada analítica.** A variável é legítima para
  fins de política pública, mas é indutora de reidentificação quando cruzada com
  município de origem e data. Se for mantida para visualização, só em
  percentuais municipais com supressão.
- 🔴 **`media_valor_total` e `dp_valor_total` fora da granularidade de par
  origem-destino**, ou publicadas apenas como intervalos de classe. Tarifa é
  indiretamente traçadora de perfil socioeconômico quando cruzada com gratuidade.
- ⚠️ **Pontos de embarque não têm georreferência pública verificada.** Ligar o
  ponto à escola depende de casar o nome do ponto ao cadastro municipal — é o
  gargalo de engenharia real desta fonte.
- ⚠️ A série é de **ônibus rodoviário intermunicipal**. **Não** cobre o
  transporte urbano municipal (ônibus, metrô, trem), que é o deslocamento escolar
  da maioria dos alunos. Não tratar como proxy da lacuna 5 inteira.
- ⚠️ Sem API: carga mensal em lote, com idempotência por `mes_viagem` + par de
  municípios. Sem varredura incremental nativa.

---

### ANTT — equipamentos (SAT/SATS), acidentes por trecho e geodados de concessão

| Campo | Valor |
|---|---|
| **URL** | https://dados.antt.gov.br/dataset/sat · https://dados.antt.gov.br/dataset/volume-sat · https://dados.antt.gov.br/dataset/acidentes-quilometro-rodovias |
| **Mantenedor** | ANTT (medição fornecida pelas concessionárias) |
| **Licença** | **CC BY 4.0** (política do portal CKAN da ANTT) |
| **Formato** | SAT: CSV, JSON e **KMZ** por equipamento. Volume SAT: CSV e JSON (102 recursos). Acidentes: CSV por concessionária. Geodados: shapefiles de Traçado, Pista Principal, Travessia de Pedestres, Acessos, Praça de Pedágio, Radar e Município |
| **Granularidade** | **trecho viário** (BR-101, km), com coordenada nos geodados e ponto de equipamento nos KMZ. Compatível com escola **por buffer**, não é chave escolar |
| **Periodicidade** | **diária** na origem, publicada como consolidado mensal e anual |
| **API/SDK oficial** | **não há API de dados**. A API CKAN de metadados funciona sem autenticação. Há painel Power BI, o que **não** é API: sem contrato estável |
| **Cobertura geográfica** | **nacional**, apenas trechos **federais concedidos** |
| **LGPD** | ✅ **risco baixo** — contagens agregadas de veículos por faixa horária; a camada de **travessia de pedestres** é geometria de infraestrutura, sem fluxo pessoal |

**Verificação (2026-09-30)**: portal **200** · `sat` **200** (15 recursos
CSV/JSON/KMZ + Power BI) · `volume-sat` **200** (102 recursos) ·
`acidentes-quilometro-rodovias` **200** (41 recursos; cabeçalho
`Concessionaria;Data;Km;Trecho` conferido)

**Relevância para o EduMaps:** entrega a **exposição ao risco de via** — ruído e
velocidade — e a **carga de tráfego** sobre vias com uso escolar. É o que
permite distinguir "escola em rua tranquila" de "escola em arterial com 60 mil
veículos/dia".

**Indicador derivado possível:**
- `iv_mobilidade_exposicao_trafego` — VMDA do trecho a até 300 m da escola,
  ponderado pelo número de matrículas.
- `iv_mobilidade_risco_rodoviario_escolar` — acidentes por km-ano no trecho,
  normalizado por VMDA.
- `iv_mobilidade_carga_pedestre` — densidade de faixas de travessia no entorno
  imediato da escola.

**Prioridade:** `[alta]` — **16 pontos** (o conjunto de acidentes, isolado, cai
para `[baixa]`)

**Justificativa:** ⭐⭐⭐ lacunas 5 e 2 (3) · ⭐⭐⭐ granularidade de trecho,
compatível com escola por buffer (3) · ⭐⭐⭐ licença CC BY (3) · ⭐⭐ cobertura
nacional (2) · ⭐⭐ periodicidade diária consolidada (2) · ⭐⭐⭐ complementa
Censo/OSM/SIOPE (3) = **16**. **API (0)** e **pacote R (0)**.

**Rastro:** `dados.antt.gov.br/dataset/sat` **200** · `/volume-sat` **200** ·
`/acidentes-quilometro-rodovias` **200**

**Riscos / cuidados:**
- 🔴 **`acidentes-quilometro-rodovias` isolado é `[baixa]`.** A chave verificada é
  `Concessionaria;Data;Km;Trecho` — **UF e km, sem município**. Sozinho, atende
  ao rebaixamento "granularidade apenas estadual sem desagregação municipal". Só
  sobe quando combinada à camada municipal/geodados da própria ANTT para resolver o
  trecho em município.
- ⚠️ **Somente rodovias federais concedidas.** Escolas em rodovia estadual ou
  municipal ficam sem cobertura — que é a maioria das escolas de zona rural. Não
  extrapolar.
- ⚠️ **Painel Power BI não é API.** Não construir pipeline contra ele.
- ⚠️ **KMZ exige GDAL/ogr** — o R não tem leitor KMZ nativo. Pré-converter para
  GeoPackage em etapa de preparo.
- ⚠️ **SAT (contagem) e acidentes (sinistro) são bases independentes**, com
  epistemologias de medição diferentes. Não cruzar como se fossem a mesma
  métrica.

---

### DNIT — Sistema Nacional de Viação (SNV) e modelagem de VMDA por trecho

| Campo | Valor |
|---|---|
| **URL** | PNCT https://www.gov.br/dnit/pt-br/assuntos/planejamento-e-pesquisa/pnct · visualizador https://servicos.dnit.gov.br/vgeo · camada VMDA/SNV (espelho INDE, ES) https://ide.geobases.es.gov.br/layers/geonode:dnit_vmda_modelagem_2022_es_utf8_epsg_31984 |
| **Mantenedor** | DNIT (produto); INDE/GeoNode (espelho de metadados e dados, operados pelo governo do Espírito Santo) |
| **Licença** | ⚠️ **não uniforme**. Portal do DNIT: CC BY-ND 3.0 no rodapé (**texto do site**). Página do PNCT: "Todos os Direitos Reservados". A camada VMDA espelhada no INDE declara **Public Domain**. **Para uso no EduMaps, a licença a considerar é a da camada do INDE: domínio público** |
| **Formato** | Vetorial (shapefile, GML 2.0/3.1.1, CSV, Excel, GeoJSON), WMS GetCapabilities, EPSG:31984 |
| **Granularidade** | **trecho de rodovia** com código SNV. Atributos verificados: `Codigo_Rod`, `Codigo_SNV`, `id_pnct`, `Unidade_Fe`, `Regiao`, `Extensao`, `Tipo_Link`, `Relevo_Pre`, `Velocidade`, `Classifica`, `VMDa_Total`, `Legenda` |
| **Periodicidade** | **anual**, com defasagem de 1–2 anos (o espelho verificado cobre 2022). O Ministério dos Transportes declara que a base georreferenciada é atualizada **a cada 3 meses** desde 2013, mas a **modelagem de VMDA é anual** |
| **API/SDK oficial** | **WMS GetCapabilities** é a via oficial utilizável, sem autenticação. O VGeo é **aplicação de página única sem API documentada e sem endpoint de download** |
| **Cobertura geográfica** | **nacional** na origem (rodovias federais), mas o espelho verificado é um **recorte estadual** (Espírito Santo) |
| **LGPD** | ✅ **risco nulo** — agregados de infraestrutura e fluxo veicular |

**Verificação (2026-09-30)**

| URL | Status |
|---|---|
| página do PNCT | **200** — 358 equipamentos, 2,66 milhões de veículos/dia, série desde 1975; rodapé "Todos os Direitos Reservados"; `/dadospnct/downloads` → **404** |
| `servicos.dnit.gov.br/vgeo` | **200** — "VGeo - Visualizador de Dados do DNITGeo", página única, **sem API** |
| página do SNV no DNIT | **200**, porém o corpo devolve **"Conteúdo Restrito — é necessário autenticar para visualizar esta página"** |
| BIT / mapas do Ministério dos Transportes | **200** — declara base georreferenciada do DNIT disponível desde 2013, atualizada a cada 3 meses |
| camada VMDA/SNV no GeoNode ES | **200** — Public Domain; downloads Shapefile/GML/CSV/Excel/GeoJSON; metadados de qualidade citam modelagem com **matriz OD da Pesquisa Nacional de Tráfego (PNT) 2016/2017** e a rede do SNV |
| `metadados.inde.gov.br/geonetwork/srv/api/search/records/_search` | **404** — a API de busca do GeoNetwork não está nesse caminho |

**Relevância para o EduMaps:** é a **malha rodoviária federal com volume de
tráfego**, ou seja, o componente de infraestrutura do bloco de mobilidade. Como
a rede viária federal é exatamente a malha que o OSM cobre de forma parcial e
irregular, esta camada é o complemento oficial que faltava.

**Indicador derivado possível:**
- `iv_mobilidade_vmdA_escolar` — VMDA do trecho dentro do raio de influência da
  escola.
- `iv_mobilidade_vulnerabilidade_via` — VMDA alto + `Velocidade` regulamentada
  alta + `Relevo_Pre` íngreme na via de acesso.
- `iv_mobilidade_acesso_rodoviario` — presença de via federal de alta capacidade
  a menos de 2 km (indicador de isolamento territorial por rodovia).

**Prioridade:** `[alta]` — **16 pontos** (o PNCT isolado cai para `[baixa]`)

**Justificativa:** ⭐⭐⭐ lacuna 5 (3) · ⭐⭐⭐ granularidade de trecho compatível
com escola (3) · ⭐⭐⭐ licença de domínio público na camada INDE (3) · ⭐⭐
cobertura nacional na origem (2) · ⭐⭐ periodicidade anual (2) · ⭐⭐⭐
complementa Censo/OSM/SIOPE (3) = **16**. **API oficial estável (0)** — o VGeo
é visualizador, não API; pontua-se pelo WMS, que é padrão OGC e não produto do
DNIT. **Pacote R (0)**.

**Rastro:** página do PNCT **200** · `servicos.dnit.gov.br/vgeo` **200** ·
`ide.geobases.es.gov.br/layers/geonode:dnit_vmda_modelagem_2022_es_utf8_epsg_31984`
**200**

**Riscos / cuidados:**
- 🔴 **A página do SNV no DNIT pede autenticação.** Não há caminho público
  navegável a partir dela; o acesso real é pelo VGeo ou pelo espelho INDE.
- 🔴 **O PNCT, isolado, é `[baixa]`.** Não há endpoint de download estável
  (`/dadospnct/downloads` → 404), a página declara "Todos os Direitos Reservados"
  e não publica licença. Servir o PNCT diretamente exigiria reconstrução via
  VGeo — isto é, **scraping frágil**, o gatilho de rebaixamento do método.
- ⚠️ **A camada VMDA é modelagem, não medição.** O próprio metadado declara que
  o VMDa foi **estimado** a partir do PNCT, de pedágios e de uma matriz OD da PNT
  2016/2017, com modelos de alocação de tráfego. É boa variável **comparativa**
  entre trechos, **não** substitui contagem real.
- ⚠️ O espelho verificado é estadual (ES). Para cobertura nacional é necessário
  localizar as contrapartes estaduais no INDE — **não verificado** nesta rodada.
- ⚠️ A restrição declarada no catálogo do INDE ("o governo concedeu o direito
  exclusivo de fazer, vender, usar ou licenciar uma invenção ou descoberta") é
  texto padrão do GeoNetwork que **contradiz** a licença Public Domain da própria
  camada. Registrar a contradição no ADR do IVET.
- ⚠️ A **Pesquisa Nacional de Tráfego (PNT) 2016/2017** aparece na metodologia
  da modelagem, mas sua matriz OD **não foi localizada em formato aberto**. Não
  contar com ela.

---

### Ministério dos Transportes — séries RENAVAM, RENAEST, RENACH e RENAINF

| Campo | Valor |
|---|---|
| **URL** | https://dados.transportes.gov.br |
| **Mantenedor** | Ministério dos Transportes (CKAN próprio, 56 conjuntos) |
| **Licença** | **Other (Public Domain)** — declarado no catálogo |
| **Formato** | ZIPs mensais, um por mês. **RENAVAM**: `i_frota_por_uf_municipio_marca_e_modelo_ano_<mm>_<yyyy>.zip`. **RENAEST**: planilha "Sinistros — Localidade — TipoVeiculo — Vitimas" |
| **Granularidade** | **municipal** no RENAVAM (por UF, município, marca, modelo e ano de veículo). No RENAEST, por **localidade** — não por município consolidado |
| **Periodicidade** | **mensal**, defasagem de poucos meses |
| **API/SDK oficial** | **não há API de dados**. A API CKAN de metadados funciona sem autenticação |
| **Cobertura temporal** | **RENAVAM**: 156 arquivos, **maio de 2013 a julho de 2026** · **RENAEST**: 55 arquivos, **outubro de 2021 a abril de 2026** · **RENACH**: mar/2020 a **ago/2024 (interrompida)** · **RENAINF**: mar/2020 a **abr/2025 (interrompida)** |
| **Cobertura geográfica** | **nacional** |
| **LGPD** | ✅ **risco baixo** — todas as séries são agregadas por município/UF, marca e modelo. Nenhum identificador de proprietário ou de veículo individual |

**Verificação (2026-09-30)**: `dados.transportes.gov.br` **200** (CKAN, 56
conjuntos, "Other (Public Domain)") · conjunto RENAVAM **200** (156 ZIPs
mensais, padrão de nome confirmado) · RENAEST **200** (55 ZIPs) · RENACH/RENAINF
**200** (séries interrompidas) · `Mapa Digital da Malha Rodoviária Nacional`
**200** — recursos apontam para o DNIT, **não** para shapefile próprio do
Ministério

**Relevância para o EduMaps:** a **frota de veículos por município** é o
denominador natural de um indicador de dependência automobilística, e o
**RENAEST** dá o padrão de sinistralidade com tipologia de vítima — incluindo
**ciclistas e pedestres**, que se sobrepõem ao trajeto escolar.

**Indicador derivado possível:**
- `iv_mobilidade_frota_por_aluno` — frota por mil habitantes de 6 a 17 anos
  (SIDRA): proxy de dependência do carro na última milha.
- `iv_mobilidade_sinistralidade_ciclista` — sinistros com vítima ciclista por
  100 mil habitantes, por município.
- `iv_mobilidade_exposicao_pedestre` — sinistros com vítima pedestre, cruzando
  com a densidade de rotas a pé no entorno escolar vinda do OSM.

**Prioridade:** `[alta]` — **16 pontos**

**Justificativa:** ⭐⭐⭐ lacunas 5 e 2 (3) · ⭐⭐⭐ granularidade municipal (3) ·
⭐⭐⭐ licença de domínio público (3) · ⭐⭐ cobertura nacional (2) · ⭐⭐
periodicidade mensal (2) · ⭐⭐⭐ complementa Censo/OSM/SIOPE (3) = **16**.
**API (0)** e **pacote R (0)**.

**Rastro:** `dados.transportes.gov.br` **200** · `dados.antt.gov.br` **200** — a
ANTP publica parte da mesma família de cadastros em CC BY, o que dá **duplo
caminho de verificação** para RENAVAM e RENAEST

**Riscos / cuidados:**
- ⚠️ **RENACH interrompida desde ago/2024** e **RENAINF desde abr/2025**. Não
  usar como indicador corrente sem declarar o corte.
- ⚠️ **RENAEST agrega por localidade**, cuja cobertura não é idêntica à divisão
  municipal do IBGE. Antes de cruzar com o Censo Escolar é obrigatório um
  **de-para localidade → município** — e esse de-para não é publicado pela fonte.
- ⚠️ **Não confundir as siglas**: **RENA** = Registro Nacional de Estradas,
  **RENAVAM** = veículos, **RENACH** = habilitação de condutores, **RENAINF** =
  infrações. A issue #123 lista "RENAC" e "RENA" como se fossem a mesma coisa.
- ⚠️ A granularidade municipal do RENAVAM é por **frota**, não por deslocamento.
  Serve como denominador e contexto, não como medida de fluxo.

---

### Prefeitura do Recife — CKAN municipal: transporte escolar, OD, fluxo e velocidade

| Campo | Valor |
|---|---|
| **URL** | https://dados.recife.pe.gov.br · https://dados.recife.pe.gov.br/dataset/transporte-escolar-gratuito · https://dados.recife.pe.gov.br/dataset/pesquisa-origem-destino |
| **Mantenedor** | Emprel (Empresa de Tecnologia da Informação do Recife); autores por órgão — Secretaria de Educação, Secretaria de Política Urbana e Licenciamento, CTTU |
| **Licença** | ❌ **ODbL** (Open Data Commons Open Database License) — declarada em todos os conjuntos verificados. **É copyleft share-alike**: leitura permitida; materialização sob share-alike = decisão do jurídico. **Ação: e-SIC protocolado a secretarias municipais de educação (protocolo(s) ______) — aguardando resposta.** |
| **Formato** | CSV e JSON. Recursos com `datastore_active: true` ficam **consultáveis por SQL** via API CKAN. Há PDF de dicionário de dados |
| **Granularidade** | **escolar** no transporte escolar (uma linha por unidade de ensino) · **par origem-destino** na pesquisa OD · **trecho viário** nas camadas de fluxo e velocidade |
| **Periodicidade** | **mista**: transporte escolar **anual** (2023); velocidade de via **anual por ano** (2016–2026); pesquisa OD **encerrada** (2016) |
| **API/SDK oficial** | ✅ **sim, documentada e sem autenticação** — CKAN Action API (`package_search`, `package_show`) e **CKAN DataStore** (`datastore_search`), com SQL. **Melhor API do lote** |
| **Cobertura geográfica** | **municipal (Recife/PE)**. Sem cobertura nacional |
| **LGPD** | ⚠️ **variável por recurso**. Transporte escolar: ✅ **risco baixo** (agregado por escola e turno). Pesquisa OD: 🔴 **risco alto** — o metadado declara explicitamente **"dados brutos"**, que em OD significa registro de viagem individual |

**Verificação (2026-09-30)**

| URL | Status |
|---|---|
| `.../api/3/action/package_search?q=transporte` | **200** — **38 conjuntos**; grupo temático "Mobilidade" |
| `package_show?id=transporte-escolar-gratuito` | **200** — ODbL, CSV "Transporte Escolar - 2023" (6.702 bytes), `datastore_active: true`, frequência **Anual** |
| `datastore_search` do recurso | **200** — colunas `escolas`, `manha`, `tarde`, `noite`; **127 registros** agregados |
| `package_show?id=pesquisa-origem-destino` | **200** — ODbL, CSV de 20.191.835 bytes, `datastore_active: true`, + dicionário PDF; notas citam "dados brutos" |
| `package_show?id=amostra-de-fluxo-de-veiculos-a-cada-15-minutos` | **200** — ODbL, CTTU, CSV de 2.167.602 bytes; 15 min, 8h–14h, 8 a 14/06/2015 |

**Relevância para o EduMaps:** é **o único conjunto verificado do lote com
granularidade escolar de deslocamento**, e a **única fonte do lote cuja API de
dados é REST, documentada, sem autenticação, com SQL**. Serve como **prova de
viabilidade** do indicador `iv_mobilidade_transporte_escolar` e como **modelo de
replicação**: os 38 conjuntos do Recife mostram que um CKAN municipal bem mantido
entrega mais sinal de mobilidade do que todo o bloco federal do MONITRIIP.

**Indicador derivado possível:**
- `iv_mobilidade_transporte_escolar` — vagas de transporte escolar gratuito por
  100 matrículas, por unidade, por turno (nível **escolar**, único do lote).
- `iv_mobilidade_velocidade_via_escolar` — velocidade média medida por trecho no
  entorno da escola, em série anual 2016–2026.
- `iv_mobilidade_ciclabilidade_acesso` — densidade de ciclovia ligando a escola à
  malha de transporte público.

**Prioridade:** `[média]` — **16 pontos, rebaixada por licença**

**Justificativa:** ⭐⭐⭐ lacuna 5 (3) · ⭐⭐ **API CKAN DataStore verificada em
payload** (2) · ⭐⭐⭐ granularidade escolar (3) · ⭐⭐⭐ licença (3) · ⭐⭐
periodicidade anual (2) · ⭐⭐⭐ complementa Censo/OSM/SIOPE (3) = **16**.
**Cobertura nacional (0)** — é um município.

**Rebaixe aplicado:** **licença ODbL share-alike** — leva a `[média]`
independentemente da soma. Esta é a **mesma razão pela qual o Banco Central foi
descartado** no lote socioeconômico: materializar um conjunto ODbL no Postgres do
EduMaps cria obrigação de share-alike sobre a base derivada, o que é
incompatível com a intenção de uso público sem copyleft do projeto. A
inconsistência seria Trapacear no método: aceitar ODbL aqui porque a fonte é
interessante,Having rejeitado lá porque é chata. **A ficha vale como prova de
viabilidade do indicador, não como fonte a ingerir** — e a leitura de dados é
permitida (o share-alike incide sobre a obra derivada publicada, não sobre a
leitura).

**Rastro:** `.../package_search?q=transporte&rows=40` **200** ·
`.../package_show?id=transporte-escolar-gratuito` **200** ·
`.../datastore_search?resource_id=0714bb43-…&limit=5` **200**

**Riscos / cuidados:**
- 🔴 **A pesquisa OD do Recife é "dado bruto" e não deve ser ingerida como
  está.** É o mesmo risco da bilhetagem, em forma pior. Se for usada, agregar a
  **no mínimo zona OD** antes do armazenamento, descartar identificadores de
  respondente, e documentar a base legal — interesse público em planejamento
  urbano **não** autoriza uso secundário de microdado de deslocamento.
- ⚠️ **Nenhuma cobertura nacional.** O indicador escolar é demonstrado em **um**
  município. A estratégia é **varredura de CKANs municipais** por
  `transporte escolar`, não integração de um portal federal. Não há catálogo
  nacional de CKANs municipais verificado.
- ⚠️ A série de velocidade é **um dataset por ano** (2016 a 2026), o que exige
  rotina de coleta incremental por nome de recurso — frágil se o padrão mudar.
- ⚠️ Sem pacote R específico para CKAN DataStore verificado. O cliente é
  `httr2`/`jsonlite` puro: viável, sem atalho.

---

### Prefeitura de São Paulo — SMUL (zonas OD), CET (lombadas) e SMT (transporte escolar)

| Campo | Valor |
|---|---|
| **URL** | Zonas OD https://dados.prefeitura.sp.gov.br/dataset/zona-de-origem-e-destino-1997-e-2007-no-municipio-de-sao-paulo · portal https://dados.prefeitura.sp.gov.br (484 conjuntos) |
| **Mantenedor** | Secretaria de Mobilidade Urbana (SMUL); CET e SMT como autores separados |
| **Licença** | **CCZero** nos conjuntos verificados de SMUL, CET e SMT (a licença **varia por autor** — verificar conjunto a conjunto) |
| **Formato** | XLS, CSV e **shapefile** para as zonas OD |
| **Granularidade** | **zona de origem-destino** — unidade geográfica equivalente a bairro, **com coordenada**. Lombadas: ponto viário |
| **Periodicidade** | **irregular**. A Pesquisa OD do Metrô foi realizada em **1997, 2007 e 2025** — sem série |
| **API/SDK oficial** | API CKAN de metadados, sem autenticação. **Sem API de dados** |
| **Cobertura geográfica** | **municipal (São Paulo/SP)** |
| **LGPD** | ⚠️ **variável**. Zonas OD: ✅ risco baixo (agregado territorial). Transporte escolar SMT: ✅ risco baixo. **SPTRANS "Créditos Eletrônicos do Bilhete Único — Usuário": 🔴 risco alto — é nível individual** |

**Verificação (2026-09-30)**: portal **200** (CKAN, 484 conjuntos; apenas ~3
relacionados a transporte, **nenhum em GTFS**) · zonas OD (SMUL) **200** (CCZero,
XLS/CSV/shapefile, notas citam Pesquisa OD do Metrô **1997, 2007 e 2025**) ·
"Créditos Eletrônicos do Bilhete Único — Usuário" (SPTRANS) **200** (CCZero, XLS,
**granularidade individual**) · "Cadastro de Lombadas" (CET) **200** (CC BY,
CSV/ODS/XLS/XLSX) · "SGTP \| Transporte Escolar" (SMT) **200** (CCZero, PDF e CSV)

**Relevância para o EduMaps:** as **zonas origem-destino com geometria** são a
peça que falta para sair da contagem agregada da ANTT e chegar ao território. Como
o IVET já opera em nível municipal, o ganho real é **desagregar o par OD-municipal
para dentro do município** — o que identifica escolas periféricas com dependência
de transporte público. O **cadastro de lombadas** da CET é complemento direto e
de risco zero ao indicador de segurança do trajeto.

**Indicador derivado possível:**
- `iv_mobilidade_od_zona_escola` — viagens com origem ou destino na zona OD que
  contém a escola.
- `iv_mobilidade_exposicao_lombada` — número de lombadas por km de trajeto
  escolar (CET).
- `iv_mobilidade_transporte_escolar_smt` — vagas e itinerários do transporte
  escolar municipal (SMT/SGTP).

**Prioridade:** `[alta]` — **14 pontos**

**Justificativa:** ⭐⭐⭐ lacuna 5 (3) · ⭐⭐ API CKAN de metadados (2) · ⭐⭐⭐
granularidade de zona OD com coordenada, compatível com escola (3) · ⭐⭐⭐ licença
CCZero (3) · ⭐⭐⭐ complementa Censo/OSM/SIOPE (3) = **14**. **Cobertura nacional
(0)** e **periodicidade compatível com o ciclo de gestão escolar (0)** — a série
OD de 1997/2007/2025 é quinquenal, não serve para acompanhamento anual.

**Rastro:** `.../dataset/zona-de-origem-e-destino-1997-e-2007-no-municipio-de-sao-paulo`
**200** · portal **200** (484 conjuntos)

**Riscos / cuidados:**
- 🔴 **"Créditos Eletrônicos do Bilhete Único — Usuário" (SPTRANS) nunca deve ser
  ingerido.** É saldo/crédito por usuário individual, sob CCZero. **Licença
  aberta não anula risco LGPD**: dado de consumo individual de transporte, cruzado
  com escola e horário, permite reconstruir o trajeto de um aluno. Se algo do
  conjunto for necessário, usar apenas o agregado por zona e período, já
  publicado separadamente.
- ⚠️ **Zonas OD são desagregação espacial, não granularidade escolar.** A zona que
  contém a escola tem tipicamente dezenas de milhares de residentes.
- ⚠️ Só existem **três** conjuntos de transporte em 484 no portal. **A ausência de
  GTFS nesse portal é a evidência de que o padrão GTFS não está sendo adotado
  pelos grandes operadores.**
- ⚠️ **Shapefile exige conversão para GeoPackage** antes de entrar no DuckDB/PostGIS
  — formato legado, com problema conhecido de codificação de atributos.

---

### OpenStreetMap — Overpass API (via de derivação já usada no EduMaps)

| Campo | Valor |
|---|---|
| **URL** | https://overpass-api.de · política de tiles: https://operations.osmfoundation.org/policies/tiles/ |
| **Mantenedor** | OpenStreetMap Foundation (serviço comunitário financiado por doações) |
| **Licença** | ✅ **ODbL** para os **dados**. ⚠️ **os servidores de *tiles* da OSMF não são livres** e estão sujeitos à *Tile Usage Policy* |
| **Formato** | JSON (Overpass) e XML; WMS/WMTS; PBF bruto |
| **Granularidade** | **escolar e municipal** — qualquer POI com coordenada, inclusive vias, paradas, semáforo, faixas de pedestres, passadeiras, sinalização escolar |
| **Periodicidade** | **contínua**, com carência de algumas semanas |
| **API/SDK oficial** | ✅ **sim, documentada e sem autenticação** — endpoint `/api/status` e consulta QL. Para o R: `sf` + requisição HTTP. **OSMnx é Python**, não R |
| **Cobertura geográfica** | **nacional**, com qualidade desigual (melhor em capitais e eixosURY) |
| **LGPD** | ✅ **risco baixo**, com um cuidado: o OSM contém **coordenadas de casas** e, raramente, de pessoas. Nunca coletar `addr:housenumber` agregado por imóvel para inspecionar padrões residenciais de aluno |

**Verificação (2026-09-30)**: `https://overpass-api.de/api/status` → **200**
("Connected as: 3017759285"; endpoint anunciado `gall.openstreetmap.de`;
**Rate limit: 2**, 2 slots disponíveis) · política de tiles **200** (texto
integral)

**Relevância para o EduMaps:** já é **a fonte mais usada pelo projeto** e cobre a
lacuna 5 melhor que qualquer fonte oficial brasileira. O que falta é **densidade
consistente**: o OSM é excelente em eixo arterial de capital e escasso em cidade
pequena, então um indicador construído só sobre OSM carrega **viés de cobertura
geográfico** que precisa ser medido e publicado junto do valor.

**Indicador derivado possível:**
- `iv_mobilidade_passadeiras_escola` — número de passadeiras a 200 m da escola.
- `iv_mobilidade_ciclabilidade_acesso` — km de ciclovia ligando a escola à malha
  de transporte público.
- `iv_mobilidade_completude_malha` — completude da malha viária no buffer de
  500 m. É **indicador de qualidade do dado**, e deve ser publicado junto do
  valor para tornar o viés de cobertura auditável.

**Prioridade:** `[alta]` — **18 pontos**

**Justificativa:** ⭐⭐⭐ lacuna 5 (3) · ⭐⭐ **API documentada e sem
autenticação** (2) · ⭐⭐⭐ granularidade escolar (3) · ⭐⭐⭐ licença ODbL (3) ·
⭐⭐ cobertura nacional (2) · ⭐⭐ periodicidade contínua (2) · ⭐⭐⭐ complementa
Censo/OSM/SIOPE (3) = **18**. **Pacote R (0)** — OSMnx é Python; o equivalente
em R é `sf` + `httr2`.

**Nota de consistência:** a licença ODbL pontua aqui como no conjunto ANTT/CC BY,
e a questão é a mesma já aplicada ao Banco Central. A diferença é de **escopo**:
o ODbL do OSM é aceito pelo projeto **há anos**, como base já ingerida, e a
materialização atual (`clean.osm_feature`) já está sob esse regime. O rebaixamento
do BCB e do Recife se aplica a **fontes novas** cuja incorporação criaria a
obrigação pela primeira vez. Registrado para que a diferença seja **explícita e
não acidental**.

**Rastro:** `https://overpass-api.de/api/status` **200** (rate limit 2) ·
`https://operations.osmfoundation.org/policies/tiles/` **200**

**Riscos / cuidados:**
- 🔴 **Limite de taxa verificado: 2 slots simultâneos.** Um plano de coleta que
  dispare dezenas de consultas em paralelo **será bloqueado**. Todo acesso ao
  Overpass precisa de **fila com repetição espaçada** e **persistência do
  resultado bruto em disco** — reconsultar o OSM para o mesmo objeto é
  desperdício.
- 🔴 **Os tiles da OSMF não são uso livre.** A política proíbe baixar em massa,
  proíbe uso offline e exige `User-Agent` identificando a aplicação, além de
  atribuição visível. Se o frontend do EduMaps usa tiles do OSM, isso **já** é uma
  obrigação em produção, não uma escolha futura.
- ⚠️ **OSMnx não é R.** Se a extração de hoje é em Python, o IVET em R terá que
  reimplementar ou manter fronteira entre linguagens. Registrar a decisão na
  issue de implementação.
- ⚠️ Derivar buffers em volta de escolas **é identificador de localização de
  menores** quando a escola atende poucos alunos. Agregar buffers.

---

### Roteadores abertos — OSRM e Valhalla (isocronas e matrizes)

| Campo | Valor |
|---|---|
| **URL** | OSRM https://router.project-osrm.org · Valhalla https://valhalla1.openstreetmap.de · ⚠️ **GraphHopper: URL pública não verificada** |
| **Mantenedor** | Project OSRM (FOSSGIS); Valhalla demo pela comunidade OpenStreetMap; GraphHopper (projeto comercial e de código aberto) |
| **Licença** | Software **livre** (OSRM: MIT; Valhalla: MIT); dados derivados do OSM sob **ODbL**. ⚠️ Licença do endpoint hospedado: **não verificada** |
| **Formato** | JSON: `routes`, `isochrone`, `sources_to_targets`, `trace_route` |
| **Granularidade** | **isocrona a partir de um ponto**; trecho viário; matriz origem-destino |
| **Periodicidade** | sob demanda; *tileset* de **data de build fixa** (a instância Valhalla verificada reportou `tileset_last_modified` fixo) |
| **API/SDK oficial** | ✅ **sim, sem autenticação**, no formato de rota documentada. ❌ **GraphHopper não verificado** |
| **Cobertura geográfica** | **nacional**, herdada do OSM |
| **LGPD** | ✅ **risco baixo**, desde que a isocrona seja agregada em grade e não devolvida por escola isolada |

**Verificação (2026-09-30)**

| URL | Status |
|---|---|
| `router.project-osrm.org/route/v1/driving/-46.6333,-23.5505;-46.6333,-23.5600?overview=false` | **200** — `{"code":"Ok"}`, `distance` 1561,5 m, `duration` 211,4 s |
| `valhalla1.openstreetmap.de/status` | **200** — `version` 3.9.0-685e3d8; `available_actions` inclui `route`, `isochrone`, `sources_to_targets`, `optimized_route`, `trace_route`, `trace_attributes`, `height` |
| `valhalla1.openstreetmap.de/isochrone?json={…costing:pedestrian, contours:[{time:15}]}` | **200** — GeoJSON `FeatureCollection` com polígono de isocrona de 15 min a pé |
| GraphHopper (endpoint público) | ⚠️ **não verificado** |

**Relevância para o EduMaps:** a isocrona é o indicador mais defensável de
**"alcance real do aluno"** — quantos residents são alcançáveis a pé em 15, 30 e
45 minutos a partir da escola. É inteiramente derivado de dado público de
infraestrutura, **sem qualquer dado de passageiro**, o que a torna a solução
**mais segura em LGPD** para expressar a lacuna 5.

**Indicador derivado possível:**
- `iv_mobilidade_isocrona_escolar_15` — população a até 15 min a pé da escola,
  interpolada da malha censitária do IBGE.
- `iv_mobilidade_isocrona_transito_45` — população a até 45 min de transporte
  público a partir do ponto de embarque mais próximo.
- `iv_mobilidade_barreira_topografica` — razão entre a isocrona de 15 min
  observada e a idealizada pelo raio euclidiano (detecta rio, ferrovia, viaduto).

**Prioridade:** `[alta]` — **13 pontos**

**Justificativa:** ⭐⭐⭐ lacuna 5 (3) · ⭐⭐⭐ granularidade de isocrona compatível
com escola (3) · ⭐⭐⭐ licença: software livre + ODbL (3) · ⭐⭐ cobertura nacional
(2) · ⭐⭐⭐ complementa Censo/OSM/SIOPE — a isocrona é o **elo exato** entre a
malha do OSM e a malha censitária do IBGE (3) = **14**, menos **API oficial
estável (0)** — nenhum dos endpoints é oficial e não há SLA — e menos
**periodicidade (0)**, pois o *tileset* é um snapshot sem atualização
contratual = **13**.

**Rastro:** `router.project-osrm.org/route/v1/driving/…` **200** ·
`valhalla1.openstreetmap.de/status` **200** ·
`valhalla1.openstreetmap.de/isochrone?json=…` **200**

**Riscos / cuidados:**
- 🔴 **As duas instâncias verificadas são servidores de demonstração, sem SLA e
  sem compromisso de continuidade.** Colocar `iv_mobilidade_isocrona_escolar_15`
  em produção dependendo delas cria ponto único de falha fora do controle do
  projeto. **Recomendação de arquitetura: extrair o *tileset* uma vez**
  (Overpass/Geofabrik) **e auto-hospedar OSRM/Valhalla em container** — o que
  também elimina a dependência de servidores comunitários estrangeiros.
- ⚠️ **O `duration` do OSRM é tempo de fluxo livre**, sem trânsito. Usar como
  custo de deslocamento sem verdade de tráfego superestima a acessibilidade em
  via arterial.
- ⚠️ **O *tileset* da Valhalla tem data de build fixa.** Reexecutar a mesma
  isocrona meses depois devolve o mesmo resultado — não tratar como dado
  atualizado.
- ⚠️ **GraphHopper não foi verificado.** Não afirmar comportamento de sua API.
- ⚠️ Isocrona por escola em cidade pequena pode ser reidentificável. Agregar em
  grade de 1 km antes de exibir.

---

### GTFS e Mobility Database (transporte público)

| Campo | Valor |
|---|---|
| **URL** | https://www.mobilitydatabase.org · https://gtfs.org |
| **Mantenedor** | MobilityData (consórcio comunitário sem fins lucrativos, apoiado pela Linux Foundation) |
| **Licença** | ⚠️ **não verificada** — o catálogo não respondeu |
| **Formato** | GTFS (ZIP com `routes.txt`, `stops.txt`, `trips.txt`, `stop_times.txt`, `calendar.txt`) |
| **Granularidade** | **ponto de embarque e horário** — a melhor granularidade teórica do lote |
| **API/SDK oficial** | ⚠️ **não verificada**: `api.mobilitydatabase.org` → **HTTP 413**; `catalog.mobilitydatabase.org` → **NXDOMAIN**. A API do transit.land → **HTTP 401** (exige chave) |
| **Cobertura geográfica** | ⚠️ **não verificada no Brasil** |
| **LGPD** | ✅ **risco baixo** — GTFS é oferta de serviço (horários, itinerários, pontos). **Não** contém deslocamento de passageiros |

**Verificação (2026-09-30)**

| URL | Status |
|---|---|
| `mobilitydatabase.org` | **403** (Cloudflare) |
| `gtfs.mobilitydatabase.org` | **NXDOMAIN** |
| `catalog.mobilitydatabase.org` | **NXDOMAIN** |
| `api.mobilitydatabase.org` | **413** |
| `gtfs.org` | **403** |
| API v2 do transit.land | **401** (exige chave) |
| API GitHub da organização MobilityData | **200** — repositórios ativos |
| CRAN `gtfsio` | **200** — 1.2.1 (2026-05-20) |
| CRAN `gtfstools` | **200** — 1.4.0 (2025-01-09) |
| `sptrans.com.br` · `metro.sp.gov.br` · `cptm.sp.gov.br` | **200** — **nenhum link GTFS exposto na navegação** |
| `supervia.com.br` | **502** |

**Relevância para o EduMaps:** o GTFS é a **única forma de calcular *catchment*
de transporte público sem dados de passageiros** — quantas linhas e a que
distância servem uma escola. É derivado apenas da oferta declarada, o que o torna
seguro em LGPD. Em São Paulo verificamos que o padrão GTFS **não é publicado** por
SPTrans, Metrô nem CPTM.

**Indicador derivado possível:**
- `iv_mobilidade_catchment_transporte` — número de linhas a 500 m / 1 km da
  escola, ponderado por frequência no pico da manhã.
- `iv_mobilidade_acesso_transporte` — tempo a pé até o ponto com maior
  frequência, derivado de GTFS + OSM.

**Prioridade:** `[baixa]` — **15 pontos antes do rebaixamento → rebaixada**

**Justificativa (bruta):** ⭐⭐⭐ lacuna 5 (3) · ⭐⭐⭐ granularidade de ponto de
embarque (3) · ⭐⭐⭐ licença não verificada, presumida compatível (3, com
ressalva) · ⭐⭐ periodicidade de feed (2) · ⭐ **pacote R — `gtfsio` e `gtfstools`
verificados no CRAN** (1) · ⭐⭐⭐ complementa Censo/OSM/SIOPE (3) = **15**.
**API oficial estável (0)** — nenhuma confirmada em 200. **Cobertura nacional
(0)** — nenhum agregador alcançável confirmou cobertura.

**Rebaixe aplicado:** *"exige scraping frágil (sem API/download estável)"* —
**leva a `[baixa]` independentemente da soma**. O agregador oficial respondeu
403, 413 e NXDOMAIN; nenhum dos grandes operadores brasileiros expôs link GTFS.

**Rastro:** `https://github.com/MobilityData` **200** (via API do GitHub) · CRAN
`gtfsio` **200** e `gtfstools` **200** · verificações negativas na tabela acima,
com os status reais

**Riscos / cuidados:**
- ⚠️ **Não iniciar pipeline de GTFS com base nesta ficha.** A `[baixa]` reflete
  **acesso, não mérito**. Se a decisão for avançar, o caminho verificável é o
  inverso do planejado: **buscar o ZIP GTFS diretamente nos portais de cada
  operador**, não passar por agregador.
- ⚠️ **403 e 413 podem ser bloqueio deste ambiente, não indisponibilidade real.**
  Ambos os catálogos são reconhecidamente ativos. Registrar como **"não
  verificado a partir deste host"**, não como inexistente.
- ⚠️ GTFS publicado apenas por municípios com equipe de TI significa **viés de
  cobertura** para o pior dos dois grupos. Auditar e reportar.

---

### Estado de São Paulo — DER, DETRAN, ARTESP e STM

| Campo | Valor |
|---|---|
| **URL** | https://dadosabertos.sp.gov.br |
| **Mantenedor** | Governo do Estado de São Paulo; autores DER, DETRAN, ARTESP, STM, SEADE |
| **Licença** | **CC BY 4.0** na maior parte do catálogo |
| **Formato** | XLSX, CSV, PDF, shapefile, ZIP |
| **Granularidade** | ⚠️ **estadual por trecho**, com município presente em parte dos conjuntos. O conjunto mais próximo do alvo é o da **STM, em nível municipal** |
| **Periodicidade** | mensal e diária, conforme o conjunto |
| **API/SDK oficial** | API CKAN de metadados, sem autenticação |
| **Cobertura temporal** | ⚠️ **não verificada com detalhe** nesta rodada; os conjuntos de sinistros e infrações têm série longa |
| **LGPD** | ✅ risco baixo nos conjuntos de infraestrutura. ⚠️ **DETRAN "Sinistros (Infosiga)" e "Infrações Lavradas" exigem cuidado**: bases público-agregadas, mas o cruzamento com placa, data e local é individualizável |

**Verificação (2026-09-30)**

| URL | Status |
|---|---|
| `dadosabertos.sp.gov.br` | **200** — CKAN estadual |
| DER — VDM, contagem volumétrica, iRAP, câmeras, radar, ocorrências rodoviárias | **200** — XLSX/PDF/shapefile |
| DETRAN — Sinistros (Infosiga), infrações lavradas | **200** |
| ARTESP — acidentes por fumaça, queimada e neblina; acessos rodoviários | **200** |
| **STM — "Monitoramento dos Planos de Mobilidade dos Municípios das Regiões Metropolitanas"** | **200** — XLSX, nível municipal |
| EMPLASA (`www.emplasa.sp.gov.br`) | ⚠️ **não respondeu** — *timeout* na tentativa direta |

**Relevância para o EduMaps:** entrega duas coisas que o nível federal não dá —
**volume médio diário por trecho com município** (DER) e o **monitoramento
municipal de Planos de Mobilidade** (STM), que é a única verificação de "alvo de
transporte" em escala municipal localizada em todo o lote.

**Indicador derivado possível:**
- `iv_mobilidade_vmd_estadual` — VMDA por trecho na hierarquia estadual.
- `iv_mobilidade_plano_mobilidade` — *(STM)* presença e estágio do Plano de
  Mobilidade por município da Região Metropolitana.
- `iv_mobilidade_risco_ambiental_via` — *(ARTESP)* sinistros por neblina e
  queimada: risco climático sobre a via escolar.

**Prioridade:** `[baixa]` — **13 pontos antes do rebaixamento → rebaixada**
(o conjunto da STM, isolado, é uma subficha `[média]`)

**Justificativa (bruta):** ⭐⭐⭐ lacuna 5 (3) · ⭐⭐ API CKAN (2) · ⭐⭐⭐ licença
CC BY (3) · ⭐⭐ periodicidade (2) · ⭐⭐⭐ complementa Censo/OSM/SIOPE (3) =
**13**. **Granularidade compatível com escola ou município (0)** — o critério não
é satisfeito pelo conjunto estadual. **Cobertura nacional (0)**. **Pacote R (0)**.

**Rebaixe aplicado:** *"granularidade apenas estadual/nacional sem desagregação
municipal/escolar"* — **leva a `[baixa]` independentemente da soma**. A única
exceção é o conjunto da **STM**, que é municipal e deve ser tratado como
subficha `[média]` própria.

**Rastro:** `dadosabertos.sp.gov.br` **200** · `dados.prefeitura.sp.gov.br`
**200** (portal municipal, para desagregar)

**Riscos / cuidados:**
- 🔴 **Não entra no IVET como indicador.** Serve como fonte de *enriquecimento*:
  cobertura real exige desagregar município a município, e esse caminho foi
  verificado apenas em São Paulo.
- ⚠️ **DETRAN/Infosiga exige regra de agregação obrigatória.** Nunca carregar a
  base bruta de infrações; cruzar apenas por município e mês.
- ⚠️ **O conjunto da STM é a única coisa deste portal que interessa ao IVET.**
  Antes de construir integração com todo o portal estadual, avaliar se a STM
  isolada resolve o requisito "metas de transporte".
- ⚠️ A **EMPLASA**, citada na issue, não foi verificável — ver tabela de
  correções.

---

### ANTP — SIMU/SIMOB e Planilha Tarifária

| Campo | Valor |
|---|---|
| **URL** | https://www.antp.org.br/sistema-de-informacoes-da-mobilidade · https://www.antp.org.br/planilha-tarifaria-custos-do-servico-onibus/apresentacao.html |
| **Mantenedor** | Associação Nacional das Transportadoras Públicas (ANTP), em parceria com o BNDES |
| **Licença** | ⚠️ **não verificada** — nenhuma licença declarada |
| **Formato** | ⚠️ **não verificado** — a página publica apenas um relatório em PDF (`Rel_2011_V3.pdf`); nenhuma base CSV/XLSX/API foi localizada |
| **Granularidade** | **municipal** (por questionário), segundo as 150+ variáveis declaradas |
| **Periodicidade** | ⚠️ **não verificada e provavelmente extinta** — dados declarados de **2014** |
| **API/SDK oficial** | ❌ **nenhuma** |
| **Cobertura geográfica** | 533 municípios com **60.000+ habitantes** em 2014 — **não é cobertura censitária total** |
| **LGPD** | ✅ **risco baixo** — questionário de atributos de frota e infraestrutura, sem dado individual |

**Verificação (2026-09-30)**: `antp.org.br` **200** (institucional, **sem seção de
dados** na navegação) · `/sistema-de-informacoes-da-mobilidade` **200** — SIMU/
SIMOB, >150 dados básicos de 533 municípios, único link de dado
`/_5dotSystem/userFiles/simob/STAQ/Rel_2011_V3.pdf` · planilha tarifária **200**
(documentos de **agosto de 2017**, substituem o GEIPOT/1996)

**Relevância para o EduMaps:** valor **metodológico**, não de dados. A Planilha
Tarifária é a referência nacional de estrutura de custo de ônibus e deve
documentar qualquer indicador de custo derivado. O SIMU é importante
**negativamente**: prova que já houve levantamento municipal de frota e semáforo
em escala razoável e que **não foi mantido**.

**Indicador derivado possível:**
- `iv_mobilidade_frota_onibus_habitante` — apenas se a base do SIMU for obtida
  (hoje: **não disponível**).
- Parâmetros de custo para `iv_mobilidade_custo_deslocamento` — a partir da
  Planilha Tarifária 2017 (comprovação por documento, não por dado).

**Prioridade:** `[baixa]` — **11 pontos antes do rebaixamento → rebaixada**

**Justificativa (bruta):** ⭐⭐⭐ lacuna 5 (3) · ⭐⭐⭐ granularidade municipal (3) ·
⭐⭐ cobertura parcial (2) · ⭐⭐⭐ complementa Censo/OSM/SIOPE (3) = **11**.
**Licença (0)** — não verificada. **API (0)**. **Periodicidade (0)** — dados de
2014. **Pacote R (0)**.

**Rebaixe aplicado:** *"exige scraping frágil"* — **leva a `[baixa]`
independentemente da soma**. Só há um PDF de 2011.

**Rastro:** `/sistema-de-informacoes-da-mobilidade` **200** ·
`/planilha-tarifaria-custos-do-servico-onibus/apresentacao.html` **200**

**Riscos / cuidados:**
- ⚠️ **"Sistema de Informações sobre Demandas de Transporte" não existe com esse
  nome.** O sistema real é o **SIMU/SIMOB**, e é sobre **frota, tarifa e
  semáforo**, não sobre demanda de viagem. Corrigir a issue #123.
- ⚠️ **Não construir pipeline contra a ANTP.** Site institucional sem seção de
  dados; o download exigiria contato com a associação.
- ⚠️ Dado de 2014, com 12 anos de defasagem. Se entrar no IVET, como referência
  histórica de comparabilidade, nunca como valor corrente.

---

### Google Maps, Google Maps Platform e Mapbox — delimitação negativa

| Campo | Valor |
|---|---|
| **URL** | ⚠️ **não verificado nesta rodada** — nenhuma página de termos, preço ou documentação foi acessada |
| **Mantenedor** | Google LLC e Mapbox, Inc. |
| **Licença** | ⚠️ **não verificada**. Estruturalmente, são **serviços proprietários com termos de uso contratuais**, não dados abertos sob licença livre |
| **API/SDK oficial** | ⚠️ **não verificado**, mas estruturalmente **exigem conta, chave de API e faturamento** — não são APIs abertas |
| **LGPD** | ⚠️ **risco alto de dependência**, não de dado: qualquer produto baseado nestes serviços carrega risco de transferência internacional de dados e de prender o EduMaps a um fornecedor comercial |

**Relevância para o EduMaps:** a resposta prática ao item "o que é open e o que
exige licença paga" é esta: **o que o IVET precisa — rede viária, isocronas,
transporte público — é inteiramente coberto por OSM (ODbL) + Overpass + OSRM +
Valhalla, sem custo e sem fornecedor.** Google Maps e Mapbox resolvem
apresentação e geocodificação, que **não são indicadores**.

**Indicador derivado possível:** **nenhum.** Esta entrada existe como
**delimitação negativa**, para que a issue #123 pare de listar fontes
proprietárias ao lado de fontes abertas na mesma lista de candidatos.

**Prioridade:** `[baixa]` — **nenhum campo verificado**

**Justificativa:** rebaixada por **"licença restritiva ou incompatível com uso
público"** e por ser **"sem API oficial aberta"**. Nenhum critério positivo é
pontuado porque nenhum campo foi verificado.

**Rastro:** ⚠️ **não verificado** — esta ficha registra a ausência de verificação,
não afirma comportamento de produto.

**Riscos / cuidados:**
- 🔴 **Não usar nem Mapbox nem Google Maps Platform como insumo do IVET.**
  Nenhuma verificação foi feita, e a dependência introduz risco jurídico e de
  dados sem contrapartida para o indicador.
- ⚠️ **Não usar tiles do Google Maps nem do Mapbox no frontend** sem revisão de
  licença. O frontend já usa Leaflet; o caminho livre é OSM.
- ⚠️ Se geocodificação for necessária, avaliar `geobr`/`nominatim` antes de
  qualquer serviço comercial.

---

### ITDP Brasil — MobiliDADOS

| Campo | Valor |
|---|---|
| **URL** | Programa https://itdpbrasil.org/monitoramento-e-avaliacao · ⚠️ **URL da plataforma MobiliDADOS não localizada** |
| **Mantenedor** | ITDP Brasil (Instituto de Política de Transporte e Desenvolvimento) |
| **Licença** | ⚠️ **não verificada** |
| **Formato** | ⚠️ **não verificado** — a página menciona plataforma de indicadores e dados abertos, sem link de download legível |
| **Periodicidade** | a página declara "**mais de 20 indicadores atualizados anualmente**" |
| **API/SDK oficial** | ⚠️ **não verificada** |
| **LGPD** | ⚠️ **não verificada** — depende inteiramente do conteúdo da plataforma |

**Verificação (2026-09-30)**: `itdpbrasil.org/monitoramento-e-avaliacao` **200** —
principal iniciativa declarada: **MobiliDADOS**, plataforma de indicadores e dados
abertos com mais de 20 indicadores atualizados anualmente. **Nenhum link de
plataforma, API ou download exposto.** WRI Brasil / "Observatório de Mobilidade"
→ ⚠️ **não localizado** como portal de dados abertos estruturado.

**Relevância para o EduMaps:** se a plataforma existir com API e licença aberta,
é um **agregador de indicadores** que poderia servir de benchmark para o bloco de
mobilidade do IVET. Na condição atual, não é utilizável.

**Indicador derivado possível:** nenhum diretamente; serve como **referência de
validação** (comparar os indicadores do IVET com os do MobiliDADOS).

**Prioridade:** `[baixa]`

**Justificativa:** rebaixada por ausência de download/API/licença verificados —
**"sem API/download estável"**. Único critério positivo: ⭐⭐ periodicidade anual
declarada na página institucional (2).

**Rastro:** `itdpbrasil.org/monitoramento-e-avaliacao` **200**

**Riscos / cuidados:**
- ⚠️ **Plataforma não localizada.** Não abrir issue de implementação sobre
  MobiliDADOS sem primeiro confirmar URL, licença e formato.
- ⚠️ **"Observatório de Mobilidade" não foi localizado** como nome oficial de
  qualquer portal federal ou de ONG com dados abertos. Provável confusão com
  observatórios urbanos de coleta própria.

---

## 🔴 Bilhetagem individual — verificado, e por isso proibido

O achado de maior risco de LGPD do lote, verificado no catálogo da ANTT: os
conjuntos de **viagens** do MONITRIIP (74 recursos, série encerrada em dez/2024)
exõem **`cnpj`, `placa`, `numero_imei`, `latitude` e `longitude` por viagem**.
Na mesma linha, o conjunto **"Créditos Eletrônicos do Bilhete Único — Usuário"**
da SPTRANS é nível individual, **sob CCZero**.

**Duas consequências distintas, e ambas registradas:**

1. **Nunca ingerir** esses conjuntos. Licença aberta **não** neutraliza risco
   LGPD: reconstruir o trajeto de um aluno a partir de coordenada + horário +
  school é reidentificação trivial.
2. **A allowlist de endpoints da Fase 0 precisa cobrir isto**, não apenas a API do
   SUS. O vetor de erro é o mesmo — um job que baixa "o conjunto de viagens
   certo" em vez do agregado.

## ⚠️ Correções à lista de candidatos da issue #123

| Candidato como listado | Resultado verificado | Correção |
|---|---|---|
| **CARR / Matriz OD** no portal do Ministério dos Transportes | **Não encontrado** — `dados.transportes.gov.br` **200**, busca por "CARR", "matriz OD" e "origem-destino" retorna 0 conjuntos | Remover. Substituir pela ficha **ANTT/MONITRIIP** |
| **"Sistema de Informações sobre Demandas de Transporte"** | **Não existe com esse nome** | A entidade real é a **SIMU/SIMOB**, sobre frota/tarifa/semáforo, não demanda de viagem. Renomear e rebaixar |
| **EMPLASA** | **Não verificável** — `www.emplasa.sp.gov.br` *timeout*; via proxy **403** (Cloudflare) | Manter como *pendente*. Substituto verificado: zonas OD da SMUL (CCZero) |
| **ANTT — Termo de Permutação** como dataset aberto | **Não encontrado no CKAN** | Remover da lista de dados; avaliar via processo administrativo |
| **Google Maps / Maps Platform / Mapbox** | Proprietários; **nenhum campo verificado** | Mover para a seção de **fornecedores**, não de fontes de dados |
| **GraphHopper** | **Não verificado** — nenhum endpoint público testado | Manter como não verificado; OSRM e Valhalla foram verificados em 200 |
| **SuperVia (Rio)** | **502** | Operador sem acesso verificável |
| **EMTU (São Paulo)** | Redireciona para a ARTESP, que é estadual | Duplicata; usar o portal estadual |
| **MetrôRio** | **200**, mas rodapé "Todos os direitos reservados" e nenhum link de dado aberto | Remover como fonte aberta: é fonte de consulta, não de dado |
| **NITTrans (Natal)** | **NXDOMAIN** | Remover ou marcar indisponível |
| **Sistemas de bilhetagem** (ANTT Viagens, SPTRANS) | Verificados — **risco LGPD máximo** | **Nunca ingerir.** Ver a seção dedicada acima |
| **Mobility Database / gtfs.org** | **Não alcançável deste host** (403, 413, NXDOMAIN) | Registrar como "não verificado neste host", **não** como inexistente |
| **"Sistema Nacional de Viário" (SNV)** | **Nome incorreto** — a página do DNIT nesse caminho responde 200 mas devolve "Conteúdo Restrito — é necessário autenticar" | A nomenclatura correta, confirmada em metadado do INDE, é **Sistema Nacional de Viação (SNV)** |
| **PNCT como malha rodoviária aberta** | **Premissa incorreta** — `/dadospnct/downloads` **404**; VGeo é visualizador sem API; página declara "Todos os Direitos Reservados" | O caminho aberto é a **camada de modelagem de VMDA sobre o SNV, espelhada no INDE em domínio público** |
| **Planos de Mobilidade (metas de transporte)** | **Parcialmente verificado** — único conjunto municipal: STM/SP, "Monitoramento dos Planos de Mobilidade dos Municípios das Regiões Metropolitanas" **200** (XLSX) | Manter apenas como municipal/estadual; **não prometer escala nacional** |
| **OSMnx como caminho de derivação em R** | **Premissa incorreta** — OSMnx é **Python** | Em R o caminho é `sf` + `httr2`; `gtfsio`/`gtfstools` são os pacotes R relevantes |
| **dados.gov.br (portal federal)** | **HTTP 401** | Não usar como caminho de coleta; usar os portais setoriais |
| **SENATRAN** | **NXDOMAIN** | Remover |
| **Pesquisa Nacional de Tráfego (PNT) 2016/2017** | A matriz OD citada na metodologia **não foi localizada em formato aberto** | Não contar com ela no IVET |

---

## Síntese do lote

| Fonte | Prioridade | Pontos | Motivo |
|---|---|---|---|
| **OpenStreetMap — Overpass API** | 🟢 `[alta]` | 18 | API documentada e sem auth, granularidade escolar, ODbL, cobertura nacional. Já é a base do EduMaps — aqui entra o **viés de cobertura** como indicador de qualidade |
| **ANTT — MONITRIIP, bilhetes de passagem** | 🟢 `[alta]` | 16 | Única matriz OD **nacional** com chave município-município, mensal, CC BY. Mitigação LGPD determinística |
| **ANTT — SAT/equipamentos, acidentes, geodados** | 🟢 `[alta]` | 16 | Exposição ao risco viário e carga de tráfego em trecho, com coordenada e CC BY, em escala federal. O conjunto de acidentes, **isolado**, é `[baixa]` (sem município) |
| **DNIT — SNV e modelagem de VMDA** | 🟢 `[alta]` | 16 | Malha rodoviária federal com volume, em domínio público via INDE. O PNCT isolado é `[baixa]` |
| **Ministério dos Transportes — RENAVAM/RENAEST/RENACH/RENAINF** | 🟢 `[alta]` | 16 | Frota por município e sinistralidade com vítima, nacionais, mensais, em domínio público |
| **Prefeitura de São Paulo — SMUL/CET/SMT** | 🟢 `[alta]` | 14 | Zonas OD com geometria (desagrega o par municipal da ANTT dentro do município) e cadastro de lombadas |
| **Roteadores abertos — OSRM e Valhalla** | 🟢 `[alta]` | 13 | Isocronas são o elo exato entre a malha do OSM e a malha censitária do IBGE, sem risco LGPD. **Condição: auto-hospedar** |
| **Prefeitura do Recife — CKAN** | 🟡 `[média]` | 16 → rebaixada | **Única granularidade escolar** e **melhor API** do lote, mas **ODbL share-alike** — mesma razão que descartou o BCB. Fica como prova de viabilidade do indicador, não como fonte a ingerir |
| **GTFS e Mobility Database** | 🔴 `[baixa]` | 15 → rebaixada | Agregador oficial inacessível deste host (403/413/NXDOMAIN) e nenhum link GTFS nos grandes operadores. Rebaixamento por **acesso**, não por mérito |
| **ANTP — SIMU/SIMOB e Planilha Tarifária** | 🔴 `[baixa]` | 11 → rebaixada | Só um PDF de 2011 está publicado; dados de 2014 e não são de demanda |
| **Estado de São Paulo — DER/DETRAN/ARTESP/STM** | 🔴 `[baixa]` | 13 → rebaixada | Granularidade estadual sem desagregação municipal. Só o conjunto da STM escapa, e é municipal |
| **Google Maps / Maps Platform / Mapbox** | 🔴 `[baixa]` | 0 | Proprietários, com chave e faturamento; nenhum campo verificado. Delimitação negativa |
| **ITDP Brasil — MobiliDADOS** | 🔴 `[baixa]` | 2 | Plataforma não localizada, sem licença, formato ou API verificáveis |

**Conclusão do lote**: a lacuna 5 **tem solução nacional verificada em quatro
fontes** — ANTT/MONITRIIP (fluxo), ANTT (tráfego e risco de trecho), DNIT/INDE
(malha e VMDA) e Transportes (frota e sinistros) — mas **não tem solução de
deslocamento escolar**: a única fonte com granularidade de escola é o CKAN do
Recife, que é ODbL. O desenho de implementação recomendado é, portanto:
**`iv_mobilidade_transporte_escolar` no Recife como referência de viabilidade**
(leitura permitida; materializar sob share-alike fica para decisão do jurídico), **depois `iv_mobilidade_od_externo` nacional pela ANTT**, e
**GTFS, isocronas e EMPLASA fora do caminho crítico** — as duas primeiras
dependem de terceiros não verificados neste lote.
