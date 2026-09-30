# Fontes — Meio ambiente e clima

> Lote G da issue #123 · lacuna do IVET nº 6 (**meio ambiente e clima**).
> Método, pesos e regras: [`../fontes_de_dados.md`](../fontes_de_dados.md).

**Achado central do lote**: a lacuna 6 tem a **melhor relação custo/benefício de
todo o catálogo**. O INMET publica alertas em **CAP 1.2 com o código IBGE do
município dentro do payload** e o MapBiomas entrega **edificação exposta a risco
climático** em COG público com **CC BY 4.0** — ambos com join direto no que o
EduMaps já tem. Nenhum exige convênio, scraping ou licença restritiva.

## ⚠️ Correções ao enunciado da issue #123

| Item listado | Verificação | Correção |
|---|---|---|
| **"IBAMA — SISLIC"** como dado aberto | ❌ SISLIC é **transacional e exige login**; não está no portal de dados abertos | O dado aberto equivalente é o dataset CKAN *"Licenças ambientais… licenciados pelo Ibama"* (Domínio Público) |
| **PRODES/DETER atribuídos ao IBAMA** | ⚠️ **são do INPE** (Programa PRODES/DETER, servido pelo Terrabrasilis) | Atribuição correta: INPE/Terrabrasilis |
| **"CNTramas"** | ❌ `cntramas.gov.br` **não resolve DNS**; não existe órgão/produto federal com esse nome | Provável confusão com o INPE Programa Queimadas ou MapBiomas |
| **CPTEC "grades, subtropical"** | ❌ nenhum produto "subtropical" publicado; `pclima.inpe.br` mudou para projeções | `clima1.cptec.inpe.br/monitoramentobrasil` → **404** |
| **MMA "painel de saúde ambiental"** | ❌ não localizado | `qualar.mma.gov.br` e `geoserver.mma.gov.br` não resolvem DNS |

---

### INMET Alerta-AS — alertas meteorológicos (CAP 1.2)

| Campo | Valor |
|---|---|
| **URL** | https://apiprevmet3.inmet.gov.br/avisos/rss · https://avisos.inmet.gov.br |
| **Mantenedor** | INMET (vinculado ao Alert-AS / Defesa Civil) |
| **Licença** | `<copyright>public domain</copyright>` declarado no RSS; licença formal não verificada |
| **Formato** | RSS 2.0 (índice) / **XML CAP 1.2** (OASIS) por alerta, com `<polygon>` |
| **Granularidade** | **município — com código IBGE na própria lista** + polígono da área de aviso |
| **Periodicidade** | diária / tempo real (avisos ativos, com início e fim) |
| **API/SDK oficial** | sim (HTTP — RSS + CAP XML, sem autenticação) |
| **Cobertura temporal** | feed de avisos **ativos** (sem histórico no índice) |
| **Cobertura geográfica** | nacional |
| **LGPD** | sem risco — padrão público de alerta que a Defesa Civil já publica |

**Verificação (2026-09-30)**: `GET /avisos/rss` → **HTTP 200**, `application/rss+xml`,
**91 `<item>` ativos**. `GET /avisos/rss/55888` → **HTTP 200**, `text/xml`, CAP 1.2
com `<polygon>` preenchido e parâmetros `<valueName>` = `ColorRisk`,
`TimeStampDateOnSet`, `TimeStampDateExpires`, **`Municipios`**, `Estados`. Trecho
verificado: `Abadia de Goiás - GO (5200050), … Wanderley - BA (2933455)`.
Rotas inexistentes (404) confirmadas: `/avisos/geojson`, `/avisos/55888`.

**Relevância para o EduMaps:** é a fonte que **mede o evento que realmente
interrompe a escola**. Cada alerta traz o parâmetro `Municipios` com
`Nome - UF (código IBGE)` — join direto no `codigo_ibge` que o EduMaps já usa,
**sem fuzzy match**.

**Indicador derivado possível:**
- `alertas_extremos_12m` — contagem por município de avisos de chuva intensa, tempestade, granizo, vendaval, calor, seca;
- `severidade_maxima_12m` · `dias_alerta_chuva_12m` · `municipio_sempre_alertado` (proxy de interrupção frequente do ciclo escolar).

**Prioridade:** `[alta]` — 18 pontos (maior do lote junto ao MapBiomas)

