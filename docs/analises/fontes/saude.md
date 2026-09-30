# Fontes — Saúde

> Lote D da issue #123 · lacuna do IVET nº 1 (**saúde** e determinantes
> sociais de saúde).
> Método, pesos e regras: [`../fontes_de_dados.md`](../fontes_de_dados.md).

**Achado central do lote**: existem **duas fontes `[alta]`** e elas são
complementares — o **DATASUS** entrega a *demanda* e a *efetividade* do cuidado em
chave IBGE, o **CNES** entrega a *oferta em ponto* com coordenada. Juntas
transformam o bloco "saúde" do IVET em algo **cartografável**.

**Achado mais importante do lote inteiro** (verificado em *payload de produção*,
não inferido): a API de Dados Abertos do SUS publica, sem mitigação,
**microdados individuais de saúde**. Isso não é hipótese de risco — foi lido. Ver
a seção "🔴 LGPD — verificado em payload" abaixo, que é pré-requisito de
arquitetura para qualquer pipeline que toque a saúde.

**Correção de premissa**: a fonte canônica de saúde *escolar* não é a **PNS**
(última edição **2019**), e sim a **PeNSE** (edição **2024**, publicada em
25/03/2026) — que é a **única** do lote com microdado em **nível de escola**.

---

### DATASUS — transferência de arquivos + Portal/API de Dados Abertos do SUS

| Campo | Valor |
|---|---|
| **URL** | https://datasus.saude.gov.br/ · transferência https://datasus.saude.gov.br/transferencia-de-arquivos/ · portal aberto https://dadosabertos.saude.gov.br/ · **API oficial (Swagger): https://apidadosabertos.saude.gov.br/** |
| **Mantenedor** | Ministério da Saúde — DATASUS/SEIDIGI (transferência) e DEMAS (portal/API) |
| **Licença** | conteúdo do portal DATASUS: **CC BY-ND 3.0 Não Adaptada** (rodapé verificado). Portal de Dados Abertos do SUS: **CC BY 3.0**. A API declara `license: MIT` no `swagger.json` — mas isso cobre o **código da API**, não necessariamente os dados |
| **Formato** | transferência: DBC, DBF, CSV, XLSX, ZIP. API REST: **JSON** e `text/csv` (declarado em `responses.200.content`) |
| **Granularidade** | **município** (chave IBGE confirmada em payload) e **ponto** (estabelecimento com lat/long) |
| **Periodicidade** | **mensal** a anual, conforme o sistema: snapshots mensais de CNES/SISAB, séries anuais de SIM/SINASC/SIH/SIA, séries de vacinação por ano (endpoints `/vacinacao/doses-aplicadas-pni-2020`…`-2026`) |
| **API/SDK oficial** | **sim (HTTP/REST)** — `https://apidadosabertos.saude.gov.br/<tag>/<recurso>`, Swagger **1.8.32**, 17 grupos: `atencao-primaria`, `cnes`, `sisvan`, `vacinacao`, `arboviroses`, `saude-indigena`, `vigilancia-e-meio-ambiente`, `educacao-em-saude`, `assistencia-a-saude`, `sisagua`, `daf`, `economia-da-saude`, `prevencao-e-promocao`, `outros-temas`, `macrorregiao-e-regiao-de-saude`, `ciencia-tecnologia`, `ouvidoria`. **Pacotes R no CRAN**: `datasus`, `datasusr` (0.1.1), `microdatasus` (3.0.0), `healthbR` |
| **Cobertura temporal** | desde **1994** (Imunizações/Nascidos Vivos); mortalidade CID-10 desde 1996; vacinação 2020–2026; CNES/SISAB com histórico mensal |
| **Cobertura geográfica** | nacional (UF + município + macrorregião/região de saúde) |
| **LGPD** | ⚠️ **MIXTA — risco alto se usados os endpoints errados.** Agregados municipais (SISAB/PMMB, macrorregião) são seguros; alguns endpoints devolvem **nível individual** (ver seção dedicada) |

**Verificação (2026-09-30)** — chamadas ao vivo, sem autenticação:
- `apidadosabertos.saude.gov.br/static/swagger.json` → **200**, `version: 1.8.32`
- `/atencao-primaria/pmmb-serie-historica?limit=1` → **200** (`dt_referencia: "29/11/2013"`)
- `/atencao-primaria/pmmb-consolidado?limit=1` → **200** (`co_ibge: 530010`, `cobertura`, `ativas_ff`, `total_vagas_ativas`, `equipe_esf`, `equipe_emsi`, **`categoria_ivs`**) — `categoria_ivs` é uma **categoria de vulnerabilidade social do Ministério da Saúde**, complementar ao IVET
- `/macrorregiao-e-regiao-de-saude/municipio?limit=1` → **200** (`codigo_municipio`, **`populacao_estimada_ibge_2022`** — denominador útil)
- `/arboviroses/dengue`, `/educacao-em-saude/pvc` → **200**
- `datasus.saude.gov.br/transferencia-de-arquivos/` → **200**, mas **é um formulário POST**, não URL direta de arquivo
- `http://tabnet.datasus.gov.br/cgi/defindex.htm` → **404** (URL canônica antiga do Tabnet está morta)

