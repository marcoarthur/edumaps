# Assistente de Relatório — plano inicial de consumo e integração (edumapsAnalytics → eduBR)

**Data:** 2026-10-12 · **Autor:** Tech Lead (agente) · **Versão:** 1.1 ·
**Status:** plano inicial para discussão, **com poucas decisões fechadas**.
**Fontes (somente leitura):** `analysis/edumapsr` (pacote `edumapsAnalytics`)
e `~/Projects/eduBR`. O repositório `eduBR` é **somente-leitura** para este
projeto (ver AGENTS.md). Toda afirmação sobre o eduBR abaixo vem do código
dele; o que não foi verificado está marcado como hipótese.

> **Decisão do developer (v1.1, 2026-10-12):** o **gestor é tratado como
> pesquisador**: usa o tooling da persona `pesquisadora-educacional` do eduBR,
> que cobre recortes territoriais (município, UF, macro-região). Quando a
> categoria **pesquisador** for modelada no EduMaps, ela fica com as análises
> **mais profundas e com mais dados** (regressões, bases amplas, limites
> maiores), e o gestor volta a um conjunto mais enxuto. Ver §3 e §10.

---

## 1. Contexto e motivação

- O `edumapsAnalytics` (diretório `analysis/edumapsr`) é a camada analítica do
  EduMaps. A cadeia é DataSource → Semantic Model → Analysis pura →
  `analysis_result` → View (plotly/JSON) / Repository (`analytics.*`). Ele é
  exposto por Plumber e consumido pelo backend Perl, que usa um cliente HTTP
  síncrono dentro de jobs Minion.
- O **Assistente do Censo** (`ask_censo()`) já usa `ellmer`, mas com tooling
  próprio e genérico: `run_sql` com SQL escrito pelo modelo, whitelist de
  schemas e redação de PII.
- O `eduBR` evoluiu em separado e hoje tem um tooling para LLM **mais seguro e
  mais rico**:
  - ferramentas semânticas, sem SQL exposto, com envelope JSON
    `dados/metadados/erro`;
  - personas;
  - ledger;
  - teto de linhas, timeout por chamada e orçamento por sessão
    (`ferramentas_edubr()`, `chat_edubr()`, `registrar_tools()`).
- Consumir o eduBR permite oferecer **assistentes especializados** sem
  reescrever o domínio. O primeiro é o **Assistente de Relatório**: o usuário
  informa um recorte geográfico e recebe um relatório servido pelo EduMaps.
- O desafio é integrar **sem acoplar**. O eduBR continua utilizável sozinho, e
  o EduMaps não escreve no repositório dele.

## 2. Objetivo e escopo desta etapa

**Entra**
- Plano de **consumo** do eduBR pelo `edumapsAnalytics`: dependência, adapter,
  conexão e reuso de personas e tooling.
- Posição do Assistente de Relatório no MVC existente.
- Alternativas de **entrega** do relatório ao EduMaps (backend e frontend).
- Contratos mínimos, riscos e backlog em fases.

**Fica fora**
- Código de produção, escolha de bibliotecas, endpoints finais e UX.
- Uma categoria "pesquisador" própria no cadastro. Por enquanto o gestor faz
  esse papel (§3).
- A persona `especialista-ml` do eduBR (pipelines de ML).
- Temas que o eduBR não oferece, e qualquer alteração no repositório eduBR.
- Substituir o Assistente do Censo. Os dois coexistem; a convergência está
  **em aberto**.

## 3. Público-alvo

- **Usuário do sistema:** somente o **gestor** (`clean.gestores`,
  `access_role = gestor`). Cada gestor administra **uma escola** (`cod_inep`).
  Dela derivam o município (`co_municipio`), a UF e a macro-região
  (`clean.censo_escolas`), que servem de recorte padrão.
- **Persona LLM:** **`pesquisadora-educacional`**, por decisão do developer.
  O gestor ganha acesso a recortes territoriais e a bases por município, rede e
  região.
- **Complemento:** as ferramentas centradas na escola, que no eduBR pertencem
  só à `gestora-escolar` (série do IDEB, escolas similares, scores, resumo),
  podem ser somadas ao conjunto da pesquisadora (§6a). **Em aberto.**