**Justificativa:** ⭐⭐⭐ (é literalmente o evento de suspensão de aulas) + ⭐⭐
(API testada, sem auth) + ⭐⭐⭐ (município **com IBGE** — melhor encaixe do lote)
+ ⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐ + ⭐⭐⭐ = **18**.

**Rastro:** `apiprevmet3.inmet.gov.br/avisos/rss` (200) · `/avisos/rss/{id}` (CAP 1.2)

**Riscos / cuidados:**
- O feed é **rotativo** (só avisos ativos) → para série é preciso **arquivar
  diariamente**, o que encaixa no padrão de `data_pipeline/` (tabela em Postgres).
- A granularidade do **polígono é mesorregião/área de aviso**, não município: a
  atribuição vem da **lista de nomes**, não da geometria — parte da área de
  aviso pode alcançar município vizinho fora do polígono.
- Verificar se **todos** os itens trazem o parâmetro `Municipios` antes de
  assumir cobertura uniforme.
- Hosts INMET sem SLA publicado.

---

### MapBiomas — cobertura, solo, fogo, degradação e risco climático

| Campo | Valor |
|---|---|
| **URL** | https://brasil.mapbiomas.org/ · risco climático https://brasil.mapbiomas.org/risco-climatico/ · downloads https://brasil.mapbiomas.org/downloads/ |
| **Mantenedor** | Rede MapBiomas (consórcio multi-institucional: ONGs, universidades, tecnologia) |
| **Licença** | **CC BY 4.0** — *"dados de uso público, aberto e gratuito mediante referência"* |
| **Formato** | GeoTIFF/COG (download direto), GeoJSON, Shp-ZIP, GEE asset, Dataverse, CSV |
| **Granularidade** | **pixel 30 m (e 10 m)**; estatística agregada por município disponível |
| **Periodicidade** | **anual** (alertas de desmatamento quinzenal; Monitor Mensal do Fogo mensal) |
| **API/SDK oficial** | **não** (sem API REST) — via COG/GEE/Dataverse |
| **Cobertura temporal** | **desde 1985** |
| **Cobertura geográfica** | nacional (17 países na rede; séries completas no Brasil) |
| **LGPD** | sem risco — sensoriamento remoto, sem dado pessoal |

**Verificação (2026-09-30)**: site → **HTTP 200**, *"resolução de 30 metros pixel a
pixel… plataforma Google Earth Engine"*, *"série histórica iniciada em 1985"*,
*"Fogo — mapas anuais e mensais desde 1985"*, *"Risco climático — indica as áreas
urbanizadas e **edificações** em áreas suscetíveis (risco médio, alto e muito
alto)"*; Coleção 11 em 12/08/2026. Download **sem GEE**, CDN público:
`HEAD https://storage.googleapis.com/mapbiomas-public/initiatives/brasil/collection11/lulc/coverage/brazil_coverage/brazil_coverage-col11_2025.tif`
→ **HTTP 200**, `image/tiff`, **52.836.463 bytes**. `api.mapbiomas.org` responde 200
na raiz mas **nenhuma rota testada existe** (`/api/v1/graphql`, `/api/v1/datasets`,
`/openapi.json` → 404).

**Relevância para o EduMaps:** é a fonte com o produto **mais diretamente
endereçado** à lacuna. O produto "Risco climático" (**Índice de Segurança
Hídrica**) é descrito oficialmente como indicando *"as áreas urbanizadas e
**edificações** em áreas suscetíveis"* — ou seja, **já entrega edificação exposta
a risco**, que é a unidade de análise do EduMaps. Solo acrescenta **declividade
urbana**, **altura da drenagem mais próxima** e **ilhas de calor urbanas**.

**Indicador derivado possível:** `risco_hidrico_escola` (classe ISH do pixel da
escola) · `edificacao_em_area_susceptivel` · `distancia_drenagem_escola_m` ·
`declividade_terreno_escola` · `ilha_de_calor_urbana` · `frequencia_queimada_no_raio_500m`.

**Prioridade:** `[alta]` — 19 pontos (maior do lote)

**Justificativa:** ⭐⭐⭐ + ⭐⭐ (download COG público; sem API) + ⭐⭐⭐ (30 m e
10 m, pixel a pixel) + ⭐⭐⭐ (CC BY 4.0) + ⭐⭐ + ⭐⭐ + ⭐ + ⭐⭐⭐ = **19**.