**Relevância para o EduMaps:** fecha a lacuna mais direta do IVET com o menor
custo de engenharia. Cobertura de Atenção Primária (eSF/eMultiequipes) por
município, produção ambulatorial (SIA), internação (SIH), mortalidade (SIM),
nascimentos (SINASC), doenças comunicáveis (SINAN) — tudo em `cod_ibge`, chave
que o EduMaps **já usa**. Combinada com o **SISAB** (que está dentro desta
mesma fonte), mede-se **efetivo** de APS, não apenas cadastro.

**Indicador derivado possível:**
- `iv_saude_cobertura_aps` = (Σ `ativas_ff` + `equipe_esf`) ÷ população IBGE × 10.000
- `iv_saude_aps_efetividade` = `total_ocupadas` ÷ `total_vagas_ativas` (vagas ocupadas vs. autorizadas)
- `iv_saude_morbidade` = internações evitáveis (ICSVD) por município, ou internações ÷ matrículas
- `iv_saude_mortalidade` = taxas brutas de mortalidade geral, infantil e por causas externalizáveis (CID-10) do SIM
- `iv_saude_carga_doenca` = incidência de dengue por município
- `iv_saude_territorio` = z-score composto dos anteriores, integrado ao IVET como bloco "Saúde" com peso explícito

**Prioridade:** `[alta]` — 17 pontos

**Justificativa:** ⭐⭐⭐ (endereça a lacuna) + ⭐⭐ (API oficial estável,
documentada, sem autenticação) + ⭐⭐⭐ (granularidade municipal confirmada em
payload real) + ⭐⭐ (cobertura nacional) + ⭐⭐ (periodicidade mensal/anual) +
⭐ (pacotes R prontos) + ⭐⭐⭐ (complementa Censo/OSM/SIOPE com dimensão que
eles não têm) = **17**. **Descontos aplicados**: licença **SemDerivações**
(CC BY-ND 3.0) é conflito conceitual direto com a construção de um *índice*
derivado → o critério de licença cai de ⭐⭐⭐ para ⭐⭐; e a existência de
endpoints com dados pessoais não mitigados obriga **allowlist explícita de
endpoints**, o que adiciona trabalho de engenharia. Mesmo assim, é a única fonte
do lote com API oficial + agregados municipais + chave IBGE.

**Rastro:** `datasus.saude.gov.br` **200** · `.../informacoes-de-saude-tabnet/`
**200** · `.../transferencia-de-arquivos/` **200** · `dadosabertos.saude.gov.br`
**200** · `apidadosabertos.saude.gov.br` **200** + 5 endpoints 200 acima ·
CRAN `datasus`/`datasusr`/`microdatasus`/`healthbR` **200** cada

**Riscos / cuidados:**
- 🔴 **LGPD — risco principal do lote.** Ver a seção dedicada abaixo.
- ⚠️ **Licença SemDerivações**: leitura literal, publicar um índice derivado é
  adaptação. Confirmar com o jurídico do órgão se a leitura "uso para pesquisa e
  produção de indicador público" se sobrepõe a ND; **documentar a decisão**.
- **Transferência de arquivos não é URL direta** (formulário POST). Para
  DBC/DBF automatizado a comunidade usa `ftp.datasus.gov.br` (citado pelo
  `healthbR` como fonte de CNES) — esse host **não respondeu** neste ambiente
  (**timeout**). Preferir a **API HTTP**.
- **Paginação obrigatória** (`limit` ≤ 1000; no CNES ≤ 20) — falha de ingestão
  silenciosa se não paginar.
- **Qualidade municipal desigual**: SIA/SINAN têm subnotificação histórica
  reconhecida. Tratar como *proxy*, com peso menor no IVET e incerteza explícita.

---

### CNES — Cadastro Nacional de Estabelecimentos de Saúde

| Campo | Valor |
|---|---|
| **URL** | portal https://cnes.datasus.gov.br/ · busca https://elasticnes.saude.gov.br/ · **API oficial: https://apidadosabertos.saude.gov.br/cnes/estabelecimentos** |
| **Mantenedor** | Ministério da Saúde — Secretaria de Atenção à Saúde (CNES NET) / DATASUS |
| **Licença** | **CC BY-ND 3.0 Não Adaptada** (rodapé verificado) — mesmo SemDerivações do resto do lote |
| **Formato** | **API REST: JSON e `text/csv`** (ambos declarados) · portal: DBF (download em massa, **não verificado**) |
| **Granularidade** | **estabelecimento (ponto)** — cada registro tem `codigo_cnes`, `codigo_municipio`, `latitude_estabelecimento_decimo_grau`, `longitude_estabelecimento_decimo_grau`. **Mais fina que município** e espacialmente juntável à escola |
| **Periodicidade** | **mensal** (snapshot por mês/UF, com `data_atualizacao` filtrável) |
| **API/SDK oficial** | **sim (HTTP/REST)** — `/cnes/estabelecimentos`, `/cnes/tipounidades`, `/cnes/tipounidades/{codigo}`, `/cnes/estabelecimentos/{codigo_cnes}`. Filtros verificados: `codigo_tipo_unidade`, `codigo_uf`, `codigo_municipio`, `status`, `data_atualizacao`, `limit` (**≤ 20**), `offset`. **Pacote R: `healthbR::cnes_*`** (baixa via `ftp.datasus.gov.br`) |
| **Cobertura temporal** | série mensal com histórico; **faixa exata não verificada** |
| **Cobertura geográfica** | nacional, com código IBGE e coordenadas |
| **LGPD** | ⚠️ **médio** — é cadastro de **estabelecimento**, não de paciente, mas a razão social **frequentemente é nome de pessoa física** (verificado em payload: `nome_razao_social: "FERNANDO NUNES AGUIAR"`, com CNPJ, endereço, telefone e e-mail) |