- **Ajuste de linguagem:** o prompt da pesquisadora foi escrito para uma
  economista, em tom técnico. O assistente acrescenta o próprio
  `system_prompt` (o eduBR concatena depois do prompt da persona) para pedir
  linguagem acessível ao gestor, sem relaxar as regras de precisão e de
  causalidade da persona.
- **Evolução:** quando o **pesquisador** for modelado, ele fica com as
  análises profundas e com mais dados (§10).

## 4. Mapa de capacidades (o que o eduBR realmente oferece)

Persona-base: `pesquisadora-educacional`. A coluna "Fase" indica onde o tema
entra no backlog (§9).

**A. Ferramentas da persona `pesquisadora-educacional` (base do assistente)**

| Grupo | Ferramenta eduBR | O que entrega | Recorte geográfico | Fase |
|---|---|---|---|---|
| Catálogo | `catalogo` | domínios, chaves, grão, anos | — | 1 |
| Perfil escolar | `perfil_escola` | escola × **município** × **estado**: infraestrutura, IDEB (mesma edição e rede), docentes | escola → município e UF | 1 |
| Comparação territorial / IDEB | `ideb_agregado` | média do IDEB **agregada no banco**, opcionalmente por rede | município · UF · macro-região | 1 |
| Redes do território | `redes_municipio` | município × rede: escolas, matrículas, docentes, IDEB médio | UF · macro-região · rede | 1 |
| Docentes | `docentes_rede` | contagens de docentes agregadas | brasil · macro-região · UF · município | 1 |
| Gestores (perfil) | `perfil_gestor` | categoria modal dos gestores escolares (Censo 2025), **agregada** | brasil · rede · macro-região · UF | 1 |
| Municípios | `municipios` | cadastro IBGE (código de 7 dígitos, região imediata/intermediária, macro-região, área) | UF | 1 (resolver código) |
| Tendência do IDEB | `tendencia_ideb_regiao` | tendência linear do IDEB por macro-região | macro-região | 1 |
| IDEB por escola | `ideb` | IDEB por escola × etapa × edição (exige filtro; município **por nome**) | UF · município | 2 |
| Base de covariáveis | `covariaveis_escola` | escola × covariáveis (handle + amostra) | UF · rede | 2 (profunda) |
| Regressões | `regressao_escolas`, `especificar_regressao`, `executar_regressao`, `coeficientes`, `metricas`, `listar_handles` | regressão declarativa (handles por sessão) | UF · rede · cortes | 2 (profunda) |

**B. Complemento opcional: ferramentas que hoje são só da `gestora-escolar`**
(somar ao conjunto A está **em aberto**)

| Ferramenta | O que entrega | Recorte |
|---|---|---|
| `resumo_escola` | IDEB por etapa com variação e oferta | escola |
| `serie_ideb_escola` | histórico do IDEB da escola | escola |
| `escolas_similares` | até 20 escolas parecidas (infraestrutura, porte, docentes, gestão; sem IDEB/INSE) | nacional, a partir da escola |
| `scores_escola` | scores compostos de 0 a 10 | escola |

**C. Não oferecido nesta etapa (não expor)**
- **INSE como tema próprio:** não há ferramenta dedicada. O INSE aparece como
  covariável (`covariaveis_escola`, conjunto A, fase 2) e nas ferramentas de ML
  (persona fora do escopo).
- **Clusters, municípios similares, OSM, IBGE populacional:** não têm
  ferramenta. Os domínios existem no catálogo, alguns vazios em dev.
- **Ranking de escola** (`indicadores_escola`): só da persona ML, e a tabela
  está **vazia em dev**.
- **Pipelines de ML** (`features_escola`, floresta, PCA): persona
  `especialista-ml`, fora do escopo.

**D. Relatórios prontos (`eduBR/analysis/*.Rmd`)**
- Não são instalados com o pacote (`analysis/` está no `.Rbuildignore`) e
  **não há função de renderização** exportada.
- Agora casam com a persona-base e servem de **referência de conteúdo e
  estrutura**, não de artefato consumível:

  | Relatório | Recorte |
  |---|---|
  | `rede_professor.Rmd` | UF / macro-região |
  | `tendencia_ideb_regiao.Rmd` | macro-região |
  | `regressao_inse_regiao.Rmd` | macro-região |
  | `perfil_gestor.Rmd` | nacional, por rede/região/UF |

