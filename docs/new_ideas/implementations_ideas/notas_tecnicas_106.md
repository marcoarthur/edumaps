# Nota técnica 106 — Canais de comunicação: núcleo (PR #207)

## Resumo

O EduMaps notificava e conversava com gestores por caminhos ad-hoc (e-mail por
`Net::SMTP` espalhado, bot de Telegram isolado, sem histórico unificado). Este
ciclo cria uma **camada de canais de comunicação** no backend: uma hierarquia de
classes onde cada canal (e-mail, WhatsApp, Telegram) sabe **validar** um
endereço, **confirmar a posse** desse endereço (envio e conferência de um
código) e **registrar histórico** do que foi enviado, para quem e com que
propósito.

Entrega: 3 commits na branch `feat/backend-canais-comunicacao` → **PR #207**
(merge `e0a16b6`).

**Escopo deliberadamente restrito**: só o **núcleo** (biblioteca + migrations +
config + testes). Sem API, sem UI, sem envio em massa (listas ficam para a
fase 2) e sem documentação funcional — esta última adiada para o ciclo de
integração, quando houver **capacidade de negócio** exposta ao usuário (o
anti-padrão do `docs/funcionalidades/` é documentar implementação; sem API/UI
não há capacidade para descrever). O pre-commit apenas **avisa** sobre a
ausência de doc, não bloqueia.

## Decisões (perguntadas ao developer no planejamento)

1. **Canais v1** = **E-mail + WhatsApp + Telegram**. A base já cobre os três
   formatos de endereço (e-mail, telefone, chat-id) sem inventar canais exóticos.
2. **Envio plugável por canal**: Telegram **real** (reusa o bot existente
   `EduMaps::Bots::Telegram`); E-mail **real** via SMTP; WhatsApp com dois
   provedores — `link` (stub que só monta o `wa.me`, útil em dev) e `cloud`
   (Cloud API da Meta, com confirmação).
3. **Endereços sobrepõem** a tabela existente `clean.contatos` — **sem
   refatorá-la**. As novas capacidades vivem em tabelas próprias
   (`canal_confirmacoes` / `canal_mensagens`), com FK para os contatos. Mexer em
   `clean.contatos` teria efeito em cascata fora do escopo.
4. **Histórico guarda metadados *e* corpo** da mensagem. É PII, com acesso
   restrito e **mascaramento na leitura** (helper `mask`). Retenção fina/expurgo
   fica como pendência.
5. **Listas (fase 2)** terão como alvo contatos/grupos da escola, com dedupe e
   **opt-out**; consentimento/opt-out é adiado, deixando apenas o **gancho** no
   modelo agora.
6. **Confirmação** usa código de **6 dígitos**, persistido apenas como
   **hash+salt** (nunca plaintext), com **TTL ~10 min** e `max_attempts`.

## Arquitetura

### `EduMaps::Channel` — fábrica

Ponto de entrada único: `%TYPES`, `types`, `is_valid_type`, `build($name, %args)`
e `build_from_config($name, $config)`. O carregamento da classe é feito com
`eval { require $file }` — **não** com `Mojo::Loader::load_class`, que devolve
`1` (sucesso) para uma classe inexistente e esconderia o erro de configuração.

### `Channel::Base` — template method

Herda de `Mojo::EventEmitter`. O método público `send_message` / `send_message_p`
(versão promíssica) orquestra sempre a mesma sequência:

```
valida endereço → registra 'queued' → _deliver (subclasse) → histórico → emite evento
```

A subclasse só implementa o que difere:

- `_address_regex`, `_normalize_address` — validação/normalização;
- `_deliver` / `_deliver_p` — entrega concreta;
- `_confirm_template` — corpo da mensagem de confirmação;
- capacidades: `address_kind`, `supports_confirm`, `max_len`.

