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

### Rodada 2026-10-11 — Painel de Administração: telemetria de acesso (feat)

**Objetivo**: certificar ponta a ponta o **Painel de Administração** (`/admin`),
que lê a telemetria de sessão (etapas 1+2) e apresenta KPIs agregados do fluxo
de acesso: logins de gestores (6/12/24 h), sessões ativas (logadas/anônimas),
buscas, eventos, série temporal e rotas mais acessadas. Privacidade: **só
agregados** — sem IP, texto de busca ou sessão individual.

Driver próprio sobre o CDP do Chrome (`:9222`, `Network.setCacheDisabled`),
alvo `http://ubatexu.lan:8080/admin` (deploy via `rex prepare` +
`deploy_backend_dev` + `deploy_frontend_dev`). Sessão obtida por
`POST /api/gestor/login` e injetada em `localStorage` antes do carregamento.

| Verificação | Resultado |
|---|---|
| SPA monta e roteia `/admin` ("Painel de Administração", nav "Administração") | 🟢 |
| Guard de admin (`GET /api/gestor/me` antes do overview) | 🟢 200, `access_role=admin` |
| `GET /api/admin/telemetry/overview?window=24h` | 🟢 200 |
| KPIs renderizados (logins 6/12/24 h; sessões ativas/logadas/anônimas; buscas; eventos) | 🟢 `0/1/1`; `11/3/8`; `3`; `49` |
| Série temporal (gráfico Carbon `LineChart`, granularidade por hora) | 🟢 eixo 09:00→09:00, 24 buckets |
| Rotas mais acessadas (com volume e `%`) | 🟢 `/escola/search 44`, `/about 22`, `/escola/panel 11`, … |
| Seletor de janela (24 h → 7 dias recalcula) | 🟢 nova request `window=7d` |
| Atualização manual ("Atualizar agora") / auto-refresh 30 s | 🟢 botão presente; `REFRESH_MS=30000` |
| Requests `/api/` com status ≥ 400 | 🟢 0 |
| `Runtime.exceptionThrown` | 🟢 0 |
| Teste de unidade da página (gsap/Carbon mockados) | 🟢 4/4 |
| Suíte frontend completa | 🟢 72/76 arquivos (4 falhas pré-existentes multipart `gestor*Api`, fora do admin) |
| `vite build` | 🟢 1053 módulos transformados |
| Teste de API do backend (`t/04-api/admin/telemetry.t`) | 🟢 401/403/200, janela inválida 400 |
| Deploy | 🟢 `rex prepare` + `deploy_backend_dev` + `deploy_frontend_dev` |

> **Nota**: a página já existia na janela visível (Chrome x11 `:9223`) para
> validação visual. Nenhuma exceção e nenhuma request falhada em ambas as
> janelas (24 h e 7 d).

### Rodada 2026-10-11 — Listas com autoinscrição por QR (feat, issue #208)

**Objetivo**: certificar ponta a ponta a **Fase 0** das listas nomeadas com QR
para autoinscrição de contatos: migrations (`clean.canal_listas`,
`canal_qrcodes`, `canal_lista_membros`, `canal_inscricoes`), API de gestão
(autenticada) e face pública anônima `GET/POST /api/canais/inscricao/:token`,
mais a SPA (gestão em `/gestor/listas` e página pública `/inscricao/:token`).

Driver próprio sobre o CDP do Chrome (`:9222`), alvo `http://ubatexu.lan:8080`.
Deploy: `rex prepare` + `deploy_db_dev` + `deploy_backend_dev` +
`deploy_frontend_dev`. A face pública exige a flag
`canais.inscricao.enabled` (por omissão **desligada → 404**); habilitada na BD
de dev (`app_config.items`) com `public_base_url=http://ubatexu.lan:8080`.

