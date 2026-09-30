# Fontes — Educação e dados escolares

> Lote A da issue #123 · contexto do eixo **educacional** (o que o IVET já
> tem como base) e indicadores de **resultado**.
> Método, pesos e regras: [`../fontes_de_dados.md`](../fontes_de_dados.md).

## ⚠️ Nota de qualidade desta rodada

Este lote foi o de **verificação mais fraca** dos oito: a pesquisa retornou os
campos do template sem preencher ("`sim (R / Python / HTTP) / não`") e deixou a
licença como "não verificado" em todas as fichas.

**Segunda passada executada (2026-09-30)**: extraí os `href` reais da página do
INEP (o `webfetch` havia devolvido só navegação) e resolvi **2 das 4 pendências**:

- ✅ **Cobertura temporal do Censo Escolar: 1995–2025, 31 edições** — a alegação
  original do levantamento ("desde 1995") estava **correta** e foi confirmada.
- ✅ **Padrão de URL confirmado**, com um *gotcha* registrado abaixo.
- ❌ **Licença: continua não verificada.** Ver a ficha do Censo Escolar.
- ❌ **Painel do PNE e download do Atlas**: não verificados nesta passada.

**Consequência honesta, mantida**: sem licença verificada, nenhuma fonte deste
lote pode entrar como `[alta]`. É a regra nº 9 do método funcionando — o jeito de
atingir o critério de aceite é marcar a pendência, não arredondar o dado.

---

### INEP — Microdados do Censo Escolar

| Campo | Valor |
|---|---|
| **URL** | https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar |
| **Mantenedor** | INEP — Instituto Nacional de Estudos e Pesquisas Educacionais Anísio Teixeira (MEC) |
| **Licença** | ❌ **não verificada, e esta é a pendência que bloqueia a promoção** — a página do microdado e o *Plano de Dados Abertos* do INEP **não publicam termo de uso nem SPDX específico para os dados**. O único texto de licença encontrado é o **rodapé do portal gov.br** (*"Todo o conteúdo deste site está publicado sob a licença Creative Commons Atribuição-SemDerivações 3.0 Não Adaptada"*) — que cobre **conteúdo do site**, não necessariamente os dados. O INEP publica RIPDs com análise da ANPD, o que é governança de tratamento, **não** licença de reutilização. **Ação: e-SIC/Fala.BR ao INEP ou consulta ao SEDAP.** |
| **Formato** | CSV dentro de ZIPs anuais. **Padrão confirmado**: `https://download.inep.gov.br/dados_abertos/microdados_censo_escolar_<ano>.zip` |
| **Granularidade** | **escola** (e turmas/movimento) |
| **Periodicidade** | anual |
| **API/SDK oficial** | não — download de arquivos; não há API REST |
| **Cobertura temporal** | ✅ **1995–2025, 31 edições** (verificado: 30 hrefs `1995…2024` + `2025`) |
| **Cobertura geográfica** | nacional |
| **LGPD** | ⚠️ **risco alto**: microdados com **nível individual**. O INEP adotou anonimização e elaborou RIPDs com análise da ANPD — ainda assim exige agregação |

**Verificação (2026-09-30)**: página de microdados do INEP **200** (219.952 bytes
de HTML). Extraídos os `href` do host `download.inep.gov.br`: **30 arquivos**
`microdados_censo_escolar_1995.zip` … `microdados_censo_escolar_2024.zip`, mais
**`microdados_censo_escolar_2025_.zip`** (ver gotcha abaixo). Página marcada como
*"Atualizado em 31/07/2026"*; a entrada 2025 consta como *"Documento atualizado
em julho/2026"*. `download.inep.gov.br` resolve em DNS (`200.130.24.15`), mas o
**handshake TLS falha deste ambiente** — a carga precisa ser verificada a partir
da rede de deploy.

