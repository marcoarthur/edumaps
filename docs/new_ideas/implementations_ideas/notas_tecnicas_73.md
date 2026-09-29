# Nota técnica 73 — Observabilidade com Sentry (backend + Minion + frontend)

**Data**: 2026-09-29
**PRs**: #122 (a confirmar)
**Issues**: — (sem issue; integração de infra)
**Áreas**: backend, frontend

## Contexto

O EduMaps não tinha rastreamento de erros em runtime: 5xx dos controllers,
falhas contínuas de jobs Minion e erros de JS no navegador só apareciam via
log manual (ou nem isso). Decidiu-se integrar o **sentry.io cloud** (tier
free) como repositório central de erros, sem self-hosted.

Decisões de produto/escopo (alinhadas antes de codar):

- **Sem conta/DSN ainda** → implementar com **placeholder** (`EDUMAPS_SENTRY_DSN`
  / `VITE_SENTRY_DSN`): sem DSN, o sistema é **no-op** silencioso.
- Escopo: **backend** (5xx), **jobs Minion** (fail), **frontend** (erros JS +
  ApiError ≥ 500). **R não instrumentado** (erros chegam como 5xx).
- **Privacidade (LGPD)**: nunca enviar CPF/salários SIOPE/token bearer;
  permit-list e redação (back e front).
- Traces/replay ficam para **fase 2** (`tracesSampleRate: 0`).

## A — `EduMaps::Services::Sentry` (cliente enxuto)

Thin client para a **Sentry Envelope API** com zero dependência CPAN extra
(só Mojolicious/Mojo):

- `_ingest_url` parser de DSN → `https://<host>/api/<project>/envelope/`
  (formato cloud `https://<key>@o<org>.ingest.sentry.io/<project>`).
- `_build_envelope`: 3 linhas — header (`event_id`, `sent_at`, `dsn`),
  item (`type=event`, `length` em bytes UTF-8), payload JSON.
- `capture_exception` (com `Mojo::Exception` e frames → `stacktrace`) e
  `capture_message`; `platform=perl`, `environment`, `release`, `server_name`.
- `_sanitize_args`: descarta valores com 11+ dígitos (CPF/CNPJ), chaves
  sensíveis (`senha|password|token|salario|cpf|...`) e valores > 200 chars;
  máx. 10 args → `extra.args`.
- `_send` **adaptativo**: `Mojo::IOLoop->is_running` (web server / worker pai)
  → `post_p` fire-and-forget; senão (job Minion no fork filho, que faz
  `Mojo::IOLoop->reset` antes do `execute`; testes) → `post` síncrono.
  Envio sempre dentro de `eval` — nunca derruba request/job.
- `ua` injetável p/ testes (stub sem rede).

## B — `EduMaps::Plugin::Sentry` (hooks)

Registrado em `EduMaps.pm` logo após o plugin Minion. Expose o helper
`sentry` (no-op sem DSN) e, com DSN, liga dois ganchos:

1. **`after_dispatch`**: response ≥ 500 → `$c->stash->{exception}` (blessed →
   `capture_exception`) ou mensagem genérica `HTTP <code> em <path>`; tags
   `method/path/status` — **corpo de request nunca é enviado**.
2. **`around 'Minion::Job::fail'`** (Class::Method::Modifiers): **choke point
   único** — no Minion 12 não existe evento de mudança de estado; todo fail
   passa por `$job->fail` (explícito OU óbito convertido em fail por
   `Minion::Job::start`/`_reap`). Contexto: `task`, `queue`, `job_id` + args
   sanitizados. Guard `$WRAPPED` evita re-wrap se o plugin registrar 2x.

**Lição do PR #121** validada: no fork do worker o loop **não roda**
(`is_running` falso) — o envio síncrono bloqueia até completar; no web server
o loop roda → fire-and-forget.

## C — Frontend (`@sentry/svelte` + `@sentry/browser`, v9)

- `src/shared/sentry.js`: `initSentry()` com **import dinâmico** — sem
  `VITE_SENTRY_DSN` nada é carregado (não afeta bundle nem vitest/MSW).
  `sendDefaultPii: false`, `beforeSend` redige chaves sensíveis em qualquer
  profundidade; tag `app=frontend`.
- `client.js` emite `EVENTS.API_ERROR` no eventBus para status ≥ 500
  (desacoplado do SDK); `sentry.js` assina e captura com contexto `http`.
- `main.js`: bootstrap assíncrono — com Sentry ativo, `mount` recebe
  `onerror` (erros de componente Svelte 5) além das integrações padrão do SDK
  (`window.onerror`, `unhandledrejection`).
- `package.json` + `package-lock.json` atualizados (deps 9.47.2).

## D — Configuração e deploy

- `edu_maps.conf` ganha bloco `sentry => { dsn, release }`
  (`files/edumaps_db.conf` + `docker-entrypoint.sh`).
- `Rexfile`: `sentry_dsn`/`sentry_release` a partir do ambiente; **release =
  SHA curto do git local** no deploy; `deploy_frontend_dev` passa `VITE_*` no
  `npm run build` (Vite serializa no build-time).
- `docker-compose.yml`: `EDUMAPS_SENTRY_DSN`/`EDUMAPS_SENTRY_RELEASE` no
  backend e no minion (vazio = no-op).

## Pendências

- **Ativar de fato**: criar conta sentry.io, configurar os DSNs nos hosts
  (via env do Rex/conf) e conferir os primeiros eventos.
- Traces/replay / monitoramento de performance (fase 2).
- Evento de estado de job nativo (quando o Minion ganhar `failed` hook,
  revisitar o wrap).