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