**Relevância para o EduMaps:** é a **base estrutural já usada** pelo EduMaps
(estabelecimentos, turmas, matrículas, profissionais, movimento). Não é lacuna
nova: é a coluna vertebral do IVET. O valor como *fonte candidata* está em
(1) ampliar o histórico para série temporal e (2) incorporar variáveis mais
recentes de infraestrutura e condições escolares.

**Indicador derivado possível:** taxa de distorção idade-série · indicadores de
fluxo (aprovação/reprovação/abandono) · cobertura de etapas/modalidades ·
indicadores de recursos humanos e infraestrutura por escola.

**Prioridade:** `[média]` — rebaixada por campos críticos não verificados

**Justificativa:** intrinsecamente é ⭐⭐⭐ (granularidade escolar) + ⭐⭐ (nacional)
+ ⭐⭐ (anual) + ⭐⭐⭐ (é o próprio Censo) — mas **licença, cobertura temporal e
padrão de URL não foram verificados**, e a granularidade individual exige
disciplina de LGPD. Sem confirmação de licença, rebaixada porprudência.

**Rastro:** página de microdados do INEP · `gov.br/inep` seção *Tratamento de
Dados Pessoais* · (Zotero: `Z:9892` — *Dicionário de Dados Tabela_Escolas.csv
(Censo 2025)*, `Z:11901` — *Aula 3: Indicadores Educacionais SAEB e Censo*)

**Riscos / cuidados:**
- 🔴 **Gotcha de URL no ano de 2025 (verificado)**: a edição 2025 **não** segue o
  padrão das demais — o arquivo é `microdados_censo_escolar_2025_**_**.zip`, com
  um **underscore extra** antes da extensão. Um ETL que monte a URL por
  interpolação `%d` recebe **404 só em 2025**, sem erro em nenhum outro ano. Não
  corrigir "à mão" no meio do pipeline: manter uma **tabela de exceções** de
  URLs, ou baixar por **scraping do `href`** da página oficial, que é a única
  fonte que não mente.
- **Nunca usar tabelas de nível aluno** no IVET — agregue por escola ou acima.
  Crossar perfil socioeconômico de estudante é tratamento de dado sensível de
  crianças e adolescentes.
- ZIPs de vários GB por ano: exigir armazenamento e ETL próprios.
- ⚠️ **Licença ainda não verificada** — este é o único item que impede `[alta]`.
  Enquanto não houver resposta do INEP, tratar com uso institucional interno.
- ⚠️ **Handshake TLS** com `download.inep.gov.br` falhou neste ambiente
  (DNS resolve). Verificar a partir da rede de deploy antes de dimensionar o job.

---

### INEP — IDEB

| Campo | Valor |
|---|---|
| **URL** | https://www.gov.br/inep/pt-br/areas-de-atuacao/pesquisas-estatisticas-e-indicadores/ideb/resultados |
| **Mantenedor** | INEP / MEC |
| **Licença** | ⚠️ não verificada (dados abertos do gov.br; sem SPDX identificado) |
| **Formato** | planilhas/ZIPs por ciclo (escola, município, UF) — padrão não verificado nesta rodada |
| **Granularidade** | **escola** e **município** |
| **Periodicidade** | anual (desde 2005) |
| **API/SDK oficial** | não — download de planilhas |
| **Cobertura temporal** | **desde 2005** (o IDEB iniciou em 2005) |
| **Cobertura geográfica** | nacional |
| **LGPD** | risco **baixo** — resultados já agregados e públicos |

**Relevância para o EduMaps:** é o **indicador sintético de qualidade** mais
usado para acompanhamento de metas. Não é lacuna nova — é **variável de
resultado**, útil para ranking, similaridade e como validação externa do IVET.

**Indicador derivado possível:** IDEB por escola/município (normalizado para o
índice composto) · `delta_ideb_ano` (variação anual).

**Prioridade:** `[média]` — 11 pontos

