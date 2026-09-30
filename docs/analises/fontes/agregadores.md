# Fontes — Agregadores e ferramentas de acesso

> Lote H da issue #123 · **não são indicadores**: são camadas de **acesso** que
> aceleram a ingestão. Método, pesos e regras: [`../fontes_de_dados.md`](../fontes_de_dados.md).

**Calibração aplicada**: por serem ferramentas de acesso, o critério "endereça
lacuna direta do IVET" entra com peso reduzido (⭐, não ⭐⭐⭐); em contrapartida,
"API/SDK estável" e "já tem pacote R/ferramenta pronta" entram com peso alto.
É o que a justificativa de cada ficha registra.

## ⚠️ Correções à lista de candidatos da issue #123

Verificação de 2026-09-30 sobre o **índice do CRAN** (259 275 linhas) e o
**arquivo do CRAN** (28 037 entradas):

| Item listado na issue | Verificação | Correção |
|---|---|---|
| `IBGE7` | ❌ **não existe** — ausente do CRAN atual e do arquivo, GitHub `total_count: 0`, r-universe 404 | Provável confusão de nome com **`ibger`**, que existe e é o pacote correto |
| `geodesobr` | ❌ **não existe** — repo `BVDataScience/geodesobr` → 404, a própria organização → 404, ausente do CRAN e do arquivo | Substituto funcional: **`geobr`** (mesma função, MIT, mantido pelo Ipea) |
| `RRPP` | ⚠️ **existe mas não é do IBGE** — é o *Residual-based Randomization Permutation Procedure* (Collyer & Adams), GPL ≥3, para análise filogenética | **Não é candidato** ao IVET; remover do cadastro |
| `mcp-brasil` sob `brasilapi/` | ❌ URL do enunciado retorna **404** | Canônica: **`Mcp-Brasil/mcp-brasil`** |

> Se a documentação interna do EduMaps cita `IBGE7`/`RRPP`/`geodesobr`, está
> errada e deve ser corrigida antes de virar decisão de arquitetura.

---

### Base dos Dados (BigQuery público)

| Campo | Valor |
|---|---|
| **URL** | https://basedosdados.org/ · código https://github.com/basedosdados/mais · SDK https://github.com/basedosdados/sdk |
| **Mantenedor** | Base dos Dados — organização sem fins lucrativos, com equipe identificada nos metadados |
| **Licença** | MIT + file LICENSE **para o software**; os **dados herdam a licença da origem** (INEP, IBGE, TSE) |
| **Formato** | Google BigQuery + parquet/Arrow |
| **Granularidade** | **escola** (`br_inep_censo_escolar.escola`, 300+ variáveis), **turma**, município, estado — e também **individual** (`.docente`, `.aluno`) ⚠️ |
| **Periodicidade** | anual |
| **API/SDK oficial** | sim — SDK R (`basedosdados`, CRAN v0.2.3, MIT) e Python. **Sem REST anônimo**: exige conta Google + projeto GCP com `billing_project_id` (bucket é *requester-pays*) |
| **Cobertura temporal** | `br_inep_censo_escolar`: **2007 → 2022** |
| **Cobertura geográfica** | nacional (27 UFs, todos os municípios) |
| **LGPD** | ⚠️ **risco mais sério do lote**: `.aluno` e `.docente` são nível **indivíduo**. A tabela `escola` é a única liberada pelo INEP a partir de 2021 (sem identificadores de estudante) → risco baixo |

**Verificação (2026-09-30)**: metadados oficiais confirmam *"Cobertura Temporal
2007(1)2022"*, *"Frequência de Atualização: one_year"*, partições `ano`/`sigla_uf`,
e que `escola` é *"a única tabela do Censo Escolar liberada pelo INEP a partir
de 2021"*. `storage.googleapis.com/basedosdados/` → `UserProjectMissing`
(confirma *requester-pays*).

**Relevância para o EduMaps:** resolve a maior fricção de ingestão do projeto —
os **microdados do Censo Escolar em ZIP de vários GB**, que hoje exigem download,
descompactação, parse e carga manual. Entrega `escola` com histórico de **16 anos**,
o que permite **IVET em série histórica**, não só no ano corrente — restrição
estrutural do IVET atual.

