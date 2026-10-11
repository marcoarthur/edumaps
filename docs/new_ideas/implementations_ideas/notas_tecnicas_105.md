# Nota técnica 105 — Painel de Administração: telemetria de acesso (PR #206)

## Resumo

Os dois ciclos anteriores construíram a **telemetria de sessão**: a etapa 1
(PR #204) deixou o backend com cookie de visitante, allowlist e persistência em
lote (`clean.event_store`, `clean.session_tracking`); a etapa 2 (PR #205)
entregou o **rastreador no navegador** que produz os eventos. Faltava **ler**
esses dados. Este ciclo entrega o **Painel de Administração** (`/admin`): uma
página que agrega o fluxo de acesso e uso — logins de gestores, sessões ativas,
buscas, rotas mais acessadas e atividade ao longo do tempo — em
**near-real-time** e **só com agregados**.

Entrega: 3 commits na branch `feat/painel-administracao` → **PR #206**
(merge `f16206f`).

## Decisões (perguntadas ao developer no planejamento)

1. **Métricas = "essencial + atividade"**: logins (6/12/24h), rotas mais
   acessadas, sessões ativas (logadas vs. anônimas), buscas e gráfico temporal.
   **Sem erros de API/5xx** no v1 — é sobre adoção, não saúde de infra.
2. **Seletor de janela** com mais opções que só 6/12/24h: **6h · 12h · 24h ·
   hoje · 7d · 30d** (whitelist). Granularidade **hora** (≤24h e hoje) ou **dia**
   (7d/30d). "Hoje" = `date_trunc('day', now())`.
3. **Endpoint único** `GET /api/admin/telemetry/overview?window=…`, sob
   `_require_admin`. `logins` fica **fixo** nas três janelas 6/12/24h
   (comparáveis entre si); as demais métricas seguem a janela escolhida.
4. **V1 com consulta direta** no `event_store`/`session_tracking` — sem rollup
   nem materialized view. Se o volume crescer, o caminho natural é MV (registrado
   como pendência).
5. "Logins" = **gestores distintos** (`COUNT(DISTINCT gestor_id)`), não número de
   logins. "Rotas" = **rotas de frontend** (`session.navigate.payload.route`).
6. **Privacidade**: só agregados — nunca IP, texto de busca, User-Agent ou sessão
   individual.

## Arquitetura

### Backend — `Roles::Business::Admin::Telemetry`

Role de negócio (padrão do repo: `Mojo::Base -role, -signatures`, `requires
qw(schema)`), composta pelo model fino `EduMaps::Model::AdminTelemetry`. Todos os
acessos ao banco usam o helper `_rows`/`_row` sobre
`schema->storage->dbh_do` — SQL cru com `Slice => {}`, o mesmo padrão das demais
roles.

**Whitelist de janelas** (`%WINDOWS`): cada janela é um hash de trechos SQL
**constantes do servidor** — `since` (corte inferior), `start` (início da série
contínua), `bucket` (`hour`/`day`) e `step`. O cliente manda só a **chave**
(`6h`…); o valor nunca vira SQL. Detalhe de Postgres: `interval ?` **não aceita
bind**, por isso os `interval '…'` são literais montados do whitelist.

As métricas:

- **logins** — `COUNT(DISTINCT st.gestor_id)` com `JOIN session_tracking` por
  `session_id`, filtrando `event_type='session.login'`, `payload->>'ok'='true'` e
  `st.gestor_id IS NOT NULL`. O `gestor_id` **não vem do evento** (o payload de
  `session.login` só tem `{ok}`): vem do vínculo da sessão, preenchido no
  `_flush_sessions`.
- **sessões** — de `session_tracking`, por `last_seen_at >= since`, com
  `COUNT(*) FILTER (WHERE is_logged)` para separar logadas de anônimas.
- **buscas / eventos** — contagem em `event_store` (`session.search`; e total).
- **top_routes** — `payload->>'route'` de `session.navigate`, com
  `share_pct` via função de janela (`SUM(COUNT(*)) OVER ()`), ordenadas por
  volume, top 10.
- **série** — `generate_series` gera **buckets contínuos** (sem furos quando não
  há evento naquela hora/dia) e o `LEFT JOIN` conta eventos e sessões distintas
  por bucket. `to_char` formata o rótulo (`YYYY-MM-DD"T"HH24:MI` ou
  `YYYY-MM-DD`).

A resposta traz `granularity` para o frontend rotular o eixo do gráfico.

### Backend — controller e rota

`Controller::Admin::telemetry_overview`: valida a janela (400 se fora da
whitelist), chama o model com **hashref** (`$model->overview({ window => $window })`
— a assinatura é com `-signatures`, então é hashref, não argumento posicional) e
devolve 500 se o `eval` falhar. Rota registrada no grupo autenticado/admin em
`Plugin::API::Admin` (`GET /telemetry/overview`).

### Frontend — feature `admin`

- `AdminTelemetryPage.svelte`: guarda dupla — restaura o token
  (`restaurarSessao`), chama `fetchMe()` e só carrega se `access_role === 'admin'`
  (senão mostra "restrita a administradores"; sem sessão mostra o
  `GestorLoginCard`). `setInterval` de **30s** para o auto-refresh (o teto do
  flush do EventLogger) + botão "Atualizar agora". Ao trocar a janela, dispara
  nova request.
- Componentes: `TelemetryStatCard` (KPI), `TelemetryWindows` (seletor),
  `TelemetryRoutesTable` (rota/volume/%), `TelemetryTimeseries` (embrulha o
  `LineChart` Carbon existente, passando `granularity` para o eixo).
- `telemetryApi.js` chama `GET /api/admin/telemetry/overview`; o token entra pelo
  `apiClient` (Bearer) já existente.
- Rota `/admin` em `routes.js` + item "Administração" na `App.svelte`; handler
  MSW (`telemetryHandlers.js`) e fixtures para os testes.

## Privacidade

A resposta do endpoint **nunca** expõe IP, `ip_anon`, User-Agent, e-mail, texto
de busca ou identificador de sessão individual — só contagens, percentuais e
rótulos (`route`, buckets de tempo). O teste de API assere o **conjunto de
chaves** da resposta exatamente para travar regressão de privacidade: se alguém
adicionar `ip` ou `query` ao payload, o teste morde.

## Validação

- **Backend** (`t/04-api/admin/telemetry.t`): auth 401/403/200, janela inválida
  → 400, KPIs por janela e o **conjunto de chaves** (privacidade). Conjunto
  `t/04-api/admin/`: **4 arquivos / 21 testes** 🟢.
- **Frontend**: `AdminTelemetryPage.test.js` (Carbon mockado via
  `vi.mock("@carbon/charts-svelte")` para não renderizar o gráfico) → **4/4**.
  Suíte completa **72/76** — as 4 falhas são **pré-existentes** de multipart
  `gestor*Api` (documentos/inventário/relações/reuniões), fora do `admin`,
  confirmadas por `git stash`. `vite build` 🟢 (1053 módulos).
- **E2E** (Chrome real via CDP, alvo `ubatexu.lan:8080/admin`): sessão obtida por
  `POST /api/gestor/login` e injetada em `localStorage` antes do carregamento.
  Painel renderiza com dados reais: logins `0/1/1`, sessões `11/3/8`, buscas `3`,
  eventos `49`, série horária (24 buckets) e rotas (`/escola/search 44`,
  `/about 22`, …). Troca de janela 24h→7d dispara `window=7d`. **0** requests
  com status ≥400, **0** exceções. Registrado em `docs/e2e/cobertura.md`.

## Deploy

`rex prepare` + `rex -H backend.edumaps deploy_backend_dev` (config + restart do
`edumaps-web`) + `deploy_frontend_dev` (build no host e cópia para
`/var/www/edumaps-frontend`). Após o merge, as imagens locais `backend`, `minion`
e `frontend` foram reconstruídas (a stack do `ubaxala` não se atualiza sozinha).

## Armadilha: não havia credencial de bootstrap de admin

O `edu_maps.conf` deployado **não** tem o bloco `admin` — as variáveis
`EDUMAPS_ADMIN_EMAIL`/`EDUMAPS_ADMIN_PASSWORD` estavam vazias no deploy, então o
template não o gerou. Para o e2e foi preciso criar um gestor
(`POST /api/gestor/pesquisas/perfil`) e **promovê-lo** a admin por SQL
(`UPDATE clean.gestores SET access_role='admin'`) no `database.edumaps`
(id `50`, `e2e.admin.tel@edumaps.test`). Fica registrado: bootstrap de admin
ainda é por texto plano/servidor, não por uma tela de administração — como o
próprio comentário do template já antecipa.

## Notas

- Capacidade nova em 🟢 ativo: `docs/funcionalidades/plataforma/painel-administracao.md`
  + índice `docs/funcionalidades/README.md`.
- Pendências: (a) sem rollup/MV — V1 consulta direta; monitorar custo com
  volume; (b) `logins` fixos em 6/12/24h (não seguem o seletor) — decisão de
  produto; (c) o admin de teste `id 50` ficou no `database.edumaps` (remover
  quando não for mais útil).
