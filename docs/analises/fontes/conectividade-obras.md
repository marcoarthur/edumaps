# Fontes — Conectividade, obras e investimentos planejados

> Lote C da issue #123 · lacunas do IVET nº 3 (**conectividade**) e nº 4
> (**investimentos planejados**).
> Método, pesos e regras: [`../fontes_de_dados.md`](../fontes_de_dados.md).

**Achado central do lote**: a lacuna 4 (investimentos) tem uma fonte **sólida e
verificada** — o **Portal da Transparência/CGU** — mas a lacuna 3 (conectividade)
**não tem nenhuma fonte limpa**: o Medidor Educação Conectada é a única medição
nacional de qualidade de banda larga em granularidade escolar, porém está atrás
de um app Shiny sem API e sem licença publicada.

**Bloqueio estrutural verificado**: o portal de dados abertos do **FNDE** é uma
**SPA (Vue) sem renderização server-side**, cujos assets respondem **404** a
clientes não-browser, e o CKAN do Portal Brasileiro de Dados Abertos exige
autenticação (**HTTP 401**). Isso torna **inviável qualquer pipeline R direto**
contra FNDE — não é_limitação do desenho do EduMaps, é da fonte. As fontes
FNDE (Novo PAC, PNATE) ficam rebaixadas por esse motivo, e não por mérito
desconhecido.

---

### CGU / Portal da Transparência — recursos transferidos (FNDE e demais)

| Campo | Valor |
|---|---|
| **URL** | https://portaldatransparencia.gov.br/download-de-dados/transferencias · docs https://portaldatransparencia.gov.br/api-de-dados · Swagger http://api.portaldatransparencia.gov.br/ |
| **Mantenedor** | Controladoria-Geral da União (CGU); dados originados do SIAFI e dos órgãos transferidores (entre eles o FNDE) |
| **Licença** | acesso livre, sem autenticação, regido pela **Lei 12.527/2011** (LAI) e pelo Aviso de Privacidade do Portal — **não há licença open data explícita (CC-BY), mas há uso público irrestrito**. Conteúdo do portal gov.br/cgu sob CC BY-ND 3.0 |
| **Formato** | planilha de dados abertos "Transferencias" (por exercício e mês, **com dicionário de dados próprio**) + API REST (Swagger) + consultas em tela |
| **Granularidade** | **município com código IBGE**, órgão/unidade gestora, ação/programa, exercício/mês. **Não desagrega por escola** |
| **Periodicidade** | **mensual** (upload por exercício + mês) |
| **API/SDK oficial** | **sim (HTTP/REST)** — `api.portaldatransparencia.gov.br`, com **cadastro obrigatório de e-mail** e rate limit de **400 req/min** (6h–23h59) / **700 req/min** (00h–05h59). ⚠️ **a lista pública de consultas da API NÃO inclui "Transferências"** — para esse conjunto o caminho oficial é a **planilha** |
| **Cobertura temporal** | portal desde 2008; séries de transferência por exercício (lista carregada dinamicamente, não verificada item a item) |
| **Cobertura geográfica** | nacional (União + entidades federativas, com códigos IBGE) |
| **LGPD** | **nulo neste recorte** — órgão, município, ação, valor. ⚠️ **risco alto nas bases vizinhas** da mesma API: "Pessoas Físicas", "Servidores" e "Notas Fiscais Eletrônicas" contêm **CPF/CNPJ** |

**Verificação (2026-09-30)**:
- `download-de-dados/transferencias` → **200**; texto oficial: *"Selecione o exercício e o mês desejados e clique em Baixar. Será gerado o arquivo Transferencias, que possui a estrutura descrita no dicionário de dados"*.
- `api-de-dados` → **200**; *"o serviço de consulta via API foi implementado em REST"*; *"Para acesso ao conjunto completo de dados, no entanto, sugerimos utilizar as planilhas de dados abertos"*; limites 400/700 req/min; cadastro de e-mail obrigatório.
- `http://api.portaldatransparencia.gov.br/` → **200** (Swagger UI); `https://api.portaldatransparencia.gov.br/v1/swagger.json` → **403**; `.../v1/publico/transferencias` → **403**.
- ⚠️ `portaldatransparencia.gov.br/download-de-dados` retornou **405 "Human Verification"** (AWS WAF) em requisição direta — **WAF intermitente**.
- `gov.br/fnde/pt-br/acesso-a-informacao/convenios-e-transferencias` redireciona ao próprio Portal, confirmando o FNDE como origem.
- `portaldatransparencia.gov.br/termos-de-uso` → **200**; base legal citada: LAI 12.527/2011, Marco Civil 12.965/2014, Lei 13.460/2017, **LGPD 13.709/2018**, Decretos 9.637/2018 e 10.332/2020.
- CRAN e PyPI: `portaldatransparencia` e `transparencia` → **404** em ambos — **não há pacote oficial**.