Eventos locais no v1: `message.invalid|queued|sent|failed` e
`confirm.requested|verified|failed`. A ponte para o **`EventBus`** (para a
telemetria de sessão, PR #204) fica para o ciclo de integração — de propósito,
para não acoplar o núcleo ao bus antes de haver consumidor.

Nota de implementação: em `Mojo::EventEmitter` os handlers recebem o **emitter
como primeiro argumento**; ao registrar handlers num laço, capturar o nome do
evento numa `my $name` — o `$_` do `for` é dinâmico e muda sob o handler.

### Canais

- **`Channel::Email`**: `Net::SMTP` nativo (núcleo do Perl, sem dependência de
  `Email::Sender`/`MIME::Lite`, que **não** estão instalados). TLS explícito:
  porta 465 = SMTPS implícito, 587 = STARTTLS pós-conexão; ambos exigem
  `IO::Socket::SSL`. Cabeçalho `From`/`Subject` com MIME-word (`Encode`), corpo
  UTF-8 8bit. Sem SMTP configurado, a entrega **falha com erro explícito** —
  nunca silenciosa.
- **`Channel::WhatsApp`**: provedor `link` → não envia, apenas monta o link
  `wa.me` (testes/dev; `can_confirm` falso); provedor `cloud` → HTTP da Cloud
  API da Meta, com `supports_confirm=1`.
- **`Channel::Telegram`**: delega ao bot já existente (`EduMaps::Bots::Telegram`)
  em vez de duplicar a integração.

### `Channel::Operacoes`

Lista canônica de tipos de operação (`aviso`, `informacao`, `pedido`, …) em
**espelho do CHECK** da coluna no banco. Fonte única em Perl; o banco valida de
novo.

### `Channel::Confirmation` / `Channel::History`

Persistência nas tabelas novas. Confirmação guarda `code_hash`+`salt`, `expira_em`
e `tentativas`; histórico grava canal, operação/motivo, destinatário, status,
corpo e um **referente polimórfico** (`referente_tipo`/`referente_id`) para
ligar a mensagem à operação de negócio que a originou.

## Persistência (migrations Sqitch)

Ambas **anexadas ao fim** do `sqitch.plan` (nunca reordenar/editar change já
deployada — quebra o `change_id` e o registry):

- **`canal_confirmacoes`** — requires `gestor_reunioes`.
- **`canal_mensagens`** — requires `canal_confirmacoes`.

FKs para `clean.contatos`. Os `verify/*.sql` seguem o estilo **gate** da issue
#160 (`DO $$ … RAISE EXCEPTION '…' $$;`): no Sqitch 1.6.1 um `SELECT` que devolve
`f` conta como sucesso, só **erro** reprova.

## Configuração

Nova categoria **`canais`** no `%TREE` do `AppConfig`, com getters
`email_config` / `whatsapp_config` / `telegram_config` / `channel_config` e o
helper `_canais_group_config`. `config_tree` passa a listar a categoria; a lista
de categorias (`Sistema, Integrações, Canais de comunicação, Aparência,
Comportamento, Outros`) é refletida em `t/02-models/app-config.t` e
`t/04-api/admin/config.t`. **Telegram não ganha chaves novas**: reusa
`integrations.bot_telegram.*`.

## Segurança

- Código de confirmação **nunca** em plaintext (hash+salt), com TTL e limite de
  tentativas.
- Corpo das mensagens é PII: leitura mascarada; expurgo/retenção é pendência.
- Credenciais SMTP vêm da config (senha cifrada), fora do repositório.

## Validação

- `prove -l t/03-plugins/channel/` + `app-config.t` + `admin/config.t` →
  **PASS, 89 testes** (com `EDUMAPS_DB_HOST=127.0.0.1`, Docker).
- Sem `EDUMAPS_DB_HOST` (default `ubatexu.lan`, sem as tabelas novas): 65 testes
  + 2 arquivos `skip_all` → **PASS**.
- `sqitch verify canal_confirmacoes canal_mensagens` → **ok**.
- `script/check_dependencies.pl` → **verde**.

Convenções de teste aprendidas: `Imports` exporta `ok is isnt like unlike
isa_ok pass fail plan done_testing subtest diag note` — **não** exporta
`is_deeply` (mas `is` faz comparação profunda de refs); `use ok` emite teste em
tempo de compilação, então **não** pode coexistir com `plan skip_all`; em
`Bareword->metodo(...)` usar parênteses para evitar sintaxe de objeto indireto.

## Deploy

- `rex prepare` + `rex -H database.edumaps deploy_db_dev` +
  `rex -H backend.edumaps deploy_backend_dev`.
- Tabelas confirmadas na **base real** (`database.edumaps`):
  `canal_confirmacoes|canal_mensagens` (atenção: há **dois** contentores DB e o
  alvo do Rex é `database.edumaps`, 172.19.198.3).
- Módulos carregam no ambiente real do `backend.edumaps` (`carton exec`, perl
  5.36): `load ok`.
- Imagens locais `sqitch`, `backend`, `minion` reconstruídas; md5 de
  `Channel.pm`/`Email.pm`/`cpanfile` batem local × contentor; app responde 200.

## Armadilha: o gate de dependências exige declarar até módulos core

O `check_dependencies.pl` (CI, passo de inventário **antes** da suíte) exige que
**todo** `use`/`require` literal de `lib/`+`script/` esteja no `cpanfile` — e
isso inclui módulos **core**. `Channel::Email` faz `require Net::SMTP`, que não
estava declarado → CI vermelha no passo de inventário (a suíte nem chegou a
rodar). Fix: `requires "Net::SMTP"` + `requires "IO::Socket::SSL"` no
`cpanfile`, com `require IO::Socket::SSL` **explícito** no ramo TLS do canal
(a leitura do `starttls` acontece no meio de `Net::SMTP`, mas declarar/tornar
explícito é a convenção do repo).

## Notas

- **CI vermelha por falha pré-existente**: `t/03-plugins/middlewares/session.t`
  (linha 66, *cache HIT* na busca de escolas) falha de forma **idêntica no
  `main`** (runs `38129720701` de 11/10 e `38088302661` de 10/10) e passa 3×
  local. Não é regressão deste ciclo; registrado no PR #207.
- **Docs funcionais adiados** para o ciclo de integração (decisão do plano). O
  banner do `ConfigPage.svelte` fica levemente desatualizado (texto informativo),
  mas a página renderiza a nova categoria dinamicamente.

## Pendências

Integração (API + UI + docs funcionais + banner da config); listas em massa
(`Channel::List::*` com fila, dedupe, opt-out/consentimento); ponte
`Channel` → `EventBus`; provedor real de WhatsApp (hoje `cloud`/`link`);
retenção/expurgo do corpo das mensagens.