**Justificativa:** ⭐⭐⭐ (resultado educacional) + ⭐⭐⭐ (escola/município) +
⭐⭐ (nacional) + ⭐⭐ (anual) + ⭐⭐ (compatível com ciclo de gestão) + ⭐⭐ (complementa) = **11**;
sem API oficial e sem licença verificada não sobe a `[alta]`.

**Rastro:** página de resultados do IDEB · seção *outros-documentos* (notas
técnicas e nota informativa do IDEB)

**Riscos / cuidados:** estrutura de arquivos pode variar entre ciclos — fixar o
ciclo no nome da tabela. Baixo risco LGPD desde que só se use o agregado público.

---

### PNUD / Ipea / FJP — Atlas do Desenvolvimento Humano (IDHM)

| Campo | Valor |
|---|---|
| **URL** | https://www.atlasbrasil.org.br/ |
| **Mantenedor** | PNUD Brasil, Ipea e Fundação João Pinheiro (FJP) |
| **Licença** | uso público com atribuição (não verificada em SPDX) |
| **Formato** | portal interativo + bases de dados para download (XLSX/CSV) |
| **Granularidade** | **município** (e UF, UDH, RM) |
| **Periodicidade** | anual (derivada de censos + PNAD Contínua) |
| **API/SDK oficial** | não — portal + download de bases |
| **Cobertura temporal** | ⚠️ a série completa exibida é **1991–2021** (Censos 1991/2000/2010 + PNAD Contínua 2012–2021); a home já exibe **IDHM 2024** para o Brasil |
| **Cobertura geográfica** | nacional |
| **LGPD** | risco **muito baixo** — 100% agregado por município |

**Verificação (2026-09-30)**: home → **HTTP 200**. Conteúdo confirma: *"IDHM
2024"* (Brasil 0,805), *"Evolução do IDHM para as UFs entre 1991 e 2021"*,
*"Fonte: Censos demográficos, 1991, 2000 e 2010. PNAD Contínua 2012 a 2021"*.
Dimensões expostas no perfil: **IDHM, POPULAÇÃO, SAÚDE, EDUCAÇÃO, RENDA,
HABITAÇÃO, VULNERABILIDADE, MEIO AMBIENTE, PARTICIPAÇÃO POLÍTICA**. O Atlas
declara *"cerca de 120 indicadores que dialogam com os ODS para o nível
municipal"* e *"78 indicadores municipais, anuais e atualizados de registros
administrativos"*.

**Relevância para o EduMaps:** **achado que muda a priorização da lacuna 1**. O
Atlas não é só IDHM: publica **~120 indicadores municipais**, com dimensões
**SAÚDE** e **VULNERABILIDADE** já calculadas. Isso significa que boa parte da
**lacuna de saúde** pode ser endereçada **agregada por município, sem risco LGPD
e sem depender de acesso difícil ao DATASUS**, que é justamente o lote de maior
dificuldade de acesso. É contexto oficial (PNUD/Ipea/FJP), não memória.

**Indicador derivado possível:** IDHM e IDHM-AD por município · componentes
(renda, longevidade, educação) como covariáveis de ponderação do IVET ·
**dimensão SAÚDE do Atlas como proxy de condição de saúde** · desagregações por
sexo e raça/cor para desigualdade territorial.

**Prioridade:** `[média]` — 12 pontos

**Justificativa:** ⭐⭐ + ⭐⭐ + ⭐⭐⭐ (município) + ⭐⭐ + ⭐⭐ + ⭐ = **12**, mais
um bônus de relevância: cobre parcialmente a lacuna 1 (saúde) e a 6 (meio
ambiente) por indicadores **já consolidados**. Sem API oficial e com
licença não verificada em SPDX.

**Rastro:** `atlasbrasil.org.br` (verificado 2026-09-30) · Painel IDHM no site do
PNUD Brasil · bases de dados na seção *Acervo*

**Riscos / cuidados:**
- **Não cobre granularidade escolar** — entra como atributo do município da
  escola, não da escola.
- Atualização depende de divulgação censos/PNAD (**intercensal**).
- Licença/termos não verificados em SPDX: confirmar antes de republicar.