**Relevância para o EduMaps:** é a **fonte financeira mais confiável e mais
padronizada do catálogo inteiro**. Entrega quanto recurso federal de educação
(PDDE, PNATE, PNAE, Proinfância/Novo PAC, PNLD) chega a cada município, mês a
mês, com código IBGE. Isso permite construir o **bloco financeiro do IVET**,
**auditar o efeito das obras** (o repasse do Proinfância apareceu no município?),
e **controlar a qualidade** de qualquer base FNDE de infraestrutura — o valor
repassado é a verdade de referência contra a qual triangular.

**Indicador derivado possível:**
- `iv_recurso_federal_educ_pc` = transferências educacionais do ano ÷ matrícula da educação básica no município, por ação;
- `iv_pct_educacao_orcamento` = (FUNDEB + transferências educacionais) ÷ receita total do município;
- `iv_repasse_obra_por_aluno` = valor de Proinfância/Novo PAC ÷ matrícula de educação infantil — **indicador direto de investimento planejado**;
- `iv_dependencia_federal` e `iv_concentracao_recurso` — fragilidade orçamentária municipal.

**Prioridade:** `[alta]` — 16 pontos

**Justificativa:** ⭐⭐⭐ + ⭐⭐⭐ + ⭐⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐⭐⭐ = **16**.
**Nenhum gatilho de rebaixamento**: não exige scraping (download oficial em
planilha), tem código IBGE padronizado, uso público não restritivo e **nenhum
dado pessoal no recorte de transferências**. Perde 1 ponto porque transferências
não estão na API (só na planilha) e não há pacote R.

**Rastro:** página de download **200** · página da API **200** · Termo de Uso
**200** · CRAN/PyPI **404** (sem pacote)

**Riscos / cuidados:**
- ⚠️ **WAF (AWS WAF) intermitente** (405 "Human Verification"): baixa taxa de
  requisição, retry com backoff, `User-Agent` de navegador, ou espelhar os
  arquivos em job noturno com cache próprio.
- **Volume**: um arquivo por exercício × mês — filtrar por ação/programa (FNDE)
  e tipo de recurso para não processar dezenas de GB.
- **API exige cadastro de e-mail** e tem rate limit: usar para consultas
  pontuais, planilha para carga histórica.
- ⚠️ **Não confundir transferência *prevista* com *transferida*** — o Portal tem
  "estimativa" e "realizado"; usar a série **realizada**.
- ⚠️ **Segregar fisicamente** as bases "Pessoas Físicas", "Servidores" e "Notas
  Fiscais" (CPF/CNPJ) do pipeline do IVET, com base legal documentada.
- **A API não expõe transferências**: não prometer API onde há planilha.

---

### Medidor Educação Conectada (MEC + NIC.br/CePtoR — SIMET)

| Campo | Valor |
|---|---|
| **URL** | https://medidor.educacaoconectada.mec.gov.br/ · https://educacaoconectada.mec.gov.br/ · página institucional https://www.gov.br/mec/pt-br/gestao-escolar/medidor-educacao-conectada |
| **Mantenedor** | MEC (SEB) em parceria com **NIC.br/CePtoR (SIMET)**; programa instituído pelo **Decreto nº 9.204/2017**, critérios de repasse pela Portaria MEC 29/2019 |
| **Licença** | ⚠️ **não verificada** — não há declaração de licença de dados abertos; o `licenca.txt` referenciado no rodapé (`http://simet.nic.br/medidor-educ-conectada/licenca.txt`) retorna **404**. Apenas o *software* tem licença, não os dados |
| **Formato** | **visualização web** (mapa + app Shiny). ❌ **não há CSV/JSON/planilha oficial**; a seção "Downloads" entrega só os executáveis do medidor (`.exe`, `.run`) e manuais em PDF |
| **Granularidade** | **escola** (por dispositivo de medição, com matrícula via Censo Escolar) + município + UF + região. A página de metodologia declara: velocidade de download/upload, perda de pacotes, quantidade de matrículas, com polígonos do IBGE |
| **Periodicidade** | **diária** (medição automática a cada ~3–4 h) |
| **API/SDK oficial** | **não** — nenhuma API pública. Existe um endpoint interno do portal (`.../modules/mod_datamapa/tmpl/default_fetch.php`) que retorna **HTTP 500** sem os parâmetros exatos do front-end |
| **Cobertura temporal** | Medidor desde **2018** (Decreto 9.204 de 23/11/2017) |
| **Cobertura geográfica** | nacional (27 UFs no seletor), mas **apenas escolas com medidor instalado** |
| **LGPD** | risco **baixo** — métricas de rede agregadas por dispositivo + matrícula agregada do Censo |

