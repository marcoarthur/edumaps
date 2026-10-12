# Assistente de Relatório — plano inicial de consumo e integração (edumapsAnalytics → eduBR)

**Data:** 2026-10-12 · **Autor:** Tech Lead (agente) · **Status:** plano inicial,
para discussão — **sem decisões de arquitetura fechadas**.
**Fontes (somente leitura):** `analysis/edumapsr` (pacote `edumapsAnalytics`)
e `~/Projects/eduBR` (repositório **somente-leitura** para este projeto — ver
AGENTS.md). Toda afirmação sobre o eduBR abaixo vem do código dele; o que não foi
verificado está marcado como hipótese.

---

## 1. Contexto e motivação

- O `edumapsAnalytics` (diretório `analysis/edumapsr`) é a camada analítica do
  EduMaps: DataSource → Semantic Model → Analysis pura → `analysis_result` →
  View (plotly/JSON) / Repository (`analytics.*`), exposta por Plumber e
  consumida pelo backend Perl (cliente HTTP síncrono dentro de jobs Minion). O
  **Assistente do Censo** (`ask_censo()`) já usa `ellmer`, mas com um tooling
  próprio e genérico: `run_sql` com SQL gerado pelo modelo, whitelist de
  schemas e redação de PII.
- O `eduBR` evoluiu separadamente e hoje tem um tooling para LLM **mais seguro e
  mais rico**: ferramentas semânticas (sem SQL exposto) com envelope JSON
  `dados/metadados/erro`, personas, ledger, teto de linhas, timeout por chamada
  e orçamento por sessão (`ferramentas_edubr()`, `chat_edubr()`).
- Consumir o eduBR permite ao EduMaps oferecer **assistentes especializados**
  sem reescrever o domínio, começando por um **Assistente de Relatório**: o
  gestor informa um recorte geográfico e recebe um relatório servido pelo
  EduMaps.
- O desafio é integrar **sem acoplar**: o eduBR tem de continuar utilizável
  sozinho, e o EduMaps não pode escrever no repositório dele.

## 2. Objetivo e escopo desta etapa

**Entra**
- Plano de **consumo** do eduBR pelo `edumapsAnalytics` (dependência, adapter,
  conexão, reuso de personas/tooling).
- Posição do Assistente de Relatório no MVC existente.
- Alternativas de **entrega** do relatório ao EduMaps (backend/frontend).
- Contratos mínimos, riscos e backlog em fases.

**Fica fora**
- Código de produção, escolha de bibliotecas, endpoints finais e UX.
- Personas além do gestor (sem "pesquisador": a categoria não existe no
  cadastro).
- Temas que o eduBR não oferece; qualquer alteração no repositório eduBR.
- Substituir o Assistente do Censo (os dois coexistem; convergência é
  **em aberto**).

## 3. Público-alvo

- **Somente gestor** (`clean.gestores`, `access_role = gestor`): cada gestor
  administra **uma escola** (`cod_inep`), da qual derivam município
  (`co_municipio`), UF e macro-região (`clean.censo_escolas`).
- **Pesquisador fica fora**: não há categoria cadastrada; não projetar fluxos,
  temas nem permissões para ele agora.
- Persona LLM correspondente no eduBR: **`gestora-escolar`** (linguagem simples,
  sem cálculos próprios, cita edição/escopo do IDEB, nunca pede ou mostra
  endereço, telefone, CEP, e-mail ou CNPJ).

## 4. Mapa de capacidades (o que o eduBR realmente oferece)

> ⚠️ **Achado central:** a persona `gestora-escolar` recebe **apenas 6
> ferramentas**, todas **centradas em uma escola** (código INEP). As ferramentas
> **territoriais** (município/UF/região) existem, mas estão registradas só para a
> persona **pesquisadora**. Por isso o fluxo "geotag → município | estado |
> macro-região" **não é coberto integralmente pelo tooling do gestor** — ver
> §6a e §8 (decisão **em aberto**).

**A. Disponível para o gestor hoje (persona `gestora-escolar`)**

