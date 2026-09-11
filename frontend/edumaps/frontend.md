# Frontend EduMaps — Arquitetura

> Documento de arquitetura do frontend **atual** (`frontend/edumaps/`),
> orientado a features (Svelte 5 + Vite). Serve de base para um inventário
> completo e futuro da aplicação.

## 1. Panorama e stack

Existem **dois** aplicativos sob `frontend/`:

| App | Situação | Stack |
|-----|----------|-------|
| `frontend/map_app/` | **Legado** — não evolui mais; mantido apenas como referência histórica | Svelte 4 (leitura), componentes em `src/lib/`, stores clássicas |
| `frontend/edumaps/` | **Atual** — SPA Vite, em evolução ativa | Svelte 5 (runes), Tailwind, Leaflet, RxJS, MSW, PWA |

O restante deste documento descreve **apenas o `edumaps`**.

### Dependências principais (`frontend/edumaps/package.json`)

| Pacote | Versão | Papel |
|--------|--------|-------|
| `svelte` | ^5.0.0 | Motor de UI (runes) |
| `vite` | ^6.4.0 | Bundler/serve dev |
| `@sveltejs/vite-plugin-svelte` | ^6.0.0 | Suporte Svelte no Vite |
| `tailwindcss` / `@tailwindcss/vite` | ^4.0.0 | CSS utilitário |
| `leaflet` / `leaflet.markercluster` | ^1.9.4 / ^1.5.3 | Mapas |
| `rxjs` | ^7.8.2 | Stores reativas (camada de estado) |
| `msw` | ^2.15.0 | Mock Service Worker (testes/dev) |
| `vitest` (+ jsdom, Testing Library) | ^4.1.0 | Testes unitários/componentes |
| `@carbon/charts-svelte` | ^1.22.18 | Gráficos (charts) |
| `vite-plugin-pwa` | ^0.21.0 | PWA + workbox |
| `concurrently` | ^10.0.3 | Orquestra o `dev` multiprocesso |

### Scripts

```bash
cd frontend/edumaps
npm run dev          # 3 processos: Vite (5173) + Morbo (backend :3000) + watcher R/Plumber
npm run build        # vite build
npm run test:run     # vitest run
npm run test:coverage
```

O `dev` conecta a porta 5173 ao backend `localhost:3000` via proxy do Vite
(ver seção 6.2) e re-executa o Plumber da análise quando `.R` muda.

---

## 2. Arquitetura orientada a features

A API espera uma organização por **camadas** com fluxo de dependência único:
`app` → `shared` → `features`. Uma feature **não importa outra feature**;
comunicação cross-feature acontece só via `EventBus` (barramento global).

```
src/
├── app/           shell, roteamento, lista de rotas
│   ├── App.svelte
│   ├── router.svelte.js       rotas reativas (runes) + action `link`
│   └── routes.js              tabela estática de rotas
├── shared/        tudo reutilizável, genérico, sem noção de domínio
│   ├── api/client.js          wrapper fetch (apiClient, ApiError)
│   ├── events/                EventBus + middlewares
│   ├── stores/                engines genéricos (RxJS)
│   ├── ui/components/         componentes Svelte genéricos
│   ├── utils/                 format(), eventDispatcher (legado)
│   └── constants/             eventos cross-feature
├── features/      recursos de domínio (um dir por feature)
│   ├── schools/
│   ├── map/
│   └── about/
└── mocks/         handlers MSW + bootstrap browser/server
```

### Convenção de estrutura por feature

Cada `src/features/<feature>/` pode conter:

| Subpasta | Para quê serve |
|----------|----------------|
| `pages/` | Páginas roteáveis (Svelte) |
| `components/` | Componentes específicos da feature (aceita subgrupos `panel/`, `icons/`) |
| `api/` | Wrappers de fetch — **única camada que importa `apiClient`** |
| `stores/` | Stores RxJS da feature (adaptadores do engine shared) |
| `utils/` | Funções de transformação de dados |
| `constants/` | Eventos/labels da feature (events.js, indicators.js) |
| `mocks/` | Handlers MSW + fixtures da feature |
| `index.js` | Barrel: exporta páginas/componentes públicos da feature |

### Features atuais