**Recurso oficial adicional no mesmo ecossistema**: a **"Consulta de escolas
que receberam recursos PDDE Educação Conectada"** (`educacaoconectada.mec.gov.br/consulta-pdde`,
**200**) consulta por UF e por **código INEP**, diferenciando escola atendida por
conexão **terrestre** (repass via PDDE) e por **satélite**. É o caminho mais
defensável para um indicador booleano "escola atendida pelo Educação Conectada".

**Relevância para o EduMaps:** é a **única fonte pública nacional de
conectividade medida de fato** em granularidade escolar. Traz velocidade de
download/upload e perda de pacotes por escola — medindo a **qualidade real** do
contrato, e não apenas a existência de repasse financeiro. Complementa o Censo
(matrículas vêm de lá) e o OSM (geocodificação do ponto do SIMET).

**Indicador derivado possível:**
- `iv_net_banda_larga_mbps` / `iv_net_perda_pct` por escola (mediana de download; perda de pacotes) — insumo direto do bloco infraestrutura/conectividade;
- `iv_escola_conectada_programa` (0/1) via consulta PDDE por INEP;
- `iv_conectividade_deficitaria` = escola com download mediano abaixo de limiar — proxy direto de vulnerabilidade territorial.

**Prioridade:** `[média]` — 13 pontos, rebaixada

**Justificativa:** soma bruta alta (⭐⭐⭐ + ⭐⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐⭐⭐ ≈ 13),
**rebaixada** por três motivos verificados: (a) **não existe API nem download em
massa oficial**; (b) **licença não localizada** — o próprio `licenca.txt` do
rodapé está **404**, o que impede afirmar compatibilidade de uso aberto;
(c) o acesso exigiria leitura do app Shiny / do endpoint interno não documentado
— isto é, **scraping frágil**, gatilho explícito de rebaixamento.

**Rastro:** `medidor.educacaoconectada.mec.gov.br` **200** (abas "Sobre o
programa", "Metodologia de medição", "Downloads e manuais", "FAQ", "Mapa das
escolas") · `educacaoconectada.mec.gov.br` **200** (menu: `/consulta-pdde`,
`/repasses`, `/conexao-satelital`, `/conexao-terrestre`, `/operadoras`) ·
`gov.br/mec/.../medidor-educacao-conectada` **200** · `.../conexao-satelital`
**200** (critérios: escola pública rural > 149 alunos, sem internet, ≥ 5
computadores) · `licenca.txt` → **404**

**Riscos / cuidados:**
- ⚠️ **Cobertura enviesada por adesão**: só escolas com medidor instalado —
  **jamais usar como denominador universal** sem identificar a população de
  escolas com medidor.
- **"Escola conectada" ≠ "escola com internet de qualidade"**: o programa mede a
  qualidade de um link **já contratado**.
- **Nenhum termo de uso/licença confirmado** → e-SIC/Fala.BR ao MEC/NIC.br antes
  de publicar derivados.
- **Extrair do app Shiny é instável** (mudança de markup derruba o pipeline) —
  não tratar como fonte primária de produção.
- **Métricas por dispositivo podem ter pouco histórico** — exigir janela mínima
  (ex.: ≥ 30 medições) antes de gerar indicador.
- ⚠️ Se o MEC/NIC.br liberar planilha CSV com dicionário (o padrão de agregação
  **já está documentado** na aba "Dados" do portal), **sobe imediatamente para
  `[alta]`**. Esta é a ficha que mais merece uma e-SIC.

---

### FNDE — PNATE (transporte escolar) e SETE

| Campo | Valor |
|---|---|
| **URL** | https://www.gov.br/fnde/pt-br/acesso-a-informacao/dados-abertos/o-que-se-pode-acessar · https://www.gov.br/fnde/pt-br/acesso-a-informacao/acoes-e-programas/programas/pnate · https://www.gov.br/fnde/pt-br/assuntos/sistemas/sete-sistema-eletronico-de-gestao-do-transporte-escolar |
| **Mantenedor** | FNDE/MEC — CGPTE; execução técnica do SETE: Cecate/UFG em parceria com o FNDE |
| **Licença** | SETE: **software livre MIT** (declarado na página do FNDE). ⚠️ **licença dos dados do PNATE não verificada** |
| **Formato** | CSV/planilha no portal de dados abertos do FNDE — conteúdo declarado: *"dados mensais sobre estimativa de repasses, valor per capita, alunos da zona rural contemplados e consulta à prestação de contas"*. ⚠️ **formato e colunas exatos não verificados** (SPA sem SSR, API 401) |
| **Granularidade** | **município** (e UF). O SETE rastreia rotas até a escola, mas **a exposição pública em escala escolar não foi verificada** |
| **Periodicidade** | **mensual** — a mais compatível com o ciclo de gestão escolar do lote |
| **API/SDK oficial** | não para PNATE; SETE é software instalável (web/desktop, funciona offline), não API |
| **Cobertura temporal** | PNATE desde ~2005 (não verificado no site); séries mensais não verificadas |
| **Cobertura geográfica** | nacional |
| **LGPD** | risco **baixo** — repasses agregados por município, contagem de alunos da zona rural |