| Grupo | Ferramenta eduBR | O que entrega | Recorte geográfico |
|---|---|---|---|
| Catálogo | `catalogo` | domínios, grão, anos disponíveis | — |
| Perfil escolar | `perfil_escola` | escola × **município** × **estado**: infraestrutura, IDEB (mesma edição e rede), docentes | escola → seu município e UF |
| Resumo | `resumo_escola` | IDEB por etapa com variação e oferta | escola |
| IDEB (série) | `serie_ideb_escola` | histórico do IDEB por etapa | escola |
| Similaridade | `escolas_similares` | até 20 escolas parecidas (infra/porte/docentes/gestão; sem IDEB/INSE) | nacional, a partir da escola |
| Scores | `scores_escola` | scores compostos 0–10 | escola |

**B. Existe no eduBR, mas só para outra persona (candidato — em aberto)**

| Grupo | Ferramenta | Recorte | Observação |
|---|---|---|---|
| Comparação territorial / IDEB | `ideb_agregado` | UF, macro-região, município (agregado no banco) | média de IDEB; sem PII |
| Redes do município | `redes_municipio` | UF / região / rede | escolas, matrículas, docentes, IDEB médio |
| Docentes | `docentes_rede` | brasil / região / UF / município | contagens agregadas |
| Gestores (perfil) | `perfil_gestor` | brasil / rede / região / UF | **agregado** (moda), sem dado pessoal |
| Municípios | `municipios` | UF | cadastro IBGE (código, região) |
| IDEB por escola | `ideb` | UF / município (**por nome**) | exige filtro |
| Tendência | `tendencia_ideb_regiao` | macro-região | tendência linear |

**C. Não oferecido (não expor)**
- **INSE** só aparece em `features_escola`/`covariaveis_escola` (personas
  pesquisadora/ML) e em relatórios; **não há ferramenta de INSE para o gestor**.
- **Clusters**, **municípios similares**, **OSM** e **IBGE populacional**: sem
  ferramenta (domínios no catálogo, mas sem tool; alguns vazios em dev).
- **Ranking de escola** (`indicadores_escola`): tabela **vazia em dev**; a
  persona do gestor declara ranking "não disponível".
- Regressões e ML (pipelines de pesquisa/ML) — fora do público gestor.

**D. Relatórios prontos (`eduBR/analysis/*.Rmd`)**
- Não são instalados com o pacote (`analysis/` está no `.Rbuildignore`) e
  **não há função de renderização** exportada.
- **Nenhum recebe município como parâmetro.** `rede_professor.Rmd` aceita
  **UF/macro-região**; `tendencia_ideb_regiao` e `regressao_inse_regiao` são por
  macro-região; os demais são nacionais.
- Uso: **referência de conteúdo/estrutura** para o relatório, não artefato
  consumível — forma de reuso **em aberto** (§6a).

## 5. Fluxo de uso (consumo pelo gestor)

1. Gestor autenticado abre o Assistente de Relatório.
2. O sistema propõe o **recorte padrão** a partir da escola do gestor (sessão
   → `cod_inep` → município → UF → macro-região); o gestor confirma ou escolhe
   outro nível: **município | estado | macro-região** (cascata de geotag já
   existente em `/api/cluster/regions|ufs|municipalities`).
3. O sistema lista **somente os temas cobertos pelo nível escolhido** (mapa §4):
   - nível escola/município (fase 1): perfil da escola vs município e estado,
     série do IDEB, escolas similares, scores;
   - níveis estado/macro-região: **dependem da decisão em aberto** (§6a).
4. O gestor escolhe um tema (opcionalmente um ano/etapa permitidos pelo tema).
5. O backend registra o pedido e enfileira um job; o lado R instancia o tooling
   do eduBR com a conexão injetada, roda o assistente (persona gestor) e produz o
   relatório.
6. O gestor acompanha o progresso e recebe o relatório (texto + tabelas, com
   edição/escopo citados e avisos de truncamento); pode salvar ou exportar
   (formato **em aberto**).

## 6. Integração técnica proposta

### a. Como o `edumapsAnalytics` consome o `eduBR`

- **Dependência:** `eduBR` em `Suggests` (ou `Imports`; **em aberto**) do
  `edumapsAnalytics`, chamado sempre como `eduBR::…`; `ellmer` já está em
  Imports. Nada do edumapsAnalytics entra no eduBR (dependência só num sentido).
