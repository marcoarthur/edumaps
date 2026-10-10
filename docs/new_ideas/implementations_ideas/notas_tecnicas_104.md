# Nota técnica 104 — Telemetria de sessão, etapa 2: rastreador no navegador (PR #205)

## Resumo

Etapa 2 da telemetria de sessão do EduMaps: o **rastreador no navegador**. A
etapa 1 (PR #204) deixou o backend pronto — cookie de visitante, allowlist e
persistência em lote. Faltava a ponta que produz os eventos: um tracker JS que
observa a navegação da SPA, as buscas, o login/logout de gestor e os erros de
API, agrega tudo em lotes e envia a `POST /api/session/events`.

Entrega: 3 commits na branch `feat/frontend-telemetria-sessao` → **PR #205**
(merge `b5827dc`).

## Decisões de privacidade (perguntadas ao usuário)

1. **Sem opt-out agora** (não respeita DNT ainda) — decisão explícita do
   developer; fica registrado como ponto a revisitar.
2. **Login que falha é registrado** (`gestor:login {ok:false}`) — o campo `ok`
   já estava na allowlist; útil para medir fricção de login.
3. **Rota enviada é o PADRÃO casado** (`matchRoute(path).path`, ex.: `/p/:token`),
   nunca o pathname cru — o link público de resposta carrega um token na URL, que
   não pode ir para o repositório de eventos.

## Arquitetura

**Dois níveis, para o motor não conhecer domínio:**

- `shared/telemetry/tracker.js` — **genérico**. Buffer em memória, allowlist de
  tipos/chaves (`CLIENT_EVENT_TYPES`, espelho exato de
  `EduMaps::Controller::Session#type_map`), flush por tempo (30s), por volume
  (teto de 200 por lote, o `max_batch` do backend) e no unload. Não importa
  nenhuma feature.
- `app/telemetry.js` — **composition root**. O único lugar que conhece o
  domínio: o mapa `evento-do-bus → evento-de-cliente` (`BUS_TO_CLIENT`), o
  `sendBatch` (beacon/fetch) e o `startTelemetry()`.

**Emissores** (nos pontos naturais, sem duplicar estado):

- `App.svelte` — `EVENTS.NAVIGATE {route}` num `$effect` sobre `match`
  (derivado de `router.path`): cobre mount, `pushState` e `popstate`.
- `SchoolSearchPageRx.svelte` — `SCHOOL_EVENTS.SEARCH_DONE {q_len, result_count}`
  **só** numa busca iniciada pelo usuário. Um marcador `searchPending` (não
  reativo) distingue busca de paginação: a transição loading→pronto da
  paginação não emite. `q_len` é o comprimento do termo — **nunca o texto**.
- `gestorPesquisasApi.js` — `GESTOR_EVENTS.LOGIN {ok}` no sucesso e no catch
  (o erro é re-lançado) e `LOGOUT` no `finally` (sai mesmo se o servidor falhar).
  Nunca e-mail/senha.
- `shared/api/client.js` — já emitia `EVENTS.API_ERROR` (≥500); o mapa converte
  `{status, url}` em `{status, route}`.

## Privacidade: defesa em profundidade

A allowlist roda **duas vezes**: no cliente (o `record` descarta tipo fora da
lista e copia só as chaves permitidas) e no servidor (o controller refaz o corte).
Mesmo que um mapa mal configurado tente enviar `escola: "Brasil"`, a chave é
descartada antes de sair do navegador. O e2e confirmou: o lote levou
`{q_len:7, result_count:5}`, sem o termo digitado.

## Robustez (telemetria é fogo-e-esqueça)

- `send` roda dentro de `try/catch` + `onError`: uma falha de rede **descarta o
  lote** e nunca propaga para a aplicação.
- O teto de buffer descarrega sozinho; o buffer não cresce sem limite.
- No unload (`pagehide`/`visibilitychange` → hidden) o flush usa
  `navigator.sendBeacon`, porque o `fetch` pode ser abortado na saída.
- Todas as dependências (tempo, timers, ciclo de vida, envio) são **injetáveis**,
  o que permitiu testar sem timers reais nem rede.

## Validação

- **Testes** (`vitest`, host node): novos `tracker.test.js` (sanitização,
  buffer, teto, intervalo, beacon, falha, stop) e `app/telemetry.test.js`
  (mapeamento, ligação no bus, comando `telemetry.flush`), mais asserções novas
  em `gestorPesquisasApi.test.js` e `SchoolSearchPageRx.test.js` (inclui
  regressão "não emite `schools:search` na paginação"). **41/41**.
  As 4 falhas em testes `gestor*Api` de upload são **pré-existentes no `main`**
  (confirmado por `git stash`), não regressões.
- **Build**: `vite build` OK.
- **Probe e2e real** (Chrome CDP `:9222` → `ubatexu.lan:8080`): navegou para
  `/escola/search`, buscou "Ubatuba", mudou de rota, forçou `pagehide` → **1
  POST** com 3 eventos (`navigate /escola/search`, `schools:search
  {q_len:7,result_count:5}`, `navigate /about`), **0 exceções** e **sem
  "Ubatuba"**. Persistido em `clean.event_store` (`source=frontend`, mesmo
  `session_id` do `session.request`). Registrado em `docs/e2e/cobertura.md`.

## Armadilha de driver (e2e)

A primeira tentativa deu `#app` vazio, sem request `/api/` e sem exceção. Não
era regressão: era **cache de service worker** de uma sessão anterior servindo o
shell antigo. Resolvido com `Network.setCacheDisabled: true` e espera explícita
pela montagem. Sem isso o probe dá falso negativo silencioso.

## Deploy

`rex prepare` + `rex -H backend.edumaps deploy_frontend_dev` (build + cópia para
`/var/www/edumaps-frontend`); imagem local `frontend` reconstruída e container
recriado (`localhost:8080` serve o bundle novo). Nenhuma mudança de backend/DB
neste ciclo.

## Notas

- Capacidade atualizada para 🟢 ativo em
  `docs/funcionalidades/plataforma/telemetria-de-sessao.md` + índice.
- Ponto em aberto registrado: **opt-out/DNT** ainda não implementado (decisão
  consciente desta rodada).