**Relevância para o EduMaps:** transporte escolar é uma dimensão clássica de
**vulnerabilidade territorial** que o IVET não expressa: quanto o município gasta
para levar alunos da zona rural à escola, e qual o valor per capita. Em
municípios grandes e esparsos, `repasses PNATE ÷ matrícula` separa rapidamente
quem tem cobertura de quem não tem. Indica também a existência de operação de
transporte rural — proxy direto de **município rural com rede dispersa**, mesma
estrutura territorial que sofre com conectividade.

**Indicador derivado possível:**
- `iv_pnate_repasse_pc` = repasse PNATE (soma anual) ÷ matrícula da educação básica no município;
- `iv_pnate_cobertura_rural` = alunos da zona rural contemplados ÷ matrículas da zona rural;
- `iv_territorio_rural_disperso` — estratificação do IVET por tipo de território.

**Prioridade:** `[média]` — 12 pontos, rebaixada

**Justificativa:** soma bruta 12 (⭐⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐⭐ + ⭐⭐⭐), **rebaixada**
por: (a) **nenhuma API/SDK e sem pacote R**; (b) **acesso não verificado** — a
mesma fragilidade do portal do FNDE (SPA sem SSR, API 401), e **não foi possível
ler uma única linha de CSV**; (c) **granularidade municipal**, não escolar, no
dado público; (d) licença do dado não verificada. **Não** rebaixei para `[baixa]`
porque, diferentemente do Medidor, aqui existe **declaração oficial de formato,
periodicidade e conteúdo** — é a fonte com especificação mais bem documentada do
lote, apenas carente de validação técnica de download.

**Rastro:** página "o que se pode acessar" do FNDE **200** (texto oficial do
PNATE transcrito acima) · página do SETE **200** (MIT, web + desktop offline,
Painel de Indicadores de Monitoramento) · ⚠️ `.../programas/pnct` → **404**

**Riscos / cuidados:**
- ⚠️ **Confundir programas**: a sigla vigente é **PNATE**. "PNCT" **não tem página
  institucional no FNDE (404)**. **Não existe sistema federal "SIGESC"** localizado.
  Confirmar base legal antes de citar em documentação.
- **Valores são estimativas de repasse** em vários meses: somar estimativas como
  se fossem repasse efetivo gera ruído — cruzar com o Portal da Transparência.
- O **SETE é adotado voluntariamente** por cada município: usar PNATE (federal,
  obrigatório) como denominador e SETE apenas como enriquecimento opt-in.
- Repasse per capita é fortemente influenciado por decisão política — interpretar
  como "esforço municipal" exige cuidado analítico.
- Coluna "alunos da zona rural" pode ter **quebras de série** entre exercícios
  (mudança de regra) — testar consistência antes de usar em tendência.

---

### FNDE — Novo PAC e infraestrutura escolar / Proinfância

| Campo | Valor |
|---|---|
| **URL** | https://www.gov.br/fnde/pt-br/acesso-a-informacao/dados-abertos/o-que-se-pode-acessar · http://www.fnde.gov.br/dadosabertos/ · https://www.gov.br/fnde/pt-br/acesso-a-informacao/acoes-e-programas/programas/proinfancia |
| **Mantenedor** | FNDE/MEC — CGEST (análise) e CGIMP (monitoramento de obras); PDA-FNDE 2026-2028 publicado |
| **Licença** | ⚠️ **não verificada** — o FNDE publica PDA e declara transparência ativa, mas não foi localizado termo de uso/licença de reutilização. Base legal: Lei 12.527/2011 |
| **Formato** | CSV/planilha via portal de dados abertos — ⚠️ **formato, nomenclatura de colunas e dicionário não verificados** |
| **Granularidade** | **município** — a página oficial FNDE descreve: *"obras e empreendimentos para construção e reestruturação de creches e pré-escolas (antigo Proinfância), com monitoramento de repasses, finalidades e execução física"* |
| **Periodicidade** | **irregular** — por campanha/ciclo PAR e por situação de obra |
| **API/SDK oficial** | **não** — `fnde.gov.br/api/3/action/package_search` e `dados.gov.br/api/3/action/package_search` retornam **HTTP 401**; a SPA do portal depende de `/static/js/*.js` que retornam **404** a cliente não-browser |
| **Cobertura temporal** | Proinfância desde **2007** (Resolução/CD/FNDE nº 6/2007); Novo PAC desde ~2023 |
| **Cobertura geográfica** | nacional (municípios e DF) |
| **LGPD** | risco **baixo** — obras, repasses, execução física. Atenção a nomes deresponsible em relatórios de prestação de contas |