**Rastro:** `brasil.mapbiomas.org` · `mapbiomas.org/faq/` e
`brasil.mapbiomas.org/uso-de-dados/` (licença) · bucket CDN verificado

**Riscos / cuidados:**
- **Não conte com API REST** — o caminho robusto é ler o COG/GeoTIFF direto
  (GDAL/`terra`) e agregar por município, ou usar a página de **Estatísticas**
  (o atalho mais barato: evita rasterizar 30 m — **validar primeiro**, os
  arquivos por município não foram baixados nesta rodada).
- A série é republicada por ano com **URL mutável**: fixar a URL da **Coleção**
  (ex.: `collection11`), não a do ano solto, ou o pipeline quebra no ano seguinte.
- `alerta.mapbiomas.org` estava com **HTTP 503** durante a verificação — usar
  `plataforma.alerta.mapbiomas.org`.
- **CC BY 4.0 exige atribuição**: crédito ao MapBiomas no rodapé da SPA e no
  relatório do IVET.
- GEE exige conta Google — preferir o bucket `storage.googleapis.com`, que não exige.

---

### INMET — séries históricas diárias (BDMEP)

| Campo | Valor |
|---|---|
| **URL** | https://portal.inmet.gov.br/dadoshistoricos · https://apitempo.inmet.gov.br/estacoes/T · https://bdmep.inmet.gov.br/ |
| **Mantenedor** | INMET (Ministério da Agricultura e Pecuária) |
| **Licença** | não verificada (sem página de termos acessível; único indício é o `public domain` do RSS) |
| **Formato** | CSV comprimido em ZIP (anual) / API REST JSON |
| **Granularidade** | **ponto (estação)** — exige join espacial com a escola |
| **Periodicidade** | diária (séries) / anual (arquivos) |
| **API/SDK oficial** | sim (HTTP — REST JSON, sem autenticação) |
| **Cobertura temporal** | **desde 2000** (ZIPs 2000→2026; 2026 parcial até 31/08) |
| **Cobertura geográfica** | nacional |
| **LGPD** | sem risco |

**Verificação (2026-09-30)**: `GET /estacoes/T` → **HTTP 200**, JSON, **673 estações
automáticas** (526 `Operante`, **147 `Pane`**), **27 UFs**, campos `CD_ESTACAO`/
`VL_LATITUDE`/`VL_LONGITUDE`/`VL_ALTITUDE`/`SG_ESTADO`/`DT_INICIO_OPERACAO`.
`portal.inmet.gov.br/dadoshistoricos` lista ZIPs `2000.zip`…`2026.zip`;
`HEAD`/Range em `2024.zip` → **HTTP 206**, `application/zip`.

**Relevância para o EduMaps:** precipitação intensa, dias de calor extremo
(>40 °C), chuva que derruba aulas e secas prolongadas que afetam o deslocamento.
A API devolve lat/lon/altitude, permitindo agregar por buffer de raio em torno
de cada escola.

**Indicador derivado possível:** `chuva_extrema_dias_ano` (precip > 10 mm/dia) ·
`dias_calor_extremo` (Tmax > 35 °C) · `dias_sem_chuva_sequencial` (≥ 5 dias, proxy
de seca) · `indice_conforto_termico_escolar`.

**Prioridade:** `[alta]` — 17 pontos

**Justificativa:** ⭐⭐⭐ + ⭐⭐ (API testada) + ⭐⭐ (ponto, exige join espacial) +
⭐⭐ (licença não verificada formalmente) + ⭐⭐ + ⭐⭐ + ⭐ (não há pacote oficial;
`httr`/`curl`) + ⭐⭐⭐ = **17**.

**Rastro:** `apitempo.inmet.gov.br/estacoes/T` (200) ·
`portal.inmet.gov.br/dadoshistoricos` (ZIPs) · `bdmep.inmet.gov.br` (200)

**Riscos / cuidados:**
- **147 das 673 estações estão `Pane`** — a série tem lacunas que **não** são só
  "sem estação", o que distorce médias se não for filtrado.
- A API **não é documentada** (caminhos inferidos por convenção) → risco de
  mudança de rota sem aviso. Intervalos longos de resposta podem dar **HTTP 204**.
- Granularidade pontual exige **método explícito de agregação espacial** (o mesmo
  do kernel de distância já usado no IVET), senão há viés de densidade de estação
  entre regiões.

---

### IBAMA — Portal de Dados Abertos (CKAN)