| Verificação | Resultado |
|---|---|
| Migração aplicada (`database.edumaps`, `edumaps_dev`) | 🟢 4 tabelas + `sqitch.changes` com `canal_listas_autoinscricao` |
| `sqitch verify` (banco limpo via `ci_db.sh`) | 🟢 |
| `GET /api/canais/inscricao/:token` | 🟢 200 `{lista_nome, escola_nome, canal, campos, expira_em}` |
| Token inválido | 🟢 404 |
| `POST` válido | 🟢 201 `{ok:1}` |
| `POST` telefone repetido (normalizado) | 🟢 201 `{duplicado:1}` — **sem** sobrescrever: 1 contato, 2 inscrições (`duplicado_de`, `conflito`), 1 membro, `usos` incrementado |
| Honeypot `_hp` preenchido | 🟢 201 falso, **nada gravado** |
| Consentimento ausente | 🟢 400 |
| Telefone < 8 dígitos | 🟢 400 |
| Rate limit (token+IP, 10/60 s) | 🟢 429 após o limite |
| `GET /api/gestor/:inep/canais/listas` sem sessão | 🟢 401 |
| SPA `/inscricao/:token` (formulário) | 🟢 lista + escola renderizam; preencher + consentir + submeter → "Inscrição confirmada!" |
| SPA `/privacidade` (link do consentimento) | 🟢 "Política de Privacidade" renderiza (página nova desta rodada) |
| Testes de unidade backend (`t/02-models/canal_listas.t` + `t/04-api/canais/`) | 🟢 3 arquivos / 30 testes |
| Suíte frontend completa | 🟢 82 arquivos / 463 testes |

> **Notas**: (1) o driver do plugin `opencode-chrome-devtools` **não estava
> conectado** — usou-se um cliente CDP próprio (mesmo padrão das rodadas
> 2026-09-28 e 2026-10-09). (2) A flag por omissão desligada é intencional
> (endpoint público inexistente até decisão do admin). (3) Dados de teste
> criados em dev: lista `E2E Coord 208` (escola de gestor id 2).

### Rodada 2026-10-11 — Confirmação de posse do telefone nas listas com QR (feat, issue #212)

**Objetivo**: certificar a Fase 1 (confirmação por Telegram) ponta a ponta em
dev (`http://ubatexu.lan:8080`), com a lista `E2E 212` (exige confirmação,
escola 35038751) e um bot público **fictício** em modo webhook (token falso:
as respostas do bot falham, o que é esperado — o fluxo de confirmação não
depende delas). Driver CDP próprio em Perl (`Mojo::UserAgent` websocket),
Chrome `:9222`. As mensagens do Telegram foram simuladas com POST no webhook
público com o `secret_token`.

| Verificação | Resultado |
|---|---|
| Migração `canal_confirmacao_listas` em `database.edumaps` | 🟢 |
| `POST` inscrição em lista que exige | 🟢 201 com `confirmacao {ref, estado:"pendente", canais:[telegram url t.me/<bot>?start=<ref>]}` |
| Webhook sem `X-Telegram-Bot-Api-Secret-Token` | 🟢 401 |
| `/start <ref>` + contato próprio com o número da inscrição | 🟢 `GET /confirmacao/:ref` → `confirmado`; membro `confirmado_via=telegram`, `telegram_chat_id` gravado, `validado=true` |
| Contato de terceiro (`user_id` ≠ `from.id`) | 🟢 recusado; continua `pendente` |
| Contato com número divergente | 🟢 `conflito=true` na inscrição; membro não confirmado; nada apagado |
| Respostas do bot com token fictício | 🟢 registradas como `failed` em `canal_mensagens` (operação `confirmacao`) |
| SPA `/inscricao/:token` → passo 2 "Confirme seu telefone" com link do Telegram | 🟢 |
| Confirmação simulada → página mostra "Telefone confirmado!" **sem recarregar** (polling) | 🟢 |
| Backend (65 arquivos / 428 testes; 6 pré-falhos idênticos no `main`) | 🟢 |
| Frontend completo | 🟢 83 arquivos / 511 testes |