- **Nenhum recebe município como parâmetro.**
- A forma de reuso está **em aberto** (§6a). Não copiar os `.Rmd` para cá.

## 5. Fluxo de uso (consumo pelo gestor)

1. O gestor autenticado abre o Assistente de Relatório.
2. O sistema propõe o **recorte padrão** a partir da escola do gestor (sessão
   → `cod_inep` → município → UF → macro-região). O gestor confirma ou escolhe
   outro recorte: **município | estado | macro-região**, de qualquer lugar do
   país, pela cascata de geotag que já existe em
   `/api/cluster/regions|ufs|municipalities`.
3. O sistema lista **somente os temas cobertos pelo nível escolhido**
   (mapa §4, coluna "Recorte"). Exemplos:
   - **município:** IDEB agregado do município, redes e docentes do município,
     perfil da escola do gestor diante do município;
   - **UF:** IDEB agregado da UF (e por rede), redes, docentes, perfil de
     gestores;
   - **macro-região:** tendência do IDEB, IDEB agregado, docentes, perfil de
     gestores.
4. O gestor escolhe um tema e, quando o tema permitir, o ano, a etapa e a rede.
5. O backend registra o pedido e enfileira um job. O lado R instancia o tooling
   do eduBR com a conexão injetada, roda o assistente (persona pesquisadora com
   o complemento de linguagem) e produz o relatório.
6. O gestor acompanha o progresso e recebe o relatório: texto e tabelas,
   citando edição, recorte e `n`, com avisos de truncamento. Pode salvar ou
   exportar; o formato está **em aberto**.

## 6. Integração técnica proposta

### a. Como o `edumapsAnalytics` consome o `eduBR`

- **Dependência:** `eduBR` em `Suggests` ou `Imports` (**em aberto**), sempre
  chamado como `eduBR::…`. O `ellmer` já está em Imports. A dependência vai num
  só sentido: nada do edumapsAnalytics entra no eduBR.
- **Adapter fino** no edumapsAnalytics (ex.: `R/adapter-edubr.R`), única porta
  de entrada para o eduBR. Ele:
  - cria o tooling;
  - aplica o catálogo de temas e os limites;
  - converte o envelope `dados/metadados/erro` em `analysis_result`.
- **Conexão injetada:** o eduBR aceita `con` em todas as funções. Reusar o
  padrão do Assistente do Censo: conexão **somente-leitura** (role
  `edumaps_leitor`, `statement_timeout` próprio) por pedido, aberta e fechada
  pelo adapter.
  - ⚠️ **Hipótese a verificar (bloqueante):** as tabelas que o eduBR consulta
    precisam **existir no banco do produto** (`database.edumaps`) e estar
    visíveis ao `edumaps_leitor`, que hoje só enxerga `clean` e `analytics`.
    O `[edumaps]` local do eduBR já apontou para o cluster antigo
    (`ubatexu.lan`). A Fase 0 mede isso.
- **Montagem do tooling (decidido: persona pesquisadora):**
  - **Só o conjunto A:** `ferramentas_edubr(con, persona =
    "pesquisadora-educacional", limites = …)`. É o caminho mais simples.
  - **Conjunto A + complemento B:** `ferramentas_edubr(con, persona = NULL)` e
    seleção por nome. Ferramentas criadas sem persona não carregam o atributo,
    então `registrar_tools(chat, subset, persona =
    "pesquisadora-educacional")` funciona sem conflito; o eduBR só reclama
    quando a persona das ferramentas e a do argumento divergem. Não altera o
    eduBR. Adotar ou não está **em aberto**.
  - **Fase 1:** restringir o conjunto A às ferramentas descritivas e agregadas
    (marcadas "1" em §4). Regressões e covariáveis ficam para a fase 2, com
    limites próprios.
- **Criação do chat:** o eduBR suporta `anthropic|gemini|ollama`; o EduMaps
  configura `gemini|groq|openai|ollama` pelo painel
  (`integrations.assistant_censo.*`). Há duas alternativas, **em aberto**:
  - (i) usar `chat_edubr()` só com os provedores em comum;
  - (ii) criar o `Chat` no edumapsAnalytics (`chat_config()`, que já conhece o
    painel) e usar `eduBR::registrar_tools(chat, tools, persona)`. É a opção
    menos acoplada à configuração do eduBR.