---

### INEP — ENEM (microdados)

| Campo | Valor |
|---|---|
| **URL** | https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/enem |
| **Mantenedor** | INEP / MEC |
| **Licença** | ⚠️ não verificada |
| **Formato** | CSV em ZIPs anuais (`microdados_enem_<ano>.zip` + complementos de redação) |
| **Granularidade** | **inscrito** (individual) — ⚠️ |
| **Periodicidade** | anual |
| **API/SDK oficial** | não |
| **Cobertura temporal** | edições 2009–2025 (não verificada nesta rodada) |
| **Cobertura geográfica** | nacional |
| **LGPD** | ⚠️ risco **relevante** — microdados individuais de inscritos |

**Relevância para o EduMaps:** desempenho por área e redação, mais o
questionário do inscrito. Complementa SAEB/IDEB na lacuna de **resultado do
ensino médio**.

**Indicador derivado possível:** média de notas por área/redação agregada por
município · desigualdade de desempenho por característica (com agregação) ·
cobertura/participação por território com ponderação.

**Prioridade:** `[média]` — 10 pontos, com ressalva metodológica

**Justificativa:** ⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐ = **10**. Perde pontos por não ser
censitário (participação voluntária → auto-seleção enviesa médias de município
com baixa participação) e por granularidade individual.

**Rastro:** página de microdados do ENEM · página de microdados do INEP (RIPDs do
Enem com adequação validada pela ANPD)

**Riscos / cuidados:**
- **Cobertura não censitária** — auto-seleção; ponderar ou descartar municípios com
  baixa participação.
- **Suprimir células pequenas** ao agregar.
- A série **"ENEM por escola" agregada cobre só 2005–2015** — não serve para anos
  recentes; para o uso atual é preciso agregar por município.

---

### PNE — Painel de Monitoramento

| Campo | Valor |
|---|---|
| **URL** | https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/inep-data/painel-de-monitoramento-do-pne |
| **Mantenedor** | INEP/MEC (instâncias: MEC, CNE, FNE, Congresso) |
| **Licença** | ⚠️ não verificada |
| **Formato** | ⚠️ **painel de BI (Power BI)** — sem CSV/XLSX massivo evidente |
| **Granularidade** | nacional/estadual por meta; **municipal em versões recentes** (não uniforme por indicador) |
| **Periodicidade** | ciclos de monitoramento (irregular, ~bienal) |
| **API/SDK oficial** | não |
| **Cobertura temporal** | PNE 2014–2024, com 5º ciclo em 2025 (não verificado) |
| **Cobertura geográfica** | nacional |
| **LGPD** | risco **baixo** — agregados |

**Relevância para o EduMaps:** indicadores de acompanhamento de política
educacional (matrículas, infraestrutura, financiamento, qualidade, equidade),
com desagregação por perfil socioeconômico.

**Indicador derivado possível:** indicadores por meta/estratégia · metas de
universalização, qualidade (IDEB), formação docente, investimento.

**Prioridade:** `[baixa]` — rebaixada por acesso

**Justificativa:** os critérios substantivos somariam bem, **mas o dado está
atrás de um Power BI** — extrair exigiria scraping de elementos dinâmicos, que é
exatamente a regra de rebaixamento do método ("exige scraping frágil"). Sem API
nem download massivo, fica `[baixa]` até haver rota de dados abertos.

**Rastro:** página do Painel de Monitoramento do PNE · `gov.br/inep` *Inep Data*
· FAQ de Monitoramento do PNE

**Riscos / cuidados:** **não raspar o Power BI** (token dinâmico, frágil e
termo de uso). Reavaliar se o INEP publicar CSV.

---

### UNESCO UIS — SDG 4