> **Notas**: (1) o caminho com o app real do Telegram (bot criado no
> @BotFather, modo polling) e o WhatsApp Cloud (template aprovado) não foram
> exercitados — dependem de credenciais externas; ficam para a validação do
> developer. (2) Achado de infra corrigido nesta rodada: deploys do Rex sem
> `EDUMAPS_CONFIG_MASTER_KEY` na shell gravavam a chave **vazia** nas units
> (segredos ilegíveis); agora o Rexfile aborta. Dev usa uma chave própria,
> fora do repositório.

### Rodada 2026-10-12 — E-mail e LGPD nas listas com QR (feat, issue #214)

**Objetivo**: certificar a Fase 2 em dev (`http://ubatexu.lan:8080`) com a lista
`E2E 214` (coleta `ambos`, exige confirmação, QR com limite 5 e validade) e a
versão **1.1** do consentimento (cita e-mail) publicada pelo modelo de admin.
Driver CDP próprio em Perl (Chrome `:9222`).

| Verificação | Resultado |
|---|---|
| Migração `canal_email_lgpd` em `database.edumaps`; 1.0 vigente no seed | 🟢 |
| Publicação da 1.1 (rascunho → vigente; 1.0 arquivada) | 🟢 |
| `GET` inscrição: `campos`/`obrigatorios` = nome, telefone, e-mail; consentimento 1.1 | 🟢 |
| `POST` com `consentimento_versao` 1.0 (desatualizada) | 🟢 409 |
| `POST` sem e-mail (coleta `ambos`) / e-mail inválido | 🟢 400 / 400 |
| `POST` válido | 🟢 201 com `exclusao_url` e `contatos` (telefone e e-mail pendentes) |
| SPA: campo e-mail + termo 1.1 visível → inscrição → link "Remover meus dados" | 🟢 |
| SPA `/privacidade/exclusao/:token` → confirmar → "Seus dados foram removidos"; recarregar → já excluído | 🟢 |
| Varredura de PII no banco (contatos, inscrições, membros, refs, confirmações, mensagens) após exclusão pelo titular | 🟢 0 ocorrências |
| Remoção pelo gestor (modelo) com motivo; varredura de PII | 🟢 0 ocorrências; auditoria `gestor` com motivo |
| Auditoria `canal_exclusoes` sem PII (titular, gestor) | 🟢 |
| Retenção avulsa: 3 linhas de resumo (`cod_inep=0`) mesmo com zero | 🟢 |
| Inscrições com `consentimento_hash` e `anonimizado_em` | 🟢 2/2 |
| Backend (74 arquivos / 476 testes; 6 pré-falhos idênticos no `main`) | 🟢 |
| Frontend completo | 🟢 88 arquivos / 611 testes |

> **Notas**: (1) envio real de código por e-mail não exercitado — não há SMTP
> em dev; coberto por testes com SMTP simulado. (2) A versão 1.1 do
> consentimento fica publicada em dev (pré-requisito para listas com e-mail).

### Rodada 2026-10-12 — Envio por e-mail para listas com QR (feat, issue #216)

**Objetivo**: certificar a Fase 3 em dev (`http://ubatexu.lan:8080`) com envio
**real por SMTP**: um Mailpit temporário no `ubaxala` (`axllent/mailpit:v1.21.0`,
só `127.0.0.1`) recebe os e-mails do backend por um túnel SSH reverso
(`backend.edumaps:127.0.0.1:1025` → Mailpit); `canais.email.*` de dev apontou
para ele só durante a rodada. Listas `E2E 216 A` e `B` (coleta e-mail, sem
exigência), 4 inscritos pela API pública (Carla nas duas listas), sessões
temporárias de gestor e admin. Driver CDP próprio em Perl (Chrome `:9222`).