- **Relatórios `analysis/`:** como não são instalados, há duas opções:
  - reimplementar a estrutura como Analysis do edumapsAnalytics, usando
    funções exportadas do eduBR (`tendencia_regiao()`, `regressao_inse()`,
    `docentes_rede()`, `perfil_gestor()`);
  - **registrar aqui** a proposta de que o eduBR passe a instalar relatórios
    parametrizáveis (`inst/`).

  Em nenhum caso copiar os `.Rmd`.

### b. Onde entra o Assistente de Relatório no MVC

| Camada | Papel no assistente |
|---|---|
| DataSource | `edubr_source(con, limites)`: encapsula a criação do tooling e a conexão |
| Semantic Model | `report_request_model`: recorte (nível + código), tema, ano/etapa/rede; valida tema × nível pelo **catálogo de temas** derivado de §4 |
| Analysis | `analyze_report(model, parameters)`: orquestra (a) as chamadas às ferramentas do tema e (b) a redação pelo LLM; devolve `analysis_result` |
| AnalysisResult | `data` = envelopes das ferramentas; `tables` = tabelas do relatório; `metadata` = ledger, avisos, truncamentos, edição dos dados, provedor/modelo, versão do eduBR |
| View | `render_report_markdown()` / `render_json()` (já existe) |
| Repository | cache/persistência em `analytics.*`, no padrão dos repositórios Postgres; detalhe **em aberto** |

- **Registro:** há duas opções, **em aberto**:
  - entrada nova no `analysis_registry` (`app-registry.R`);
  - um `run_report()` próprio, como `run_cluster`/`run_similarity`, já que o
    modelo não é um `school_indicator_model`.
- **Controller/HTTP:** endpoint Plumber novo (ex.: `POST /report`) no padrão
  de `/ask`. Erros de cliente → 400, de provedor → 502, internos → 500.
- **Task:** job Minion na fila `analytics`, como o `chat_ask`, com progresso e
  resultado em `job->finish`. O cache do `Analytics::Client` (24 h) serve os
  pedidos repetidos.
- **Determinismo × LLM:** a hipótese preferida é **o adapter chamar de forma
  determinística as ferramentas de cada tema** e o LLM **só redigir**. Isso dá
  reprodutibilidade e custo previsível. A alternativa é um agente livre, que
  escolhe as ferramentas; ela combina mais com a fase 2 (perguntas
  exploratórias). **Em aberto.**

### c. Como o relatório é servido ao EduMaps (opções, sem escolha)

| Opção | Como | Prós | Contras |
|---|---|---|---|
| **1. Markdown + tabelas via job** | Minion → Plumber `/report` → JSON `{markdown, tabelas, metadados}`; o frontend faz polling e renderiza com o `TextoMarkdown` seguro (já existe) | reusa todo o caminho do Assistente do Censo; menor esforço | só markdown simples; gráficos exigem trabalho à parte |
| **2. HTML pré-renderizado (R Markdown)** | o R renderiza HTML (`rmarkdown`) e o salva (`analytics.*` ou arquivo); o backend serve por link/iframe ou download | próximo dos relatórios do eduBR; exportável (PDF) | HTML de terceiros na SPA (CSP, XSS); pandoc no contêiner; mais pesado |
| **3. JSON estruturado por seções** | `analysis_result` → seções tipadas (texto, tabela, série), renderizadas por componentes Svelte nativos (Carbon Charts já está no projeto) | UX integrada, acessível, sem HTML externo | mais frontend; contrato de seções a desenhar |

## 7. Contratos e interfaces mínimas (abstratos)

**Entrada (pedido de relatório)**
```
ReportRequest {
  geotag:  { nivel: "municipio" | "uf" | "regiao" | "escola",
             codigo: codigo_ibge(7) | sigla_uf | sigla_regiao | cod_inep }
  tema:    id do catálogo de temas (derivado do mapa §4)
  opcoes?: { ano?, etapa?, rede? }        # só os que o tema aceita
  contexto (do servidor, não do cliente): { gestor_id, cod_inep }
}
```

**Catálogo de temas (derivado, não inventado)**
```
temas_disponiveis(nivel, perfil = "gestor") ->
  [ { id, titulo, ferramentas_edubr[], niveis[], profundidade: "descritiva" | "profunda" } ]
```
O campo `perfil` prepara a separação futura gestor × pesquisador (§10). Hoje há
um único perfil, e a fase define quais profundidades estão liberadas.

