# Fontes — Segurança pública

> Lote F da issue #123 · lacuna do IVET nº 2 (**segurança pública**).
> Método, pesos e regras: [`../fontes_de_dados.md`](../fontes_de_dados.md).

**Achado central do lote**: a fonte primária (**SINESP/Infoseg**) tem
**acesso restrito a órgãos de segurança pública** — não há download em massa
aberto. O caminho viável e reprodutível é o **BrazilCrime** (CRAN), que empacota
os dados do SINESP para consumo em R. Isso inverte apriorização: a fonte com
melhor interface é um *wrapper*, não o órgão.

> ⚠️ **Regra de ouro deste domínio**: usar **exclusivamente contagens
> agregadas por município** (ou estado). Nunca coordenadas de ocorrência,
> endereço ou identificação de vítima. Aplicar **supressão de células
> pequenas** (count < 5) para evitar reidentificação.

---

### BrazilCrime (CRAN) — acesso a dados do SINESP

| Campo | Valor |
|---|---|
| **URL** | https://cran.r-project.org/package=BrazilCrime |
| **Mantenedor** | Giovanni Vargette (aut/cre), Igor Laltuf, Marcelo Justus — Unicamp |
| **Licença** | MIT + file LICENSE (código do pacote). **Termos dos dados são do SINESP e não estão na página do CRAN — a confirmar.** |
| **Formato** | Pacote R (funções que baixam/filtram); devolve data frames |
| **Granularidade** | município e estado |
| **Periodicidade** | herda a atualização do SINESP (não verificada) |
| **API/SDK oficial** | sim — R (wrapper do SINESP) |
| **Cobertura temporal** | desde 2015 |
| **Cobertura geográfica** | nacional (por estado/município) |
| **LGPD** | Wrapper: **não anonimiza**. Risco do integrador. Usar só agregado por município/estado. |

**Verificação (2026-09-30)**: página CRAN conferida — v0.3.0, publicado
2025-09-05, `Depends: R (≥ 4.1.0)`, `Imports: dplyr, forecast, ggplot2`,
DOI `10.32614/CRAN.package.BrazilCrime`, licença MIT, descrição oficial
"Accesses Brazilian Public Security Data from SINESP Since 2015 — by state and
municipality". Duas vignettes (acesso aos dados; previsões).

**Relevância para o EduMaps:** fecha a lacuna 2 do IVET com dado **nacional**,
**municipal** e já dentro da stack R do projeto (`analysis/edumapsr`), sem
scraping próprio.

**Indicador derivado possível:** **taxa de ocorrências por 100 mil habitantes
por município**, por categoria; indicador de exposição a
violência no entorno escolar (agregado municipal, aplicado como atributo do
município da escola).

**Prioridade:** `[alta]` — 3+2+3+2+2+1+3 = **16 pontos** (sem contar periodicidade, não verificada)

**Justificativa:** endereça lacuna direta (⭐⭐⭐), SDK R estável no CRAN
(⭐⭐), granularidade municipal (⭐⭐⭐), licença MIT do pacote (⭐⭐, com
ressalva dos termos dos dados), cobertura nacional (⭐⭐), já é ferramenta de
acesso pronta (⭐), complementa Censo/OSM/SIOPE (⭐⭐⭐).

**Rastro:** https://cran.r-project.org/package=BrazilCrime ·
DOI 10.32614/CRAN.package.BrazilCrime

**Riscos / cuidados:**
- **LGPD é a maior risco do IVET**: o pacote não anonimiza. Responsabilidade é
  nossa — agregar por município, aplicar supressão de células pequenas
  (count < 5) e nunca cruzar com identificador de escola em células pequenas.
- Depende da disponibilidade/estrutura do SINESP (fonte primária pode mudar).
- Termos de uso dos **dados** (não do código) não verificados: confirmar antes
  de publicar imagens/dados derivados.
- Enviar dados de crime ao Sentry/backend exigiria o mesmo cuidado de
  sanitização já existente (`_sanitize_args`).

---

### SINESP / Infoseg (SENASP — MJSP)