| Verificação | Resultado |
|---|---|
| Migração `canal_envios` em `database.edumaps` | 🟢 |
| Limites: SMTP disponível, saldo 500/500 | 🟢 |
| Lista dinâmica A+B: prévia com 4 destinatários (Carla deduplicada), amostra mascarada | 🟢 |
| Rascunho → prévia (rodapé + estimativa 3) → teste (`[Teste]` no Mailpit) | 🟢 |
| Disparo imediato → job `canais_envio` → **concluído, 3 enviados, 0 falhas** | 🟢 |
| Cada e-mail: rodapé com lista e link pessoal; `List-Unsubscribe` = link, `List-Unsubscribe-Post: One-Click`, `Precedence: bulk` | 🟢 3/3 |
| Destinatários mascarados na API | 🟢 |
| SPA `/privacidade/sair/:token` pelo link do e-mail → "Pronto, você saiu" → recarregar → "já tinha saído" | 🟢 |
| One-Click (RFC 8058, form) | 🟢 200 |
| Selo de opt-out só em quem saiu; contador de saídas do envio = 2 | 🟢 |
| Envio pela lista dinâmica: 2 opt-out + 1 duplicado ignorados; só Carla (uma vez) e Davi receberam | 🟢 |
| Reinscrição pelo QR desfaz o opt-out (`n_optouts` 2 → 1) | 🟢 |
| Funil: acessos, inscrições, saídas, `confirmados` null (lista sem exigência), série diária completa | 🟢 |
| Agendado → admin suspende (201) → envio `suspenso`; disparo com escola suspensa → 409 `escola_suspensa` | 🟢 |
| Reativar → envio volta a `agendado` (não antecipa); cancelar | 🟢 |
| Cota da escola em 1 → disparo → 409 `cota_insuficiente` (saldo 0) | 🟢 |
| Remoção pelo gestor → varredura de PII: destinatários de envio só com hash (sem e-mail/contato), mensagens/contatos/inscrições sem resto | 🟢 0 ocorrências |
| Telas: `EnviosPage`, detalhe, `SegmentosPage`, `ListasPage` (+ aba Funil), painel Envios do admin no `/config` | 🟢 |
| Backend 81 arquivos / 508 testes (6 pré-falhos idênticos no `main`); frontend 96 / 718 | 🟢 |

> **Achados corrigidos na rodada**: (1) faltava espaço entre o nome da lista e
> "da escola" na página de saída; (2) "1 saíram dos envios" → "1 saiu".
> **Comportamento documentado**: a taxa acesso → inscrição pode passar de 100%
> (inscrições sem abrir a página, ou várias a partir de um acesso).
> **Não exercitado**: provedor SMTP real (só captura), WhatsApp/Telegram no
> envio (fora do escopo).

### Rodada 2026-10-12 — Assistente de Relatório (feat, issue #219, Fase 1)

**Objetivo**: certificar a Fase 1 em dev (`http://ubatexu.lan:8080`) de ponta
a ponta: Perl → Minion (fila `analytics`) → R (`/report`, `edumapsAnalytics`)
→ eduBR (`2dc9af9`, persona pesquisadora, role `edumaps_leitor`) → **LLM real
do painel (Gemini)** → tela `/gestor/relatorios`. Sessão temporária do gestor
da escola 35038751 (Ubatuba/SP). Driver CDP próprio em Perl (Chrome `:9222`).

| Verificação | Resultado |
|---|---|
| Sem sessão → 401 | 🟢 |
| Recorte-padrão: escola → Ubatuba (SP, SE) | 🟢 |
| Temas do nível UF = IDEB, redes, professores, gestores | 🟢 |
| Escola de outro gestor → 400; tema fora do nível → 400 | 🟢 |
| `minha_escola` (escola) | 🟢 ~5 s, 6 seções |
| `ideb_territorio` (município, anos iniciais) | 🟢 ~7 s |
| `docentes_territorio` (UF BA) | 🟢 ~5–9 s |
| `gestores_territorio` (região S) | 🟢 ~11–13 s |
| `tendencia_ideb` (região NE, anos finais) | 🟢 ~6–7 s |
| Texto redigido pelo Gemini (`rastreio.llm = ok`) em todos | 🟢 |
| Pedido repetido servido do cache (~1,6 s, `cache_hit`) | 🟢 |
| Sem PII nos relatórios (endereço, telefone, CEP, CNPJ, e-mail) | 🟢 |
| Tela: recorte, temas, opções, "Gerar relatório" → seções + fontes | 🟢 |
| Backend 103 / 676 (só falhas antigas); R 28 arquivos / 1085 asserções; frontend 101 / 779 | 🟢 |