| Feature | `pages/` | `components/` | `api/` | `stores/` | Observações |
|---------|----------|---------------|--------|-----------|-------------|
| `schools` | SchoolSearchPage, SchoolSearchPageRx, SchoolRankingPage, SchoolPanelPage, SchoolPayrollPage | SchoolCard, SchoolList, SchoolReactiveList, SchoolSearchForm, SchoolRanking, SchoolPayrollTable, `panel/*` (5), `icons/*` (2) | schoolApi, rankingApi, autocompleteApi | schoolPaginationStore | A mais completa; caso de referência da convenção |
| `map`   | — | LeafletMap | — | — | `context.js` (Svelte context p/ Leaflet), `icons.js` (vazio) |
| `about` | AboutPage | — | — | — | Feature mínima de exemplo |

### Barrels (`index.js`)

- `features/schools/index.js` exporta as 5 páginas + `SchoolRanking`.
- `features/map/index.js` exporta `LeafletMap` e `useMapContext`.
- `features/about/index.js` exporta só `AboutPage`.

---

## 3. Roteamento

Roteador **caseiro** baseado em runes, sem dependência externa
(`svelte-routing` não tem compatibilidade comprovada com Svelte 5).

### `src/app/router.svelte.js`

- Classe `Router` com **`path = $state(window.location.pathname)`** — estado
  reativo numa classe JS pura.
- Construtor escuta `popstate`; `navigate(to)` usa `history.pushState` e
  atualiza o `$state`.
- Exporta o singleton `router` e a **action** `link` (intercepta `<a>`:
  ignora cliques modificados, hrefs externos; senão `preventDefault` + navigate).

```js
export class Router {
  path = $state(window.location.pathname);
  // ...
}
export const router = new Router();
export function link(node) { /* action */ }
```

### `src/app/routes.js`

Tabela estática (sem parâmetros/nesting) + matcher:

| Rota | Componente |
|------|------------|
| `/about` | AboutPage |
| `/escola/ranking` | SchoolRankingPage |
| `/escola/payroll` | SchoolPayrollPage |
| `/escola/panel` | SchoolPanelPage |
| `/escola/search` | **SchoolSearchPageRx** (a "Rx"; a clássica não é roteada) |

`matchRoute(pathname)` → `routes.find(...) ?? null`.

### `src/app/App.svelte`

- `$effect` redireciona `/` → `/about`.
- `let match = $derived(matchRoute(router.path))` — reatividade de rota.
- `<match.component />` — componente dinâmico.
- Monta `<Toast />` globalmente e o nav com `use:link`.

---

## 4. Componentes Svelte

Todos os componentes usam **runes do Svelte 5** (sem `svelte:legacy`), exceto
`PaginationControls.svelte` (órfão, sintaxe Svelte 4 — ver seção 10).

Runes em uso:

| Rune | Onde é usada |
|------|--------------|
| `$props()` | Todos os componentes (ex.: `SchoolCard`, `SchoolMap`) |
| `$bindable()` | `InputAutocomplete` (`value`) |
| `$state()` | `SchoolSearchPage`, `LeafletMap`, `SchoolMap`, `DataTable`, classes (`Router`) |
| `$derived` / `$derived.by()` | `SchoolCard`, `SchoolSummary`, `Icon`, `DataTable`, `App` |
| `$effect()` | assinatura RXJS com cleanup, pós-monta imperativo, ciclo de vida |
| `{#snippet}` / `{@render}` | `PageableList`, `SchoolReactiveList`, `SchoolSearchForm`, `LeafletMap` |

### 4.1 Inventário `shared/ui/components`

| Componente | Responsabilidade | Props principais | Slots/snippets | Quem usa |
|------------|------------------|------------------|----------------|----------|
| `DataTable.svelte` | Tabela genérica com ordenação (cycle asc/desc/limpar), caption, footer, `col.render` (função **ou** snippet) | `columns` (`{key,label,sortable?,render?}`), `data`, `caption`, `footer`, `rowKey` | `render` por coluna | `SchoolPayrollTable` |
| `InputAutocomplete.svelte` | Combobox com debounce + `switchMap` (RXJS interno), acessível (`aria-*`), seleção via `onmousedown` | `value` (bindable), `fetchSuggestions`, `minLength=3`, `debounceMs=300`, callbacks `onQueryChange/onSelect/onClear/onError`, snippet `option` | `option` | `SchoolSearchForm` |
| `Toast.svelte` | Container de toasts; assina `toast$` via `$effect`; stack top-right, `in:fly/out:fade`, ícone por tipo | — (lê store global) | — | `App.svelte` |
| `PageableList.svelte` | Lista paginável "tudo-em-um": loading/erro/vazio/paginação embutida (controles só se `meta.total_pages>1`) | `items`, `meta`, `loading`, `error`, `hasSearched`, `onPageChange`, `onPerPageChange`, `perPageOptions` | `children` (por item), `loadingSnippet`, `emptySnippet`, `errorSnippet` | `SchoolReactiveList` |
| `PaginationControls.svelte` | Controles de paginação (legado Svelte 4) | `pagination`, `perPageOptions`, callbacks | — | **nenhum** (órfão) |

