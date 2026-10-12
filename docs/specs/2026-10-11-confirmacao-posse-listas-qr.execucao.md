# Execução — Confirmação de posse nas listas com QR (#212, Fase 1)

> **Documento de execução** (WBS + DAG + log de decisões), companheiro da spec
> [`2026-10-11-confirmacao-posse-listas-qr.md`](./2026-10-11-confirmacao-posse-listas-qr.md).
> A spec é o **contrato**; este arquivo é **mutável** e registra o andamento.

- **Issue:** [#212](https://github.com/marcoarthur/edumaps/issues/212)
- **Branch:** `feat/canais-confirmacao-posse`
- **Onda atual:** 1 (modelo, estado, gestão e página pública contra o contrato)

## Princípios de execução

- **Duas trilhas em paralelo, diretórios disjuntos:** T-A (`data_pipeline/` +
  `backend/`) e T-B (`frontend/`).
- **Git centralizado:** subagentes só escrevem código e rodam teste; commit,
  push, deploy e PR são do coordenador.
- **Migrations validadas por banco limpo** (`db/fixtures/ci_db.sh`, porta
  `5433`, `sqitch verify` como gate). Nenhuma change já deployada é editada.
- **Contrato da onda congelado abaixo.** Mudança exige aviso às duas trilhas.

## Contrato da onda 1 (congelado)

### Público

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| POST | `/api/canais/inscricao/:token` | (Fase 0) | (Fase 0) + `confirmacao` quando a lista exige |
| GET | `/api/canais/confirmacao/:ref` | — | `200 {estado, canais, expira_em}` · `404` genérico · `429` (rate limit; o polling trata como transitório) |

`confirmacao` na resposta do POST (só se `lista.exige_confirmacao`):

```json
// membro pendente (novo, ou reinscrição de pendente → nova ref, a anterior é invalidada)
{ "ref": "<32 hex>", "estado": "pendente", "expira_em": "<ISO8601>",
  "canais": [ { "canal": "telegram", "url": "https://t.me/<bot>?start=<ref>" },
              { "canal": "whatsapp" } ] }
// membro já confirmado (reinscrição)
{ "estado": "confirmado" }
```

- `canais` contém só os canais **disponíveis** (ordem: telegram, whatsapp);
  pode ser `[]`.
  - telegram: `canais.telegram.enabled` verdadeiro **e** `token` **e**
    `bot_username` definidos.
  - whatsapp: `canais.whatsapp.enabled` verdadeiro, `provider=cloud`, `token`,
    `phone_number_id` **e** `template_confirmacao` definidos.
- `GET /api/canais/confirmacao/:ref`: `ref` pendente válida → `estado:"pendente"`
  com `canais` e `expira_em`; `ref` já usada (confirmada) → `200
  {estado:"confirmado", canais:[], expira_em}`; inexistente, expirada sem uso
  ou invalidada → `404 {error:"Confirmação não encontrada."}` (genérico).
  Também `404` com a feature desligada (`canais.inscricao.enabled`). Sem PII.
- Listas sem exigência: resposta do POST **idêntica** à Fase 0 (sem a chave).

### Endpoints da onda 2 (o frontend já implementa contra eles, com mock)

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| POST | `/api/canais/confirmacao/:ref/whatsapp` | — | `202 {enviado:1, expira_em}` · `404` · `409` (canal indisponível) · `429` |
| POST | `/api/canais/confirmacao/:ref/whatsapp/verificar` | `{codigo}` | `200 {estado:"confirmado"}` · `400` (código inválido) · `410` (expirado/tentativas) |

### Gestão (Bearer + posse do `cod_inep`)

| Método | Rota | Mudança |
|---|---|---|
| POST | `/listas` | aceita `exige_confirmacao` (boolean, default `false`) |
| PATCH | `/listas/:id` | **novo**: `{nome?, descricao?, exige_confirmacao?}` → `200` detalhe · `400` (nada a alterar / inválido) · `409` (nome duplicado) · `404` |
| GET | `/listas`, `/listas/:id` | + `exige_confirmacao`, `membros_confirmados`, `membros_pendentes` |
| GET | `/listas/:id/inscricoes` | cada membro + `estado` (`nao_exigida`\|`pendente`\|`confirmado`), `confirmado_via`, `confirmado_em` |

Estado derivado do membro: `confirmado` se `confirmado_em` não nulo; senão
`pendente` se a lista exige; senão `nao_exigida`. `membros_pendentes` conta os
pendentes só quando a lista exige (senão `0`).

### Modelo (para a onda 2 consumir)

`Roles::Business::Canal::Confirmacao` (ou métodos no role de listas):
`abrir_ref(membro_id, inscricao_id)` → `{ref, expira_em}`;
`estado_ref(ref)`; `concluir(ref|membro, via => 'telegram'|'whatsapp',
telegram_chat_id?)` → membro `confirmado_em/via`, `validado=true`, ref
`usada_em`; `registrar_conflito(ref)` → `canal_inscricoes.conflito=true`.

## WBS

| ID | Trilha | Escopo | Depende | Status | Evidência |
|----|--------|--------|---------|--------|-----------|
| M1 | T-A | Migration `canal_confirmacao_listas` (deploy/revert/verify gate) | — | 🟢 | `ci_db.sh verify` ok; revert → deploy ok |
| M2 | T-A | Modelo: refs (hash, TTL 24h, invalidação), estado, concluir, conflito | M1 | 🟢 | `t/02-models/canal_confirmacao.t` |
| M3 | T-A | AppConfig: folhas `canais.telegram.*` + `canais.whatsapp.template_*`; disponibilidade de canais | — | 🟢 | `t/02-models/app-config.t` |
| A1 | T-A | POST inscrição com `confirmacao`; GET `confirmacao/:ref` | M2,M3 | 🟢 | `t/04-api/canais/confirmacao.t` |
| A2 | T-A | Gestão: `exige_confirmacao`, PATCH, contadores, estado por membro | M2 | 🟢 | `t/04-api/canais/gestao.t` |
| F1 | T-B | `ListasPage`: toggle, selo, filtro, contadores | contrato | 🟢 | vitest (ListasPage/gestorCanaisApi) |
| F2 | T-B | `InscricaoPublicaPage`: passo 2 (Telegram, WhatsApp, polling) | contrato | 🟢 | vitest (InscricaoPublicaPage/ConfirmacaoTelefone) |
| T1 | coord. | verificação independente, commit, deploy da onda | M1..F2 | ⚪ | |

Onda 2 (depois): `Telegram::Updates`, webhook, task de polling, WhatsApp
template + endpoints de código. Onda 3: integração, e2e, docs, PR.

## Log de decisões

- **2026-10-11 — Perguntas em aberto da spec seguem a proposta:** `ref` válida
  por 24h; página consulta o estado a cada 3s por até 5 min; `chat_id`
  confirmado em `canal_lista_membros.telegram_chat_id` (sem tocar
  `clean.contatos`).
- **2026-10-11 — Config do bot público na onda 1.** As folhas
  `canais.telegram.*` e `canais.whatsapp.template_*` entram já na onda 1 porque
  a disponibilidade dos canais (resposta do POST) depende delas; o uso efetivo
  (envio/recebimento) é da onda 2.
- **2026-10-11 — GET de `ref` usada responde `confirmado`** (não 404), para a
  página pública, que consulta o estado, enxergar a conclusão feita no Telegram.
- **2026-10-11 — 429 no GET de confirmação (aprovado pelo coordenador).** O
  GET tem bucket de rate limit próprio (`rate_max × 6` por janela, 60/min no
  default), separado do POST: o limite do POST (10/min) quebraria o polling de
  3s (20/min). O cliente ignora 429 e tenta no próximo tick.
- **2026-10-11 — Ref de 128 bits completos** (`gen_random_bytes(16)` em hex,
  pgcrypto já presente); só `sha256(lc ref)` é gravado; `expira_em` em ISO 8601
  UTC.
- **2026-10-11 — Ref aberta na mesma transação da inscrição**; a API pública
  não expõe ids internos.
- **2026-10-11 — `concluir` idempotente** (preserva o primeiro
  `confirmado_em/via`); `registrar_conflito` só com ref pendente e não altera
  membro.
- **2026-10-11 — Ligar `exige_confirmacao` numa lista com membros** não abre
  refs para eles: passam a contar como `pendente` e só recebem ref ao se
  reinscrever (confirmação retroativa é fora de escopo, spec).
- **2026-10-11 — UX:** `confirmacao` tem precedência sobre `duplicado` na
  página; ao esgotar 5 min de polling, a página oferece "Verificar
  novamente"; o toggle "Exigir confirmação" fica no detalhe da lista (não havia
  edição de lista na UI).