**Verificação (2026-09-30)**: página "o que se pode acessar" **200** com o texto
oficial transcrito acima · `www.fnde.gov.br/dadosabertos/` **200** mas SPA (Vue)
sem conteúdo server-side; `www.fnde.gov.br/static/js/app.a2f69268.js` → **404** ·
`dados.gov.br/dados/conjuntos-dados/proinfancia` → 200 mas **SPA sem SSR**
(indistinguível de 404) · `dados.gov.br/api/3/action/package_search` → **401** ·
`dadosabertos.mec.gov.br` → **403** (Cloudflare) ·
`gov.br/fnde/.../programas/novo-pac` → **404** · página do Proinfância **200**
(projetos-padrão Tipo 1/Tipo 2/Próprio; entrada via SIMEC/PAR;.Res. CD/FNDE 6/2007)

**Relevância para o EduMaps:** responde à lacuna 4 — **investimentos planejados**.
Entrega o que o IVET não tem: se o município tem obra em andamento, quanto já foi
repassado, em que etapa está a execução física. Como é por município, é um
**indicador de capacidade de execução e prioridade política** — diferente de
"orçamento previsto": é obra de fato.

**Indicador derivado possível:**
- `iv_obra_infra_educ_inf_ativa` (0/1) · `iv_obra_educ_inf_repassado` (R$/ano) · `iv_obra_educ_inf_fase` (planejada → em obras → concluída) · `iv_obra_educ_inf_percentual_execucao_fisica`;
- `iv_investimento_obras_previsto` = repasse normalizado por matrícula de educação infantil.

**Prioridade:** `[média]` — 10 pontos, rebaixada

**Justificativa:** soma bruta 10 (⭐⭐⭐ + ⭐⭐⭐ + ⭐⭐ + ⭐⭐), **rebaixada** por:
(a) **acesso não verificável na prática** — API 401, assets 404, sem dicionário
lido, sem colunas confirmadas; (b) **granularidade municipal, não escolar**; (c)
**periodicidade irregular**, fora da compatibilidade com o ciclo de gestão
escolar; (d) licença não verificada. **É a fonte que mais se beneficiaria de uma
e-SIC** — o PDA 2026-2028 promete exatamente o CSV + dicionário que falta.

**Rastro:** página FNDE "o que se pode acessar" **200** · PDA-FNDE 2026-2028 em
PDF · página do Proinfância **200**

**Riscos / cuidados:**
- ⚠️ **Acesso frágil é o risco dominante**: a SPA do FNDE não responde fora do
  navegador e o CKAN federal exige autenticação. Qualquer pipeline R direto
  quebra. Mitigação: **e-SIC/Fala.BR ao FNDE pedindo URL de download + dicionário
  de dados**, ou navegador headless institucional.
- **Sem chave de escola confirmada**: a obra é municipal; a atribuição à rede
  (municipal/estadual) e, quando for creche, à escola se faz **por regra, não por
  linha da base**.
- Dados de "execução física" podem conter **nomes de responsáveis técnicos** —
  filtrar colunas antes de publicar.
- **Confirmar se o conjunto "Novo PAC" cobre obras além de creches/pré-escolas**:
  o texto do FNDE cita explicitamente só a educação infantil, o que reduziria
  bastante o alcance para o IVET.

---

### GESAC / Wi-Fi Brasil — conexão de escolas