> `shared/ui/index.js` só exporta `DataTable`; os demais são importados por
> path (`@/shared/ui/components/...`).

### 4.2 Inventário `features/schools/components`

| Componente | Responsabilidade | Notas |
|------------|------------------|-------|
| `SchoolCard.svelte` | Cartão de escola (presentacional): INEP, endereço, chips de modalidade, links (tel/OSM/WhatsApp), links internos ranking/panel | usa `formatPhone`, `$derived` |
| `SchoolList.svelte` | Grid simples de `SchoolCard` (4 estados: loading/erro/sem busca/vazio) | **sem paginação** — versão da página clássica |
| `SchoolReactiveList.svelte` | Envolve `PageableList` com os 4 snippets, renderizando `SchoolCard` | versão **paginada** p/ página Rx; nome "Reactive" vem do parceria com o store RxJS |
| `SchoolSearchForm.svelte` | Form de busca (2× `InputAutocomplete`: escola + município); `canSubmit=$derived` (≥3 chars); emite EventBus **e** chama `onSearch` | documenta por que emite e chama prop |
| `SchoolRanking.svelte` | Busca indicadores e ranking por INEP; selos pos/percentil; reseleção de indicador/rede | carrega com `onMount`, estado `$state` |
| `SchoolPayrollTable.svelte` | Wrapper de `DataTable` com columns formatadas (carga `h`, moeda pt-BR), `rowKey=cpf` | |

#### Subgrupo `panel/` (painel escolar)

`SchoolPanel.svelte` é o *composition root*: header com `SchoolSummary`,
seções `TeachingStages`, `InfrastructureGrid`, `SchoolIndicator`, `SchoolMap`
(se lat/lng), `SimilarSchools`.

| Componente | Papel |
|------------|-------|
| `SchoolSummary.svelte` | badge de rede (cor por rede) + matrículas formatadas + porte `$derived` (small/medium/large) |
| `TeachingStages.svelte` | grid de ícones por etapa (ordem fixa `ETAPAS_ORDER`) |
| `InfrastructureGrid.svelte` | grid de ícones por item de infra (ordem fixa `INFRA_ORDER`) |
| `SchoolIndicator.svelte` | card de indicador com selo circular (`posicao/total/percentil`) |
| `SimilarSchools.svelte` | grid de escolas semelhantes (botões) |
| `SchoolMap.svelte` | wrapper de `LeafletMap`; `L.divIcon` customizado (SVG `ICONS.edumaps.svg`), layerGroup de similares, 2× `$effect` reativos, checkbox `showSimilar` |

#### Subgrupo `icons/`

- `Icon.svelte` — renderiza SVG do dicionário por `name`; props `name, size,
  active, showLabel`; tudo `$derived`; `active=false` sobrepõe "×" (acessível).
- `icon-data.js` — dicionário `ICONS` (SVGs 24×24) categorizados
  (`etapa/infra/porte/brand`) + `ETAPAS_ORDER`, `INFRA_ORDER`, `NETWORK_LABELS`.
  Princípio documentado: **inventário fixo, estado variável**.

---

## 5. JavaScript puro / services

### 5.1 `shared/api/client.js`

Wrapper fino sobre `fetch` (sem interceptor global):

- `request(path, { method, params, body, headers })`:
  - monta `new URL(path, window.location.origin)` — relativo, cai no proxy Vite;
  - filtra params vazios;
  - `!response.ok` → tenta `data.error` (envelope backend) senão `Erro ${status}`;
    lança `ApiError { status, url }`;
  - `204` → `null`; senão `response.json()`.