| Campo | Valor |
|---|---|
| **URL** | https://www.gov.br/mj/pt-br/assuntos/sua-seguranca/seguranca-publica/sinesp-1 |
| **Mantenedor** | SENASP — Secretaria Nacional de Segurança Pública (MJSP) |
| **Licença** | não verificada (uso operacional restrito) |
| **Formato** | não verificado — sem seção pública de download em massa na página institucional |
| **Granularidade** | não verificada (sistema operacional; agregações existem mas não publicadas abertamente) |
| **Periodicidade** | não verificada |
| **API/SDK oficial** | não — Infoseg é de uso restrito a profissionais de segurança pública |
| **Cobertura temporal** | não verificada |
| **Cobertura geográfica** | nacional (uso restrito) |
| **LGPD** | não explicitada publicamente; presume-se alto risco se incluir localização pontual |

**Relevância para o EduMaps:** é a **fonte primária** por trás do BrazilCrime.
Importante para memória e atribuição, não para ingestão direta.

**Indicador derivado possível:** (via BrazilCrime) — ver ficha acima.

**Prioridade:** `[baixa]` — rebaixada pela regra de **acesso restrito/licença não
verificada**, apesar de ser a melhor cobertura nacional.

**Justificativa:** não há via aberta de consulta/download em massa confirmada;
Infoseg é restrito a órgãos de segurança. Integrar exigiria convênio/autorização,
não escopo de um pipeline público.

**Rastro:** página institucional SINESP (MJSP) — verificada em 2026-09-30

**Riscos / cuidados:**
- Não fazer scraping de interface operacional: ilegal/termo de uso/fragilidade.
- Citar SINESP como origem em qualquer análise que use BrazilCrime.

---

### SINESP municipal / portais estaduais de segurança

| Campo | Valor |
|---|---|
| **URL** | não há URL única (variável por UF/município) |
| **Mantenedor** | Secretarias estaduais/municipais de Segurança Pública |
| **Licença** | não verificada — varia por órgão |
| **Formato** | não verificado (relatórios/boletins, CSVs avulsos) |
| **Granularidade** | bairro/ocorrência em alguns portais — não escolar |
| **Periodicidade** | não verificada |
| **API/SDK oficial** | não |
| **Cobertura temporal** | não verificada |
| **Cobertura geográfica** | regional/municipal — **heterogênea** |
| **LGPD** | boletins podem conter identificadores/addresses → risco alto |

**Relevância para o EduMaps:** desagregação por bairro seria valiosa para
"entorno escolar", mas a heterogeneidade inviabiliza cobertura nacional.

**Indicador derivado possível:** ocorrências agregadas por bairro (só se já
agregadas e anonimizadas na origem).

**Prioridade:** `[baixa]` — rebaixada: sem API, scraping frágil, sem
padronização, cobertura não nacional.

**Justificativa:** a regra de rebaixamento se aplica integralmente; integrar 27
portais diferentes não é sustainable nem reprodutível.

**Rastro:** nenhum portal individual verificado nesta rodada (amostra por UF
seria trabalho dedicado).

**Riscos / cuidados:**
- Alto risco LGPD/ética se boletins tiverem endereço ou vítima.
- Licenças inconsistentes — não reutilizar sem termos explícitos.

---

### SNSP / "Banco Nacional de Dados de Segurança" (SUSP)

| Campo | Valor |
|---|---|
| **URL** | não verificada (referenciado em páginas do MJSP/SUSP) |
| **Mantenedor** | MJSP/SENASP (Sistema Único de Segurança Pública) |
| **Licença** | não verificada |
| **Formato** | não verificado |
| **Granularidade** | não verificada |
| **Periodicidade** | não verificada |
| **API/SDK oficial** | não verificada |
| **Cobertura temporal** | não verificada |
| **Cobertura geográfica** | não verificada |
| **LGPD** | risco alto se houver microdados sensíveis |

**Relevância para o EduMaps:** conceitualmente relevante (SUSP articula o
sistema nacional), mas sem conjunto de dados abertos confirmado.

**Indicador derivado possível:** (a confirmar — pode ser apenas agregados
estaduais/municipais)

**Prioridade:** `[baixa]` — ficha essencialmente **não verificada**; permanece
como *lead* a confirmar em dados.gov.br / dados.gov.br/mj antes de qualquer uso.