- **Adapter fino** no edumapsAnalytics (ex.: `R/adapter-edubr.R`), única
  porta de entrada para o eduBR: cria o tooling, filtra temas, aplica limites e
  converte o envelope `dados/metadados/erro` em `analysis_result`.
- **Conexão injetada:** o eduBR aceita `con` em todas as funções. Reusar o
  padrão do Assistente do Censo: conexão **somente-leitura** (role
  `edumaps_leitor`, `statement_timeout` próprio) por pedido, aberta e fechada
  pelo adapter.
  - ⚠️ **Hipótese a verificar (bloqueante):** as tabelas e o schema que o eduBR
    consulta precisam **existir no banco do produto** (`database.edumaps`) e
    estar visíveis ao `edumaps_leitor` (hoje restrito a `clean`/`analytics`).
    O `[edumaps]` local do eduBR já apontou para o cluster antigo
    (`ubatexu.lan`). Fase 0 mede isso.
- **Reuso de tooling e persona (opções para o gap territorial):**
  1. **Só o conjunto do gestor:** `ferramentas_edubr(con, persona =
     "gestora-escolar")`. Respeita a curadoria do eduBR, mas cobre só
     escola × município × estado.
  2. **Subconjunto curado no adapter:** `ferramentas_edubr(con, persona = NULL)`
     e seleção, por nome, das ferramentas **agregadas e sem PII** do grupo B
     (`ideb_agregado`, `redes_municipio`, `docentes_rede`, `perfil_gestor`),
     com o prompt próprio do assistente somado ao `prompt_persona("gestora-escolar")`.
     Não altera o eduBR, mas **contorna a curadoria** de personas dele.
  3. **Pedido ao eduBR:** registrar aqui um achado/proposta para o mantenedor do
     eduBR (persona territorial para gestores, ou ampliar a `gestora-escolar`).
     É a opção mais limpa, mas depende de outro repositório.
  - **Em aberto:** qual opção (ou combinação: 1 agora, 3 como evolução).
- **Provedor LLM:** o eduBR suporta `anthropic|gemini|ollama`; o EduMaps
  configura `gemini|groq|openai|ollama` pelo painel (`integrations.assistant_censo.*`).
  Alternativas: (i) usar `chat_edubr()` só com provedores em comum; (ii) criar o
  `Chat` no edumapsAnalytics (`chat_config()`) e usar
  `eduBR::registrar_tools(chat, tools, persona)`. **Em aberto** (ii é a menos
  acoplada à configuração do eduBR).
- **Relatórios `analysis/`:** como não são instalados, as opções são reimplementar
  a estrutura como Analysis do edumapsAnalytics usando funções exportadas do
  eduBR, ou propor no eduBR (§6a.3) que relatórios parametrizáveis passem a ser
  instalados (`inst/`). **Não copiar** os `.Rmd` para cá (cria divergência).

### b. Onde entra o Assistente de Relatório no MVC

| Camada | Papel no assistente |
|---|---|
| DataSource | `edubr_source(con, limites)`: encapsula a criação do tooling e a conexão |
| Semantic Model | `report_request_model`: recorte (nível + código), tema, ano/etapa, persona; valida tema × nível pelo **mapa de capacidades** |
| Analysis | `analyze_report(model, parameters)`: orquestra (a) chamadas determinísticas às ferramentas do tema e (b) a redação pelo LLM; devolve `analysis_result` |
| AnalysisResult | `data` = envelopes das ferramentas; `tables` = tabelas do relatório; `metadata` = ledger, avisos, truncamentos, edição do IDEB, provedor/modelo |
| View | `render_report_markdown()` / `render_json()` (já existe) |
| Repository | cache/persistência em `analytics.*` (padrão dos repositórios Postgres); detalhe **em aberto** |

- **Registro:** entrada nova no `analysis_registry` (`app-registry.R`) ou um
  `run_report()` próprio, como `run_cluster`/`run_similarity`, já que o modelo
  não é um `school_indicator_model`. **Em aberto.**
- **Controller/HTTP:** endpoint Plumber novo (ex.: `POST /report`) no padrão de
  `/ask`: erros de cliente 400, de provedor 502, internos 500.