| Campo | Valor |
|---|---|
| **URL** | https://dadosabertos.ibama.gov.br/ · `api/3/action/package_search` |
| **Mantenedor** | IBAMA |
| **Licença** | **mista por dataset** — "Outra (Aberta)" (26), "Public Domain" (26), ODbL (7), CC-BY (4), "Open" (2), ⚠️ **5 sem licença declarada** |
| **Formato** | CSV / JSON / XML / HTML / GeoJSON / SHP-ZIP / WMS |
| **Granularidade** | município (agregados) e ponto/polígono (licenças, acidentes) |
| **Periodicidade** | mensal / trimestral (varia por dataset) |
| **API/SDK oficial** | **sim — API CKAN pública, sem autenticação** |
| **Cobertura temporal** | desde 2021-09 (mais antigos) a 2026-09 |
| **Cobertura geográfica** | nacional (**federal apenas** — estadual não coberto) |
| **LGPD** | baixo nas bases licenciatórias (razão social/CNPJ de terceiros, sem pessoa física); atenção a bases de **autuação** — avaliar caso a caso |

**Verificação (2026-09-30)**: `GET /api/3/action/package_search?rows=100` →
**HTTP 200**, `result.count = 79`, sem token. Datasets-chave confirmados:
*"Licenças ambientais de atividades e empreendimentos licenciados pelo Ibama"*
(Domínio Público, mod. 2026-05-29); *"Siema — Comunicado de Acidente Ambiental"*
(ODbL, CSV/GeoJSON/SHP-ZIP); *"Emissões de Poluentes Atmosféricos"*; *"Termos de
Embargo"* (ODbL); *"Fiscalização — auto de infração"* (24 recursos).
⚠️ `dados.gov.br/api/3/action/...` → **HTTP 401** (CKAN federal exige credencial),
logo `dadosabertos.ibama.gov.br` é a **única** rota de descoberta confiável.

**Relevância para o EduMaps:** três subconjuntos servem de fato: **Siema** (acidentes
ambientais), **Emissões Atmosféricas** e **Licenças ambientais**. Cruzar escola com
licença/auto/auto de infração no entorno dá **exposição a passivo ambiental
industrial** — eixo de vulnerabilidade que o IVET hoje não tem.

**Indicador derivado possível:** `licenca_ambiental_no_raio_1km` ·
`auto_infracao_ambiental_no_municipio_12m` · `comunicado_acidente_ambiental_proximo` ·
`emissao_atmosferica_municipio` · `area_embargada_no_municipio`.

**Prioridade:** `[média]` — 13 pontos, rebaixada

**Justificativa:** ⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐ = **13**, rebaixada por
três motivos verificados: (a) **SISLIC — exatamente o item pedido — é transacional
e exige login**, logo não há dado aberto de licenciamento *em si*; (b) as licenças
relevantes estão no CKAN, mas o restante do IBAMA está em PowerBI/ArcGIS, exigindo
engenharia reversa; (c) 5 dos 79 datasets **não têm licença declarada**.

**Rastro:** `dadosabertos.ibama.gov.br/api/3/action/package_search` (200, 79 datasets)

**Riscos / cuidados:**
- **Nunca raspar PowerBI** (embed token dinâmico) — usar apenas o CKAN.
- `sisfogo.ibama.gov.br/portal/sharing/rest/content/groups` → **HTTP 400**: não há
  API pública de conteúdo.
- A licença **varia por dataset**: checar `license_title` **para cada** antes de publicar.
- Cobertura **estritamente federal** → municipalities com licenciamento delegado
  ao estado ficam sem dado (descontinuidade territorial).

---

### CEMADEN — alertas e riscos geo-hidrológicos

| Campo | Valor |
|---|---|
| **URL** | https://www.gov.br/cemaden/pt-br/ · https://georisk.cemaden.gov.br/ · https://painelalertas.cemaden.gov.br/ |
| **Mantenedor** | CEMADEN — Centro Nacional de Monitoramento e Alertas de Desastres Naturais (MCTI) |
| **Licença** | não verificada |
| **Formato** | painéis web; sem API |
| **Granularidade** | município (alertas) / bacia e setor de encosta (risco) |
| **Periodicidade** | diária (risco previsto) / mensal (boletins) |
| **API/SDK oficial** | **não** — 10 rotas `/api/*` testadas no GeoRisk, todas 404 |
| **Cobertura temporal** | não verificada |
| **Cobertura geográfica** | nacional |
| **LGPD** | sem risco |

