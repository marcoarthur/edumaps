# Cobertura E2E (browser real via CDP)

Fluxos e2e da SPA EduMaps. Para **cada feature**:
1. `browser_navigate` → rota correspondente;
2. carregar e assertar o conteúdo-chave;
3. interagir no fluxo principal (quando houver);
4. registrar `PASS`/`FAIL` (com data e observação).

**Legend**: · ainda não executado · 🟢 PASS · 🔴 FAIL · ⚪ planejado (pré-requisito ausente)

## Rodada 2026-09-28 (tiles OSM no lugar do CARTO)

**Causa do bug "mapas sem tiles + tarja para definir chave API"**: o tile
layer usava o CDN `basemaps.cartocdn.com` (`light_all`), que exige
chave/API em algumas condições. **Fix: `LeafletMap.svelte` e
`AnalBaseMap.svelte` (legado) passaram a usar
`https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png`** (sem chave).

Validação e2e (Chrome CDP `:9333`, profile `/tmp/edumaps-cdp2`, alvo
`http://ubatexu.lan:8080/gestor/painel?inep=35211576`, fluxo "Buscar
escolas similares"):

| Verificação | Resultado |
|---|---|
| Bundle servido | `index-CWm3qagX.js` — `cartocdn: 0`, única `tileUrl` = OSM |
| Tiles carregados | 🟢 15/15 (hosts `a/b/c.tile.openstreetmap.org`) |
| Status HTTP dos tiles | 🟢 200 `image/png` (frio, 17 respostas, 0 falhas) |
| Tarja/texto de API key no DOM do mapa | 🟢 ausente (`keyTexts: []`, `tileErrorCls: false`) |
| Testes unitários frontend | 🟢 26 arquivos / 138 testes (docker `node:22-slim`) |
| Deploy | 🟢 `rex prepare` + `deploy_frontend_dev` (`backend.edumaps`) |

> **Nota do fix**: o `edumaps` não passa `tileUrl` custom em nenhum caller —
> todos os mapas (escolas similares, escola, rede, cluster) usam o default
> do `LeafletMap`; a troca única corrige todos.

## Ambiente desta rodada (2026-09-28)

`ubatexu.lan` e `backend.edumaps` seguem **fora do ar**, então o alvo
padrão (`http://ubatexu.lan:8080`) não existe. A rodada rodou contra um
alvo montado local:

| Peça | Onde |
|---|---|
| Banco | container `edumaps-db` (já existente), `127.0.0.1:5432` |
| Backend | perlbrew na máquina, `prefork` em `:3000` |
| Build da SPA | `node:22-slim` (`npm ci` + `vite build`) |
| Servidor da SPA | `nginx:alpine`, `/api` com proxy para o backend |
| Dev server (para diagnosticar) | `vite dev` em `:5173` |
| Chrome | CDP em `127.0.0.1:9222`, profile dedicado |

O plugin `opencode-chrome-devtools` **não estava conectado** nesta sessão
(`browser.tabs.list` → *No desktop browser is connected*). O e2e foi feito
dirigindo o **CDP direto** com um cliente WebSocket próprio, dentro de um
container com `--network host` (assim `127.0.0.1:9222` alcança o Chrome sem
expor o CDP na rede). O runbook continua válido: só o *driver* mudou.

Descoberta de infraestrutura, **pré-existente**:

- Rotas com query string (`/escola/ranking?inep=…`) retornam **500 do
  nginx** — o `try_files $uri $uri/ /index.html` não cobre o caminho com
  `?`. Montar as URLs com a query **antes** do `browser_navigate`.

> **Correção de uma leitura anterior deste arquivo.** Numa primeira
> passagem observei `/` e `/gestor` quebrando com
> `TypeError: fn is not a function` no flush do Svelte e atribuí a causa ao
> `manualChunks` do `vite.config.js`. **Atribuição errada**: o erro não
> reproduz em nenhuma configuração testada — mesmo build, mesmo chunk,
> perfil de browser novo, origem nova e primeira visita. É
> **transiente** e a causa não foi identificada. As tabelas abaixo já não
> o tratam como falha Reproduzível.

## Cobertura por rota

| # | Rota | Feature | Status | Obs. |
|---|------|---------|--------|------|
| 1 | `/` | home | 🟢 2026-09-28 | Renderiza os pilares; 0 exceções (ver nota sobre o erro transitício acima) |
| 2 | `/about` | about | 🟢 2026-09-28 | Página institucional |
| 3 | `/municipio/compare` | network-compare | 🔴 2026-09-28 | 500 do nginx (query string) |
| 4 | `/escola/search` | schools | 🟢 2026-09-28 | Formulário e hints renderizam |
| 5 | `/escola/panel?inep=35245239` | schools | 🟢 2026-09-28 | Carrega com 1 chamada `/api` |
| 6 | `/escola/ranking?inep=35011162` | schools | 🔴 2026-09-28 | 500 do nginx (query string) |
| 7 | `/escola/payroll?inep=…&date=…` | schools | 🔴 2026-09-28 | 500 do nginx (query string) |
| 8 | `/escola/financeiro?inep=…` | schools | 🔴 2026-09-28 | 500 do nginx (query string) |
| 9 | `/cluster/geotag` | cluster-geotag | 🔴 2026-09-28 | 500 do nginx (reproduz com URL sem query) |
| 10 | `/gestor` | gestor | 🟢 2026-09-28 | Card de login, 1 chamada `/api`, 0 exceções |
| 11 | `/gestor/painel?inep=35245239` | gestor | 🟢 2026-09-28 | Raio-X com 1 chamada `/api` |
| 12 | `/gestor/pesquisas?inep=…` | gestor | 🟢 2026-09-28 | Carrega |
| 16 | `/chat/censo` | chat | 🟢 2026-09-28 | Página carrega; o NL→SQL depende do serviço de analytics (ausente) |
| 27 | `/config` | config | 🟢 2026-09-28 | Árvore de categorias, 3 chamadas `/api` |

### Rota fora da tabela — descoberta nesta rodada

| # | Rota | Feature | Status | Obs. |
|---|------|---------|--------|------|
| 28 | `/chat/historico` | chat (histórico) | 🔴→🟢 2026-09-28 | **Não estava na cobertura.** Ver achados abaixo |

### Interações em `/chat/historico` (build de produção, com sessão real)

| Interação | Status | Obs. |
|----------|--------|------|
| Listar conversas | 🟢 | 3 conversas, `/api/chat/conversas` 200 |
| Contador no calendário | 🟢 | `aria-label="28 - 3 conversa(s)"`; badge "3" no dia 28 |
| Clicar num dia do calendário | 🟢 | Filtra para as conversas do dia (as 3 são de 28/09) |
| Buscar por texto | 🟢 | Filtra a lista **depois** da correção nº 3 |
| Buscar pelo campo **da lista** | 🟢 | Tinha `bind:value` num prop não-bindável (achado 9) |
| Limpar a busca | 🟢 | Volta à listagem completa |
| Selecionar uma / todas | 🟢 | Checkbox e "selecionar todas" criados nesta rodada |
| Exportar todas (.md) | 🟢 | Baixa `conversas-2026-09-28.md`, 818 B, 3 seções |
| Exportar selecionadas | 🟢 | Idem, com os ids marcados |
| Exportar **uma** conversa | 🟢 | Botão do item |
| Excluir | 🟢 | `confirm()` + `DELETE` 204 + item some da lista |
| "Ver conversa" | ⚪ | **Sem destino** — ver achado 10 |

> **Nota de driver**: o `a.click()` de um `blob:` disparado por script **não**
> concede *user activation*, e o Chrome descarta o download. Só funciona com
> clique de verdade (`Input.dispatchMouseEvent`). O `Page.setDownloadBehavior`
> na sessão de página não redirecionou o download — o arquivo foi para o
> diretório padrão do Chrome. Para `confirm()`, é preciso responder a
> `Page.javascriptDialogOpening` com `Page.handleJavaScriptDialog`.

## Achados em `/chat/historico` (commit `9fd4a0e`)

A página **não funcionava**. Três bugs independentes, todos do mesmo
commit, nenhum pego pelos testes (a rota não tem `*.test.js` nem handler
MSW):

1. **`ChatCalendar.svelte:66` — `$effect(buildCalendar())`**.
   `$effect` espera uma **função**; a chamada passava o **retorno** de
   `buildCalendar()` (`undefined`). Erro: `TypeError: Object.defineProperty
   called on non-object`. Como o erro acontece no flush do Svelte, ele
   **aborta o `onMount` da página** — a lista nunca era buscada e a tela
   mostrava "Nenhuma conversa encontrada" mesmo com conversas no banco.
   *Corrigido: `$effect(() => { buildCalendar(); })`.*

2. **`ChatConversaItem.svelte:33` — `{snippet}` sem prop**.
   O JSDoc declara `conversa.snippet`; o template usava o identificador
   solto. Erro: `ReferenceError: snippet is not defined`, uma vez por
   linha da lista. *Corrigido: `conversa.snippet`.*

3. **`ChatHistoricoPage.svelte` — `searchResults` escrito e nunca lido**.
   A busca preenchia `searchResults`, mas o template passava
   `conversas={conversas}`. O servidor era consultado e o resultado
   descartado: **a busca não filtrava nada na tela**.
   *Corrigido: `conversas={searchQuery.trim() ? searchResults : conversas}`.*

Uma vez a página carregou, apareceram **mais seis defeitos** — nenhum deles
pego por teste, porque a rota não tem cobertura. Os dois primeiros só eram
visíveis depois da correção nº 3.

4. **Handlers stub em `ChatConversaList.svelte`** — "Exportar todas",
   "Exportar selecionadas" e o item inteiro tinham `onclick={() => {}}` /
   `onClick={() => {}}` / `onExport={(id) => {}}` / `onDelete={(id) => {}}`,
   embora a página passasse as funções reais. Exportar e excluir não faziam
   nada. *Corrigido: handlers ligados e `onExportOne`/`onDelete`/`onOpen`
   repassados.*

5. **`exportConversas` ignorava a autenticação.** Era a única função de
   `chatApi.js` que não passava por `apiClient`: usava `fetch` cru com
   `credentials: "include"`, ou seja, só cookie. Mas `_require_gestor` só
   lê `Authorization: Bearer` → **401 nos dois botões de exportar**.
   *Corrigido: passou a usar `apiClient.download`, que monta o header e
   ainda aproveita o `Content-Disposition` para o nome do arquivo.*

6. **`URL.revokeObjectURL` no mesmo tick** do `a.click()` pode cancelar o
   download antes de ele começar; e o `a` solto no DOM é frágil.
   *Corrigido: âncora anexada ao `body` e `revoke` num `setTimeout`.*

7. **Os botões "Excluir" e "Exportar" do item eram inclicáveis.** O botão
   "Ver conversa" é um overlay `absolute inset-0` sobre o card inteiro e,
   por vir depois no DOM, ficava por cima: `document.elementFromPoint` no
   centro do botão de excluir devolvia o overlay, não o botão. O
   `stopPropagation` dos handlers não ajudava, porque o clique nem chegava
   neles. *Corrigido: `relative z-10` no cabeçalho do item.*

8. **`bind:value={searchQuery}` num prop não-bindável.** O campo de busca
   **dentro da lista** escrevia numa cópia local: digitar nele não filtrava
   e não chegava no input do topo. *Corrigido: `$bindable("")` no
   componente e `bind:searchQuery` na página.*

9. **Não havia UI de seleção.** `selectedIds`/`toggleSelect`/`selectAll`
   existiam, mas o item não tinha checkbox — logo "Exportar selecionadas"
   nunca podia ser usado. *Corrigido: checkbox por item e "selecionar
   todas"; o botão só habilita com seleção.*

10. **"Ver conversa" não tem destino.** A `ChatPage` não sabe reabrir uma
    conversa salva: não lê id nem query param, a rota é estática, e
    `getConversa()` em `chatApi.js` não é chamado por código nenhum. Em vez
    de deixar o clique mudo, a página agora avisa que a reabertura não está
    disponível. **Continua sendo lacuna de produto** — implementá-la exige
    rota/param e carga da conversa no chat.

11. **O filtro `ids` do export nunca funcionou — em nenhuma das duas
    formas.** Só apareceu depois de ligar os botões (achado 4):
    - `?ids[]=1` — o `to_hash` do Mojolicious **não** converte a notação
      de colchete: a chave vira literalmente `ids[]` e `to_hash->{ids}`
      volta `undef`. Resultado: `@ids` vazio, filtro ignorado, e o export
      saía com **todas** as conversas do gestor, **em silêncio**.
    - `?ids=1` — aí o filtro era aplicado, mas o `prefetch => mensagens`
      fazia JOIN e `id` existe nas duas tabelas →
      `ERROR: column reference "id" is ambiguous` → **500**.

    *Corrigido nos dois lados:* o controller coleta `ids` e `ids[]` e
    filtra para inteiro, e o `prefetch` foi removido do modelo (ele era
    inclusive **descartado** — o loop já buscava as mensagens com
    `$c->mensagens->search(...)`, ou seja o JOIN só existia para atrapalhar).

12. **O teste do export afirmava o que não testava.** Ele usava
    `?ids[]=$id` — a forma ignorada — e depois conferia que o corpo tinha
    `## Pergunta 1` e `## Resposta 1`. Como o filtro não valia, o corpo
    vinha com *todas* as conversas, então as asserções passavam por uma
    conversa que não era a pedida. *Corrigido: o teste cria a própria
    conversa e passa a contar as seções, checando que a outra não vaza;
    o subteste novo cobre `ids=`, `ids[]`, ids repetidas e `all=1`.*

13. **A chamada usava a chave errada.** O `POST /api/chat/conversas`
    espera `messages` (inglês), não `mensagens` — `mensagens` dá 400
    "messages deve ser um array". E a resposta traz só `{id}`, apesar de o
    comentário prometer `{id, created_at}`.

### Achados abertos (não corrigidos — 14 e 16 são decisão de produto)

Os três são do backend (`Roles/Business/Chat/Conversas.pm::search_conversas`)
e reproduzíveis só depois da correção nº 3 — antes dela a busca nem
filtrava a tela, então ninguém via estes sintomas.

14. **Busca devolve uma linha por mensagem, não por conversa.** O SQL usa
    `SELECT DISTINCT c.id, c.titulo, c.created_at, c.updated_at,
    ts_headline(...) AS snippet`. Como o **`snippet` entra no `DISTINCT`**,
    duas mensagens com trechos diferentes produzem **duas linhas com o
    mesmo `id`**. O `COUNT(DISTINCT c.id)` do total já conta certo, e o
    comentário do método diz "Retorna conversas distintas que têm match",
    ou seja a **intenção é uma linha por conversa** e o `DISTINCT` não
    cumpre por causa do `snippet`. Além disso o item de busca **não traz
    `msg_count`**, então o `ChatConversaItem` renderiza ` msg` sem número.
    *Mitigação no cliente:* a página deduplica os ids em `listaExibida`.
    Sem isso, ids repetidos num `{#each}` com key derrubam a tela com
    `each_key_duplicate` — foi o que aconteceu ao adicionar a key
    durante esta rodada, e o sintoma (busca que "não filtra nada") é
    parecido com o do achado nº 3, o que confunde o diagnóstico.
15. **`snippet` vem com HTML** (`30 escolas têm <b>biblioteca</b>.`, porque
    `ts_headline` marca o match com `<b>`) e é renderizado como **texto** —
    o usuário vê as tags. Duas saídas: `{@html}` no componente (exige
    sanitizar, senão é XSS a partir do conteúdo da conversa) ou passar
    `StartSel=<mark>, StopSel=</mark>`/remover as tags no backend.
16. **Busca é sensível a acento.** `to_tsvector('portuguese', ...)` não
    remove acento, e o `unaccent` não está no SQL:

    | consulta | conversas |
    |----------|-----------|
    | `matriculas` | **0** |
    | `matrículas` | 1 |

    Digitação sem acento é o caso comum; resolver com `unaccent` no
    `to_tsvector` (exige a extensão `unaccent` no banco).

 (não são bugs do app, mas custam tempo)

- **`?ids[]=` e não `?ids=`.** O `export_conversas` lê
  `params->to_hash->{ids}`; sem os colchetes o Mojolicious não monta o
  `arrayref` e a rota estoura em **500**. `?ids[]=1&ids[]=2` → 200.
  Descobri isso porque "corrigi" para `ids` durante esta rodada e quebrei o
  export — o teste e2e pegou, mas o contrato merece ficar escrito no
  cliente.
- **Autenticação é por header, não cookie.** `_require_gestor` só lê
  `Authorization: Bearer`. `credentials: "include"` sozinho dá 401 mesmo
  com sessão válida. Toda chamada nova tem de passar por `apiClient`.
- **O `POST /api/chat/conversas` espera `messages`** (inglês), não
  `mensagens`; e responde só `{id}`.

## Verificação do backend de conversa (commit `9fd4a0e` + PR #100)

Com 3 conversas semeadas via API e uma sessão de gestor real
(`POST /api/gestor/login`), conferido **contra a API, não contra o código**:

- `meta` gravado no banco como **objeto** jsonb (`jsonb_typeof = 'object'`,
  6 mensagens).
- `GET /api/chat/conversas/:id` devolve `meta` como **dict**, com as chaves
  `timestamp`, `sql`, `resultado`, `origem` — e `origem.join(", ")`, que é
  exatamente o que `ChatMessage.svelte` faz. Antes da correção do PR #100
  vinha `str`.
- A página de histórico consome só a **listagem**; `getConversa(id)` existe
  em `chatApi.js` e **não é chamado por nenhum código**. Ou seja: a
  correção do `meta` é verificável pela API, mas **não tem efeito
  visível na SPA** — o que o `frontend` mostra hoje continua igual.

## Pendências de cobertura

- Rotas **13-15, 17-26** não executadas (exigem sessão de gestor com
  escola real ou formulário público).
- Interações ainda não cobertas: busca de escola, paginação do
  histórico, exclusão, exportar `.md`.
- Os 500 do nginx em query string impediram 5 rotas (#3, 6, 7, 8 e 9).
  **Não é bug do app** — é o `try_files` do nginx de e2e. Ainda assim o
  `nginx.conf` do repo tem o mesmo `location /` e merece uma
  `location ~ \.html$` ou checagem de `?`.
- `/chat/historico` não tem `*.test.js` nem handler MSW — foi por isso que
  três bugs sobreviveram até o e2e.

_Atualizar esta tabela a cada rodada; manter rastro de data + achados._

## Rodada 2026-09-28 — Perfil da escola (`/escola/perfil`)

Feature nova (issue #105): painel analítico do gestor com diagnóstico,
posição relativa (município/rede/Brasil/cluster), distribuição no cluster,
sinais de atenção e escolas similares (Gower). Consome
`GET /api/school/:cod_inep/profile` (ponte backend → serviço analítico R).

| Verificação | Resultado |
|---|---|
| Bundle deployado contém a rota/feature | 🟢 `index-DAS1-W4A.js` com `escola/perfil`, "Perfil da Escola", "Posição relativa", `school_profile` |
| `GET /api/school/23165669/profile` (via `ubatexu.lan:8080`) | 🟢 200, payload com `indicadores_comparados`/`cluster_resumo`/`peers`/`flags` |
| `co_entidade` inexistente | 🟢 400 (`Escola não encontrada`, sem vazar caminho/linha) |
| `co_entidade` malformado | 🟢 404 |
| Painel em `http://ubatexu.lan:8080/escola/perfil?inep=23165669` | 🟢 PASS (validação visual do developer, 2026-09-28) |
| Atalho "Perfil analítico" em `/escola/panel` e `/gestor/painel` | 🟢 presente |

Desempenho no host analítico de dev: escola típica (sem cluster persistido)
**~1,7–2,4s**; escola com cluster persistido ~3,4s (percentis sobre 2.821
escolas). A primeira chamada de cada escola é mais lenta (cache do backend
`analytics.analysis_cache` cobre as seguintes por 24h).

## Rodada 2026-09-29 — Perfil da Escola Fase 2 (issue #107)

Read-through do perfil (referências/percentis pré-computados):

| Verificação | Resultado |
|---|---|
| `GET /api/school/23165669/profile` warm | 🟢 200 em ~0,1–0,4s; `cached=true`, `reference_source_municipio=reference` |
| Escola com cluster persistido (`51054531`) | 🟢 `cluster_source=persisted`, `cluster_scope=cluster_profile`, `cluster_run_id` presente |
| `POST /api/task/school_profile` (JSON, limit=2) | 🟢 202; job processou 2 (`analytics.school_profile` 422→424) |
| Timer `edumaps-school-profile-refresh.timer` | 🟢 enabled, próxima execução agendada |
| Painel `/escola/perfil` (linha "Perfil atualizado em") | 🟢 PASS (validação visual do developer, 2026-09-29) |

## Rodada 2026-09-29 — Roadmap do Perfil da Escola (itens A/B/C)

| Verificação | Resultado |
|---|---|
| `/escola/perfil` — seção "Evolução" (IDEB/SAEB por ano) | 🟢 PASS (validação visual do developer, 2026-09-29) |
| `/municipio/perfil?ibge=2307304` — "Rede vs. Brasil" + clusters | 🟢 PASS (validação visual do developer, 2026-09-29) |
| `GET /api/school/:cod/evolution` | 🟢 200 (27 pontos); 99999999 → 400; `abc` → 404 |
| `GET /api/network/:ibge/profile` | 🟢 200 (225 escolas); 9999999 → 400; `abc` → 404 |
| `/ask` "Como está a escola 23165669?" | 🟢 200 consultando `analytics.school_profile_flat` (resposta coerente com o perfil) |

## Rodada 2026-10-07 — Certificação e2e do Bot Telegram (login → `system.bot.info`)

**Objetivo**: certificar ponta a ponta o fluxo da #188 (PR #189) — login na
SPA dispara `system.bot.info` e o bot entrega a mensagem no Telegram. Driver
próprio sobre o CDP do Chrome (mesmo padrão da rodada 2026-09-28), container
`node:22-slim` com `--network host`, alvo `http://ubatexu.lan:8080/gestor`.

**Causa raiz do teste manual do developer (falha ≠ bug)**: no produto
(`database.edumaps`) a `app_config.items` só tinha `allowed_actions` do
`bot_telegram` — faltavam `enabled`, `token` e `chat_id`. E
`EDUMAPS_CONFIG_MASTER_KEY` estava **vazia** no serviço `edumaps-web`, o que
impede o backend de cifrar/decifrar secrets (nem o `assistant_censo.api_key`
era legível). O log do backend registrava a cadeia a funcionar, só faltava
config: `Notifier: bot desativado — system_bot_info ignorada`.

**Preparação** (ambiente dev autorizado): master key gerada e setada em
`edumaps-web` + `edumaps-minion` (systemd, restart); config completa via SQL
na BD do produto (`enabled=1`, `chat_id` do `tools/notify/.env`, `token`
cifrado com `pgp_sym_encrypt` + master key; `allowed_actions` já continha
`system_bot_info`); gestor admin descartável `e2e.bot@edumaps.local` (hash
`salt:hmac_sha256` via `Digest::SHA` — ⚠️ `openssl dgst -mac HMAC` diverge do
Perl, não usar para esse hash).

| Verificação | Resultado |
|---|---|
| Login na SPA (`/gestor`) — Chrome CDP real | 🟢 `POST /api/gestor/login` → **200** |
| Sessão criada | 🟢 navegou para `/gestor/painel` ("Painel do Gestor") |
| `Middleware::Login` → EventBus `system.bot.info` | 🟢 log `Middleware::Bot: system_bot_info entregue` |
| Envio ao Telegram | 🟢 `Notifier: system_bot_info enviada (HTTP 200)` — API aceitou (`ok:true`) |
| Mensagem esperada | 🟢 `Login realizado: e2e.bot@edumaps.local`; no próximo login do developer: `Login realizado: rovai@edumaps.dev` |

> **Notas**: `getUpdates` da API do Telegram **não** é evidência de envio (lista
> só mensagens recebidas pelo bot) — a prova é o HTTP 200 com `ok:true` no log
> do Notifier. A master key agora vive nos units do host (`backend.edumaps`);
> se rotacionar, re-cifrar os secrets (`secret_key_version`).

## Rodada 2026-10-09 — Busca 502: container do backend morto; validado pós-`up -d` (PR #196)

**Contexto**: após o ciclo #172+#157 (PR #196), as imagens `backend`/`minion`
foram reconstruídas e os containers recriados (`docker compose up -d`,
12:53). O developer reportou **"busca retorna 502"** verificando os dockers.

**Causa raiz do 502**: o container `edumaps-backend` **antigo** (criado ~5
dias antes, código velho) estava com o aplicativo **sem escutar em `:3000`**.
O nginx do frontend registrou `connect() failed (111: Connection refused)`
no upstream `172.18.0.5:3000` de **12:07:16 até 12:40:31** — todos os
`/api/*` da SPA (`school/suggestions`, `city/suggestions`,
`school/search/pageable`, `gestor/me`) responderam **502**. A armadilha
conhecida do AGENTS: imagem reconstruída ≠ container recriado. O
`docker compose up -d` (12:53) recriou o backend com a imagem mergeada →
`restart=0`, zero 502 desde então (log do nginx confirma).

| Verificação (alvo `http://localhost:8080`, Chrome CDP `:9222`) | Resultado |
|---|---|
| `/escola/search` carrega (formulário) | 🟢 PASS |
| Autocomplete: digitar "freire" → `GET /api/school/suggestions?q=freire` | 🟢 200 (1359 B) |
| "Buscar Escolas" → `GET /api/school/search/pageable?escola=freire&page=1&per_page=10` | 🟢 200 (1382 B) — lista renderiza (Paulo Freire/RJ etc.) |
| `/` (home) | 🟢 PASS (landing, sem chamadas de API) |
| `/municipio/compare` | 🟢 PASS (mapa após selecionar município) |
| Nenhum 502 no nginx após 12:53 | 🟢 PASS |

**Observações**:
- `search/pageable` para escola **inativa** retorna vazio por design:
  `tp_situacao_funcionamento = 1` (só em funcionamento). Ex.: "mojuca"
  (CENTRO EDUCACIONAL MOJUCA, Porto Velho) tem `tp=2` → corretamente
  excluída; `search`/`suggestions` (sem o filtro) a acham.
- A página de busca é **lista** (mapa é do painel da escola e das páginas de
  comparação/geotag) — `leaflet-container` ausente na rota de busca é
  esperado.
- Nenhuma correção de código foi necessária: era infra/local (container
  recriado). Sem deploy.

## Rodada 2026-10-09 — Certificação de regressão pós #160/#136

**Objetivo**: certificar que os merges recentes — #160 (`sqitch verify` como
gate) e #136 (git hooks) — **não mudaram comportamento** da SPA. Nenhum dos
dois toca `frontend/`/`backend/` de runtime (é infra de banco/CI e de git),
logo o esperado é **regressão zero**.

Driver próprio sobre o CDP do Chrome (`:9222`), container
`node:22-slim --network host`, alvo `http://localhost:8080` (o plugin de
browser do agente **não estava conectado** — mesmo padrão de 2026-09-28).
14 rotas + interação de busca + fluxo de mapa, com captura de console,
exceções e requisições `/api/`.

| Rota | Resultado | API |
|---|---|---|
| `/` home | 🟢 PASS | — |
| `/about` | 🟢 PASS | — |
| `/escola/search` (+ digitar "freire" + Buscar) | 🟢 PASS | `suggestions` 200, `search/pageable` 200; 60 cards, "freire" presente |
| `/escola/panel?inep=35245239` | 🟢 PASS | `panel/info` 200 |
| `/escola/perfil?inep=23165669` | 🟢 PASS | `profile` 200, `evolution` 200 |
| `/escola/ranking?inep=35011162` | 🟢 PASS | `info`/`indicators`/`ranking` 200 |
| `/escola/financeiro?inep=35245239` | 🟢 PASS | `finance` 200; `gestor/me` 401 (anônimo, esperado) |
| `/gestor` | 🟢 PASS | `gestor/me` 401 (card de login, esperado) |
| `/municipio/compare` | 🟢 PASS | — |
| `/municipio/perfil?ibge=2307304` | 🟢 PASS | `network/profile` 200 |
| `/cluster/geotag` | 🟢 PASS | `regions`/`presets`/`columns`/`years` 200 |
| `/chat/censo` | 🟢 PASS | — |
| `/chat/historico` | 🟢 PASS | — ("Sessão não encontrada", esperado anônimo) |
| `/config` | 🟢 PASS | — (card de admin, esperado) |

As 14 rodadas: **0 exceções, 0 erros de console, 0 falhas de rede** (fora as
duas 401 de `gestor/me`, esperadas). As rotas com query string que em rodadas
antigas davam **500 do nginx** (`ranking`, `financeiro`, `municipio/perfil`)
agora **PASS** — o nginx do container atual não reproduz o `try_files` antigo.

### Fluxo de mapa (regressão histórica de tiles)

| Verificação | Resultado |
|---|---|
| `/municipio/compare?codigo_ibge=2307304` — `.leaflet-container` | 🟢 1 |
| Tiles OSM | 🟢 8/8 `complete` e `naturalWidth>0`, 0 `.leaflet-tile-error` |
| Hosts de tile | 🟢 `a/b/c.tile.openstreetmap.org`, HTTP 200 |
| `/escola/panel?inep=35245239` — mapa | 🟢 1 container, 8/8 tiles OK |

### Achado aberto (pré-existente — não é regressão) → **resolvido no PR #201**

Na `/municipio/compare?codigo_ibge=…` (com dados/mapa) o Chrome registrava
**4 rejeições de promise não tratadas** cujo motivo é a **string de um rótulo
de etapa** (`"Infantil"`), **sem stack**. Não derrubava a página: gráficos, mapa
e tiles renderizam; 0 erros de console do app; API 200. Reproduzia em todas as
execuções; **não** aparecia em `/municipio/perfil` nem `/escola/panel`. A origem
é a camada de gráficos (Carbon Charts, `tooltip.customHTML`/rótulos de etapa) —
**não** há `throw`/`reject` em `src/features/network-compare`. **Não
relacionado a #136/#160** (frontend inalterado há 6 dias). Rastreado na
**issue #200**.

**Causa raiz** (medida via CDP `setPauseOnExceptions` + source maps): o Radar
do `@carbon/charts` 1.22.18 anima os rótulos do eixo com
`transition(...).end().finally(...)`; `.end()` **rejeita com o datum** (string,
ex.: "Infantil") quando a transição é interrompida por um novo update, e o
`.finally()` do Carbon **não trata** a rejeição. Interrupções vinham do wrapper
app (`RadarChart.svelte`) que re-renderizava o Carbon com options idênticas
(ResizeObserver + `$effect`).

**Fix (PR #201, merge `9c26dcc`)**: no wrapper — `syncSize`/`$effect` só
re-atribuem `chartOptions` quando o conteúdo muda (fim do churn) + guarda de
`unhandledrejection` para reasons **string** enquanto o radar está montado
(erros `Error` continuam a propagar).

### Rodada 2026-10-09 — validação do fix #200 (PR #201)

Alvo `http://localhost:8080` (imagem local reconstruída + deploys
`frontend`), driver CDP (`node:22-slim --network host`), rota
`/municipio/compare?codigo_ibge=2307304`.

| Verificação | Resultado |
|---|---|
| Rejeições `Runtime.exceptionThrown` no load | 🟢 0 (eram 4× `"Infantil"`) |
| Rejeições após troca de modo do radar (Perfil → Volume) | 🟢 0 |
| Radar renderizado (grupo de modo + `h2` + paths SVG) | 🟢 `246` paths |
| Toggle de modo (Perfil → Volume) | 🟢 `aria-checked` muda |
| Testes unitários (charts + network-compare + shared/ui) | 🟢 41/41 (9 no charts, 3 novos do guard) |
| `vite build` | 🟢 OK |
| Deploy | 🟢 `rex prepare` + `deploy_frontend_dev` + imagem local `frontend` |

### Rodada 2026-10-10 — Busca Escola: toast espúrio "Nenhuma escola encontrada." na carga (fix, PR #203)

**Relato do developer**: "a busca (busca escola) não retorna (vazia)" com a
imagem docker em `localhost:8080`.

**Diagnóstico** (smoke CDP `:9222`, drivers próprios `smoke_busca*.mjs`,
alvo `http://localhost:8080`): a **busca funcionava** (nome e município →
`/api/school/search/pageable` 200, cards renderizados). O "vazio" era um
**toast espúrio na carga** da página: `createPaginationStore` emite um ciclo
loading→pronto na **montagem** (sem filtro o adaptador devolve
`meta.total_entries = 0` **sem chamar a API**), e o `notifySearchOutcome` da
página convertia `total === 0` em toast "Nenhuma escola encontrada." — mesmo
sem o usuário buscar nada. Buscas reais sem correspondência (ex.: "E.M.",
prefixo ausente da base local) retornam vazio **consistentemente** (curl =
browser = `[]`), não é bug.

**Fix (PR #203, merge `2f4e43d`)**: guard `if (!hasSearched) return;` no topo de
`notifySearchOutcome` (`SchoolSearchPageRx.svelte`) — só notifica o resultado
de busca iniciada pelo usuário. Teste de regressão novo em
`SchoolSearchPageRx.test.js` (montagem sem busca → 0 toasts; comprovado que
falha sem o guard).

| Verificação (imagem local `frontend` reconstruída, `localhost:8080`) | Resultado |
|---|---|
| Carga fresca de `/escola/search` — toast espúrio | 🟢 **ausente** (`toasts=[]`); corpo: "Informe um nome de escola ou município para começar" |
| Busca por nome (`CENTRO EDUCACIONAL DE UBATUBA`) | 🟢 `/api/school/search/pageable?escola=…&page=1&per_page=10` 200; toast "Busca concluída: 1 escola encontrada" |
| Busca por município (`Ubatuba`) | 🟢 200, resultados |
| Busca real vazia (`E.M.`) | 🟢 200 vazio; toast legítimo "Nenhuma escola encontrada." (usuário buscou) |
| Autocomplete (`freire`) vs app | 🟢 sinais preservados |
| Testes unitários da feature (schools) | 🟢 21 arquivos / 99 testes (incl. regressão nova) |
| Deploy | 🟢 imagem local `frontend` reconstruída + `rex prepare` + `deploy_frontend_dev` |

### Rodada 2026-10-10 — Telemetria de sessão: tracker no navegador (feat, etapa 2)

**Objetivo**: certificar ponta a ponta a **etapa 2** da telemetria de sessão —
o rastreador no navegador (Svelte/JS) que envia eventos a
`POST /api/session/events` e os persiste em `clean.event_store` pela allowlist
do backend (etapa 1, PR #204). Regra de privacidade: **nunca o texto digitado**.

Driver próprio sobre o CDP do Chrome (`:9222`, `Network.setCacheDisabled`),
alvo `http://ubatexu.lan:8080/escola/search` (deploy via `redeploy` +
`deploy_frontend_dev`).

| Verificação | Resultado |
|---|---|
| App monta com o bundle novo (`index-CKSXScwW.js` contém `api/session/events`) | 🟢 |
| Busca por "Ubatuba" + navegação SPA (`pushState`/`popstate` → `/about`) | 🟢 input/btn/results OK, rota muda |
| Flush no unload (`pagehide` → `sendBeacon`) | 🟢 1 `POST /api/session/events` |
| Corpo do lote | 🟢 3 eventos: `navigate /escola/search`, `schools:search` `{q_len:7,result_count:5}`, `navigate /about` |
| **Texto digitado no lote** | 🟢 **ausente** (nunca "Ubatuba"; allowlist corta no cliente e no servidor) |
| Exceções / erros de console | 🟢 0 |
| Persistência em `clean.event_store` (BD do backend) | 🟢 `source=frontend`, `session_id` único, payload só com as chaves permitidas |
| Sessão do request de API (`Middleware::Session`) | 🟢 `session.request` com o **mesmo** `session_id` dos eventos `frontend` |
| Testes unitários (tracker + mapeamento + gestor + busca) | 🟢 41/41 |
| `vite build` | 🟢 OK |
| Deploy | 🟢 `rex prepare` + `deploy_frontend_dev` + imagem local `frontend` |

> **Nota de driver**: um `#app` vazio na primeira tentativa era **cache de
> service worker** de sessão anterior, não regressão — resolvido com
> `Network.setCacheDisabled: true` e espera pela montagem. Sem isso o probe
> dá falso negativo (nenhuma request `/api/`, nenhuma exceção).