**Verificação (2026-09-30)**: `apidadosabertos.saude.gov.br/cnes/estabelecimentos?limit=1`
→ **200**, payload com `codigo_cnes: 9629866`, `codigo_municipio`, `codigo_tipo_unidade: 22`,
`latitude`/`longitude`, `endereco_email_estabelecimento`. Portal **200**;
`elasticnes.saude.gov.br` **200** (ElastiCNES 0.2.0). ⚠️
`s3.amazonaws.com/cnes/` → **404 `NoSuchBucket`** — o antigo bucket público de
CNES **não existe mais**; as rotas `/cnes/arquivos/...` de receitas antigas
estão **mortas**. `cnes.datasus.gov.br/services/arquivos-download/base-dados/` →
**503**.

**Relevância para o EduMaps:** é a peça que **transforma o bloco "saúde" do IVET
em algo cartografável**. O IVET é mapeado por escola; o CNES entrega a oferta de
saúde **em ponto**, com lat/long. Habilita indicadores de **acesso espacial** que
nenhuma outra fonte do lote oferece, e é o complemento perfeito ao OSM (que o
EduMaps já usa) e ao Censo (que dá o lado da demanda).

**Indicador derivado possível:**
- `iv_saude_dist_ubs` = **distância rodoviária/viária da escola até a UBS mais próxima** (haversine se não houver malha viária) — indicador forte, espacial, sem dado pessoal
- `iv_saude_aps_presenca` = nº de estabelecimentos tipo UBS/eSF por km² ou por mil matrículas
- `iv_saude_urgencia_proximidade` = existência e distância de SU/SUDEN com centro cirúrgico e obstétrico (resolutividade)
- `iv_saude_acesso_ponderado` = escore de acesso por distância-tempo simulado sobre a malha viária do OSM — **aproveita o pipeline de roteamento que o EduMaps já tem**

**Prioridade:** `[alta]` — 16 pontos

**Justificativa:** ⭐⭐ (endereça a lacuna de forma estrutural — oferta, não
morbidade, a dimensão mais defensável em termos de LGPD) + ⭐⭐ (API oficial
documentada, verificada ao vivo, sem autenticação, com filtro por município e
tipo de unidade) + ⭐⭐⭐ (granularidade de **ponto com coordenadas**, mais fina
que município, juntável à geometria da escola) + ⭐⭐ (cobertura nacional) +
⭐⭐ (periodicidade mensal) + ⭐ (pacote R: `healthbR`) + ⭐⭐⭐ (complementa
diretamente Censo/OSM/SIOPE) = **16**. **Descontos**: licença SemDerivações
(⭐⭐ em vez de ⭐⭐⭐) e o caminho de download em massa ser menos robusto que a
API (contornável). **Não cai em nenhum rebaixamento automático**: não exige
scraping, não é só estadual/nacional, tem licença CC, e o risco LGPD é de
**dados de profissionais, não de pacientes**.

**Rastro:** `cnes.datasus.gov.br` **200** · `elasticnes.saude.gov.br` **200** ·
`apidadosabertos.saude.gov.br/cnes/estabelecimentos?limit=1` **200** ·
`s3.amazonaws.com/cnes` **404** · CRAN `healthbR` **200**

**Riscos / cuidados:**
- ⚠️ **Sanear na ingestão, não depois.** Descartar na entrada:
  `nome_razao_social`, `nome_fantasia`, `numero_cnpj_entidade`,
  `numero_telefone_estabelecimento`, `endereco_email_estabelecimento`,
  `endereco_estabelecimento`/`bairro`. Manter apenas `codigo_cnes`,
  `codigo_municipio`, `codigo_tipo_unidade`, `status`, lat/long,
  `data_atualizacao`. Sem isso o CNES carrega **nomes de profissionais de saúde**
  no banco — dado pessoal desnecessário para o IVET.
- **Paginação obrigatória** (`limit` ≤ 20) e ~400 mil estabelecimentos ⇒ ~20 mil
  requisições se o limite não for respeitado. **Não baixar tudo**: filtrar por
  `codigo_tipo_unidade` (UBS, SU, hospital) e pelo recorte do estudo.
- **Rota de download em massa não é confiável** (bucket S3 morto, `services/` em
  503). **Priorizar sempre a API HTTP**; FTP apenas como fallback, com cache
  local versionado (o modelo que o `healthbR` já implementa).
- **Cobertura histórica só como snapshot mensal**: a API não expõe série. Manter
  `dt_snapshot` na tabela, ou perder a série temporal.
- **`status` e `data_atualizacao` são essenciais**: estabelecimento desativado
  (`status=0`) com geometria válida contamina o indicador.
- **Presença cadastral ≠ operação**: combiner **obrigatoriamente** com o SISAB
  para medir efetivo, não cadastro.
- **Viés de localização**: UBS de interior podem estar subcadastradas ou com
  geometria imprecisa — distância mínima é indicador com **incerteza explícita**.