**Verificação (2026-09-30)**: home → HTTP 200 (redireciona para `gov.br/cemaden`).
`georisk.cemaden.gov.br/api/{risco,risks,alertas,municipios,v1/riscos,geojson,
previsao,health,dados}` → **todos 404**. `plataforma.cemaden.gov.br`,
`alerta.cemaden.gov.br`, `apiv2.cemaden.gov.br`, `dados.cemaden.gov.br` →
**todos ENOTFOUND**. A página *"Pesquisadores fazem recomendações para redução de
riscos nas redes de ensino brasileiras"* é oficial — ou seja, o mandato bate
perfeitamente com o IVET.

**Relevância para o EduMaps:** é **o** órgão cujo mandato é alertas de desastres,
com programa **AlertaGeo** e **GeoRisk** — continuação natural do INMET em espaço
e tempo.

**Indicador derivado possível:** `alerta_geo_escolar_no_municipio` ·
`risco_deslizamento_30d` · `setor_encosta_alta_susceptibilidade` ·
`dias_risco_hidro_12m` · `bacia_hidrocritica`.

**Prioridade:** `[média]` — 11 pontos, rebaixada

**Justificativa:** soma 11 pela régua mecânica, rebaixada por **dois bloqueios**:
**API = 0** e **licença = 0**. Sem API, o acesso seria scraping de painel — o que
o método manda penalizar.

**Rastro:** `georisk.cemaden.gov.br` (200, título "GeoRisk") ·
`painelalertas.cemaden.gov.br` (200) · página de recommendations em `gov.br/cemaden`

**Riscos / cuidados:**
- GeoRisk é app **Next.js**; sem rota `/api/*`, ingerir exigiria reverter o bundle
  JS — frágil e proibido.
- **Recomendação**: tratar o CEMADEN como fonte de **boletins PDF**
  (`monitoramento-hidrologico`, `impactos-seca`, estáticos) e deixar o tempo real
  para o INMET. **Reavaliar para `[alta]` se abrir API.**

---

### INPE / Terrabrasilis — PRODES e DETER

| Campo | Valor |
|---|---|
| **URL** | `terrabrasilis.dpi.inpe.br/geoserver/ows?service=WFS&request=GetCapabilities` |
| **Mantenedor** | INPE — DGI/TERRA |
| **Licença** | não verificada |
| **Formato** | OGC WFS 2.0 / WMS 1.3.0 — GeoJSON, GML, CSV, shapefile |
| **Granularidade** | polígono (desmatamento), bioma |
| **Periodicidade** | anual (PRODES acumulado) / quinzenal (DETER) |
| **API/SDK oficial** | **sim** (padrões OGC, sem autenticação) |
| **Cobertura temporal** | PRODES desde 1988; DETER desde 2007 |
| **Cobertura geográfica** | nacional (todos os biomas) |
| **LGPD** | sem risco — sensoriamento remoto |

**Verificação (2026-09-30)**: `GetCapabilities` → **HTTP 200**, `application/xml`,
**93 camadas** WFS, incluindo `prodes-cerrado-nb:accumulated_deforestation_2000`,
`prodes-amazon-nb:accumulated_deforestation_2007_biome`, `deter-amz:deter_amz`,
`prodes-brasil-nb:biomas_brasil`. WMS → **194 camadas** (versões pt-BR).
⚠️ **`servicos.terrabrasilis.gov.br` NÃO resolve DNS** (ENOTFOUND) — a API foi
movida; `/download/` retorna **403**.

**Relevância para o EduMaps:** uso **indireto**. Desmatamento é proxy de pressão
sobre a rede (perda de vegetação e solo, obras de drenagem, transformação
territorial) e de **dinâmica territorial** no município que circunda a escola.

**Indicador derivado possível:** `desmatamento_acumulado_5a_no_raio5km` ·
`taxa_desmatamento_recente_no_municipio` · `perda_vegetacao_nativa_10a`.

**Prioridade:** `[média]` — 9 pontos, rebaixada

**Justificativa:** ⭐⭐ (API OGC) + ⭐⭐ (nacional) + ⭐⭐ (periodicidade) + ⭐
(pacote R via `sf`) = **9**, mas **rebaixada de `[alta]` para `[média]`**: não
atende a dois critérios de peso 3 — *endereça lacuna direta* (desmatamento não é
evento extremo nem clima) e *complementa Censo/OSM/SIOPE* — e a licença não foi
verificada, o que o método manda penalizar.