**Saída (relatório)**
```
ReportResult {
  titulo, recorte, tema,
  corpo_markdown | secoes[],              # conforme a opção de entrega
  tabelas[],
  fontes: [ { ferramenta, edicao/ano, escopo, n } ],
  avisos: [ truncado, sem_dados, limite_excedido, ... ],
  rastreio: { ledger_resumo, provedor, modelo, versao_edubr, duracao_ms, cache_hit }
}
```

**Assinaturas indicativas (R)**
```
edubr_source(con, limites = list(), persona = "pesquisadora-educacional")
temas_disponiveis(nivel, perfil = "gestor")
run_report(request, config = NULL) -> analysis_result
```

## 8. Riscos, restrições e pontos em aberto

- **Tom e público:** o prompt da pesquisadora é técnico. O complemento de
  linguagem deve torná-lo acessível ao gestor **sem** relaxar as regras de
  precisão. Há risco de o gestor ler associação como causa, sobretudo nas
  regressões; por isso elas ficam na fase 2, com avisos explícitos.
- **Volume e custo:** a persona pesquisadora traz bases maiores (covariáveis,
  regressões com handles). Mitigações:
  - na fase 1, só ferramentas descritivas e agregadas;
  - limites do eduBR **menores** que o padrão (`max_linhas`, `max_chamadas`,
    `max_linhas_total`, `max_caracteres`, `max_amostra`);
  - um tooling **por pedido**.
- **Schema/banco (bloqueante, em aberto):** o eduBR precisa ler o banco do
  produto pelo `edumaps_leitor`. Antes de qualquer código, validar:
  - as tabelas;
  - os tipos (`co_municipio` int × `codigo_ibge` varchar(7)); várias
    ferramentas filtram município **por nome**, com grafia exata;
  - as permissões.
- **Contexto confiável:** hoje o `/api/chat/ask` aceita `contexto` vindo do
  cliente, sem checar a sessão. O relatório deve exigir autenticação e derivar
  o recorte padrão **da sessão do gestor**.
- **LGPD:**
  - as ferramentas removem endereço, telefone, CEP e CNPJ, mas **não e-mail**,
    que só é coberto pelo prompt;
  - `perfil_gestor` é **agregado** (o Censo do gestor só tem contagens, sem
    nome, CPF ou e-mail);
  - `exportar()` e as funções de domínio fora do tooling **não** filtram PII,
    então o adapter só deve usar as ferramentas;
  - os relatórios salvos são dados do usuário, e a retenção está
    **em aberto**.
- **Custo de LLM:** um relatório por pedido, com cache por recorte, tema,
  edição, versão do prompt e versão do eduBR. Teto de tokens (`max_tokens`).
  Provedor e modelo vêm do painel.
- **Timeouts:**
  - o eduBR altera o `statement_timeout` da conexão a cada chamada e o
    restaura depois, então a conexão **não pode ser compartilhada** entre
    pedidos concorrentes;
  - o Plumber é síncrono e o cliente Perl tem timeout de 300 s: alinhar o
    timeout total do relatório e o progresso do job.
- **Reprodutibilidade:** registrar a versão do eduBR, a edição dos dados, o
  ledger e o prompt. Preferir chamadas determinísticas com o LLM só redigindo
  (§6b). O texto do LLM varia, por isso o cache e a versão contam.
- **Dados vazios em dev** (ranking, municípios similares, IBGE): não oferecer
  esses temas.
- **Dívidas encontradas no levantamento** (registrar como issues separadas):
  - o chat atual renderiza markdown como texto puro e descarta o gráfico;
  - `stop_chat_internal()` não está definido (`chat-dictionary.R:29`);
  - `censo-dictionary.R` está fora do `Collate`.
- **Independência:** o eduBR fica intacto. Qualquer necessidade nele vira um
  **achado registrado aqui**, nunca uma alteração lá.

## 9. Backlog em fases

**Fase 0 — Viabilidade (spike, sem UI)**
- Instalar o eduBR no host/contêiner `analytic` e chamar
  `ferramentas_edubr(con_leitor, persona = "pesquisadora-educacional")` contra
  `database.edumaps`.