> **Achados corrigidos na rodada**:
> 1. o texto do LLM usava ponto decimal e citava o nome interno da
>    ferramenta: os dados para o LLM passaram a sair arredondados pelo formato
>    e sem nome de ferramenta, e o prompt pede padrão brasileiro;
> 2. faltava espaço nos separadores "·" do cabeçalho e das fontes;
> 3. `censo-dictionary.R` estava fora do `Collate` e quebrou a reinstalação do
>    pacote no deploy.
>
> **Observações**:
> - logo depois de um deploy do `analytic`, os jobs que pegam o reinício do
>   serviço R falham (não há nova tentativa);
> - a chave do cache de relatórios não inclui a versão do prompt nem do
>   pacote, então uma mudança de texto só aparece depois de 24 h ou de limpar
>   o cache;
> - logo após o deploy do frontend, o service worker pode servir o bundle
>   antigo (tela em branco até recarregar).

### Rodada 2026-10-12 — Assistente de Relatório, Fase 2 (feat, issue #219)

**Objetivo:** certificar os temas de aprofundamento em dev
(`http://ubatexu.lan:8080`), com o **Gemini real**, gestor da escola 35038751
(Ubatuba/SP) e sessão temporária. Driver CDP próprio em Perl, um caso por aba.

| Verificação | Resultado |
|---|---|
| Catálogo: `ideb_escolas` (município, profunda); temas da escola (minha escola, histórico, parecidas) | 🟢 |
| `ideb_escolas` Ubatuba (anos finais): 11 escolas com nota, mediana 4,7, **"7ª de 11"**, linha da escola destacada | 🟢 ~6–8 s |
| `infraestrutura_ideb` BA e SP: seção de associações (10 itens urbano/rural), 2 tabelas técnicas recolhidas, aviso "associação" | 🟢 ~6 s |
| `historico_escola`: gráfico de linhas, série, scores | 🟢 ~5 s |
| `escolas_parecidas`: **10 escolas distintas**; "Todas as etapas" por padrão | 🟢 ~11 s |
| Regressão: `ideb_territorio` (Fase 1) segue OK | 🟢 |
| Avisos e fontes sem nome interno de ferramenta; sem PII; texto da regressão fala em associação | 🟢 |
| Tela: tema certo por nível, associações, "Associação não é causa" no topo, `<details>` técnicos, "★ sua escola" | 🟢 11/11 |
| R 29 / 1374 asserções; frontend 101 / 795; Perl dos relatórios 2 / 23 | 🟢 |

> **Achados corrigidos na rodada:**
> 1. **Pilha estourando no Plumber.** O `escolas_similares` estourava a pilha
>    de C do R (8 MB) dentro do Plumber; agora a pilha é de 64 MB, via
>    `LimitSTACK` na unit e `ulimits` no compose. A integração fora do
>    Plumber não reproduzia o erro.
> 2. **Etapa obrigatória sem padrão.** A etapa era sempre obrigatória e
>    enviava "anos iniciais" a uma escola que não os oferece. O catálogo passou
>    a expor `padroes`, e a etapa sem padrão vira "Todas as etapas".
> 3. **Nomes internos na tela.** Os avisos e o rodapé de fontes mostravam
>    nomes internos de ferramenta; foram removidos.
> 4. **Menos escolas parecidas que o pedido.** A ferramenta devolvia 7 escolas
>    distintas para `n = 10`; agora pede 20 linhas e fica com 10 escolas.
> 5. **Cache entre versões.** Uma mudança do pacote R só aparecia depois de
>    24 h de cache. Agora `edumapsAnalytics` 0.2.0 e `analytics_source_version`
>    sobem juntos.
>
> **Nota do driver:** o Mojo limita mensagens de WebSocket a 256 KB e
> derrubava as capturas grandes; use `max_websocket_size`.