**Indicador derivado possível:**
- **IVET em série histórica 2007–2022** (backtest, estabilidade temporal, trajetória por escola);
- variáveis de infraestrutura/equipe straight da tabela `escola` (300+ variáveis);
- `br_inep_ideb.municipio` como variável de **resultado** para validação externa;
- nível `turma` como unidade intermediária (reduz ruído amostral vs. nível escola).

**Prioridade:** `[alta]` — 18 pontos

**Justificativa:** ⭐⭐ (destrava a ingestão do Censo e o eixo temporal) + ⭐⭐
(SDK R/Python MIT, mas via BigQuery = dependência de nuvem) + ⭐⭐⭐
(escola/turma/município) + ⭐⭐⭐ (MIT) + ⭐⭐ + ⭐⭐ + ⭐ + ⭐⭐⭐ (é o próprio
Censo) = **18**.

**Rastro:** `basedosdados/mais` README · `basedosdados/sdk`
`br_inep_censo_escolar/escola/table_description.txt` · CRAN `basedosdados` v0.2.3

**Riscos / cuidados:**
- **Regra dura: usar apenas `escola` e `turma`.** `.aluno`/`.docente` são nível
  indivíduo e tratam dado sensível de crianças e adolescentes — barrado no IVET.
- **Cobertura termina em 2022** (um ciclo atrasado): 2023/2024 **não** estão lá.
  Planejar **em paralelo**, não em substituição — o job R/`t/05-tasks` continua
  sendo a fonte do ano corrente; o BD serve para backfill e séries.
- Depende de conta GCP + billing; sem isso até listar o bucket retorna 400. O
  endpoint de catálogo do site (`/api/tables?search=`) retornou **HTTP 500**.
- **Chaves de join diferentes**: BD usa `id_municipio` (BigQuery); EduMaps usa
  `codigo_ibge`. Exige camada de mapeamento no ingest.
- Colunas renomeadas/retipadas pelo BD (booleanos 0/1, datas `DATE`): regressão
  silenciosa se alguém assumir o schema bruto do INEP.
- A licença MIT é do **SDK**, não dos dados: publicar o IVET exige conferir a
  licença do INEP para os microdados pós-LGPD.

---

### tesouror (CRAN) — SIOPE, SICONFI, SIORG

| Campo | Valor |
|---|---|
| **URL** | https://cran.r-project.org/package=tesouror · docs https://strategicprojects.github.io/tesouror/ |
| **Mantenedor** | Strategic Projects / Castlab — André Leite (aut, cre) + 6 coautores |
| **Licença** | MIT + file LICENSE |
| **Formato** | API REST (JSON) + `tibble`; 6 APIs — SICONFI (ORDS), CUSTOS, SADIPEM, Transferências Constitucionais, SIORG e **SIOPE (OData v4)** |
| **Granularidade** | **município** (SIOPE, SICONFI RREO/RGF/DCA/MSC) + estado (CUSTOS) + federal (SIORG). **Sem granularidade escolar** |
| **Periodicidade** | **bimestral** (SIOPE, `periodo` 1–6) e RREO/DCA; **mensal** (remuneração SIOPE, CUSTOS) |
| **API/SDK oficial** | sim (R) — v0.3.1 (2026-09-12), **80 funções**, aliases PT/EN, paginação, cache, retry com backoff |
| **Cobertura temporal** | não verificada explicitamente para SIOPE; vinheta cobre RREO longitudinal |
| **Cobertura geográfica** | municipal, **iteração por UF** (não há chamada que traga os 5 570 municípios de uma vez) |
| **LGPD** | risco **baixo** — dados orçamentários agregados. ⚠️ **Exceção**: `get_siope_responsaveis()` retorna **nome de servidor público** (dado pessoal) — não usar |

**Relevância para o EduMaps:** é o **acesso ao SIOPE**, um dos três pilares do
IVET. E traz algo que a issue não tinha listado: **SICONFI (RREO, RGF, DCA, MSC)
na LC 101 com granularidade municipal** — ou seja, **capacidade orçamentária e
saúde fiscal do município**, dimensão clássica de vulnerabilidade territorial e
que o IVET hoje provavelmente não tem. A vinheta "RREO longitudinal — handling
layout drift across years" indica que o time já enfrentou a mudança de layout do
RREO entre exercícios — problema real de qualquer série histórica.

