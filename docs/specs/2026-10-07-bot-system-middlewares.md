# Especificação de Requisitos — Bot Telegram: categoria de envio `system.bot.<severidade>` + middleware de login

**Data:** 2026-10-07
**Autor:** engenheiro de software (agente) com o developer
**Versão:** 1.0
**Issue relacionado:** #188

---

## 1. Contexto e Objetivo

O Bot Telegram (issues #183, fases 1A–1D) já envia mensagens de pontos de
alerta **fixos** (ingestão via `Ingestion::Runner`). Faltava uma **categoria
geral de envio** para **middlewares do sistema**: qualquer middleware registrado
no EventBus deve poder mandar mensagem para o chat configurado, sem conhecer o
Bot nem a AppConfig — basta emitir um evento com o label agregador
`system.bot.<severidade>`.

O caso de uso concreto solicitado é um middleware que dispara na **ação de
login** dos gestores (`POST /api/gestor/login`), avisando a operação do acesso
com sucesso — sem que o controller de login espere pelo processo do Bot (o
envio é assíncrono via `Mojo::Promise`).

**Valor:** operação acompanha eventos do sistema (login, futuramente trace e
sentry) no Telegram com a mesma política de `enabled` + `allowed_actions` já
existente — sem acoplar emissores ao bot.

## 2. Requisitos Formais

### RF-001: Categoria "system middlewares" de envio via label `system.bot.<severidade>`

**Ator:** qualquer middleware registrado no EventBus (login, trace, sentry, …)
**Descrição:** O sistema deve permitir que qualquer middleware do EventBus envie
mensagem ao bot emitindo evento com tipo `system.bot.<severidade>`, onde
`<severidade>` ∈ {`info`, `warn`, `error`, `trace`}, e payload `{ text }`.
**Prioridade:** Essencial
**Critérios de Aceitação:**
- [ ] Evento `system.bot.info` com `{ text: "..." }` gera envio ao Telegram com a
      ação `system_bot_info`; idem `warn`→`system_bot_warn`, `error`→`system_bot_error`,
      `trace`→`system_bot_trace`.
- [ ] Severidade fora do conjunto conhecido é ignorada com log, **sem**
      interromper a cadeia de middlewares do EventBus nem o emissor.
- [ ] A cadeia do EventBus continua intacta: o middleware de envio sempre repassa
      o evento (`$next`).

### RF-002: Política de envio preservada (best-effort + decisão do admin)

**Ator:** administração da instalação
**Descrição:** O sistema deve continuar respeitando a política existente do
Notifier para os eventos `system.bot.*`: `enabled=0` por omissão, ação precisa
estar em `allowed_actions`, token/chat_id vindos da AppConfig (decifrados em
memória), e falha de envio **nunca** derruba o emissor.
**Prioridade:** Essencial
**Critérios de Aceitação:**
- [ ] As 4 novas ações (`system_bot_info/warn/error/trace`) aparecem no
      `multiselect` do Painel de Configuração, **todas desmarcadas por omissão** —
      nada é enviado sem decisão explícita do admin.
- [ ] Config existente permanece válida (sem migration).
- [ ] Erro do Notifier (config incompleta, API recusa, timeout) é logado e o
      emissor segue o fluxo normal.

### RF-003: Middleware de login dispara `system.bot.info` no sucesso

**Ator:** gestor escolar / admin (via `POST /api/gestor/login`)
**Descrição:** O sistema deve disparar `system.bot.info` com texto
"Login realizado: `<email>`" sempre que a rota `gestor_login` responder **200**
(credenciais válidas — gestor ou admin de instalação).
**Prioridade:** Essencial
**Critérios de Aceitação:**
- [ ] Login 200 emite `system.bot.info` com o e-mail do gestor no texto.
- [ ] Login 401 (credenciais inválidas) NÃO emite.
- [ ] Rotas que não são de login não emitem.
- [ ] Nenhuma credencial/senha é logada ou enviada.

### RF-004: Envio assíncrono — login não espera o Bot

**Ator:** usuário final do login
**Descrição:** O sistema deve enviar a mensagem do bot de forma assíncrona
(`Mojo::Promise`, `post_p` não-bloqueante) quando houver **loop de eventos
rodando** (web worker, Minion), para que o request de login não espere o RTT do
Telegram; em contexto sem loop (CLI), o envio permanece síncrono.
**Prioridade:** Essencial
**Critérios de Aceitação:**
- [ ] Com loop rodando, o emit retorna imediatamente e o envio resolve em
      background (fire-and-forget), sem bloquear a resposta do login.
- [ ] O caminho síncrono da ingestão (fase 1D, `Runner::_notify`) permanece
      com o contrato 1/0 intacto (sem regressão).
- [ ] O endpoint admin de teste (`send_text` síncrono) permanece funcional.

## 3. Decomposição Arquitetural

### 3.1 Motor Analítico

Nada — nenhuma métrica, agregação ou processamento novo.

### 3.2 Frontend (Svelte)

Nada de código novo. O `multiselect` de "Ações permitidas" do Painel de
Configuração já lê `EduMaps::Bots::Policy::Actions->available` — as 4 ações
novas aparecem automaticamente, desmarcadas.

### 3.3 Backend (Perl)

| Módulo | Mudança |
|--------|---------|
| `EduMaps::Middleware::Bot` | **Novo** — middleware da cadeia do EventBus que filtra `system.bot.<severidade>` e informa o Bot via Notifier; fronteira assíncrona (loop rodando → `notify_p` fire-and-forget; sem loop → `notify` síncrono); nunca estoura a cadeia; `has notifier` injetável |
| `EduMaps::Middleware::Login` | **Novo** — plugin HTTP (`around_dispatch`) que emite `system.bot.info` em login 200 (`gestor_login`) |
| `EduMaps::Bots::Telegram` | `send_text_p` (novo, `post_p` → mapeia `{ok,status,error}`; nunca rejeita); `send_text` síncrono intacto |
| `EduMaps::Bots::Notifier` | `notify_p` (novo, mesma política de `notify`, resolve 1/0); `notify` síncrono intacto; check de política extraído p/ `_policy` |
| `EduMaps::Bots::Policy::Actions` | +4 ações: `system_bot_info`, `system_bot_warn`, `system_bot_error`, `system_bot_trace` |
| `EduMaps::Plugin::Helpers` | `add_mw` passa a aceitar FQCN (`EduMaps::Middleware::Bot`) |
| `EduMaps.pm` | Registra `Middleware::Login` (plugin) + `Middleware::Bot` (add_mw) + handlers no-op das 4 severidades (evita WARN do bus) |

**Contrato de evento:**

```
emit('system.bot.<severidade>', { text => '...' })
   severidade ∈ {info, warn, error, trace}
   → Middleware::Bot → Notifier(action = system_bot_<severidade>) → Telegram
```

## 4. Modelo de Dados

Nada — sem migrations, sem tabelas novas. A AppConfig (`bot_telegram`) já
comporta as ações novas via `multiselect`.

## 5. Contratos de API

Sem endpoints novos. Novas ações no `POST /api/admin/config` (validação
`is_valid` cobre as 4) e no `GET` de definições da árvore (options do
multiselect).

## 6. Riscos e Suposições

- **WARN do EventBus**: `emit('system.bot.*')` sem handler registrado gera o
  aviso "disparado sem nenhum handler registrado" — mitigado com handlers no-op
  das 4 severidades no startup (o consumo real é no middleware).
- **`Mojo::Promise->wait` é no-op com loop rodando** (verificado no Mojo 5.44):
  por isso a fronteira assíncrona é o Middleware::Bot, e o caminho da ingestão
  não vira fire-and-forget.
- **[SUPOSIÇÃO]** O conjunto inicial de severidades é `{info, warn, error, trace}`;
  adicionar severidade nova = 1 linha no mapa do Middleware::Bot + 1 ação na
  Policy.
- **[SUPOSIÇÃO]** Mensagem vazia (`text` ausente/vazio) não é enviada — log de
  debug e skip.

## 7. Critérios de Aceitação Globais

- [ ] Suíte backend sem regressão (comparação com baseline via `git stash`).
- [ ] Gate `perl -c` OK nos módulos tocados.
- [ ] Testes novos: middleware Bot (cadeia + severidades + skip), middleware
      Login (200/não-login/401), `send_text_p` e `notify_p` (mock sem rede).
- [ ] Deploy `rex prepare` + `deploy_backend_dev`; md5 bate em container local e
      `backend.edumaps`.
- [ ] Docs funcionais (`plataforma/bot-telegram.md`) atualizadas.