- **Task:** job Minion na fila `analytics` (como `chat_ask`), com progresso e
  resultado em `job->finish`; o cache do `Analytics::Client` (24 h) serve para
  pedidos repetidos.
- **Determinismo × LLM:** a hipótese preferida é **o adapter chamar as
  ferramentas do tema de forma determinística** e o LLM **só redigir**. Isso dá
  reprodutibilidade e custo previsível. A alternativa é o agente escolher as
  ferramentas livremente. **Em aberto.**

### c. Como o relatório é servido ao EduMaps (opções, sem escolha)

| Opção | Como | Prós | Contras |
|---|---|---|---|
| **1. Markdown + tabelas via job** | Minion → Plumber `/report` → JSON `{markdown, tabelas, metadados}`; o frontend faz polling e renderiza com o `TextoMarkdown` seguro (já existe) | reusa todo o caminho do Assistente do Censo; menor esforço | só markdown simples; gráficos exigem trabalho à parte |
| **2. HTML pré-renderizado (R Markdown)** | R renderiza HTML (`rmarkdown`) e o salva (`analytics.*` ou arquivo); o backend serve por link/iframe ou download | próximo dos relatórios do eduBR; exportável (PDF) | iframe/HTML de terceiros na SPA (CSP, XSS); pandoc no contêiner; mais pesado |
| **3. JSON estruturado por seções** | `analysis_result` → seções tipadas (texto, tabela, série) e componentes Svelte nativos (Carbon Charts já está no projeto) | UX integrada, acessível, sem HTML externo | mais frontend; contrato de seções a desenhar |

## 7. Contratos e interfaces mínimas (abstratos)

**Entrada (pedido de relatório)**
```
ReportRequest {
  geotag:  { nivel: "escola" | "municipio" | "uf" | "regiao",
             codigo: cod_inep | codigo_ibge(7) | sigla_uf | sigla_regiao }
  tema:    id do catálogo de temas (derivado do mapa §4)
  opcoes?: { ano_ideb?, etapa? }          # só os que o tema aceita
  contexto (do servidor, não do cliente): { gestor_id, cod_inep }
}
```

**Catálogo de temas (derivado, não inventado)**
```
temas_disponiveis(nivel) -> [ { id, titulo, ferramentas_edubr[], niveis[] } ]
```

**Saída (relatório)**
```
ReportResult {
  titulo, recorte, tema,
  corpo_markdown | secoes[],              # conforme a opção de entrega
  tabelas[],
  fontes: [ { ferramenta, edicao/ano, escopo } ],
  avisos: [ truncado, sem_dados, limite_excedido, ... ],
  rastreio: { ledger_resumo, provedor, modelo, duracao_ms, cache_hit }
}
```

**Assinaturas indicativas (R)**
```
edubr_source(con, limites = list())
temas_disponiveis(nivel)
run_report(request, config = NULL) -> analysis_result
```

## 8. Riscos, restrições e pontos em aberto

- **Cobertura territorial para gestor (em aberto):** sem as opções 2 ou 3 de
  §6a, estado e macro-região não têm temas no conjunto do gestor.
- **Schema/banco (bloqueante, em aberto):** o eduBR precisa ler o banco do
  produto pelo `edumaps_leitor`. Validar tabelas, tipos (`co_municipio` int ×
  `codigo_ibge` varchar(7)) e permissões antes de qualquer código.
- **Contexto confiável:** hoje o `/api/chat/ask` aceita `contexto` do cliente,
  sem checar a sessão. O relatório deve derivar escola/recorte padrão **da
  sessão do gestor** e exigir autenticação.
- **LGPD:** as ferramentas removem endereço, telefone, CEP e CNPJ, mas não
  e-mail (este só é coberto pelo prompt). `exportar()` e as funções de domínio
  fora do tooling **não** filtram PII, então o adapter só deve usar as
  ferramentas. Nomes de escola e INEP são dados institucionais. Relatórios
  salvos são dados do gestor: retenção **em aberto**.
- **Custo de LLM:** um relatório por pedido; cache por (recorte, tema,
  edição, versão do prompt e do eduBR). Teto de tokens (`max_tokens`). Provedor
  e modelo vêm do painel.