**Indicador derivado possível:**
- **Teto de gasto em educação por município** (`get_siope_expenses()` por função ÷ matrícula do Censo) → proxy de *esforço*, complementar ao *resultado*;
- **Fundeb executado vs. previsto** → autonomia financeira municipal;
- **Margem fiscal (RGF)** → fragilidade do município em financiar a escola.

**Prioridade:** `[alta]` — 17 pontos

**Justificativa:** ⭐⭐ + ⭐⭐ (CRAN, MIT, 7 autores, 80 funções) + ⭐⭐⭐
(município, join direto por município do Censo) + ⭐⭐⭐ (MIT) + ⭐⭐ + ⭐⭐
(bimestral, compatível) + ⭐ + ⭐⭐⭐ (é o próprio SIOPE) = **17**.

**Rastro:** CRAN `tesouror` v0.3.1 · docs `articles/siope.html` (OData
`https://www.fnde.gov.br/olinda-ide/servico/DADOS_ABERTOS_SIOPE/versao/v1/odata/`,
filtro `COD_MUNI`)

**Riscos / cuidados:**
- **Não tem granularidade escolar** — para o IVET por escola é preciso join
  espacial (PostGIS) por área de influência, não join por código.
- **CUSTOS é lento e frágil**: a própria doc avisa que consultas de ano inteiro
  dão *timeout* (HTTP 504); page size caiu de 1000 → 500; paginação parcial
  retorna `attr(x, "partial") = TRUE`. Tratar como opcional, sempre filtrando.
- Os nomes de coluna para `$filter`/`$select` são os **originais em MAIÚSCULA** —
  fazer `max_rows = 1` e `toupper(names(x))` para descobrir.
- ⚠️ **Mistura de códigos**: `cod_muni` do SIOPE é do IBGE (casa com o
  EduMaps), mas Transferências Constitucionais usa **códigos internos do Tesouro** —
  erro clássico.
- **Layout drift** no RREO/SICONFI entre exercícios: séries longas exigem
  validação ano a ano.
- Publicação recente (set/2026): atividade forte, histórico curto — espere
  breaking changes.

---

### geobr / ibger / sidra / censobr (família IBGE)

| Campo | Valor |
|---|---|
| **URL** | `geobr` https://cran.r-project.org/package=geobr · `ibger` https://cran.r-project.org/package/ibger · `censobr` https://cran.r-project.org/package=censobr · `sidra` https://cran.r-project.org/package/sidra |
| **Mantenedor** | `geobr` e `censobr`: Rafael H. M. Pereira (Ipea) + Rogério J. Barbosa, financiados por **Ipea** · `ibger`: Strategic Projects (mesmo time do `tesouror`) |
| **Licença** | **MIT** em `geobr`/`ibger`/`censobr` · ⚠️ **GPL-3** em `sidra`/`sidrar` |
| **Formato** | API REST/JSON oficial do IBGE + download de malhas espaciais + integração Arrow/DuckDB |
| **Granularidade** | **município** (`geobr`, `ibger`/`sidra`) e **setor censitário** (`censobr`) — nenhum chega a escola |
| **Periodicidade** | anual (Censo Populacional); malhas por ano de referencia |
| **API/SDK oficial** | sim — API do IBGE é **oficial** (`servicodados.ibge.gov.br/api/docs` → 200); pacotes R comunitários no CRAN |
| **Cobertura temporal** | `censobr`: censos populacionais **desde 1960** · demais não verificadas uniformemente |
| **Cobertura geográfica** | nacional |
| **LGPD** | risco **baixo** (agregados). ⚠️ `censobr` tem vinheta de **microdata** do Censo — usar só agregadas |