| Campo | Valor |
|---|---|
| **URL** | https://www.gov.br/mcom/pt-br/acesso-a-informacao/acoes-e-programas/programas-projetos-acoes-obras-e-atividades/wi-fi-brasil/conexao-de-escolas |
| **Mantenedor** | Ministério das Comunicações (MCom, Secretaria de Telecomunicações); instalação via **Telebrás** (modalidade satelital) e **RNP** (modalidade terrestre). ⚠️ **GESAC não é um órgão**: é a modalidade satelital do Wi-Fi Brasil — `gesac.com.br` **não resolve DNS** |
| **Licença** | conteúdo do portal MCom sob CC BY-ND 3.0; ⚠️ **licença dos dados de conectividade não verificada** |
| **Formato** | **painel Power BI** embutido na página oficial. ❌ sem CSV/JSON/API pública |
| **Granularidade** | escola (*"permite consultar o status de conexão de cada uma das escolas contempladas"*) — detalhe não verificado no painel |
| **Periodicidade** | **não verificada** (atrelada a status de instalação/contratação) |
| **API/SDK oficial** | **não** — apenas Power BI embutido |
| **Cobertura temporal** | desde ~2022 (*"somente em 2022 foram contratadas mais de 16 mil conexões para escolas"*) |
| **Cobertura geográfica** | nacional, com foco em escolas sem cobertura terrestre (rural/remotas) |
| **LGPD** | sem dado pessoal na granularidade escolar; a página **exige nome e telefone do gestor** para alterar informações (tratamento de dado pessoal no fluxo de atendimento, não na base pública) |

**Relevância para o EduMaps:** captura o nicho mais crítico — **escola rural sem
fibra atendida por satélite**. Um bloco de conectividade
"atendida por satélite / terrestre / sem atendimento" é diferenciador territorial
forte e **não duplica** o Medidor (que mede qualidade de quem já tem link).

**Indicador derivado possível:**
- `iv_conectividade_modalidade` ∈ {satélite, terrestre, provedor próprio, sem atendimento} por escola;
- `iv_escola_remota_satelitalizada` — proxy de "vulnerabilidade territorial mitigada por investimento público".

**Prioridade:** `[baixa]` — rebaixada

**Justificativa:** **é um programa, não um conjunto de dados**. Não há API, download,
dicionário, granularidade confirmada por código INEP em formato legível por
máquina, nem periodicidade verificada. O único caminho seria exportar o Power BI
(sujeito aos termos do serviço) — *scraping frágil* com licença não verificada:
**os dois gatilhos de rebaixamento ao mesmo tempo**. Endereça a lacuna (⭐⭐⭐) e tem
granularidade escolar (⭐⭐⭐), mas zera em todos os demais critérios verificáveis.