- **Teto de linhas e orçamento:** usar os limites do eduBR (`max_linhas` ≤ 1000,
  `max_chamadas`, `max_linhas_total`, `max_caracteres`) com valores **menores**
  para relatório; um tooling **por pedido** (handles em memória).
- **Timeouts:** o eduBR altera `statement_timeout` na conexão a cada chamada e
  restaura depois. Conexão **não compartilhada** entre pedidos concorrentes. O
  Plumber é síncrono, com timeout de 300 s no cliente Perl: alinhar o timeout
  total do relatório e o progresso do job.
- **Reprodutibilidade:** registrar a versão do eduBR, a edição dos dados, o
  ledger e o prompt; preferir ferramentas determinísticas com LLM só redigindo
  (§6b). O texto do LLM varia, então cache e versão contam.
- **Dados vazios em dev** (ranking, municípios similares, IBGE): não oferecer
  esses temas.
- **Dívidas encontradas no levantamento:**
  - o chat atual renderiza markdown como texto puro e descarta o gráfico;
  - `stop_chat_internal()` é chamado, mas não está definido (`chat-dictionary.R:29`);
  - `censo-dictionary.R` está fora do `Collate`.

  Registrar como issues separadas.
- **Independência:** o eduBR fica intacto; qualquer necessidade nele é um
  **achado registrado aqui**, nunca uma alteração lá.

## 9. Backlog em fases

**Fase 0 — Viabilidade (spike, sem UI)**
- Instalar o eduBR no contêiner/host `analytic` e chamar
  `ferramentas_edubr(con_leitor, persona = "gestora-escolar")` contra
  `database.edumaps`.
- **Aceite:** as 6 ferramentas do gestor respondem sem `erro.tipo = conexao` para
  3 escolas reais; ledger e limites funcionam; lacunas de schema/permissão
  documentadas.

**Fase 1 — MVP: relatório da minha escola no meu município (geotag → tema)**
- Recorte fixo pela sessão: escola do gestor, comparada com o município e a UF
  dela.
- Temas: **perfil da escola vs município/estado**, **série do IDEB**, **escolas
  similares** (só ferramentas da `gestora-escolar`).
- Entrega pela opção 1 (markdown via job + `TextoMarkdown`).
- **Aceite:** um gestor autenticado escolhe um dos 3 temas e recebe em até
  N segundos (**em aberto**) um relatório em PT-BR que cita a edição do IDEB e o
  escopo, sem PII, com avisos de truncamento visíveis. O mesmo pedido repetido
  vem do cache. Pedidos sem sessão retornam 401.

**Fase 2 — Recortes territoriais (estado, macro-região, outro município)**
- Depende da decisão de §6a (opção 2 ou 3).
- Temas: IDEB agregado, redes e docentes do território, perfil agregado de
  gestores.
- **Aceite:** para cada nível, só aparecem temas cobertos pelo mapa; os
  agregados nunca trazem dado pessoal; o orçamento por pedido é respeitado.

**Fase 3 — Relatório rico e exportável**
- Tabelas e gráficos (opção 3 ou 2), exportação (PDF/markdown), histórico de
  relatórios do gestor.
- **Aceite:** o relatório exportado reproduz o conteúdo exibido; o histórico
  respeita a retenção definida.

**Fase 4 — Generalização do padrão**
- Extrair o "assistente sobre eduBR" (adapter + catálogo de temas + contrato)
  para novos assistentes, como EDAs completas.
- **Aceite:** um segundo assistente é criado só com configuração de temas, sem
  mudar o adapter.

---

### Pontos em aberto — resumo

1. Cobertura territorial para gestor: só `gestora-escolar`, subconjunto curado
   ou pedido ao eduBR.
2. Banco/schema: o eduBR roda sobre `database.edumaps` com `edumaps_leitor`?
3. `Suggests` × `Imports` do eduBR.
4. Criação do chat: `chat_edubr()` × `Chat` do EduMaps + `registrar_tools()`.
5. Determinismo: ferramentas fixas por tema × agente livre.
6. Entrega: opção 1, 2 ou 3.
7. Registro: `analysis_registry` × `run_report()` próprio.
8. Retenção e exportação dos relatórios; tempo-alvo do MVP.
9. Convergência futura com o Assistente do Censo.