**Rastro:** `terrabrasilis.dpi.inpe.br/geoserver/ows` (200, 93 camadas WFS)

**Riscos / cuidados:**
- **Correção de atribuição**: PRODES/DETER são do **INPE**, não do IBAMA.
- **A API mudou de host**: qualquer código apontando para
  `servicos.terrabrasilis.gov.br` está quebrado.
- `/download/` em **403** → a ingestão tem de ser por WFS/WMS, não por arquivo.
- **DETER é não-oficial por desenho** (alerta com taxa de falso positivo) — não
  usar como dado definitivo.
- Cuidado ao comparar anos pré/pós-2016: a resolução efetiva do sensor limita a
  série histórica.

---

### CPTEC / INPE — diagnóstico e previsão

| Campo | Valor |
|---|---|
| **URL** | https://clima.cptec.inpe.br/ · `ftp.cptec.inpe.br/clima/` · https://pclima.inpe.br/ |
| **Mantenedor** | CPTEC — Centro de Previsão de Tempo e Estudos Climáticos (INPE/MCTI) |
| **Licença** | não verificada |
| **Formato** | diretórios FTP/HTTPS com notas técnicas PDF; sem API |
| **Granularidade** | grade (~5–25 km, por produto) — não verificada |
| **Periodicidade** | mensal / trimestral (sazonal: OND, SON, JAS…) |
| **API/SDK oficial** | **não** (nenhuma OWS/OPeNDAP encontrada) |
| **Cobertura temporal** | não verificada |
| **Cobertura geográfica** | nacional |
| **LGPD** | sem risco |

**Verificação (2026-09-30)**: `clima.cptec.inpe.br` → 200; notas técnicas de OND,
SON, ASO, JAS, JJA, AMJ, MAM, FMA, JFM **todas acessíveis**. `ftp.cptec.inpe.br/clima/`
→ 200, índice Apache com `dados/prec/`, `INMET/analises/`, `pldsdias/` (série
`cams_opi_merged.2021NN` a partir de 01/2021), `MultiModelo/`, `boletins/`.
`pclima.inpe.br` → 200 mas título agora é **"Projeções Climáticas no Brasil"**
(mudou de escopo).

**Relevância para o EduMaps:** o CPTEC serve à **previsão e ao diagnóstico**
(El Niño/La Niña, anomalias), não à série observacional. Para o IVET, o valor é
**contexto de risco sazonal**: uma escola no semiárido sob La Niña tem risco de
seca prolongado diferente do mesmo município sob El Niño.

**Indicador derivado possível:** `indice_enso_12m` (ONI) como covariável de
moderação · `anomalia_precipitacao_trimestre` · `risco_sazonal_seca_ou_enchente_escolar`.

**Prioridade:** `[média]` — 9 pontos, rebaixada

**Justificativa:** soma 9 pela régua mecânica, rebaixada por **dois bloqueios
duros verificados**: **API/SDK = 0** (só listagem de diretório web — acesso
frágil por construção) e **licença = 0**.

**Rastro:** `clima.cptec.inpe.br` (200) · `ftp.cptec.inpe.br/clima/` (200, índice)

**Riscos / cuidados:**
- O "acesso" verificado é **listagem de diretório web**, não API — consumir isso é
  frágil por construção.
- `pldsdias/` (CAMS OPI merged, precipitação diária) é a pérola desse
  diretórios e **merece ser testado diretamente** antes de descartar a fonte.
- `queimadas.cptec.inpe.br` falha por certificado TLS com nome alternativo inválido.

---

### INPE — Programa Queimadas

| Campo | Valor |
|---|---|
| **URL** | https://queimadas.dgi.inpe.br/ → https://terrabrasilis.dpi.inpe.br/queimadas/portal/ |
| **Mantenedor** | INPE — DGI, Programa Queimadas |
| **Licença** | não verificada |
| **Formato** | shapefile/GeoJSON de download — **formato não verificado** |
| **Granularidade** | polígono de cicatriz de fogo |
| **Periodicidade** | anual e mensal |
| **API/SDK oficial** | não (portal com seção "Dados para download") |
| **Cobertura temporal** | não verificada |
| **Cobertura geográfica** | nacional |
| **LGPD** | sem risco |