---

### IBGE — PeNSE (Pesquisa Nacional de Saúde do Escolar) e PNS 2019

> **Correção de premissa**: a fonte canônica de saúde *escolar* é a **PeNSE**,
> não a PNS. A edição mais recente da PNS é **2019**; a PeNSE tem edições
> **2009, 2012, 2015, 2019 e 2024** — a **2024 publicada em 25/03/2026**. E a
> PeNSE é a **única fonte do lote com microdado em nível de escola**.

| Campo | Valor |
|---|---|
| **URL** | PeNSE (microdados): **https://svs.aids.gov.br/daent/cgdnt/pense/** · PNS: **https://ftp.ibge.gov.br/PNS/** · API de pesquisas: https://servicodados.ibge.gov.br/api/v1/pesquisas/ |
| **Mantenedor** | IBGE (produção/divulgação); PeNSE é **IBGE + Ministério da Saúde + Ministério da Educação** (dados também hospedados pelo MS/SVSA-CGDNT) |
| **Licença** | microdados IBGE: uso livre com atribuição, sob o **Decreto nº 4.657/1942 (art. 4º, III — livre cópia para fins exclusivos de ensino e pesquisa não comercial)** — leitura conservadora: uso institucional/acadêmico OK, **redistribuição dos microdados brutos é limitada**. Portal gov.br: CC BY-ND 3.0. ⚠️ **licença específica da PeNSE não verificada** |
| **Formato** | microdados: TXT, CSV, **XLSX e RData (`.rdata`)**, SAS `.sas7bdat` · API IBGE: JSON · dicionários: XLS/XLSX · questionários e notas: PDF |
| **Granularidade** | **escola** (PeNSE: questionário da escola + questionário do estudante, microdado por escola, com município) e **domicílio/pessoa** (PNS, com pesos e códigos de município/UF) |
| **Periodicidade** | **quinquenal** — PeNSE 2009/2012/2015/2019/2024. Compatível com o plano decenal de saúde e educação, **não** com ciclo anual |
| **API/SDK oficial** | **sim (HTTP/JSON)** — `/api/v1/pesquisas` (catálogo), `/pesquisas/10056/periodos`, `/pesquisas/10056/periodos/2024/indicadores` (árvore completa, ids 91315–91391). **Pacotes R: `PNSIBGE` (0.2.1)** e `healthbR::pns_*`. ⚠️ **não há pacote R oficial para PeNSE** |
| **Cobertura temporal** | PNS: **2013 e 2019** (o FTP só tem esses dois). PeNSE: 2009, 2012, 2015, 2019 com microdados publicados (2024: **microdado não verificado**) |
| **Cobertura geográfica** | nacional, com recortes UF e município (via pesos/códigos) |
| **LGPD** | 🔴 **risco alto — dado individual sensível de saúde.** PNS: pessoas + domicílios, com antropometria, exames, medicamentos. PeNSE: **menores de 13–17 anos**, com violência, saúde mental, sexualidade. Dados de **crianças e adolescentes** acionam o **ECA** e o art. 14 do Marco Civil. **Microdados não anonimizados** |