| Campo | Valor |
|---|---|
| **URL** | https://uis.unesco.org/ · navegador https://databrowser.uis.unesco.org/ |
| **Mantenedor** | UNESCO Institute for Statistics |
| **Licença** | Termos de uso do UIS — atribuição e restrições de redistribuição **não verificadas** |
| **Formato** | navegador + download CSV; API SDMX/SDG **em evolução** (não estável) |
| **Granularidade** | ⚠️ **país** (e região) — **não desagrega de forma consistente a município/escola** |
| **Periodicidade** | anual, por indicador (variável) |
| **API/SDK oficial** | não estável (SDMX experimental; `unstats.un.org/sdgapi/` é da ONU, não do UIS) |
| **Cobertura temporal** | varia por indicador |
| **Cobertura geográfica** | mundial/nacional |
| **LGPD** | sem risco |

**Relevância para o EduMaps:** padrões internacionais de medição (SDG 4) para
**benchmarking** e relatórios — não para o eixo territorial.

**Indicador derivado possível:** indicadores SDG 4.1.1 (proficiência em leitura e
matemática), 4.2.x, 4.5.x (desigualdades), 4.a (ambientes seguros e inclusivos).

**Prioridade:** `[baixa]` — rebaixada por granularidade

**Justificativa:** rebaixa pela regra **"granularidade apenas estadual/nacional
sem desagregação"**: predomina o nível país, o que é inútil para um índice
**territorial**. Contribuição marginal frente às fontes brasileiras.

**Rastro:** `uis.unesco.org` · termos de uso em `uis.unesco.org/en/terms-use`

**Riscos / cuidados:** termos de uso exigem atribuição e podem restringir
redistribuição. Só usar para contexto/relatório, nunca como insumo do IVET.

---

## Síntese do lote

| Fonte | Prioridade | Pontos | Motivo |
|---|---|---|---|
| **Atlas / IDHM (PNUD)** | 🟡 `[média]` | 12 | **Melhor achado do lote**: ~120 indicadores municipais, com dimensões SAÚDE e VULNERABILIDADE — abre parte da lacuna 1 sem risco LGPD. |
| **IDEB (INEP)** | 🟡 `[média]` | 11 | Variável de **resultado**; sem API e sem licença verificada. |
| **ENEM (INEP)** | 🟡 `[média]` | 10 | Resultado do EM, mas auto-seleção e granularidade individual. |
| **Censo Escolar (microdados)** | 🟡 `[média]` | — | Coluna vertebral já usada; rebaixada por **licença e cobertura temporal não verificadas**. |
| **Painel do PNE** | 🔴 `[baixa]` | — | Atrás de **Power BI** — exigiria scraping frágil. |
| **UNESCO UIS** | 🔴 `[baixa]` | — | Granularidade de **país** — inútil para índice territorial. |

## 🔴 Tarefa em aberto — terceira passada de verificação

A **segunda passada** (2026-09-30) resolveu a cobertura temporal e o padrão de
URL do Censo Escolar. Restam três pendências concretas, **todas de licença** —
que é o único critério que ainda separa este lote de `[alta]`:

1. **Licença** de: microdados do Censo Escolar, IDEB, ENEM, painel do PNE —
   obter Termos de Uso/SPDX. O INEP publica o *Plano de Dados Abertos*, mas
   **sem licença por conjunto**. Caminho: **e-SIC/Fala.BR ao INEP** ou consulta ao
   **SEDAP** (Serviço de Acesso a Dados Protegidos, link no menu *Dados Abertos*).
2. Confirmar se o **painel do PNE** tem rota de dados abertos (CSV) — se tiver,
   sobe de `[baixa]` para `[média]`.
3. Confirmar download massivo do **Atlas** em CSV (hoje a base está em XLSX na
   seção *Acervo*) — destravaria a ingestão em R.

**Impacto no plano:** como nenhuma fonte do lote educação tem licença
verificada, **nenhuma entra na Fase 1 de implementação**. Isso não impede
concluir o catálogo — bloqueia a promoção a `[alta]`, e a ação de maior retorno é
uma única e-SIC com as quatro perguntas de uma vez.