**Verificação (2026-09-30)**: redirect → 200, título "Programa Queimadas • INPE",
com seções "Sistemas", "Dados para download", "Relatórios". ⚠️ **os links de
download não estão no HTML estático** (app JS) → formato e intervalo temporal
**não verificados**.

**Relevância para o EduMaps:** fraca de forma direta. Fogo é fator de
**tenacidade do território**: proximidade a cicatrizes recorrentes afeta acesso
rodoviário, qualidade da água e cobertura vegetal perto da escola.

**Indicador derivado possível:** `frequencia_queimada_5a_no_raio2km` ·
`ano_do_ultimo_fogo_no_municipio` · `severidade_queimada_media_no_raio`.

**Prioridade:** `[baixa]` — 9 pontos, rebaixada por **redundância**

**Justificativa:** soma 9 pela régua mecânica, rebaixada para `[baixa]`: o
**MapBiomas Fogo entrega a mesma informação** (mapas anuais e mensais desde 1985)
com **CC BY 4.0** e **download COG público direto**, contra licença não
verificada e download manual aqui.

**Rastro:** `queimadas.dgi.inpe.br` → 200 → `terrabrasilis.dpi.inpe.br/queimadas/portal/`

**Riscos / cuidados:** **`CNTramas` não existe** (DNS) — provável confusão com
este programa ou com o MapBiomas. Como os links são renderizados por JS, a
ingestão exigiria raspar a app — redundante.

---

### SGB (ex-CPRM) — setorização e áreas de risco

| Campo | Valor |
|---|---|
| **URL** | https://www.sgb.gov.br/ · https://geoportal.sgb.gov.br/portal/home/ |
| **Mantenedor** | SGB — Serviço Geológico do Brasil (MCTI) |
| **Licença** | não verificada |
| **Formato** | produtos por município; sem API |
| **Granularidade** | **setor de risco (bairro/quadra)** — a mais fina do lote |
| **Periodicidade** | irregular (sob demanda/projeto específico) |
| **API/SDK oficial** | **não** (sem GeoServer público — `/geoserver/ows` → 404) |
| **Cobertura temporal** | n/a (produtos pontuais) |
| **Cobertura geográfica** | ⚠️ **parcial — não há produto nacional** |
| **LGPD** | sem risco |

**Verificação (2026-09-30)**: home → 200. Sitemap (1.048 URLs) **não expõe nenhum
path de risco** — os hits são todos notícias de mapeamentos específicos
(São Roque/MG, Xapuri e Brasiléia/AC, Porto Esperidião/MT, Sarutaia/SP, Aracati/CE,
São Sebastião do Pajeú/BA) e **Planos Municipais de Redução de Riscos** em Rio
Branco/AC, Aracati/CE e Tucuruí/PA. URLs canônicas candidatas **todas 404**:
`/riscos`, `/setorizacao`, `/vulnabilidades`, `/areas-de-risco`.

**Relevância para o EduMaps:** a mais **direta conceitualmente** — é literalmente
o mapeamento que define onde uma escola **não pode** ser construída — mas a mais
**inviável operacionalmente**: **não existe produto nacional**.

**Indicador derivado possível:** `escola_em_setor_risco_alto` · `setor_risco_tipo_1a4` ·
`distancia_a_setor_risco`.

**Prioridade:** `[baixa]` — 8 pontos, rebaixada

**Justificativa:** soma 8 pela régua mecânica, **rebaixada** por acionar a regra
*"sem cobertura nacional"* — e aqui é pior: não há nem produto estadual. A soma só
se sustenta porque *endereça* (⭐⭐⭐) e *granularidade* (⭐⭐⭐) são reais, mas a
ausência de cobertura e de API anula o valor prático.

**Rastro:** `sgb.gov.br` (200) · `geoportal.sgb.gov.br` (404 em `/geoserver/ows`)

**Riscos / cuidados:**
- O dado é produzido **município a município, sob projeto específico e por
  solicitação** — sem catálogo, sem endpoint, sem índice espacial. Coletar exigiria
  garimpar notícia por notícia.
- **Caminho alternativo obrigatório**: construir a camada de risco a partir de
  **GeoRisk/CEMADEN + INMET Alerta-AS + MapBiomas Solo** (declividade, altura da
  drenagem, ISH), que são nacionais e automatizáveis; e tratar o SGB como fonte
  **complementar sob demanda** (se um município-alvo for atingido, pedir o produto
  via ofício, no escopo de acesso à informação).