- Exporta `apiClient = { get, post }`.
- Convenção backend: erros em `{ "error": "..." }`.

### 5.2 APIs das features (`features/schools/api/`)

Única camada que importa `apiClient`. Nenhum componente chama `fetch` direto.

| Arquivo | Função | Endpoint |
|---------|--------|----------|
| `schoolApi.js` | `searchSchools` | `GET /api/school/search` (escola, municipio, limit) |
| | `getSchoolInfo` | `GET /api/school/:codInep/info` |
| | `getSchoolPayroll` | `GET /api/school/:codInep/payroll` (date `MM-YYYY`, default `10-2025`) |
| | `getSchoolPanelData` | `GET /api/school/:codInep/panel/info` |
| | `searchPaginatedSchools` | `GET /api/school/search/pageable` → `{ data, meta:{current_page,per_page,total_entries,total_pages} }` |
| `rankingApi.js` | `getAvailableIndicators` | `GET /api/school/:codInep/indicators` |
| | `getSchoolRanking` | `GET /api/school/:codInep/ranking` (indicador, rede) |
| `autocompleteApi.js` | `fetchSchoolSuggestions` | `GET /api/school/suggestions?q=` |
| | `fetchMunicipioSuggestions` | `GET /api/city/suggestions?q=` |

> Autocomplete: os endpoints estão marcados como "chute" (comentário no
> arquivo) — o contrato real do backend precisa ser confirmado.

### 5.3 Convenções

- `shared/constants/events.js` — só eventos **cross-feature** (`ERROR`,
  `TOAST_ADD`, `TOAST_REMOVE`).
- `features/schools/constants/events.js` — eventos da feature com namespace
  `schools/` (colisão evitada): `SEARCH`, `CLEAR`, `PAGE_CHANGE`,
  `PER_PAGE_CHANGE`; comandos `SCHOOL_COMMANDS.EXECUTE_SEARCH`.
- `shared/utils/format.js` — `formatPhone` (10/11 dígitos).
- `features/schools/utils/transformPanelData.js` — converte payload da API em
  `{ school, indicators, similarSchools }` (mapeia `tp_rede_local` →
  municipal/estadual/privada; infere etapas de `in_comum_*`).
- `shared/utils/eventDispatcher.js` — **legado/morto** (ver seção 10).

---

## 6. Stores, eventos e middlewares

### 6.1 Stores — camada de estado (RxJS)

Três paradigmas coexistem; a camada de **stores usa RxJS**, não runes nem
`writable`:

| Store | Arquivo | Mecanismo |
|-------|---------|-----------|
| Paginação (engine genérico) | `shared/stores/paginationStore.js` | `BehaviorSubject` params + `reloadTrigger$`, `debounceTime` + `distinctUntilChanged(deepEqual)`, `switchMap(fetchFn)`, `catchError`→`{error}`, `startWith(loading)`, `shareReplay(1)` |
| Toast | `shared/stores/toastStore.js` | `BehaviorSubject` `toast$`; `addToast/removeToast/clearAllToasts` |
| Ponte toast (adapter) | `shared/stores/toastEventBridge.js` | `registerToastEventBridge()` = `bus.on(EVENTS.TOAST_ADD, ...) → addToast()`; registrada em `main.js` |
| Paginação de escolas | `features/schools/stores/schoolPaginationStore.js` | adaptador: valida filtros (mín. 3 chars) e chama `createPaginationStore` |

API do `createPaginationStore`:
`{ result$, setSearch, goToPage, setPerPage, reload, getCurrentParams }`.
Regras: `setSearch` sempre reseta `page:1`; `goToPage` clampa >= 1;
`setPerPage` reseta página.

**Padrão de consumo em componentes** (ex.: `Toast.svelte`,
`SchoolSearchPageRx.svelte`):

```js
let result = $state(initial);
$effect(() => {
  const sub = store.result$.subscribe((v) => { result = v; });
  return () => sub.unsubscribe();   // cleanup
});
```

### 6.2 EventBus e middlewares

#### `shared/events/EventBus.js`

Barramento **callback-based** (não Observable — decisão documentada: não vazar
a "forma" de um stream reativo). Singleton `eventBus` (em testes prefere-se
`new EventBus()` isolado).

API pública:

