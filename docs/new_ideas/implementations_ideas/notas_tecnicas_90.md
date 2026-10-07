# Nota técnica 90 — Bot Telegram Fase 1D: eventos reais de ingestão no Notifier (#183)

**Data**: 2026-10-07
**Escopo**: PR #187 — integração com alertas existentes: ingestão notifica
`ingest_done`/`ingest_failed`/`ingest_stall` via um serviço único de
notificação, respeitando `enabled` + `allowed_actions` da AppConfig.
**Issues**: #183 (fase 1D; 1A no #184, 1B no #186, 1C frontend coberta na 1B).

## Resumo

A fase 1B entregou a config persistida e o endpoint de teste; faltava ligar
eventos **reais** do sistema ao bot. Esta fase criou `EduMaps::Bots::Notifier`,
o ponto único pelo qual eventos chegam ao Telegram, e integrou-o ao
`Ingestion::Runner::run_job` nos três desfechos de um job (sucesso, falha,
stall). A premissa de projeto é a mesma da 1A/1B: notificação é **best-effort**
— o bot é um observador, nunca um gate; e nada é enviado sem decisão explícita
do admin (`enabled=1` + ação em `allowed_actions`).

## Decisões de design

1. **`EduMaps::Bots::Notifier` como ponto único de envio.** Em vez de cada
   ponto de alerta montar o `Telegram` e o seu próprio controle de política,
   todos os eventos passam por `notify($action, $text)`. Isso concentra três
   regras que não podem divergir: validação de ação (**erro de programação** —
   ação fora da whitelist da `Policy::Actions` é `croak`, o Runner captura e
   loga), leitura da config efetiva (`bot_telegram_config()` da AppConfig, token
   decifrado em memória — nunca em claro) e o contrato best-effort.

2. **Dois modos de falha, tratados de forma oposta.** *Erro de programação*
   (ação desconhecida) morre — é bug e precisa aparecer no log. *Falha de
   runtime* (API do Telegram recusou, config incompleta) **nunca** morre: loga
   e devolve 0. A ingestão segue intacta nos dois casos (o Runner envolve a
   chamada em eval).

3. **Injeção de dependência no Runner (`has notifier`, lazy).** Os testes
   substituem o Notifier real por um mock — sem isso o `ingestion_runner.t`
   exigiria rede/BD. O Notifier, por sua vez, recebe `bot_class` e
   `app_config` injetáveis pelos mesmos motivos.

4. **Erro com `[STALL]` vira `ingest_stall`.** O watchdog de stall
   (#166/#156) marca os erros com o literal `[STALL]`; o Runner mapeia esse
   caso para a ação `ingest_stall` — o ponto de alerta mais valioso (job
   travado em vez de apenas falho).

5. **Correção de diagnóstico pré-existente no `Telegram::send_text`.**
   Exposta pelo smoke: em falha de **conexão** (não de HTTP), o `res` fica
   vazio (`code`/`message` undef) e a causa real morava em `$tx->error`.
   Antes o código montava `error => "HTTP " . …` com undefs — perde-se o
   diagnóstico. Agora: `{ ok=>0, status=>0, error=>$tx->error->{message} }`.
   Medido: `api.telegram.org` tem **Connect timeout intermitente** (1 em 3
   tentativas no smoke) — sem esta correção, o log diria apenas "HTTP ".

## Entregas

- `EduMaps::Bots::Notifier` (novo, `Bots/Notifier.pm`): `notify($action,$text)`
  com política best-effort; `bot_class`/`app_config` injetáveis.
- `Ingestion/Runner.pm`: hooks `ingest_done`/`ingest_failed`/`ingest_stall` +
  `has notifier` + `_notify` (eval, loga sem propagar).
- `Bots/Telegram.pm`: diagnóstico de falha de conexão via `$tx->error`.
- Testes: `t/05-tasks/bot_notifier.t` (novo, 8 subtests, mocks sem rede),
  `ingestion_runner.t` +3 subtests (mock de notifier), `bot_telegram.t` +1
  (erro de conexão reporta causa).
- Docs funcionais: `plataforma/bot-telegram.md` (bullet de envio automático em
  ingestão) e índice.

## Validação

- Suíte completa: **523 testes**, conjunto de falhas **idêntico ao baseline**
  via `git stash` (falhas pré-existentes de R/Siope/OSM/analytics — ver
  AGENTS.md); zero regressão. CI: backend PASS (10m26s).
- Smoke ponta a ponta: config real persistida na BD dev (token cifrado, master
  key dedicada) → job de teste morre com `[STALL]` → runner real →
  `Notifier: ingest_stall enviada (HTTP 200)` → **mensagens confirmadas no
  Telegram** (loop 1, loop 2 e stall). A ingestão reportou a falha
  normalmente — a notificação não interferiu.
- Deploy: `rex prepare` + `deploy_backend_dev` OK; md5 de `Notifier.pm` e
  `Runner.pm` batem entre container local, `backend.edumaps` e working tree;
  imagens Docker locais backend/minion reconstruídas.

## Pendências

- #183 permanece aberta: recebimento/bidirecional (chat com o bot) e migração
  gradual do `notify.sh` para o Notifier (pontos de alerta adicionais).
- Config do smoke (token real cifrado) ficou persistida na BD dev local —
  higienizar quando não for mais útil para testes manuais.
- `api.telegram.org` com timeout de conexão intermitente (1/3 no smoke) —
  considerar retry/timeout configurável no futuro.