**Verificação (2026-09-30)**: `geobr` v2.1.0 (2026-09-20, MIT, Ipea);
`ibger` v0.2.0 (2026-07-08, MIT); `censobr` v1.0.0 (2026-09-21, MIT, *"all the
population censuses taken in and after 1960"*); `sidra` v0.2.0 (GPL-3);
`servicodados.ibge.gov.br/api/docs` → 200.

**Relevância para o EduMaps:** é a **camada de contexto espacial e demográfica**
que faz o eixo territorial funcionar. `geobr` dá malhas oficiais de município com
topologia fixa (resolve "qual município é esta escola" e "qual a área de
influência") e já integra `sf` + DuckDB + Arrow — alinhado ao PostGIS do
projeto. E `censobr` é o achado mais valioso: **setor censitário desde 1960**,
que permite ao IVET ir além do município e construir vulnerabilidade
**intra-municipal** — que é literalmente a promessa do "Vulnerabilidade Educacional
**Territorial**".

**Indicador derivado possível:**
- **Setor censitário como unidade de vulnerabilidade** → IVET em nível de bairro/setor;
- IDHM e condicionantes socioeconômicas como covariáveis;
- malhas município+setor para **join espacial canônico** e área de influência.

**Prioridade:** `[alta]` — 15 pontos

**Justificativa:** ⭐ (contexto espacial; importante mas não é *a* lacuna) +
⭐⭐ (API oficial do IBGE + pacotes CRAN mantidos por Ipea) + ⭐⭐ (município e
setor censitário — melhor que município, mas não chega a escola) + ⭐⭐⭐ +
⭐⭐ + ⭐⭐ + ⭐ + ⭐⭐ = **15**. Nota de honestidade: relevance **de fundação,
não de novidade** — provavelmente já coberta, parcial ou totalmente, pelo
pipeline existente. Vale pelo `censobr` e pelo `geobr`, não pelo `sidra`.

**Rastro:** páginas CRAN dos quatro pacotes · `servicodados.ibge.gov.br/api/docs`

**Riscos / cuidados:**
- **Nenhum chega a granularidade escolar**: o cruzamento com a rede escolar é
  sempre trabalho nosso (join espacial ou por `cod_ibge`).
- ⚠️ **`sidra`/`sidrar` são GPL-3**: em R, depender de GPL-3 num pacote que o
  EduMaps distribua propaga copyleft. Se `edumapsr` virar pacote distribuído,
  isso é questão legal — `ibger` (MIT) é a alternativa segura.
- **Divergência de códigos** entre malhas e setores censitários, que mudam entre
  censos → bridge table `cod_ibge` + `ano` é obrigatória.
- **Censo Populacional (IBGE) ≠ Censo Escolar (INEP/ME)**: nomes parecidos,
  unidades e frequências diferentes. Não confundir.
- `geobr` exige **R ≥ 4.4.0** — conferir a versão de R no `analytic.edumaps`.
- Microdata do Censo é reidentificável em áreas pequenas: usar agregadas.

---

### MCP-Brasil

| Campo | Valor |
|---|---|
| **URL** | https://github.com/Mcp-Brasil/mcp-brasil (canônico; `brasilapi/mcp-brasil` → 404) |
| **Mantenedor** | Comunidade (1 797 stars, 275 forks); criado 2026-03-26, push 2026-09-19. **Independente do governo** (o README declara não-oficialidade e não-endosso) |
| **Licença** | **MIT só para o código**. Dados sob a licença de cada fonte upstream, mapeadas em `SOURCES.md` + `ACCEPTABLE_USE.md`. **Sem licença única para o conjunto** |
| **Formato** | Servidor MCP (stdio e HTTP `:8000/mcp`) com ~533 tools + datasets locais em **DuckDB embedded** consultáveis por SQL |
| **Granularidade** | **varia**: escola (`inep_censo_escolar` ~180k escolas, 2023), município (SICONFI, SIOPE, TCE-*), estado, federal |
| **Periodicidade** | **irregular**: datasets locais são *snapshots* fixos (Censo/ENEM = 2023); features REST seguem o ritmo de cada API |
| **API/SDK oficial** | não (SDK comunitário): `pip install mcp-brasil` / `uvx`. 66 das ~70 APIs sem chave; 4 exigem cadastro gratuito |
| **Cobertura temporal** | n/a (ferramenta); subjacente: Censo Escolar **snapshot 2023** |
| **Cobertura geográfica** | nacional + 14 TCs estaduais (dá despesa municipal em SP, RJ, RS, PE, CE, ES, RN, PI, SC, TO, PA) |
| **LGPD** | risco **médio com mitigação declarada**: whitelist de colunas bloqueia `NU_INSCRICAO`, nome e CPF. ⚠️ o próprio `SOURCES.md` é **internamente contraditório** (sumário diz "Médio", cabeçalho da seção 4 diz "ALTO"). Existe env `MCP_BRASIL_LGPD_ALLOW_PII` — **não usar para o IVET** |

**Relevância para o EduMaps:** empacota num lugar três eixos que o IVET já
consome — **Censo Escolar** (dataset local 2023), **FNDE** (repasses, merenda,
PNATE, transporte) e **SICONFI/Tesouro** (RREO, RGF, DCA, MSC). O ganho real não
é o MCP (feito para agentes de IA, não para pipeline R): é a **camada de cache
DuckDB**, que permite consultar o ZIP de microdados por SQL local sem reparsear
vários GB a cada execução.

**Indicador derivado possível:** cruza **cobertura de merenda/PNATE (FNDE)** e
**capacidade orçamentária municipal (SICONFI)** com as variáveis de
infraestrutura do Censo, alimentando dimensões de recursos por aluno sem carregar
o microdado completo no Postgres.

**Prioridade:** `[alta]` — 16 pontos

**Justificativa:** ⭐ (endereça lacuna — peso reduzido por ser ferramenta) +
⭐⭐ + ⭐⭐⭐ (escola/município) + ⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐ + ⭐⭐⭐ = **16**.

**Rastro:** `Mcp-Brasil/mcp-brasil` README/`SOURCES.md`/`ACCEPTABLE_USE.md`
·lidos 2026-09-30

**Riscos / cuidados:**
- **Adequação ao stack é indireta**: é MCP/Python; o EduMaps é R + PostGIS. Para
  ingestão real seria ler o cache DuckDB ou contornar o servidor. **Não tratar
  como substituto do job R em `t/05-tasks`.**
- **Snapshot único de 2023** — sem histórico 2007→2024; pode desatualizar em silêncio.
- **Toda distribuição herda o risco do agregado** — ativar `inep_censo_escolar`
  herda risco médio; `tse_*` herda risco alto. Selecionar features explicitamente.
- Repositório com ~6 meses de vida: sem histórico de estabilidade. Tratar como
  dependência experimental, com camada de abstração própria.
- `SOURCES.md` escrito em 2026-04-26 e o autor recomenda revisão semestral —
  licenças upstream mudam sem aviso.

---

### BrasilAPI

| Campo | Valor |
|---|---|
| **URL** | https://brasilapi.com.br/ · docs https://brasilapi.com.br/docs · repo https://github.com/BrasilAPI/BrasilAPI (11,2k stars, 1 032 commits) |
| **Mantenedor** | Comunidade (Filipe Deschamps, Luciano Pfrommer); hospedada na Vercel |
| **Licença** | MIT no código, mas **Termos de Uso inacabados**: o README pede para não usar crawling automatizado e que o volume "tenha a natureza de uma pessoa real". ⚠️ `robots.txt` tem **`Disallow: /api/*`** |
| **Formato** | API REST (JSON) |
| **Granularidade** | **logradouro** — o payload do CEP traz o bloco `ibge` com `city: "3509502"` e `state: "35"`; também CNPJ, banco, DDD, PIX, feriados |
| **Periodicidade** | irregular (depende das fontes subjacentes); sem cadência garantida |
| **API/SDK oficial** | não (HTTP direto é o canônico); libs comunitárias em ~10 linguagens — **nenhuma em R** |
| **Cobertura temporal** | não verificada (consulta pontual, sem série) |
| **Cobertura geográfica** | nacional (todos os CEPs) |
| **LGPD** | dados sem sensível, mas **CNPJ expõe razão social, sócios e e-mails** (dado pessoal). O risco real é **operacional**: `robots.txt` + ToS |

**Verificação (2026-09-30)**: endpoints ao vivo `api/cep/v1/{cep}`, `api/cnpj/v1/{cnpj}`,
`api/banks/v1`, `api/ddd/v1`, `api/feriados/v1/{ano}` → **200**.
⚠️ **`fipe/*` retorna 404** em todas as variantes — a FIPE citada como feature
pelo MCP-Brasil **não está mais disponível**.

**Relevância para o EduMaps:** utilidade pontual e real: `/api/cep/v1/{cep}` já
devolve o **código IBGE do município**, o que resolve o caso em que o Censo ou o
OSM entrega endereço sem `cod_ibge`. Serve como **lookup** no ETL. Fora isso, não
tem nada de educacional.

**Indicador derivado possível:** nenhum próprio. Contribui como serviço de enriquecimento:
`cep → {sigla_uf, cidade, cod_ibge}` para completar a geocodificação; CNPJ →
natureza jurídica do mantenedor, se houver decisão de modelar a rede.

**Prioridade:** `[média]` — 10 pontos, rebaixada por licença/ToS

**Justificativa:** ⭐ + ⭐⭐ + ⭐⭐ + ⭐ (MIT no código, mas ToS inacabados +
`robots.txt` bloqueando `/api/*`) + ⭐⭐ + 0 + 0 (sem lib R) + ⭐ = **10**,
rebaixada ao não poder entrar como fonte de ingestão em lote.

**Rastro:** `BrasilAPI/BrasilAPI` README (seção Termos de Uso) ·
`brasilapi.com.br/robots.txt` · payloads ao vivo

**Riscos / cuidados:**
- **Não usar para ingestão em lote.** `robots.txt` diz `Disallow: /api/*` e o
  README proíbe automação — o próprio projeto cita um provedor estourando 5× o
  limite. Um job noturno do EduMaps é exatamente o padrão a evitar. **Só sob
  demanda, volume de pessoa real.**
- **FIPE fora do ar (404)** — corrigir qualquer doc que a cite via BrasilAPI.
- **Sem versionamento de resposta nem SLA**: mudança de schema quebra o ETL em silêncio.
- Para `cep → cod_ibge` **em escala**, usar base dos Correios ou `basedosdados`;
  BrasilAPI é o atalho, não a fonte canônica.

---

### BrazilDataAPI (CRAN)

| Campo | Valor |
|---|---|
| **URL** | https://cran.r-project.org/package=BrazilDataAPI |
| **Mantenedor** | Renzo Caceres Rossi (aut, cre) — pessoa física, mantenedor único |
| **Licença** | **GPL-3** (copyleft forte) |
| **Formato** | API REST via `httr` + datasets curados embarcados |
| **Granularidade** | **estado** (população por estado/ano) e **nacional** (World Bank) — **zero municipal, zero escolar** |
| **Periodicidade** | irregular (wrappers + datasets estáticos versionados no CRAN) |
| **API/SDK oficial** | não (as APIs de destino não são oficiais); sim como pacote R (v0.3.0, 2026-07-02) |
| **Cobertura temporal** | não verificada |
| **Cobertura geográfica** | nacional, sem desagregação municipal |
| **LGPD** | risco **baixo** — demografia agregada, sem dado pessoal |

**Relevância para o EduMaps:** **praticamente nula** para o IVET. É um canivete
suíço genérico (CEP, CNPJ, feriados, bancos, desenvolvimento econômico) que
**não toca em educação, orçamento público nem SIOPE**. Único dado com alguma
utilidade: população estadual por ano — o nível mais grosseiro possível para um
índice **territorial**.

**Indicador derivado possível:** nenhum aplicável. No máximo, covariável de
controle grosseira, descartável diante de qualquer fonte municipal.

**Prioridade:** `[baixa]` — 7 pontos, rebaixada a `[baixa]`

**Justificativa:** ⭐ + ⭐⭐ + ⭐ (só estadual) + ⭐ (GPL-3) + ⭐⭐ + 0 + ⭐ + 0 =
**7**, rebaixada por **dois** gatilhos: "só estadual sem desagregação" e
copyleft GPL-3 (a mais restritiva do lote para composição).

**Rastro:** CRAN `BrazilDataAPI` v0.3.0 · repo `lightbluetitan/brazildataapi`

**Riscos / cuidados:**
- **Escopo desalinhado com o IVET** — não investir tempo.
- **GPL-3 com repo sem LICENSE detectável** (`license: null` na API do GitHub):
  depender do CRAN e conferir o `LICENSE` empacotado.
- **Bus factor 1** (3 stars). Se o autor abandonar, sai do CRAN.
- Origem variável: Nager.Date e REST Countries são projetos estrangeiros.

---

### APIs-PublicasBrasil (IF-TI)

| Campo | Valor |
|---|---|
| **URL** | https://github.com/IF-TI/APIs-PublicasBrasil |
| **Mantenedor** | Organização `IF-TI` (11 stars) — ⚠️ **sem LICENSE** (API retorna `license: null`; arquivo 404) |
| **Licença** | **Nenhuma declarada** — sem licença, o padrão é "todos os direitos reservados": não há direito de reuso |
| **Formato** | Markdown (tabelas de links) — **não é API nem SDK** |
| **Granularidade** | n/a (lista de links); as fontes linkadas são majoritariamente federais |
| **Periodicidade** | **abandonada**: criado e último push em 2025-07-28, 39 segundos depois — zero atualização em ~14 meses |
| **API/SDK oficial** | não |
| **Cobertura temporal** | n/a — README declara "Última atualização: 28/07/2025" |
| **Cobertura geográfica** | nacional (federais; nenhum link para SIOPE, SICONFI, INEP) |
| **LGPD** | n/a — a lista não contém dados |

**Relevância para o EduMaps:** **nenhuma**. Verificada a lista inteira: **não
menciona INEP, microdados do Censo, SIOPE, FNDE, SICONFI, Tesouro, IDEB nem
orçamento educacional**. Na seção "Educação e Cultura" há só "MEC - Dados
Abertos" e "Museus do Brasil". Não introduz fonte nova alguma.

**Indicador derivado possível:** **nenhum** — sem dados, sem granularidade, sem
chave de junção, sem API.

**Prioridade:** `[baixa]` — 4 pontos, rebaixada

**Justificativa:** ⭐ + ⭐⭐ + ⭐ = **4**, rebaixada por **três** gatilhos:
ausência de licença (hard blocker para qualquer artefato derivado), abandono
há ~14 meses com commit único, e zerar justamente os dois critérios de peso
máximo da calibração de ferramentas de acesso (API estável e ferramenta pronta).

**Rastro:** `IF-TI/APIs-PublicasBrasil` README + `api.github.com/repos/...`
(`license: null`, `pushed_at: 2025-07-28T13:50:22Z`)

**Riscos / cuidados:**
- O item 3 da issue **mistura dois repositórios**: `public-apis` é outro projeto,
  internacional, sem relação com o Brasil.
- **Links provavelmente mortos** após 14 meses sem manutenção. **Não usar como
  fonte de verdade** — para índice confiável, usar `dados.gov.br` (CKAN) direto.
- **Sem licença = sem direito de reuso**: nem para copiar a tabela num doc interno.

---

## Síntese do lote

| Fonte | Prioridade | Pontos | Motivo |
|---|---|---|---|
| **Base dos Dados** | 🟢 `[alta]` | 18 | Censo Escolar 2007–2022 em BigQuery; resolve a ingestão e dá série histórica. |
| **tesouror** | 🟢 `[alta]` | 17 | SIOPE + **SICONFI** (fiscal municipal) — abre uma dimensão nova do IVET. |
| **MCP-Brasil** | 🟢 `[alta]` | 16 | FNDE + SICONFI + cache DuckDB do Censo; comunitário e recente. |
| **geobr/ibger/censobr** | 🟢 `[alta]` | 15 | Malhas oficiais + **setor censitário desde 1960** → vulnerabilidade intra-municipal. |
| **BrasilAPI** | 🟡 `[média]` | 10 | Só `cep → cod_ibge` sob demanda; ToS/robots proibem lote. |
| **BrazilDataAPI** | 🔴 `[baixa]` | 7 | Só estadual, GPL-3, escopo desalinhado do IVET. |
| **APIs-PublicasBrasil** | 🔴 `[baixa]` | 4 | Sem licença, abandonada, não introduz fonte nova. |

**Correção de registro**: `ibge7`, `geodesobr` e `RRPP` **saem do cadastro** de
fontes do IBGE (inexistentes / não relacionados). `geobr` é o substituto correto
de `geodesobr`.