**Verificação (2026-09-30)**:
- `ftp.ibge.gov.br/PNS/` → **200**, listando **somente** `2013/`, `2019/`, `Documentacao_Geral/` → **confirma PNS 2019 como edição mais recente**
- `ftp.ibge.gov.br/PNS/2019/Microdados/Dados/PNS_2019_20220525.zip` → **206**, header `PK` (existe)
- `svs.aids.gov.br/daent/cgdnt/pense/` → **200**, com `microdados-PeNSE-2009-csv.zip`, `-2012-escolas.xlsx`, `-2015-amostra1/2-csv.zip`, `-2019-csv.zip`, `-2019-xlsx.zip`, `-2019-sas7bdat.zip`, dicionários, `questionario-aluno/escola-PeNSE-2019.pdf`, `nota-tecnica-01-2022.pdf`
- `.../pense/microdados-PeNSE-2019-xlsx.zip` → **206**, `bytes 0-300/95692207` (91 MB, existe)
- `.../pns/materiais-tecnicos/` → **200**, com `pns-2019-csv.zip` (43 MB), **`pns-2019-rdata.zip` (55 MB, contém `pns-2019.rdata` — formato nativo R!)**, dicionário, questionário e PDFs temáticos
- `servicodados.ibge.gov.br/api/v1/pesquisas` → **200**: registro `{"id":10056,"nome":"Pesquisa Nacional de Saúde do Escolar"}` com períodos 2015/2019/**2024 (publicado 25/03/2026)**; e `{"id":47,"nome":"Pesquisa Nacional de Saúde"}` com **apenas 2013 e 2019**
- `/pesquisas/10056/periodos/{2024,2019}/indicadores/1.13.2.1/resultados/BR` → **200 com corpo `[]`**; `/resultados` sem localidade → **500** → **agregados não disponíveis via esta API**
- `www.ibge.gov.br` e `sidra.ibge.gov.br` → **403** (Cloudflare) — páginas não verificáveis deste ambiente
- CRAN `PNSIBGE` **200** (0.2.1, GPL-3, autor Gabriel Assunção/IBGE); `healthbR` **200**

**Relevância para o EduMaps:** é a fonte que **mais diretamente fecha a lacuna do
IVET**, e a que nenhuma outra do lote entrega. A lista de indicadores da PeNSE
2024 foi lida na API do IBGE e inclui, textualmente: **"Faltaram aula por
motivos relacionados à própria saúde"** (1.13.2.1), **"Classificaram seu estado
de saúde como muito bom ou bom"** (1.13.1), **"Não foram vacinados contra o
HPV"** (1.13.3), "Autoavaliação em saúde mental foi negativa, nos 30 dias
anteriores" (1.10.2), "Classificados como inativos" (1.9.1.2), "Consumiram algum
alimento ultraprocessado no dia anterior" (1.7.1.1), **"Deixaram de ir à escola
porque não se sentiam seguros no trajeto casa-escola"** (1.12.1.1), "Em escolas
que informaram possuir pia… e oferecer sabão" (1.15.2). Esses itens são a
**dimensão "saúde" do IVET pronta-made**. E a PeNSE inclui **questionário da
escola** (estrutura, cantina, merenda) — a **única fonte que cruza saúde e escola
no mesmo registro**.

**Indicador derivado possível:**
- `iv_saude_absenteismo` = % de estudantes que faltaram por motivo de saúde nos 12 meses anteriores — **indicador-chave**, liga saúde a aprendizagem
- `iv_saude_autopercepcao` = % que avalia saúde como "muito bom/bom" (negativo quando baixo)
- `iv_saude_saude_mental` = % com autoavaliação negativa em saúde mental
- `iv_saude_sedentari` / `iv_saude_ultraprocessados` = % inativos / % consumiu AUP
- `iv_saude_vacinacao_hpv` = % não vacinados contra HPV
- `iv_saude_merenda_escolar` = % que consome merenda · `iv_saude_cantina` = % de escolas com cantina
- **Caminho agregação-first**: estimar por **município** (ou rede de ensino) via
  pesos de expansão, e só então espacializar por área de entorno (buffer
  500 m–1 km) com geometria do CNES/OSM. **Nunca publicar estatística por escola.**

**Prioridade:** `[média]` — 19 pontos, rebaixada

**Justificativa:** soma bruta a mais alta do lote (⭐⭐⭐ + ⭐⭐ + ⭐⭐⭐ + ⭐⭐ +
⭐⭐ + ⭐⭐ + ⭐⭐⭐ = **19**), **rebaixada** por dois motivos verificados:
1. **LGPD (razão dominante).** É o conjunto com **dado individual sensível de
   saúde de menores (13–17 anos)**, não agregado nem anonimizado. Dispara o
   art. 13 da LGPD *e* a proteção especial da criança e do adolescente. Sem
   governança (CEP/CONEP, ambiente controlado) **não deve entrar no pipeline**.
2. **Agregados não legíveis por máquina (verificado).** A API do IBGE devolve a
   árvore de indicadores da PeNSE 2024, mas o endpoint de **resultados** devolve
   `[]`. Ou seja: **metadados via API, valores só em PDF** — o que exigiria
   digitação ou scraping de PDF, exatamente o critério que manda rebaixar.
3. Planos quinquenais impedem acompanhamento de série curta (2015→2019→2024).

**Rastro:** `ftp.ibge.gov.br/PNS/` **200** · `pense/` **200** · dois ZIPs **206** ·
`api/v1/pesquisas` **200** · `/periodos/2024/indicadores` **200** ·
`/resultados/BR` **200 com `[]`** · CRAN `PNSIBGE` **200** · `healthbR` **200**

**Riscos / cuidados:**
- 🔴 **LGPD + ECA — bloqueio duro até haver governança.** Antes de qualquer
  ingestão: (i) projeto aprovado por CEP/Conep; (ii) ambiente controlado e
  isolado, **sem conexão** com a BD de desenvolvimento; (iii) DPO/encarregado
  designado; (iv) **regra de não persistência** — só tabelas agregadas no
  Postgres, nunca o microdado; (v) supressão de células com **n < 30** (ou
  n < 11, limiar conservador) em qualquer cruzamento geográfico.
- **Não publicar estatística por escola**, mesmo com supressão: indicador de
  saúde mental por escola, em município pequeno, é reidentificável. Agregar no
  mínimo a município; ideal, por rede de ensino ou área de entorno com
  k-anonimato verificado.
- **Resultados agregados não legíveis por máquina**: se a opção for usar só os
  indicadores publicados, o caminho hoje é **PDF** → risco alto de erro de
  transcrição. Alternativa: ler o microdado **dentro do ambiente controlado** com
  `PNSIBGE`/`healthbR` e exportar só agregados.
- **Mistura PeNSE/PNS**: pesquisas distintas, populações e pesos distintos.
  `PNSIBGE` só cobre PNS 2013/2019 — **não há pacote R oficial para PeNSE**,
  logo a ingestão do `.rdata`/`.xlsx` é escrita à mão.
- ✅ **O `.rdata` é uma dádiva** (55 MB verificado): `load()` direto evita
  descompressão DBC e join manual. Usar.
- **Decreto 4.657/1942 art. 4º, III** limita redistribuição dos microdados brutos —
  publicar só derivados, com atribuição ao IBGE/MS.
- **Não misturar 2013/2019 sem tratamento**: o IBGE tem nota oficial de retirada
  temporária de indicadores da PNS 2013 para recomparabilidade.

---

### CIDACS — Plataforma de Dados Desidentificados (PDD)

| Campo | Valor |
|---|---|
| **URL** | descrição/FAQ https://cidacs.bahia.fiocruz.br/pdd/ · portal **https://pdd.cidacs.org/** · metadados **https://dataverse.cidacs.org/** |
| **Mantenedor** | CIDACS — Centro de Integração de Dados e Conhecimentos para Saúde, laboratório do Instituto Gonçalo Moniz (Fiocruz, Bahia), criado em 2016 |
| **Licença** | PDD: **dados públicos e abertos** (o FAQ declara). Conteúdo do portal institucional: **CC BY-NC-SA 2.0 BR** — **restritiva (NonCommercial) e ShareAlike**. ⚠️ **licença por dataset não verificada** (a PDD orienta consultar a página do dataset no Dataverse) |
| **Formato** | **CSV** (app e biblioteca) · **CSV compactado `.zip`** via API · metadados em Dataverse (JSON/API) |
| **Granularidade** | **município** (agregados) e, em alguns datasets, **individualizado não-nominal desidentificado** — os dois coexistem na plataforma |
| **Periodicidade** | **variada por dataset** — *"implementa pipelines de atualização que se adequam aos intervalos de disponibilização/atualização da fonte"* |
| **API/SDK oficial** | **sim (HTTP + Python)** — API oficial + biblioteca Python (token por e-mail) + app desktop Windows. Em **R: apenas integrável** — **não há pacote R oficial verificado** |
| **Cobertura temporal** | varia por base; exemplo verificado na citação oficial: **SINASC desde 1996**. Catálogo inclui SIM, SINAN, SINASC, SIH, SIA, SISVAN, PNAD, Censo 2022, programas sociais, vacinação |
| **Cobertura geográfica** | nacional |
| **LGPD** | **mitigada por desenho**: dados "desidentificados (não-nominais), individualizados ou agregados"; LGPD aplicada via art. 4º/7º (pesquisa) e **art. 13 (estudos de saúde pública)**. Mitigações verificadas: cadastro obrigatório, perfil de acesso por dataset, **expiração de 60 dias**, download monitorado |

**Verificação (2026-09-30)**:
- `cidacs.bahia.fiocruz.br/pdd/` → **200**. FAQ confirma: *"A Plataforma de Dados
  Desidentificados (PDD) é **aberta**, isto é, qualquer usuário pode acessar"*;
  dados *"desidentificados (não-nominais), individualizados ou agregados"*; prazo
  de acesso *"atualmente é de **60 dias**"*; datasets citados: SIM, SINAN,
  SINASC, Censo Demográfico 2022; suporte `pdd.cidacs@gmail.com`
- `cidacs.bahia.fiocruz.br/o-cidacs-e-a-lgpd/` → **200**. Texto da Plataforma de
  Dados Integrados: *"O acesso aos dados integrados e anonimizados produzidos no
  Cidacs é **restrito**"*; exige vínculo, **projeto com parecer favorável do
  CEP/Conep**, plano de dados, termos assinados, análise **presencial ou via VPN
  2F**; *"Os dados, mesmo anonimizados, **não podem ser baixados**. Somente é
  permitido obter dados agregados"*
- `pdd.cidacs.org/` **200** · `dataverse.cidacs.org/` **200** (6.985 downloads;
  coleções "PDD Cidacs", "Cidacs NIHR", "Gates", "Plataforma de vigilância de long...")

**Relevância para o EduMaps:** responde à pergunta direta do lote — **o acesso
público existe: SIM**. É uma camada pública, gratuita e aberta de dados de saúde
desidentificados, com metadados catalogados, dicionários e API. **Verificação
negativa importante**: a **Plataforma de Dados Integrados** (o produto de *record
linkage* com dados nominais) **NÃO é pública**.

**Indicador derivado possível:**
- `iv_saude_notificacoes` = dengue, sarampo, tuberculose, meningite, hanseníase por município e ano, em taxa por 10.000 — risco epidemiológico do território da escola
- enriquecimento com **covariáveis já harmonizadas** (renda, transferência, formalidade) sem refazer a carga do Censo
- principal uso real: **atalho operacional** — entrega base já ingerida, dicionário pronto e API, evitando ETL DBC próprio

**Prioridade:** `[média]` — 15 pontos, rebaixada

**Justificativa:** soma bruta alta (⭐⭐⭐ + ⭐⭐ + ⭐⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐⭐⭐),
**rebaixada** por: (a) **licença NonCommercial (CC BY-NC-SA 2.0 BR)** — a
ambiguidade "produto educacional é uso comercial?" é real e o `ShareAlike` pode
contaminar artefatos derivados; (b) **nenhum pacote R oficial** (só Python,
contra o stack R do projeto) → wrapper `httr2` fino ou `reticulate`; (c) **atrito
operacional**: cadastro, vínculo profissional, formulário por dataset e **janela
de acesso de 60 dias** — pipeline de dados precisa reagendar renovação, o que é
frágil para produção contínua. Some-se que a plataforma **também serve datasets
individualizados não-nomais**: a mitigação **existe e é séria**, mas depende de o
usuário **escolher certo** — não é mitigação por padrão. **Veredito: excelente
segunda opção/fallback, não fonte primária.**

**Rastro:** `pdd/` **200** · `o-cidacs-e-a-lgpd/` **200** · `pdd.cidacs.org` **200**
· `dataverse.cidacs.org` **200** · nenhum pacote `pdd`/`cidacs` no índice CRAN

**Riscos / cuidados:**
- ⚠️ **Nunca acessar a PDD como atalho para microdados nominais.** Escolher
  datasets **agregados por município**; datasets individualizados não-nomais podem
  ser reidentificáveis ao cruzar com Censo/PNAD (*singling out* em município
  pequeno).
- **Licença NC** precisa de parecer antes de republicar derivados; **verificar no
  Dataverse a licença por dataset**, não assumir a do portal.
- **Sem cliente R** → wrapper fino ou dependência Python.
- **Expiração de 60 dias** → rotina de renovação de perfil no pipeline, senão a
  carga falha silenciosamente meses depois.
- **Duplicação de fonte**: a PDD redistribui DATASUS/IBGE. Usá-la como primária
  cria **dois pipelines para o mesmo dado** sem ganho — justificar em ADR.

---

### VIGITEL — Vigilância de Fatores de Risco e Proteção para Doenças Crônicas

| Campo | Valor |
|---|---|
| **URL** | dados https://svs.aids.gov.br/daent/cgdnt/vigitel/ · institucional https://www.gov.br/saude/pt-br/composicao/svsa/inqueritos-de-saude/vigitel |
| **Mantenedor** | Ministério da Saúde — SVSA, DAENT/CGDNT |
| **Licença** | **CC BY-ND 3.0 Não Adaptada** (rodapé verificado) |
| **Formato** | **CSV compactado em ZIP** (por ano e consolidado), XLS (dicionário), PDF (relatórios e nota metodológica), DTA |
| **Granularidade** | ⚠️ **estado (UF, comDistinção capital/interior) e nacional — NÃO municipal.** Verificado: **zero ocorrências** de "municip" nos metadados e nos arquivos publicados. População-alvo: **adultos ≥ 18 anos** |
| **Periodicidade** | **anual** |
| **API/SDK oficial** | **não** — apenas download em massa (ZIP). **Pacote R: `healthbR::vigitel_*`** (`vigitel_data()`, `vigitel_years()`, `vigitel_dictionary()`), que encapsula os ZIPs oficiais |
| **Cobertura temporal** | **desde 2006** — verificados `vigitel-2006-…` … `vigitel-2023-…` e o consolidado **`vigitel-2006-2024-peso-rake-csv.zip`** (87.121.523 bytes); ⚠️ **2022 ausente** na listagem |
| **Cobertura geográfica** | nacional + estadual (27 UFs) |
| **LGPD** | inquérito telefônico de adultos; os **arquivos publicados vêm com peso calibrado ("peso rake") e sem identificadores** → risco baixo. O **microdado individual** só é liberado sob requerimento ao comitê gestor |

**Relevância para o EduMaps:** ⚠️ **correção de premissa**: VIGITEL **não** é a
fonte de cobertura de PSF/UBS — isso é o **SISAB**, dentro da ficha do DATASUS.
VIGITEL é inquérito telefônico de **fatores de risco em adultos** (tabaco,
álcool, inatividade, hipertensão, diabetes, obesidade, colesterol). O que ela
oferece é **contexto ambiental de saúde do adulto**, proxy fraco porém útil de
determinantes que se transmitem à população escolar, e a **única série longa do
lote (2006–2024)**, útil como tendência.

**Indicador derivado possível:**
- `iv_saude_comportamento_risco` = escore z (tabagismo + álcool + inatividade + obesidade + hipertensão) por UF e ano — **atributo de contexto do território**, não do aluno
- `iv_saude_tendencia_uf` = variação do escore (sinal de deterioração do entorno em uma década)

**Prioridade:** `[baixa]` — 13 pontos, rebaixada

**Justificativa:** **duplo rebaixamento previsto nos critérios**: (a)
**granularidade incompatível** — UF/nacional sem desagregação municipal, e o
critério manda rebaixar explicitamente neste caso; aqui o escore é **idêntico
para todos os municípios de uma UF**, o que anula o uso dentro do IVET
territorial; (b) **população-alvo errada** — adultos ≥ 18, não escolares; a
lacuna do IVET é saúde *da população escolar*, que a PeNSE mede diretamente;
(c) **sem API** (só ZIPs). Soma bruta ≈ 13 (licença ⭐⭐, cobertura ⭐⭐,
periodicidade ⭐⭐, pacote R ⭐, complementaridade ⭐⭐, endereça-lacuna ⭐⭐ como
proxy indireto), mas as regras de rebaixamento se aplicam.

**Rastro:** `svs.aids.gov.br/daent/cgdnt/vigitel/` **200** (lista completa de ZIPs,
dicionários, notas) · `vigitel-2006-2024-peso-rake-csv.zip` → **206**,
`content-range: bytes 0-300/87121523`, `content-type: application/zip` (87 MB,
existe) · busca por "municip" no HTML → **0 ocorrências** · CRAN `healthbR` **200**
(`R/vigitel.R` referencia esta rota)

**Riscos / cuidados:**
- ⚠️ **Não usar como indicador de cobertura de UBS/PSF** — confusão conceitual
  já presente no pedido original.
- **Sem desagregação municipal**: no máximo entra como atributo de estado, com
  peso baixo e **rótulo explícito na UI** para não ser lido como dado municipal.
- **2022 ausente** na série publicada — série com **lacuna**, não "interrompida".
  Tratar missing explicitamente.
- **Microdado individual**: se a equipe tentar o caminho do comitê gestor, o
  processo passa a exigir aprovação ética e o risco LGPD sobe para **alto**.
- **CC BY-ND**: mesmo problema de derivação do DATASUS.

---

## 🔴 LGPD — verificado em payload, não inferido

Os três endpoints abaixo foram consultados **ao vivo** e devolvem **dados
individuais sem mitigação**. Nenhum deve entrar no pipeline como está:

| Endpoint | O que devolve | Verificação |
|---|---|---|
| `/sisvan/estado-nutricional` | **peso, altura, IMC, fase de vida, município, CNES e data de acompanhamento por pessoa** | 200 com `limit=1` |
| `/vacinacao/doses-aplicadas-pni-<ano>` | **data de vacinação por pessoa**, `codigo_documento` (pseudoidentificador), raça, município, estabelecimento | 200 com `limit=1` |
| `/cnes/estabelecimentos` | **nome de pessoa física**, CNPJ, endereço, telefone, e-mail | 200 com `limit=1` |

**Consequência de arquitetura (não é opcional)**: o `data_pipeline` deve manter um
**arquivo de configuração com allowlist de endpoints/tabelas permitidos por
fonte**, revisável em code review, e o job de ingestão deve **recusar** qualquer
endpoint fora da lista. Sem isso, um erro de digitação numa URL baixa microdado de
saúde de menores para o banco de desenvolvimento.

Mitigação já decidida para o CNES: descartar na entrada `nome_razao_social`,
`nome_fantasia`, `numero_cnpj_entidade`, `numero_telefone_estabelecimento`,
`endereco_email_estabelecimento`, `endereco_estabelecimento`/`bairro` — manter
apenas `codigo_cnes`, `codigo_municipio`, `codigo_tipo_unidade`, `status`,
lat/long e `data_atualizacao`.

---

## ⚠️ Correções à lista de candidatos da issue #123

| Item listado | Verificação | Correção |
|---|---|---|
| **"PNS como fonte de saúde escolar"** | ⚠️ PNS tem só **2013 e 2019**. A **PeNSE** é a pesquisa de saúde *escolar* (2009/2012/2015/2019/**2024**, publicada 25/03/2026) e a única com **nível de escola** | Usar **PeNSE**, e PNS apenas para contexto do adulto |
| **"VIGITEL = cobertura de PSF/UBS"** | ❌ VIGITEL é inquérito de **fatores de risco em adultos**; cobertura de APS é o **SISAB** (no DATASUS) | Reatribuir; VIGITEL só como contexto por UF |
| **"DATASUS = Tabnet"** | ❌ `tabnet.datasus.gov.br/cgi/defindex.htm` → **404** (URL morta). Tabnet agora em `datasus.saude.gov.br/informacoes-de-saude-tabnet/` | Usar a **API** `apidadosabertos.saude.gov.br` |
| **"API do SUS sem autenticação"** | ✅ **confirmado** para os endpoints testados | Vale manter |
| **"dados do CNES via S3 público"** | ❌ `s3.amazonaws.com/cnes` → **404 `NoSuchBucket`**; rotas antigas **mortas** | Usar a **API** `apidadosabertos.saude.gov.br/cnes/*` |
| **"CIDACS com dados nominais públicos"** | ❌ a **Plataforma de Dados Integrados é restrita** (convênio, CEP/Conep, VPN 2F, sem download); só a **PDD** é aberta | Usar apenas a PDD, e apenas agregados por município |

---

## Síntese do lote

| Fonte | Prioridade | Pontos | Motivo |
|---|---|---|---|
| **DATASUS** (transferência + API, incl. SISAB) | 🟢 `[alta]` | 17 | Base obrigatória do bloco "Saúde". Sempre via **allowlist de endpoints agregados**. |
| **CNES** (+ API oficial) | 🟢 `[alta]` | 16 | Complemento espacial perfeito (UBS/SU por distância). Sanear dados pessoais na ingestão. |
| **IBGE — PeNSE 2024/2019** (+ PNS 2019) | 🟡 `[média]` | 19 → rebaixada | A fonte mais on-target do lote, mas exige **governança LGPD/CEP** para menores; e os agregados não vêm legíveis por máquina. |
| **CIDACS — PDD** | 🟡 `[média]` | 15 | Acesso público **verificado**; boa camada de conveniência, mas NC + cadastro + janela de 60 dias + só Python. |
| **VIGITEL** | 🔴 `[baixa]` | 13 → rebaixada | População adulta, granularidade UF/nacional, sem API, sem municipal. Não substitui SISAB. |

**Conclusão do lote**: o bloco "saúde" do IVET **é viável sem tocar em dado
individual**: `DATASUS/SISAB` para efetividade de APS em chave IBGE + `CNES` para
acesso espacial em ponto. A PeNSE é a **dimensão mais valiosa** — e a que exige
decisão institucional antes de qualquer linha de código, porque é o único
conjunto do catálogo com **dado sensível de menor**.
