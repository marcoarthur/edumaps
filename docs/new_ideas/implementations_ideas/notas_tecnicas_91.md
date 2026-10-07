# Nota técnica 91 — Bot Telegram: categoria `system.bot.<severidade>` + middleware de login (#188)

**Data**: 2026-10-07
**Escopo**: PR #189 — categoria geral de envio para **middlewares do sistema**:
qualquer middleware registrado no EventBus emite `system.bot.<severidade>` e o
Bot informa o chat, com envio **assíncrono** (o emissor não espera o RTT do
Telegram).
**Issues**: #188 (spec + entrega).

## Resumo

Até a fase 1D, o bot só conhecia pontos de alerta **fixos** (ingestão via
`Notifier`). Faltava uma categoria aberta a **qualquer middleware do sistema**:
um middleware (login, futuramente trace/sentry) emite um evento com label
agregador `system.bot.<severidade>` e o sistema decide o resto. Este ciclo
entregou essa ponte na cadeia do EventBus (`EduMaps::Middleware::Bot`), o caso
de uso concreto (`EduMaps::Middleware::Login` disparando no login de gestor com
sucesso) e o caminho **assíncrono** de envio (`send_text_p`/`notify_p`) — o
request de login não espera o processo do bot.

## Decisões de design

1. **Middleware na cadeia do EventBus, não handler.** `EduMaps::Middleware::Bot`
   casa `^system\.bot\.([a-z]+)$` e repassa para o Notifier com a ação
   equivalente. Middleware (e não handler) porque o consumo é transversal a
   vários labels; para silenciar o WARN do bus ("sem nenhum handler
   registrado"), os 4 labels ganham handlers no-op no startup — aquele
   middleware não é eval'd, logo precisa ser **defensivo** (nunca croak; sempre
   `$next->($event)`), e é: severidade fora do mapa ou texto vazio são logados e
   ignorados, e falha do Notifier é capturada.

2. **Fronteira assíncrona no middleware, não em quem emite.** `Mojo::Promise
   ->wait` é no-op com loop rodando (medido no Mojo 5.44): se a fronteira
   ficasse no controller, nada seria garantido. A decisão vive no
   `Middleware::Bot`: loop rodando (web/Minion) → `notify_p` fire-and-forget;
   sem loop (CLI) → `notify` síncrono. Os chamadores síncronos da fase 1D
   (ingestão CLI, endpoint admin de teste) ficaram **intactos** — sem regressão
   no contrato 1/0.

3. **`send_text_p` nunca rejeita.** O `post_p` do Mojo resolve com o TX mesmo
   em erro de conexão, mas pode rejeitar em hard failures; o callback de
   rejeição mapeia para `{ok=>0, status=>0, error}` — quem consome
   (`notify_p` → middleware) só lida com resolução. O mapeamento
   `_map_response` é compartilhado com o `send_text` síncrono (estado da arte
   da correção de diagnóstico da 1D: causa real em `$tx->error`).

4. **Política única via `_policy`.** As checagens de `enabled` +
   `allowed_actions` + token/chat_id (com os mesmos logs) foram extraídas de
   `notify` para `_policy`, compartilhadas com `notify_p`. Ação fora da
   whitelist da Policy continua `croak` síncrono em ambos (erro de programação;
   o middleware captura). As 4 ações novas nascem **OFF** no multiselect —
   config existente permanece válida, nada envia sem decisão do admin.

5. **Login emite só no sucesso, e só o e-mail.** `around_dispatch` captura o
   e-mail do corpo antes do dispatch, e após `$next->()` confere `res->code ==
   200` e o nome da rota (`gestor_login`) — 401 e rotas não-login não emitem.
   Senha nunca entra no texto nem no log.

## Arquivos

| Arquivo | Mudança |
|---------|---------|
| `lib/EduMaps/Middleware/Bot.pm` | **novo** — ponte system.bot.* → Notifier (fronteira assíncrona) |
| `lib/EduMaps/Middleware/Login.pm` | **novo** — plugin HTTP, emite em login 200 |
| `lib/EduMaps/Bots/Telegram.pm` | `send_text_p` + `_build_request`/`_map_response` (refactor) |
| `lib/EduMaps/Bots/Notifier.pm` | `notify_p` + `_policy`/`_bot_from` (refactor) |
| `lib/EduMaps/Bots/Policy/Actions.pm` | +4 ações `system_bot_*` |
| `lib/EduMaps/Plugin/Helpers.pm` | `add_mw` aceita FQCN |
| `lib/EduMaps.pm` | plugin Login + `add_mw(Bot)` + handlers no-op |
| `t/03-plugins/middlewares/bot.t`, `login.t` | **novos** |
| `t/05-tasks/bot_telegram.t`, `bot_notifier.t` | estendidos |

## Testes

`bot.t`: cadeia + severidades→ação, `$next` sempre chamado, severidade fora do
mapa ignorada, texto vazio ignorado, croak do Notifier não propaga. `login.t`:
app mínimo + FakeBus — 200 emite (com e-mail no texto), 401 não emite, rota
não-login não emite. `send_text_p`: sucesso / recusa HTTP / erro de conexão /
rejeição do `post_p`, tudo com mocks sem rede. `notify_p`: mesma política,
resolve 1/0, croak síncrono para ação fora da whitelist.

Verdes: middlewares 17/17; bot_telegram+bot_notifier 19/19; `t/04-api/pesquisa.t`
(rota real de login) 12/12; `analytics.t` pré-falho **confirmado** via `git
stash` (não é regressão). CI backend PASS (run 37684534788).

## Deploy

`rex prepare` + `rex -H backend.edumaps deploy_backend_dev`; `md5sum` de
`lib/EduMaps/Middleware/Bot.pm` idêntico (a19c359d) em working tree,
`backend.edumaps` e container local; imagens `backend`/`minion` reconstruídas
localmente.

## Pendências / próximos passos

- #183 segue aberta: recebimento/bidirecional e migração do `notify.sh`.
- Backlog: #165 (SICONFI), ingestão IBGE (em `extrair_dados_ibge`), #177 passo
  2, #156, #155.