---

### MMA — Portal de Dados Abertos

| Campo | Valor |
|---|---|
| **URL** | https://www.gov.br/mma/pt-br/acesso-a-informacao/dados-abertos |
| **Mantenedor** | MMA — Ministério do Meio Ambiente e Mudança do Clima |
| **Licença** | não verificada — **o portal está vazio** |
| **Formato** | não verificado — nenhum formato publicado |
| **Granularidade** | não verificado |
| **Periodicidade** | não verificado |
| **API/SDK oficial** | não (verificado: nenhuma API) |
| **Cobertura temporal** | não verificado |
| **Cobertura geográfica** | não verificado |
| **LGPD** | não verificado |

**Verificação (2026-09-30)**: a página retorna **HTTP 200 (190.041 bytes) mas não
contém `id="content-core"` nem corpo de artigo** — só navegação. A subpágina de
"disponibilização das bases no PDA do órgão" → 200, **também só navegação**.
`qualar.mma.gov.br`, `geoserver.mma.gov.br`, `plataforma.brasil.gov.br` →
**ENOTFOUND**.

**Relevância para o EduMaps:** **praticamente nula na forma atual.** O catálogo
institucional lista seções relevantes (Controle do Desmatamento, Queimadas,
Qualidade do Ar, Zoneamento, Áreas Contaminadas), mas são **páginas de conteúdo,
não dados abertos**.

**Indicador derivado possível:** nenhum viável enquanto o portal estiver vazio. Se
o Qualar voltar: `pm25/pm10_media_anual` e `dias_acima_do_limite` por município.

**Prioridade:** `[baixa]` — 1 ponto

**Justificativa:** ⭐ (parcial) e **todos os outros critérios = 0** — API
inexistente, granularidade/licença/cobertura/periodicidade não verificadas, sem
pacote R, sem complementaridade demonstrada. **Nenhum** campo de produto confirmado.

**Rastro:** `gov.br/mma/.../dados-abertos` (200, sem corpo)

**Riscos / cuidados:** não consumir o MMA por *scraping* de páginas
institucionais — seria frágil e, no caso do Boletim do Fogo, redundante com o
MapBiomas Fogo.

---

## Síntese do lote

| Fonte | Prioridade | Pontos | Motivo |
|---|---|---|---|
| **MapBiomas** | 🟢 `[alta]` | 19 | Melhor fonte do lote: edificação exposta a risco, 30 m, CC BY 4.0, COG público. |
| **INMET Alerta-AS** | 🟢 `[alta]` | 18 | Mede o evento que **interrompe a aula**, com código IBGE no payload. |
| **INMET séries diárias** | 🟢 `[alta]` | 17 | 26 anos de série diária, API sem auth. |
| **IBAMA (CKAN)** | 🟡 `[média]` | 13 | Passivo ambiental industrial; **SISLIC não é dado aberto**. |
| **CEMADEN** | 🟡 `[média]` | 11 | Mandato perfeito, **mas sem API** — só boletins PDF por enquanto. |
| **Terrabrasilis (PRODES/DETER)** | 🟡 `[média]` | 9 | Uso indireto (pressão territorial); licença não verificada. |
| **CPTEC** | 🟡 `[média]` | 9 | Contexto sazonal; **só listagem de diretório**, sem API. |
| **INPE Queimadas** | 🔴 `[baixa]` | — | **Redundante** com MapBiomas Fogo. |
| **SGB setorização** | 🔴 `[baixa]` | 8 | Conceito ideal, **sem produto nacional**. |
| **MMA (PDA)** | 🔴 `[baixa]` | 1 | Portal **vazio** — nenhum produto. |

**Correções de registro**: `CNTramas` não existe; **SISLIC não é dado aberto**
(exige login); **PRODES/DETER são do INPE**, não do IBAMA; CPTEC não publica
"grades subtropical".

**Ordem de implementação sugerida** (verificada, join direto por IBGE, licença
aberta): **1)** INMET Alerta-AS · **2)** MapBiomas (começando por Solo + Índice de
Segurança Hídrica) · **3)** INMET séries diárias · **4)** IBAMA (Siema +
Licenças + Emissões, via CKAN) · **5)** Terrabrasilis · **6)** CEMADEN (só
boletins até abrir API) · **7)** CPTEC · **8)** SGB (sob demanda, por ofício).