## Verificação independente (coordenador, onda 1)

- **Migrations:** `ci_db.sh verify` → `canal_confirmacao_listas .. ok`,
  *Verify successful*.
- **Backend:** `prove -l t/02-models/ t/04-api/canais/ t/04-api/admin/
  t/03-plugins/channel/ t/04-api/gestor*` → 37 arquivos / 298 testes; falham só
  `City.t` (#21) e `indicators_quality.t` (#8), **idênticas no `main` limpo**
  (worktree) — pré-existentes.
- **Contrato:** campos conferidos lado a lado (`exige_confirmacao`,
  `membros_confirmados/pendentes`, `estado`, `confirmado_via/em`, `canais[].url`,
  `expira_em`).

## Onda 2 — contrato (congelado)

Mantém tudo da onda 1. Os endpoints do WhatsApp já descritos acima passam a
existir no backend **exatamente** como estão (o frontend já os consome).

### Público

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| POST | `/api/canais/confirmacao/:ref/whatsapp` | — | `202 {enviado:1, expira_em}` · `404` · `409` · `429` |
| POST | `/api/canais/confirmacao/:ref/whatsapp/verificar` | `{codigo}` | `200 {estado:"confirmado"}` · `400` · `410` |
| POST | `/api/canais/telegram/webhook` | update do Telegram (JSON) | `200 {ok:1}` · `401` (header `X-Telegram-Bot-Api-Secret-Token` ausente/errado) · `404` (feature desligada ou `recebimento` ≠ `webhook`) |

- WhatsApp: `expira_em` do **código** (TTL 10 min); limite de 3 envios por
  ref e por telefone em 1h (`429`); `409` se o canal whatsapp não está
  disponível; `410` em código expirado ou tentativas excedidas (5).
- Webhook: sempre `200` para updates válidos, mesmo os ignorados (o Telegram
  não deve reenviar).

### Admin (Bearer admin, mesmo guard de `/api/admin/config`)

| Método | Rota | Saída |
|---|---|---|
| GET | `/api/admin/canais/telegram/status` | `200 {enabled, recebimento, bot_username, webhook:{url, pending_update_count, last_error_message}?, polling:{ativo, offset}}` |
| POST | `/api/admin/canais/telegram/webhook` | `200 {ok:1, url}` · `409` (recebimento ≠ webhook, ou sem `public_base_url`/secret) · `502` (Telegram recusou) |
| DELETE | `/api/admin/canais/telegram/webhook` | `200 {ok:1}` · `502` |
| POST | `/api/admin/canais/telegram/polling` | `202 {ok:1, job_id}` (ou `200 {ok:1, ja_ativo:1}`) · `409` (recebimento ≠ polling ou bot desligado) |

URL do webhook: `<canais.inscricao.public_base_url>/api/canais/telegram/webhook`.

### Comportamento do bot (Telegram::Updates)

- `/start <ref>` com ref pendente → grava `telegram_chat_pendente`, responde
  com teclado `request_contact` ("Compartilhar meu número", `one_time_keyboard`).
- `contact` com `user_id == from.id` → localiza a ref pendente pelo `chat_id`
  → número normalizado (tolerância ao `55`) igual ao `telefone_norm` →
  `concluir(via=telegram, telegram_chat_id)` e resposta de sucesso (remove o
  teclado); diferente → `registrar_conflito`, resposta "número não confere".
- contato de terceiro → recusa; `/start` sem ref válida, ou qualquer outra
  mensagem → resposta fixa curta. Rate limit simples por `chat_id`.
- Cada envio do bot registra em `canal_mensagens` (operação `confirmacao`).

### Polling

Task Minion `telegram_polling`: `getUpdates(offset, timeout=25)` → `handle` →
persiste `update_offset` em `canal_telegram_estado` → reagenda a si mesma
enquanto `enabled` e `recebimento=polling`. Lock Minion
`telegram_polling:<bot>` garante um único job ativo. Iniciada pelo endpoint
admin e, no boot do worker, se a config pedir polling.

### Frontend (onda 2)

`ConfigPage`, grupo "Telegram (bot público)": painel de status e ações
"Registrar webhook" / "Remover webhook" (modo webhook) e "Iniciar polling"
(modo polling), contra os endpoints admin acima.

| ID | Trilha | Escopo | Status |
|----|--------|--------|--------|
| B1 | T-A | `Channel::Telegram::Updates` + envio com teclado pelo bot público | 🟢 |
| B2 | T-A | Webhook público + endpoints admin (status/webhook/polling) | 🟢 |
| B3 | T-A | Task `telegram_polling` (offset, lock, reagendamento) | 🟢 |
| B4 | T-A | WhatsApp: template de autenticação + endpoints de código | 🟢 |
| F3 | T-B | ConfigPage: status e ações do bot público | 🟢 |

### Log de decisões — onda 2

- **Desvios da T-A aceitos pelo coordenador:**
  - `POST …/whatsapp` → `502` quando a Meta falha (registrado em
    `canal_mensagens`, não conta no limite); o cliente mostra erro genérico.
  - `POST …/whatsapp` com ref já confirmada → `404` (ref usada); `…/verificar`
    com ref confirmada → `200 {estado:"confirmado"}` (idempotente).
  - Limite de envios: 3 por ref (total) e 3 por telefone em 1h (só `sent`).
  - Webhook: `404` quando o **bot público** está desligado/incompleto (não
    `canais.inscricao.enabled`); segredo não configurado → `401`.
  - Admin: `DELETE webhook` sem token → `409`; status traz `webhook.erro`
    quando `getWebhookInfo` falha.
  - Um código WhatsApp vale para qualquer ref do mesmo telefone
    (`Channel::Confirmation` é chaveado por telefone) — prova a mesma posse.
- **Bot só em conversa privada**; grupos e updates sem `message` são
  ignorados; rate limit 20 updates/min por `chat_id` (memória).
- **Polling:** cada job faz um ciclo, grava o offset por update (nunca
  retrocede), reagenda com 1s (backoff 5s→5min em erro; `409` de webhook ativo
  chama `deleteWebhook`). Início automático no evento `wait` do primeiro laço
  do `minion worker`.
- **Frontend:** painel de status como componente próprio
  (`TelegramPublicoStatus`), visível em qualquer folha do grupo
  `canais_telegram`; botão extra "Atualizar status".

## Verificação independente (coordenador, onda 2)

- **Backend:** `prove -l t/02-models/ t/04-api/canais/ t/04-api/admin/
  t/04-api/gestor* t/03-plugins/ -r t/05-tasks/telegram_polling.t
  t/05-tasks/bot_telegram.t t/05-tasks/bot_notifier.t` → 65 arquivos / 428
  testes; falham só 6 arquivos **idênticos no `main` limpo**: `City.t`,
  `domain/quality.t`, `indicators/quality.t`, `indicators_quality.t`,
  `03-plugins/analytics.t` (mock em `/tmp/user/1000/opencode`) e
  `middlewares/session.t`. `check_dependencies.pl` OK.
- **Frontend:** `vitest run` → 83 arquivos / 511 testes PASS; `vite build` OK.
- **Contrato:** admin devolve `{error}` em 409/502 e `webhook.url` nulo quando
  não registrado, como o painel espera.

## Onda 3 — integração, e2e e fecho (coordenador)

- **Docs funcionais** atualizadas (`listas-autoinscricao`, `canais-de-comunicacao`,
  `painel-configuracao`, índice).
- **Achado de infra:** deploys do Rex sem `EDUMAPS_CONFIG_MASTER_KEY` na shell
  gravavam a chave vazia nas units do `backend.edumaps` (segredos ilegíveis).
  Corrigido com trava no Rexfile (aborta) + regra no AGENTS.md; dev usa chave
  própria em `~/.config/edumaps/dev_master_key`.
- **E2E (dev, CDP):** verde — ver `docs/e2e/cobertura.md`, rodada #212. Telegram
  simulado pelo webhook com bot fictício; app real do Telegram e WhatsApp Cloud
  não exercitados (credenciais externas).
- **Validação visual** aprovada pelo developer.