| Método | Semântica |
|--------|-----------|
| `emit(type, payload, {source})` | dispara evento com `{id (uuid), type, payload, timestamp, source}` |
| `on(type, handler)` | registra; **retorna unsubscribe** |
| `once(type, handler)` | auto-desregistra antes de chamar |
| `onAny(handler)` | observa TODOS os eventos (telemetria) |
| `use(middleware)` | adiciona middleware ao pipeline; retorna função remover |
| `waitFor(type, {timeoutMs})` | Promise resolve no próximo evento; **rejeita** após timeout |
| `handle(command, handler)` | comando request/reply (handler único; duplicado lança) |
| `request(command, payload)` | executa handler do comando (sem handler lança) |
| `destroy()` | limpa; uso posterior lança erro |

Pipeline: middlewares em ordem de registro, cada um chama `next(event)` para
seguir (pode transformar o payload, bloquear ou só observar). Erro num
middleware interrompe só aquele evento. Dispatch: handlers do tipo + `onAny`,
sempre em `try/catch` (`#safeCall`) — handler quebrado não derruba os demais.

#### Inventário de middlewares

| Middleware | Arquivo | Efeito |
|------------|---------|--------|
| `logger` | `shared/events/middlewares/logger.js` | Em DEV: `console.debug("[event] <tipo>", payload, source)`; observa e repassa |

Registrado uma vez em `src/main.js`: `eventBus.use(logger)` —
**existe só este middleware hoje**.

### 6.3 Camada HTTP / proxy (middlewares de rede *inexistentes*)

- **Sem interceptor HTTP**: `client.js` é wrapper fino; não há retry, auth
  hook ou tratamento global de 401.
- **Proxy dev (Vite)**: `/api` → `http://localhost:3000`;
  `/analytic-api` → `http://analytic:8000` (rewrite remove o prefixo).
- **Caching prod**: PWA `NetworkFirst` para `^/api/` com `cacheName:
  edumaps-api`, expiration 300s (evita dado stale); service worker em
  `public/mockServiceWorker.js`.
- **Deploy**: `frontend/nginx.conf` (na raiz de `frontend/`, junto ao
  `Dockerfile`) serve o build estático e faz proxy para o backend.

---

## 7. Contexto e integração Leaflet

Leaflet é **imperativo** (não declarativo); a integração isola isso:

- `features/map/components/LeafletMap.svelte` — cria o mapa em `onMount`
  (`L.map(...).setView(center, zoom)` + `L.tileLayer` CartoDB light_all);
  publica `mapState = $state({ map, ready })`; destrói em `onDestroy`;
  render `{@render children?.()}` só quando `ready`.
- `features/map/context.js` — `provideMapContext`/`useMapContext` (chave
  `Symbol("leaflet-map")`); `useMapContext` lança fora de um `<LeafletMap>`.
- API imperativa exportada via `bind:this`: `getMap`, `fitBounds`, `setView`,
  `invalidateSize`.
- `panel/SchoolMap.svelte` consome o contexto + `L.divIcon`/`L.layerGroup` e
  reage com `$effect` (marcador principal, grupo de similares, fitBounds).

A abordagem reativa substitui o antigo `setInterval(checkMap, 50)` do legado.

---

## 8. Testes e mocks

### Stack de testes

Vitest + `jsdom` + `@testing-library/svelte` + `@testing-library/user-event`
+ **MSW** (`setupFiles: ./src/vitest-setup.js`). Cobertura v8 em
`src/features/**/*.{js,svelte}`.

### MSW

```
src/mocks/
├── handlers.js     barrel -> importa schoolsHandlers
├── browser.js      setupWorker (dev browser)
└── server.js       setupServer (testes Node)
src/features/schools/mocks/
├── handlers.js     http.get /api/school/:codInep/{indicators,ranking} + fixtures demo
└── fixtures.js     DEMO_SCHOOL_COD_INEP="35123456", INDICATORS_FIXTURE, RANKING_FIXTURES
```

- Testes: `server.listen({ onUnhandledRequest: "error" })` — requisição não
  mockada **falha**; `resetHandlers`/`close` no afterEach/afterAll.
- Dev: `main.js` tem `enableMocking()` **comentada** — MSW no browser está
  desativado; requisições reais vão pelo proxy Vite.