- **Aceite:**
  - as ferramentas da fase 1 respondem sem `erro.tipo = conexao` para
    3 municípios, 2 UFs e 1 macro-região reais;
  - o ledger e os limites funcionam;
  - as lacunas de schema e de permissão ficam documentadas;
  - o teste da mescla A+B com `registrar_tools` passa (se o complemento for
    adotado).

**Fase 1 — MVP: geotag → tema descritivo**
- **Recortes:** município, UF ou macro-região, com padrão vindo da escola do
  gestor.
- **Temas descritivos e agregados** (conjunto A, marca "1"):
  - IDEB agregado do território (opcionalmente por rede);
  - redes do território;
  - docentes do território;
  - perfil de gestores (UF/região);
  - tendência do IDEB (região);
  - perfil da escola do gestor diante do município e do estado.
- Entrega pela opção 1 (markdown via job + `TextoMarkdown`).
- **Aceite:**
  - o gestor autenticado escolhe recorte e tema e recebe, em até N segundos
    (**em aberto**), um relatório em PT-BR acessível;
  - o relatório cita a edição, o recorte e o `n`, sem PII, com avisos de
    truncamento visíveis;
  - só aparecem temas compatíveis com o nível escolhido;
  - um pedido repetido vem do cache;
  - pedido sem sessão recebe 401.

**Fase 2 — Aprofundamento (ainda no perfil gestor)**
- IDEB por escola no território, covariáveis e regressões declarativas
  (conjunto A, marca "2"), com limites próprios e avisos de
  associação × causalidade.
- Complemento B (escola do gestor: série, similares, scores), se adotado.
- **Aceite:**
  - as regressões rodam dentro de `max_amostra` e do orçamento;
  - todo resultado de regressão traz o aviso de associação.

**Fase 3 — Relatório rico e exportável**
- Tabelas e gráficos (opção 3 ou 2), exportação (PDF/markdown) e histórico de
  relatórios.
- **Aceite:**
  - o relatório exportado reproduz o conteúdo exibido;
  - o histórico respeita a retenção definida.

**Fase 4 — Generalização do padrão**
- Extrair o "assistente sobre o eduBR" (adapter + catálogo de temas +
  contrato) para novos assistentes, como EDAs completas.
- **Aceite:** um segundo assistente é criado só com configuração de temas, sem
  mudar o adapter.

## 10. Evolução: quando o pesquisador for modelado

- **Pesquisador** (nova categoria no cadastro): é quem tem interesse em
  análises **mais profundas e com mais dados**. Ele assume:
  - os temas de profundidade "profunda" (regressões, covariáveis, IDEB por
    escola em escala);
  - limites maiores (`max_linhas_total`, `max_amostra`, orçamento);
  - eventualmente o agente livre, com perguntas exploratórias e handles.
- **Gestor:** volta a um conjunto **mais enxuto**, voltado à escola e ao
  território dela: a curadoria `gestora-escolar` mais os agregados descritivos,
  com limites menores e linguagem simples.
- **O que preparar desde já** para essa separação não exigir retrabalho:
  - o catálogo de temas tem campo `profundidade` e é filtrado por `perfil`;
  - os limites são configurados por perfil;
  - a persona do eduBR é escolhida pelo perfil (gestor →
    `pesquisadora-educacional` + complemento de linguagem; no futuro,
    pesquisador → `pesquisadora-educacional` pleno, gestor →
    `gestora-escolar` + agregados).
- Personas `especialista-ml` e ML continuam fora até haver demanda.

---

### Pontos em aberto — resumo

1. Somar ao conjunto da pesquisadora o complemento B (ferramentas da escola da
   `gestora-escolar`).
2. Banco/schema: o eduBR roda sobre `database.edumaps` com o `edumaps_leitor`?
3. `Suggests` × `Imports` do eduBR.
4. Criação do chat: `chat_edubr()` × `Chat` do EduMaps + `registrar_tools()`.
5. Determinismo: ferramentas fixas por tema × agente livre (fase 2).
6. Entrega: opção 1, 2 ou 3.
7. Registro: `analysis_registry` × `run_report()` próprio.
8. Retenção e exportação dos relatórios; tempo-alvo do MVP.
9. Convergência futura com o Assistente do Censo.
10. Desenho da categoria **pesquisador** (cadastro, permissões, limites).
