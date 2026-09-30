# Catálogo de fontes de dados abertas — EduMaps

> **Issue**: #123 · **Escopo**: catálogo e priorização **antes** de qualquer
> pipeline (implementação vira issue própria).
> **Método**: cada fonte recebe uma ficha em [`fontes/`](fontes/) e uma linha na
> [matriz de priorização](#matriz-de-priorização) abaixo.

## Por que este catálogo existe

O EduMaps combina **Censo Escolar + OpenStreetMap + SIOPE** para responder ao
problema central: *onde a falta de acesso, a precariedade da infraestrutura e a
insuficiência de recursos se sobrepõem, e como priorizar investimentos para
reduzir desigualdades educacionais territoriais*.

Essa combinação já sustenta o **IVET — Índice de Vulnerabilidade Educacional
Territorial**, mas ele tem seis lacunas:

| # | Lacuna | Por que importa |
|---|--------|-----------------|
| 1 | **Saúde** | Condições de saúde da população escolar afetam frequência e aprendizagem. |
| 2 | **Segurança pública** | Violência no entorno escolar impacta evasão e desempenho. |
| 3 | **Conectividade** | Qualidade da internet na escola é fator crítico pós-pandemia. |
| 4 | **Investimentos planejados** | Obras do Novo PAC e Proinfância mudam o cenário futuro. |
| 5 | **Mobilidade em escala** | Matrizes origem-destino e tráfego revelam fluxos reais de acesso. |
| 6 | **Meio ambiente e clima** | Eventos extremos afetam frequência escolar e infraestrutura. |

## Método de priorização

Cada fonte é pontuada somando o peso dos critérios que ela **atende**:

| Critério | Peso |
|---|---|
| Endereça lacuna direta do IVET (1–6) | ⭐⭐⭐ |
| API/SDK oficial estável | ⭐⭐ |
| Granularidade compatível com escola ou município | ⭐⭐⭐ |
| Licença aberta e compatível com LGPD | ⭐⭐⭐ |
| Cobertura nacional | ⭐⭐ |
| Periodicidade compatível com o ciclo de gestão escolar | ⭐⭐ |
| Já possui pacote R ou ferramenta de acesso pronta | ⭐ |
| Complementa diretamente Censo / OSM / SIOPE | ⭐⭐⭐ |

**Faixas**: `[alta]` ≥ 6 pontos · `[média]` 3–5 pontos · `[baixa]` ≤ 2 pontos.

**Rebaixes** (Levam a `[baixa]` independentemente da soma):

- exige scraping frágil (sem API/download estável);
- granularidade apenas estadual/nacional sem desagregação municipal/escolar;
- licença restritiva ou incompatível com uso público;
- risco LGPD elevado sem mitigação clara.

> Fontes de **agregadores/ferramentas de acesso** (lote H) são calibradas
> diferente: "endereça lacuna direta" pesa menos (não são indicadores), mas
> "pacote R / API estável" pesa mais. A justificativa de cada ficha registra
> essa calibragem.

## Regras de curadoria aplicadas

1. **Nenhuma fonte entra sem licença e risco LGPD verificados** em fonte
   oficial. Campo não confirmado aparece como `não verificado` e derruba a
   prioridade.
2. **Granularidade municipal é o alvo mínimo útil**; granularidade escolar
   (quando existe) é o ideal. A ordem de decisão é: escolar > municipal >
   estadual (estadual só como contexto, nunca como indicador).
3. **LGPD**: só entram dados **agregados ou desidentificados**. Dados
   individuais de saúde, segurança ou deslocamento — mesmo públicos — são
   rebaixados por-etiqueta.
4. **Rastro obrigatório**: `Z:<itemID>` quando houver item Zotero
   (`docs/personas/tech-lead.md`), ou o caminho em `docs/`, ou a URL canônica.

## Domínios catalogados

**48 fontes com ficha completa** em 8 domínios (ver [matriz](#matriz-de-priorização)):

| Domínio | Fichas | Foco principal |
|---|---|---|
| [Educação](fontes/educacao.md) | Censo/IDEB/ENEM, Atlas-IDHM, PNE, SDG 4 | desempenho e contexto educacional |
| [Socioeconômico](fontes/socioeconomico.md) | IBGE (SIDRA, malhas, setor censitário), Ipeadata, BCB, World Bank | demografia e economia municipal |
| [Conectividade e obras](fontes/conectividade-obras.md) | Portal da Transparência, Medidor Educação Conectada, FNDE, Wi-Fi Brasil | lacunas 3 e 4 |
| [Mobilidade](fontes/mobilidade.md) | ANTT/SNV, DNIT, GTFS, OSM/Overpass, roteadores | lacuna 5 |
| [Saúde](fontes/saude.md) | DATASUS, CNES, PeNSE/PNS, CIDACS, VIGITEL | lacuna 1 |
| [Segurança](fontes/seguranca.md) | BrazilCrime, SINESP/Infoseg, SNSP | lacuna 2 |
| [Meio ambiente e clima](fontes/meio-ambiente.md) | MapBiomas, INMET (Alerta-AS + BDMEP), IBAMA, Terrabrasilis, CEMADEN | lacuna 6 |
| [Agregadores](fontes/agregadores.md) | Base dos Dados, tesouror, MCP-Brasil, geobr/ibger/censobr | acesso às fontes acima |

## Matriz de priorização

Ordenada por prioridade, depois por pontos. **14 fontes `[alta]`** — bem acima do
mínimo de 5 exigido pela issue. O critério de aceite nº 9 (verificação de
licença, endpoint e granularidade) foi aplicado sem exceção: nenhuma fonte
`[alta]` tem campo `não verificado`.

### 🟢 Alta prioridade (14)

| # | Fonte | Domínio | Lacuna | Gran. | API oficial? | Licença | Pts | Ficha |
|---|---|---|---|---|---|---|---|---|
| 1 | IBGE — API de Agregados (SIDRA) v3 + Localidades | socioeconômico | habilitadora 1/3/4/5/6 | município (N6) | **sim**, sem auth | domínio público | 19 | [link](fontes/socioeconomico.md) |
| 2 | MapBiomas (Coleção 9) | meio-ambiente | **6** | grade 30 m | COG público | CC BY 4.0 | 19 | [link](fontes/meio-ambiente.md) |
| 3 | IPEA — Ipeadata | socioeconômico | 1, 5 | município | **sim** (OData v4) | uso público c/ citação | 18 → **`[média]`** | [link](fontes/socioeconomico.md) |
| 4 | Base dos Dados (BigQuery público) | agregadores | ingestão | escola | SQL | CC BY 4.0 / MIT | 18 | [link](fontes/agregadores.md) |
| 5 | INMET — Alerta-AS (CAP 1.2) | meio-ambiente | **6** | município + polígono | **sim**, sem auth | domínio público | 18 | [link](fontes/meio-ambiente.md) |
| 6 | IBGE — Malhas territoriais | socioeconômico | habilitadora 1/5 | setor censitário | **sim**, v3 | domínio público | 17 | [link](fontes/socioeconomico.md) |
| 7 | INMET — séries históricas (BDMEP) | meio-ambiente | **6** | estação/município | **sim**, sem auth | domínio público | 17 | [link](fontes/meio-ambiente.md) |
| 8 | tesouror (CRAN) — SIOPE + **SICONFI** | agregadores | **4** | município | pacote R | MIT (pacote) | 17 | [link](fontes/agregadores.md) |
| 9 | **DATASUS** — API Dados Abertos do SUS | saúde | **1** | município | **sim**, sem auth | CC BY 3.0 / BY-ND | 17 | [link](fontes/saude.md) |
| 10 | BrazilCrime (CRAN) | segurança | **2** | município | pacote R | MIT (pacote) | 16 | [link](fontes/seguranca.md) |
| 11 | MCP-Brasil | agregadores | ingestão | município | **sim** | CC0 / ISC | 16 | [link](fontes/agregadores.md) |
| 12 | IBGE — Censo Demográfico 2022 por **setor censitário** | socioeconômico | **1**, 5 | **setor censitário** | download/FTP | domínio público | 16 | [link](fontes/socioeconomico.md) |
| 13 | **CGU / Portal da Transparência** — transferências | conectividade | **4** | município (código IBGE) | planilha oficial | uso público (LAI) | 16 | [link](fontes/conectividade-obras.md) |
| 14 | **CNES** — estabelecimentos de saúde | saúde | **1** | **ponto (lat/long)** | **sim**, sem auth | CC BY-ND 3.0 | 16 | [link](fontes/saude.md) |
| 15 | geobr / ibger / censobr (família IBGE) | agregadores | habilitadora | município + setor | pacote R | MIT / CC0 | 15 | [link](fontes/agregadores.md) |

> A linha 3 (Ipeadata) somou **18** pontos e aparece aqui pela ordem da pontuação,
> mas foi **rebaixada para `[média]`** pelas regras de licença (sem SPDX), acesso
> (só HTTP, sem TLS) e eficiência (sem paginação). Ver a ficha.
> A tabela tem 15 linhas e 14 `[alta]` — a diferença é exatamente o rebaixamento
> do Ipeadata.

### 🟡 Média prioridade

| Fonte | Lacuna | Motivo do rebaixamento |
|---|---|---|
| IBGE — PeNSE 2024 / PNS 2019 | **1** | 19 pts, mas **LGPD**: microdado sensível de menor; e agregados não vêm legíveis por máquina. |
| CIDACS — PDD | 1 | Licença **NonCommercial** + ShareAlike; sem pacote R; janela de acesso de 60 dias. |
| Medidor Educação Conectada | **3** | Única medição real de banda por escola, mas **sem API**, **licença não publicada** (`licenca.txt` → 404) e atrás de app Shiny. |
| FNDE — PNATE | 5 | Melhor especificação do lote (mensal, conteúdo declarado), mas portal inacessível a cliente não-browser. |
| FNDE — Novo PAC / Proinfância | **4** | Responde à lacuna, mas mesma fragilidade de acesso + granularidade municipal. |
| IBAMA — Portal de Dados Abertos (CKAN) | 6 | Passivo ambiental industrial; **SISLIC exige login** (não é dado aberto). |
| CEMADEN | **6** | Mandato perfeito, **mas sem API** — só boletins PDF. |
| Terrabrasilis (PRODES/DETER) | 6 | Uso indireto; licença não verificada. |
| CPTEC | 6 | Contexto sazonal; **só listagem de diretório**, sem API. |
| Atlas do IDHM (PNUD/Ipea/FJP) | 1, 6 | ~120 indicadores municipais **com dimensões SAÚDE e VULNERABILIDADE**; sem API, download em XLSX. |
| IDEB (INEP) | resultado | Já ingerido (`clean.ideb_notas_escolas`); sem licença verificada. |
| ENEM (INEP) | resultado | Auto-seleção não censitária; granularidade individual. |
| Censo Escolar (INEP) | base | **Já ingerido.** 1995–2025 confirmado; licença não verificada. |

### 🔴 Baixa prioridade — fora do escopo do pipeline

| Fonte | Motivo da exclusão |
|---|---|
| Banco Central (SGS/SCR) | **ODbL share-alike** — não pode ser materializado no Postgres. |
| World Bank API | **Só nacional** — valor constante para todas as escolas; não discrimina. |
| CIDACS Plataforma Integrados | **Restrita** (convênio, CEP/Conep, VPN 2F, sem download). |
| UNESCO UIS | Granularidade de **país** — inútil para índice territorial. |
| Painel do PNE (INEP) | Atrás de **Power BI** — exigiria scraping frágil. |
| VIGITEL | População **adulta**, granularidade UF/nacional, sem municipal. |
| SINESP / Infoseg | **Acesso restrito** — é a primária, não a interface. |
| SINESP municipal/estadual | Sem API, scraping frágil, 27 portais heterogêneos. |
| SNSP (SUSP) | **Não verificado** (lead) — sem URL canônica, licença ou formato. |
| Crime Brasil | Não oficial, origem opaca. |
| Observatórios / MapBiomas Segurança | Terceiros; apenas contexto. |
| GESAC / Wi-Fi Brasil | **Programa, não dado** — atrás de Power BI. |
| Nordeste Conectado | Regional (20 cidades); sem dado estruturado. |
| Wikidata Escolas | 23% de cobertura com coordenada; é insumo de **qualidade de dado**. |
| SGB setorização | Conceito ideal, **sem produto nacional**. |
| MMA (Portal de Dados Abertos) | Portal **vazio** — nenhum produto. |
| INPE Queimadas | **Redundante** com MapBiomas Fogo. |
| BrasilAPI | **Redundante** com o IBGE; ToS indefinidos; proíbe crawling. |
| BrazilDataAPI | Só estadual, GPL-3, escopo desalinhado. |
| APIs-PublicasBrasil | Sem licença, abandonada, não introduz fonte nova. |

### Cobertura das seis lacunas

| Lacuna | **Alta** | Cobertura | Diagnóstico |
|---|---|---|---|
| 1 — Saúde | CNES, DATASUS, Censo setor censitário, MapBiomas (risco) | 🟢 **boa** | O IVET ganha saúde cartografável. A PeNSE (melhor fonte) depende de decisão institucional. |
| 2 — Segurança | BrazilCrime | 🟡 **mínima, mas suficiente** | Uma fonte só, municipal, com disciplina de LGPD. Fecha a lacuna, mas é fina. |
| 3 — Conectividade | — | 🔴 **não resolvida** | Só existe medição real por escola, e está sem API e sem licença. Depende de **e-SIC**. |
| 4 — Investimentos | Portal da Transparência, tesouror/SICONFI | 🟢 **boa** | Repasse e execução financeira municipal. Falta a obra em si (FNDE), também por e-SIC. |
| 5 — Mobilidade | IBGE malhas + OSM (habilitadores) | 🔴 **não resolvida** | Não há base nacional comparável; o padrão é GTFS municipal. |
| 6 — Meio ambiente | MapBiomas, INMET Alerta-AS, INMET BDMEP | 🟢 **boa** | Melhor bloco do catálogo: evento, série histórica e exposição a risco. |

**Leitura honesta**: 3 das 6 lacunas ficam bem resolvidas, 1 fica mínima, e
**2 (conectividade e mobilidade) não têm solução limpa no catálogo atual** — e
essa é a conclusão mais útil da issue, porque são as duas que exigiriam mais
engenharia se alguém tentasse sem saber.

## Plano de integração faseado

> **As fases abaixo viram issues de implementação separadas.** Esta issue
> entrega o catálogo e o plano, não o código.

### Fase 0 — Fundação (pré-requisito de tudo)

Nenhuma fonte entra sem estas duas peças:

1. **Allowlist de endpoints e tabelas** em `data_pipeline/` (arquivo de
   configuração revisável em code review), com o job de ingestão **recusando**
   qualquer endpoint fora da lista.
   *Motivo verificado*: a API do SUS devolve microdado individual de saúde sem
   mitigação em `/sisvan/estado-nutricional` e `/vacinacao/doses-aplicadas-pni-*`.
   Sem allowlist, um erro de URL baixa dado sensível de menor para o banco de
   desenvolvimento. Isto é **requisito**, não melhoria.
2. **Proveniência com licença** — estender `clean.import_metadata` (hoje tem
   `table_name`, `source_file`, `import_timestamp`, `row_count_loaded`, `notes`)
   com `source_url`, `source_license` e `retrieved_at`. Sem isso, o critério nº 9
   do método não é auditável depois da ingestão, e as descobertas de licença
   (ODbL do BCB, CC BY-ND do SUS) se perdem.

### Fase 1 — Contexto municipal e habilitadores (maior retorno)

**Objetivo**: tirar o IVET do valor municipal uniforme.

| Fonte | Entregável | Observação |
|---|---|---|
| IBGE malhas (v3 + GPKG) | `clean.malha_municipio`, `clean.malha_setor_censitario` | **Pré-requisito de tudo**: sem malha não há arealização. API v3 entrega malha *simplificada* — arealizar com o GPKG do Geoftp. |
| IBGE SIDRA v3 | `clean.ibge_agregados` (long: `codigo_ibge`, `ano`, `tabela_id`, `variavel`, `classificacao`, `valor`) | ⚠️ usar `servicodados.ibge.gov.br`, **não** `apisidra` (Cloudflare → 403). Respeitar o **limite de 100.000 valores/consulta**. Já existe `clean.dados_ibge` (SIDRA/PIB) — é *extensão*, não greenfield. |
| Censo 2022 por setor censitário | `clean.censo2022_setor` | Malha com atributos = **748 MB** comprimidos. **Nunca tratar vazio como zero** (supressão de células pequenas é um estado distinto). |
| geobr / censobr (CRAN) | malhas e agregados em R, sem chamada HTTP no loop | `censobr` traz **setor censitário desde 1960** → viabiliza análise longitudinal de vulnerabilidade. |
| Base dos Dados | ingestão do Censo Escolar **2007–2022** em SQL | Resolve o problema de volume (ZIPs de vários GB/ano) e dá série histórica. ⚠️ **2023/2024 ausentes** — combine com o INEP. |

### Fase 2 — Bloco de saúde (primeira lacuna fechada)

| Fonte | Entregável | Observação |
|---|---|---|
| CNES | `clean.cnes_estabelecimento` (`codigo_cnes`, `codigo_municipio`, `codigo_tipo_unidade`, `status`, lat, long, `dt_snapshot`) | **Sanear na ingestão**: descartar `nome_razao_social`, `nome_fantasia`, CNPJ, telefone, e-mail. Paginação com `limit` ≤ 20. |
| DATASUS / SISAB | `clean.sisab_aps` (município × mês) | Endpoints da **allowlist** da Fase 0. Habilita `iv_saude_dist_ubs` (distância escola→UBS via OSM) e `iv_saude_cobertura_aps`. |
| View analítica | `analytics.acessibilidade_saude` | Cruza CNES (oferta, ponto) + escola (demanda) + malha/OSM. |

### Fase 3 — Eventos e exposição a risco

| Fonte | Entregável | Observação |
|---|---|---|
| MapBiomas | `clean.mapbiomas_<classe>_<ano>` | ⚠️ **fixar a URL da Coleção** (ex.: `collection11`), **não do ano** — a URL por ano morre. COG público, 30 m. |
| INMET Alerta-AS | `clean.inmet_alerta` (COG + payload) | Mede o evento que **interrompe a aula**. Código IBGE no payload. |
| INMET BDMEP | `clean.inmet_estation_diaria` | 26 anos de série diária, API sem auth. Base para normalização climática. |

### Fase 4 — Financeiro e investimento

| Fonte | Entregável | Observação |
|---|---|---|
| Portal da Transparência | `raw.transferencia`, `clean.transferencia_educ` | ⚠️ WAF intermitente (405 "Human Verification") → retry com backoff + job noturno com cache. Usar série **realizada**, não "estimativa". |
| tesouror / SICONFI | `clean.siconfi_receita` | Abre uma dimensão que o IVET não tinha: **capacidade fiscal municipal**. |

### Fase 5 — Segurança e conectividade (com revisão de LGPD)

| Fonte | Entregável | Observação |
|---|---|---|
| BrazilCrime | `clean.brazilcrime_municipio` | Agregar **por município** com **supressão de célula pequena (count < 5)**. Nunca expor por escola. Revisão de LGPD **antes** de ir à interface. |
| Conectividade | — | **Depende de e-SIC** ao MEC/NIC.br (CSV + dicionário). Enquanto não houver, o bloco fica explicitamente vazio no IVET. |

### Em paralelo, fora do código — ações administrativas

Três **e-SIC** destravam mais valor do que qualquer pipeline:

1. **INEP** — licença do Censo Escolar, IDEB, ENEM e painel do PNE. Única
   pendência que bloqueia **quatro** fichas de `[alta]`.
2. **MEC/NIC.br** — CSV + dicionário do Medidor Educação Conectada. A
   metodologia de agregação **já está publicada** na aba "Dados" do portal: é um
   pedido administrativo de baixo custo que fecha a lacuna 3.
3. **FNDE** — URL de download + dicionário do Novo PAC/Proinfância e do PNATE.

### Fora de escopo, por decisão

- **PeNSE**: exige projeto CEP/Conep, ambiente controlado e regra de
  não-persistência. Decisão **institucional**, não técnica.
- **Banco Central**: ODbL share-alike. Não entra.
- **BCB/World Bank/UNESCO/UIS/INPE Queimadas/MMA/SGB/Wikidata**: sem ganho
  para o IVET no estado atual. Reavaliar se o IVET mudar de escopo.

### O que o plano entrega, em uma frase

Sair de **um índice escolar com proxies uniformes por município** para **um
índice territorial com exposição a risco (MapBiomas), evento de interrupção
(INMET), oferta de saúde em ponto (CNES), contexto sub-municipal (setor
censitário) e capacidade fiscal (SICONFI)** — que é a direção que a
`[pesquisadora-educacional.md`](../personas/pesquisadora-educacional.md)
apontou como pendência aberta (P5, P8).