**Justificativa:** sem URL canônica, licença ou formato confirmados, não atende
ao critério de rastreabilidade.

**Rastro:** referência institucional SUSP/Lei 13.675 (MJSP)

**Riscos / cuidados:** pode ser apenas infraestrutura operacional, não repositório
aberto. Não usar sem confirmação oficial.

---

### Crime Brasil / repositórios estaduais de crime

| Campo | Valor |
|---|---|
| **URL** | não verificada (múltiplas iniciativas homônimas; nenhum repositório **oficial** único identificado) |
| **Mantenedor** | projetos de terceiros (jornalismo/universidade), não órgão público |
| **Licença** | não verificada |
| **Formato** | não verificado |
| **Granularidade** | município (em geral) |
| **Periodicidade** | não verificada |
| **API/SDK oficial** | não |
| **Cobertura temporal** | não verificada |
| **Cobertura geográfica** | parcial (depende do projeto) |
| **LGPD** | depende da fonte; se agregada, baixo risco |

**Relevância para o EduMaps:** poderia ser alternativa mais leve ao BrazilCrime,
mas a origem dos dados é incerta (derivam do SINESP, provavelmente).

**Indicador derivado possível:** taxa de crime municipal — redundante com
BrazilCrime.

**Prioridade:** `[baixa]` — sem rastreabilidade à fonte primária e licença
não verificada.

**Justificativa:** critério de rebaixamento "licença restritiva/não verificada";
preferir o caminho oficial (BrazilCrime/SINESP) a replicações de terceiros.

**Rastro:** não verificado nesta rodada.

**Riscos / cuidados:**-chain de origem opaca; não usar como fonte única.

---

### Observatórios de segurança urbana / MapBiomas Segurança

| Campo | Valor |
|---|---|
| **URL** | não verificada |
| **Mantenedor** | terceiros (ONGs, universidades, projetos de mapeamento) |
| **Licença** | não verificada (variável; CC-BY costuma, mas não garantido) |
| **Formato** | não verificado |
| **Granularidade** | município/bairro quando agregado |
| **Periodicidade** | não verificada |
| **API/SDK oficial** | não |
| **Cobertura temporal** | não verificada |
| **Cobertura geográfica** | parcial |
| **LGPD** | se agregada, baixo-médio risco |

**Relevância para o EduMaps:** KPIs de violência urbana já consolidados; **complementar**
BrazilCrime como leitura de contexto, não como fonte primária.

**Indicador derivado possível:** índices sintéticos de exposição (homicídio,
violência) — mas como *contexto*, não indicador do IVET.

**Prioridade:** `[baixa]` — fontes majoritariamente não oficiais, licenças e
sustentabilidade incertas.

**Justificativa:** regra de rebaixamento — fonte não oficial com rastreabilidade
da primária não comprovada.

**Rastro:** não verificado nesta rodada.

**Riscos / cuidados:** evitar usar como insumo de índice sem documentar a
origem.

---

## Síntese do lote

| Fonte | Prioridade | Motivo |
|---|---|---|
| **BrazilCrime (CRAN)** | 🟢 `[alta]` | Único caminho reproduzível, nacional, municipal, em R. |
| SINESP/Infoseg | 🔴 `[baixa]` | Acesso restrito; é a primária, não a interface. |
| SINESP municipal/estadual | 🔴 `[baixa]` | Sem API, scraping frágil, heterogêneo. |
| SNSP (SUSP) | ⚪ `[baixa]` | Não verificado (lead). |
| Crime Brasil | 🔴 `[baixa]` | Não oficial, origem opaca. |
| Observatórios/MapBiomas | 🔴 `[baixa]` | Terceiros; apenas contexto. |

**Conclusão**: a lacuna 2 do IVET é endereçável **apenas via BrazilCrime**, com
métricas municipais agregadas e forte disciplina de LGPD. Isso torna segurança
pública a **lacuna mais barata** de fechar (um `library(BrazilCrime)`) e também
a de **maior risco ético** — deve entrar no ciclo com revisão de LGPD antes de
qualquer exposição na interface.