- Cobertura parcial: ranking/indicators têm handlers; busca paginada,
  autocomplete e panel **não têm** — sinais mockados via `vi.mock` nos testes
  de página (ex.: `SchoolSearchPageRx.test.js` mocka
  `searchPaginatedSchools` com `of(...)`/`throwError`).

---

## 9. Convenções e padrões de código

- **Dependência**: feature→feature é proibida; cross-feature só por EventBus.
- **Componente genérico** (shared/ui) não conhece domínio (endpoint, formato).
  APIs sabem o endpoint; components `panel/*` + pages conhecem o contrato.
- **Comunicação**:
  - pai→filho: props (`$props`); filho→pai: callbacks ou `bind:` à Svelte 5;
  - fora da árvore / cross-feature: `eventBus.emit`;
  - relação pai/filho pode coexistir com EventBus (caso `SchoolSearchForm`).
- **Estado**: UI efêmera → `$state` local; estado compartilhado/imperativo →
  store RxJS; estado global assíncrono → EventBus.
- **Mapa**: sempre via `LeafletMap` + contexto; código imperativo confinado a
  `onMount`/`$effect`/actions.

---

## 10. Pendências para o inventário futuro

Achados nesta análise (não bloqueiam, mas merecem decisão no inventário):

1. **`PaginationControls.svelte`** — legado Svelte 4, órfão (nenhum import);
   substituído por `PageableList`.
2. **`shared/utils/eventDispatcher.js`** — não importado; referencia
   `EVENTS.SEARCH/CLEAR/PAGE_CHANGE/PER_PAGE_CHANGE/ACTION` que **não existem**
   no `shared/constants/events.js` (só `ERROR/TOAST_ADD/TOAST_REMOVE`).
3. **`features/map/icons.js`** — arquivo vazio (placeholders); ícones reais em
   `features/schools/components/icons/icon-data.js`.
4. **`SchoolSearchPage` vs `SchoolSearchPageRx`** — a clássica sobrevive como
   referência; a Rx é a roteada. Definir se a clássica será removida.
5. **`shared/ui/index.js`** — exporta só `DataTable`; padrão de import dos
   demais é por path. Definir barrel completo.
6. **MSW browser desativado** (`//await enableMocking();` em `main.js`).
7. **Autocomplete** — endpoints `suggestions` marcados como contrato não
   confirmado.
8. **Inventário de ícones/cores de cluster** — `app.css` define
   `cluster-1..6` (semântica de desempenho) e `brand-*`; confirmar vínculo com
   dados de ranking.

---

## Anexo: árvore de referência (paths principais)

```
frontend/edumaps/src/
├── main.js  app.css  index.html → app/App.svelte (mount svelte 5)
├── app/
│   ├── App.svelte  routes.js  router.svelte.js  routes.test.js
├── shared/
│   ├── api/client.js          (+ client.test.js)
│   ├── events/EventBus.js (+ index.js, middlewares/logger.js)
│   ├── stores/paginationStore.js  toastStore.js  toastEventBridge.js
│   ├── ui/index.js  ui/components/{DataTable,InputAutocomplete,Toast,
│   │                        PaginationControls,PageableList}.svelte
│   ├── utils/{format,eventDispatcher}.js
│   └── constants/events.js
├── features/
│   ├── schools/
│   │   ├── pages/{SchoolSearchPage,SchoolSearchPageRx,SchoolRankingPage,
│   │   │         SchoolPanelPage,SchoolPayrollPage}.svelte
│   │   ├── components/{SchoolCard,SchoolList,SchoolReactiveList,
│   │   │        SchoolSearchForm,SchoolRanking,SchoolPayrollTable}.svelte
│   │   │   components/panel/{SchoolPanel,SchoolSummary,TeachingStages,
│   │   │        InfrastructureGrid,SchoolIndicator,SimilarSchools,SchoolMap}.svelte
│   │   │   components/icons/{Icon.svelte, icon-data.js}
│   │   ├── api/{schoolApi,rankingApi,autocompleteApi}.js
│   │   ├── stores/schoolPaginationStore.js
│   │   ├── utils/transformPanelData.js
│   │   ├── constants/{events,indicators}.js
│   │   └── mocks/{handlers,fixtures}.js
│   ├── map/{components/LeafletMap.svelte, context.js, icons.js, index.js}
│   └── about/pages/AboutPage.svelte
└── mocks/{handlers,browser,server}.js
```