**Rastro:** página MCom **200** (texto oficial: "modalidade GESAC" — antena
instalada pela Telebrás; *"Em 2022 foram contratadas mais de 16 mil conexões para
escolas"*; contato oficial `conectividade@mcom.gov.br`) · `gesac.com.br` → **NXDOMAIN**

**Riscos / cuidados:**
- **Sem identificador de escola padronizado (INEP)** nos dados públicos: a chave de
  junção com o Censo **não está confirmada**.
- **Power BI embutido**: exportação automatizada viola os termos do serviço.
- **Cobertura dupla** com o Medidor Educação Conectada → risco de contagem
  inconsistente entre blocos do IVET.
- "Wi-Fi Brasil" é conectividade, **não qualidade** — não confundir com o SIMET.
- **Não incorporar** nome/telefone do gestor em tabelas analíticas.

---

### Nordeste Conectado (MCom + RNP + Chesf)

| Campo | Valor |
|---|---|
| **URL** | https://www.rnp.br/programas-e-projetos/norteste-conectado/ · página oficial MCom (versão em inglês) |
| **Mantenedor** | MCom + Rede Nacional de Ensino e Pesquisa (RNP, executora da 1ª fase) + Chesf (cedência de fibra) |
| **Licença** | páginas institucionais sob CC BY-ND 3.0. ❌ **não existe dado** |
| **Formato** | apenas texto institucional + PDF de apresentação. ❌ sem CSV/JSON/API |
| **Granularidade** | **município/cidade** (20 cidades em 6 estados: BA, CE, PB, PE, PI, RN). Sem desagregação escolar |
| **Periodicidade** | **não verificada** (projeto por fases, sem série publicada) |
| **API/SDK oficial** | não |
| **Cobertura geográfica** | ⚠️ **regional** — Nordeste (6 estados, 20 cidades) |
| **LGPD** | sem dado pessoal |

**Relevância para o EduMaps:** contribui apenas como **evidência de política
pública regional** de interiorização de fibra (rede de dados sobre a malha da
Chesf, redes metropolitanas, Wi-Fi em praças). **Não entrega medida de
conectividade escolar** — serve para qualificar narrativas do IVET no Nordeste e
checar se o bloco de conectividade é coerente com a oferta de backbone regional.

**Indicador derivado possível:**
- `iv_backbone_fibra_regional` — covariável de controle regional, **não indicador primário**;
- lista dos ~20 municípios atendidos — camada de contexto em mapa comparativo.

**Prioridade:** `[baixa]`

**Justificativa:** duplo rebaixamento: (a) **escopo regional** — 20 cidades em 6
estados, sem representatividade nacional; (b) **não é dado** — sem API, planilha,
granularidade escolar ou periodicidade. Soma ≈ 2–4 pontos.

**Rastro:** `rnp.br/programas-e-projetos/norteste-conectado/` **200** (parceria
MCom+RNP, 20 cidades, tráfego de 100 Gb/s sobre fibra da Chesf) ·
`plataforma.rnp.br/nordeste-conectado` → **404** (não há camada de dados)

**Riscos / cuidados:**
- ⚠️ **Não usar como fonte de conectividade escolar** — o risco máximo aqui é
  contaminar o IVET com um proxy de backbone que **não equivale** a banda larga
  na escola.
- Sem identificadores padronizados: as "20 cidades" estão em prosa, sem tabela.
- Fase de implantação ambígua → risco de afirmar obras concluídas que não existem.

---

### Wikidata — WikiProject Brasil Escolas

| Campo | Valor |
|---|---|
| **URL** | https://www.wikidata.org/wiki/Wikidata:WikiProject_Brasil_Escolas · licença https://www.wikidata.org/wiki/Wikidata:Licensing |
| **Mantenedor** | Comunidade Wikimedia; o WikiProject é mantido por voluntários |
| **Licença** | **CC0 1.0 (domínio público)** para dados estruturados — confirmado em `Wikidata:Licensing`. Textos de projeto são CC BY-SA 4.0 |
| **Formato** | **API HTTP oficial** (`/w/api.php`) + **endpoint SPARQL oficial** (`https://query.wikidata.org/sparql`, JSON/RDF/CSV) |
| **Granularidade** | escola (item Wikidata com `P31`/`P279` escola, `P17`=Brasil, `P625` coordenadas, INEP quando presente) |
| **Periodicidade** | **irregular** — edições comunitárias contínuas, sem snapshot oficial nem data de corte |
| **API/SDK oficial** | **sim (HTTP)**. ⚠️ **em R não há pacote mantido**: `WikidataR` foi **removido do CRAN em 2026-02-08**, junto do `WikidataQueryServiceR` ("for policy violation"); `WQBSPARQL` não está no CRAN. Alternativa: SPARQL direto (`httr2` + `jsonlite`) ou Python (`wikidata` 0.9.0, GPLv3) |
| **Cobertura temporal** | não verificada (o projeto cita Censo Escolar 2023 como referência de totais, sem data de corte própria) |
| **Cobertura geográfica** | ⚠️ **nacional mas muito parcial e enviesada**: em **06/04/2025** havia **8.602 escolas brasileiras no Wikidata, das quais somente 1.994 (23%) tinham coordenadas** |
| **LGPD** | sem dado pessoal. O risco é **outro**: qualidade e **viés de representatividade** |

**Relevância para o EduMaps:** não fecha nenhuma das lacunas deste lote (não há
conectividade nem obras no Wikidata). Serve a outro propósito igualmente útil:
**validação cruzada de georreferenciamento** — o EduMaps produz ponto por escola;
o Wikidata dá um segundo par de coordenadas, colaborativo, para **detecção de
outliers** e revisão humana. Também enriquece metadatos ausentes no Censo
(patrimônio histórico) e integra-se ao OSM (o projeto declara a integração
Wikidata↔OSM).

**Indicador derivado possível:**
- `cobertura_geo_dupla` (0/1) — escola com coordenada no Censo **e** no Wikidata: **usar como variável de qualidade do dado, nunca como indicador de vulnerabilidade**;
- `divergencia_geo_hausdorff_m` — distância entre a coordenada do EduMaps e a do Wikidata;
- `escola_patrimonio_historico` — contexto cultural.

**Prioridade:** `[baixa]` — rebaixada

**Justificativa:** zera "endereça lacuna direta" (não tem conectividade nem
investimento). Ganha API (⭐⭐), licença CC0 (⭐⭐⭐), granularidade escolar
(⭐⭐⭐), cobertura nominal (⭐⭐), complementa Censo/OSM (⭐⭐⭐), mas **perde a
periodicidade** e **perde "pacote pronto"** (WikidataR removido do CRAN em
08/02/2026). Soma bruta ≈ 13, mas como **não endereça a lacuna** e a cobertura
efetiva é de **23% do que existe no Wikidata** (1.994 de 179.286 do Censo 2023),
a régua de desempate manda para `[baixa]`. **Não é fonte de IVET; é insumo de
qualidade de dado.**

**Rastro:** `action=parse&page=Wikidata:WikiProject Brasil Escolas` **200**
(seções "Dados Abertos em Educação", "Georreferenciamento", "Aplicações";
dados de 8.602/1.994 em 06/04/2025; paper *Structuring Georeferenced Open Data
of Brazilian Schools on Wikidata*, Wiki Workshop 2025) · `Wikidata:Licensing`
**200** (CC0) · `query.wikidata.org/sparql` **200** · ⚠️
`Wikidata:WikiProject_Brazil/Schools` → **404** (a página correta é
`Wikidata:WikiProject Brasil Escolas`, sem underscore) · CRAN `WikidataR` →
arquivado 08/02/2026

**Riscos / cuidados:**
- **Cobertura minúscula e enviesada**: 1.994 escolas com coordenada contra
  179.286 no Censo 2023. Qualquer uso como "base de escolas" é inválido.
- **Viés de seleção geográfico** não aleatório; a georreferenciação pende para
  escolas já notórias/urbanas. **Jamais extrapolar** métricas de cobertura.
- **Sem snapshot estável**: extrair por SPARQL dá resultado diferente a cada dia —
  fixar data de extração e versionar o dump local.
- **Tooling R fragmentado**: pacotes descontinuados em 2026 — o caminho real é
  SPARQL direto.
- **CC0 não cobre a proveniência**: a origem citada é o Censo Escolar 2023, o
  que impõe atribuição moral — citar mesmo sob CC0.

---

## ⚠️ Correções à lista de candidatos da issue #123

| Item listado | Verificação | Correção |
|---|---|---|
| **"PNCT"** como programa do FNDE | ❌ `gov.br/fnde/.../programas/pnct` → **404**. A sigla vigente é **PNATE** | Usar **PNATE**. "PNCT" aparece como forma abreviada em resolução CONTRAN, não confirmada |
| **"SIGESC"** | ❌ nenhuma base oficial localizada com essa sigla em MEC/FNDE/transportes | Sigla provavelmente incorta ou estadual; **não usar** |
| **"PDL Educationis"** | ❌ `pdleducationis.com.br` / `www.` / `pdl.educationis.com.br` → **NXDOMAIN**; nenhuma página FNDE/MEC/CGU a descreve | **Não usar** |
| **"Novo PAC" da CGU** | ❌ `gov.br/cgu/pt-br/assuntos/novo-pac` → **404**; `painelnovopac.cgu.gov.br` → **NXDOMAIN**; o PDA-CGU acessível **não lista** base "Novo PAC" | O dado de obras é o do **FNDE** ([`FNDE — Novo PAC`](#fnde--novo-pac-e-infraestrutura-escolar--proinfância)), não da CGU |
| **"GESAC"** como entidade | ⚠️ **não é órgão nem programa próprio** — `gesac.com.br` → **NXDOMAIN**. É a **modalidade satelital do Wi-Fi Brasil** (MCom + Telebrás) | Reformular como Wi-Fi Brasil/satélite |
| **"dados.gov.br" como fonte** | ❌ CKAN federal exige credencial (**401**) | `dadosabertos.ibama.gov.br` e portais próprios são as rotas confiáveis |

---

## Síntese do lote

| Fonte | Prioridade | Pontos | Motivo |
|---|---|---|---|
| **CGU / Portal da Transparência** | 🟢 `[alta]` | 16 | **Única fonte sólida do lote**: transferências educacionais mensais por município com código IBGE, uso público, sem dado pessoal. |
| **Medidor Educação Conectada** | 🟡 `[média]` | 13 | Única medição **real** de banda larga por escola — mas sem API, sem licença e atrás de Shiny. **Candidata a e-SIC**. |
| **FNDE — PNATE** | 🟡 `[média]` | 12 | Melhor especificação oficial do lote (mensal, conteúdo declarado), carente de validação técnica. |
| **FNDE — Novo PAC / Proinfância** | 🟡 `[média]` | 10 | Responde à lacuna 4, mas portal inacessível a cliente não-browser. |
| **GESAC / Wi-Fi Brasil** | 🔴 `[baixa]` | — | Programa, não dado; atrás de Power BI. |
| **Nordeste Conectado** | 🔴 `[baixa]` | — | Regional, sem dado estruturado. |
| **Wikidata Escolas** | 🔴 `[baixa]` | — | 23% de cobertura com coordenada; é insumo de **qualidade de dado**, não de IVET. |

**Conclusão do lote**: **a lacuna 4 está praticamente resolvida** pelo Portal da
Transparência (repasses) + FNDE (obras, mediante e-SIC). **A lacuna 3 está
bloqueada por desenho da fonte** — e a contramedida correta não é scraper, é
**e-SIC**: o Medidor Educação Conectada já publica a metodologia de agregação na
aba "Dados" do portal, o que torna o pedido de CSV + dicionário administrativo e
de baixo custo. Essa é a ação de maior retorno da fase de implementação.
