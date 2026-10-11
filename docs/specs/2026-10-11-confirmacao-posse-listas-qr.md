# Especificação de Requisitos — Confirmação de posse do telefone nas listas com QR (Fase 1)

**Data:** 2026-10-11
**Autor:** Tech Lead / Product Engineer (agente) com o developer
**Versão:** 1.0
**Issue relacionado:** #212
**Depende de:** listas com QR (#208, PR #209) e núcleo de Canais
(`EduMaps::Channel`, PR #207)
**Spec anterior:** [`2026-10-11-listas-qr-autoinscricao-contatos.md`](./2026-10-11-listas-qr-autoinscricao-contatos.md)
(Fase 0, contrato congelado — esta spec **estende** aquele contrato, sem
quebrá-lo)

---

# ENTREGÁVEL 1 — ISSUE

## Título

**Confirmação de posse do telefone nas listas com QR (Telegram + WhatsApp — Fase 1)**

## Contexto

A Fase 0 (#208) entregou listas nomeadas com QR para autoinscrição: qualquer
pessoa com o QR registra **nome + telefone** numa lista da escola. Por decisão de
produto, o telefone entrou **sem validação** (`validado=false`). O núcleo de
Canais (#207) já tem a peça de **confirmação de posse** (`Channel::Confirmation`:
código de 6 dígitos, só hash+salt, TTL e limite de tentativas), mas ela ainda não
está ligada a nenhum fluxo.

## Problema

O gestor não sabe se o telefone informado é **de quem se inscreveu**. Erros de
digitação, números de terceiros e inscrições de má-fé entram na lista
indistinguíveis dos números corretos. Sem essa garantia, a lista não serve de
base confiável para comunicação futura (Fase 3: envio em massa).

## Objetivo

Permitir que o gestor **exija confirmação de posse** numa lista. Quem se inscreve
nessa lista confirma o número **no próprio celular**, logo após o formulário,
por um de dois caminhos:

- **Telegram** (caminho principal, sem custo): abre o bot da escola por um link,
  toca em "Compartilhar meu número" e o Telegram entrega o número da conta, já
  verificado por ele;
- **WhatsApp** (quando configurado): recebe um código de 6 dígitos e o digita na
  página.

O gestor vê, por membro, se o telefone está **pendente** ou **confirmado**, e por
qual canal.

Métrica de valor: % de membros com telefone confirmado nas listas que exigem
confirmação.

## Escopo (Fase 1)

1. Opção por lista **"Exigir confirmação do telefone"** (padrão: desligada →
   comportamento da Fase 0 inalterado).
2. Após a inscrição numa lista que exige confirmação, a página pública oferece os
   canais de confirmação **disponíveis** (configurados e ativos).
3. **Telegram:** bot **dedicado** ao público, deep link com nonce de uso único,
   pedido de compartilhamento de contato e conferência do número.
4. **WhatsApp:** envio de código por **template de autenticação** da WhatsApp
   Cloud API e verificação na página.
5. Recebimento de atualizações do bot em dois modos configuráveis:
   **polling** (dev, sem URL pública) e **webhook** (produção).
6. Membro entra na lista como **pendente** e passa a **confirmado** ao concluir;
   o gestor vê o estado, o canal e a data, e pode filtrar.
7. Configuração dos novos itens no Painel de Configuração (categoria Canais).

## Fora de escopo (Fase 1)

- Pedir confirmação **retroativa** de membros já existentes (inscritos na Fase 0
  ou que abandonaram a confirmação) — exige envio ativo, fica para a Fase 3.
- Canal e-mail, expiração/`max_usos` na UI, retenção/expurgo, consentimento
  versionado na UI (Fase 2).
- Envio em massa, opt-out, múltiplos QR por lista (Fase 3).
- Uso do bot dedicado para qualquer outra conversa além da confirmação (o bot
  responde só ao fluxo de confirmação).
- Substituir o bot de notificações internas (`integrations.bot_telegram`), que
  continua como está.

## Requisitos Funcionais

### RF-101: Exigir confirmação por lista — Essencial
**Ator:** gestor autenticado.
**Descrição:** O sistema deve permitir que o gestor ligue/desligue, por lista, a
exigência de confirmação de posse do telefone.
**Aceite:**
- [ ] Criar lista aceita `exige_confirmacao` (boolean, default `false`).
- [ ] `PATCH /api/gestor/:cod_inep/canais/listas/:id` altera `exige_confirmacao`
      (e `nome`/`descricao`); `403` fora da escola do gestor.
- [ ] Listas existentes ficam com `exige_confirmacao=false` (Fase 0 intacta).
- [ ] Mudar a opção **não** altera membros já existentes.

### RF-102: Inscrição em lista que exige confirmação — Essencial
**Ator:** inscrito (não autenticado).
**Descrição:** Ao registrar-se numa lista que exige confirmação, o sistema deve
gravar o membro como **pendente** e devolver uma referência opaca de confirmação
e os canais disponíveis.
**Aceite:**
- [ ] `POST /api/canais/inscricao/:token` devolve, além do contrato da Fase 0,
      `confirmacao: { ref, estado:"pendente", canais:[...] }` quando a lista exige.
- [ ] `ref` é um nonce aleatório de 128 bits, de uso único, com validade
      (default 24h); não revela ids internos.
- [ ] `canais` lista só os canais **ativos e configurados** (`telegram` com
      `url` do deep link; `whatsapp` sem dados extras).
- [ ] Sem nenhum canal disponível: o membro entra pendente e a resposta indica
      `canais: []` (a página informa que a escola confirmará depois). Nada falha.
- [ ] Inscrição repetida (mesmo telefone na mesma lista) de membro **pendente**
      gera nova `ref` (invalida a anterior); de membro **confirmado** não gera
      `ref` (`confirmacao.estado = "confirmado"`).
- [ ] Listas que não exigem confirmação mantêm a resposta da Fase 0 sem
      `confirmacao`.

### RF-103: Confirmação pelo Telegram (compartilhar contato) — Essencial
**Ator:** inscrito, no app do Telegram.
**Descrição:** O sistema deve confirmar a posse quando o inscrito abre o bot pelo
deep link e compartilha o **próprio** contato, cujo número coincide com o
informado na inscrição.
**Aceite:**
- [ ] Deep link `https://t.me/<bot_username>?start=<ref>`.
- [ ] Bot recebe `/start <ref>` válido → responde com teclado
      "Compartilhar meu número" (`request_contact`).
- [ ] Contato compartilhado com `contact.user_id == from.id` (o próprio
      usuário) e número normalizado igual ao `telefone_norm` da inscrição →
      membro **confirmado** (`confirmado_via='telegram'`), bot agradece.
- [ ] Número diferente → **não** confirma, marca `conflito=true` na inscrição,
      bot informa que o número não confere; nada é apagado.
- [ ] Contato de terceiro (`user_id` ausente ou ≠ `from.id`) → recusado.
- [ ] `ref` inválida, expirada ou já usada → mensagem genérica; nenhuma
      alteração.
- [ ] Mensagens fora do fluxo → resposta curta padrão; o bot não conversa.

### RF-104: Confirmação pelo WhatsApp (código) — Importante
**Ator:** inscrito, na página pública.
**Descrição:** O sistema deve enviar um código de 6 dígitos ao número inscrito
por template de autenticação da WhatsApp Cloud API e confirmar quando o código
digitado confere.
**Aceite:**
- [ ] `POST /api/canais/confirmacao/:ref/whatsapp` envia o código (reusa
      `Channel::Confirmation`, TTL 10 min, 5 tentativas) → `202`.
- [ ] `POST /api/canais/confirmacao/:ref/whatsapp/verificar {codigo}` →
      `200 {estado:"confirmado"}` ou `400` (código inválido) / `410`
      (expirado/tentativas excedidas).
- [ ] Reenvio limitado (default: 3 envios por `ref` e por telefone por hora) →
      `429` acima disso.
- [ ] Envio usa mensagem do tipo **template** (nome e idioma configuráveis);
      sem template configurado, o canal `whatsapp` não aparece como disponível.
- [ ] Código nunca é persistido nem devolvido pela API em claro.

### RF-105: Estado da confirmação na página pública — Essencial
**Ator:** inscrito.
**Descrição:** A página pública deve guiar a confirmação e refletir o estado,
inclusive quando a confirmação ocorre fora dela (Telegram).
**Aceite:**
- [ ] `GET /api/canais/confirmacao/:ref` → `{estado, canais, expira_em}` sem PII.
- [ ] A página mostra os botões dos canais disponíveis, consulta o estado
      periodicamente (ex.: a cada 3s, por até 5 min) e exibe "Telefone
      confirmado!" ao concluir.
- [ ] O inscrito pode sair sem confirmar; a página informa que a inscrição foi
      registrada como pendente.

### RF-106: Visão do gestor — estado de confirmação — Essencial
**Ator:** gestor autenticado.
**Descrição:** O sistema deve exibir, por membro, o estado da confirmação, o
canal e a data, com filtro e contagem.
**Aceite:**
- [ ] `GET .../listas/:id/inscricoes` inclui `estado`
      (`nao_exigida`/`pendente`/`confirmado`), `confirmado_via`, `confirmado_em`.
- [ ] Detalhe da lista traz `membros_confirmados` e `membros_pendentes`.
- [ ] Na `ListasPage`, coluna de estado com selo e filtro por estado; opção
      "Exigir confirmação" no criar/editar lista.

### RF-107: Bot dedicado e recebimento configuráveis — Essencial
**Ator:** administrador da instalação.
**Descrição:** O sistema deve permitir configurar o bot público e o modo de
recebimento sem deploy.
**Aceite:**
- [ ] Novos itens em Canais de comunicação: `canais.telegram.token` (segredo),
      `canais.telegram.bot_username`, `canais.telegram.recebimento`
      (`polling`|`webhook`), `canais.telegram.webhook_secret` (segredo),
      `canais.telegram.enabled`; `canais.whatsapp.template_confirmacao`,
      `canais.whatsapp.template_idioma`.
- [ ] Modo **polling**: um worker consome `getUpdates` (long polling) com
      `offset` persistido; sem perda nem reprocessamento de updates ao reiniciar.
- [ ] Modo **webhook**: `POST /api/canais/telegram/webhook` aceita só
      requisições com o header `X-Telegram-Bot-Api-Secret-Token` correto
      (`401` caso contrário); registrar/desregistrar o webhook é uma ação do
      admin.
- [ ] O bot de notificações internas (`integrations.bot_telegram`) **não** muda.

## Requisitos Não Funcionais

- **RNF-101 (Segurança):** `ref` de 128 bits, uso único, expirável, guardada só
  como hash; verificação do `user_id` do contato no Telegram; segredo do webhook
  comparado em tempo constante; tokens de bot e WhatsApp cifrados (AppConfig).
- **RNF-102 (LGPD):** o número recebido do Telegram serve **só** para comparar;
  guarda-se o `chat_id`/`user_id` do Telegram apenas se o inscrito confirmar, como
  endereço confirmado do canal (finalidade: comunicação da escola). Texto da
  página explica o que é compartilhado.
- **RNF-103 (Custo/antiabuso):** limites de envio do WhatsApp por `ref` e por
  telefone (cada mensagem tem custo); rate limit dos endpoints de confirmação
  igual ao da inscrição.
- **RNF-104 (Não destrutivo):** confirmação **marca**, nunca apaga; divergência
  vira `conflito`, não sobrescrita (mesmo modelo da Fase 0).
- **RNF-105 (Compatibilidade):** contrato público da Fase 0 preservado (campos
  só **acrescentados**); migrations **novas** — nenhuma change já deployada é
  editada (regra do `sqitch.plan`, AGENTS.md).
- **RNF-106 (Resiliência):** falha do Telegram/WhatsApp nunca derruba a
  inscrição: o membro fica pendente e o erro é registrado em
  `canal_mensagens`.

## Critérios de Aceite (visão do usuário)

- [ ] Gestor marca "Exigir confirmação" na lista "Responsáveis".
- [ ] Pai escaneia o QR, preenche nome+telefone e vê "Confirme seu telefone"
      com o botão **Telegram**.
- [ ] Tocando no botão, o Telegram abre o bot; ele toca em "Compartilhar meu
      número" e recebe "Telefone confirmado".
- [ ] De volta ao navegador, a página mostra "Telefone confirmado!" sem recarregar.
- [ ] O gestor vê o membro com selo **Confirmado (Telegram)**.
- [ ] Quem digitou um número que não é o seu não consegue confirmar e aparece
      como **Pendente** (com conflito registrado).
- [ ] Listas sem a opção continuam funcionando como na Fase 0.

## Riscos

| # | Risco | Impacto | Mitigação |
|---|-------|---------|-----------|
| R1 | Template de autenticação do WhatsApp não aprovado / sem conta Business | Médio | WhatsApp é opcional: sem template configurado o canal não aparece; Telegram cobre a Fase 1 |
| R2 | Inscrito não usa Telegram | Médio | WhatsApp como segunda opção; membro fica pendente sem erro |
| R3 | Webhook inviável em dev (sem HTTPS público) | Médio | modo polling (decisão do developer) |
| R4 | Polling e webhook ativos ao mesmo tempo (Telegram recusa `getUpdates` com webhook) | Baixo | modo único na config; trocar de modo chama `deleteWebhook`/`setWebhook` |
| R5 | Bot público recebe spam | Baixo | bot só reage a `/start <ref>` válida e ao contato; resto tem resposta fixa; rate limit por `chat_id` |
| R6 | Custo de mensagens WhatsApp por abuso | Médio | limites por `ref`/telefone/hora; rate limit; só após inscrição válida |
| R7 | Número no Telegram diferente do informado (troca de chip, DDI) | Baixo | normalização com/sem `55`; divergência vira `conflito`, não falha silenciosa |

## Dependências

- `Channel::Confirmation`, `Channel::Telegram`, `Channel::WhatsApp`,
  `Channel::History` (PR #207).
- Listas com QR: `canal_listas`, `canal_lista_membros`, `canal_inscricoes`,
  `Roles::Business::Canal::Listas`, `InscricaoPublicaPage`, `ListasPage` (PR #209).
- Minion (worker de polling); AppConfig (categoria `canais`).
- Externo: bot criado no @BotFather (token + username); para o WhatsApp, conta
  Business, `phone_number_id` e template de autenticação aprovado.

## Métricas de sucesso

- % de membros confirmados nas listas que exigem confirmação.
- Taxa de conclusão da confirmação (inscritos pendentes → confirmados) por canal.
- Tempo mediano entre inscrição e confirmação.
- Nº de conflitos (número divergente) por lista.
- Custo de envio WhatsApp por confirmação.

## Decisões já tomadas (com o developer, 2026-10-11)

1. **Canais:** Telegram **e** WhatsApp; **Telegram primeiro** (caminho principal).
2. **Obrigatoriedade:** **configurável por lista**, default desligado.
3. **Pendentes:** entram na lista como **pendente** e passam a confirmado
   (modelo não destrutivo).
4. **Sem confirmação retroativa** nesta fase.
5. **Recebimento do bot:** os dois modos, **polling em dev**, webhook em produção.
6. **Bot dedicado** ao público (`canais.telegram.*`), separado do bot de
   notificações internas.

## Perguntas em aberto

1. Texto definitivo das mensagens do bot e do template do WhatsApp (revisão da
   escola) — a implementação usa textos provisórios configuráveis no código.
2. Validade da `ref` (proposto: 24h) e da janela de polling na página (5 min).
3. Guardar o `chat_id` confirmado como endereço do contato em `clean.contatos`
   (útil para a Fase 3) ou só em `canal_confirmacoes`? Proposto: em
   `canal_lista_membros` (`telegram_chat_id`), sem tocar `clean.contatos`.

---

# ENTREGÁVEL 2 — PLANO DE IMPLEMENTAÇÃO

## Arquitetura proposta

```
┌─ Frontend Svelte ──────────────────────────────────────────────────────┐
│ ListasPage: toggle "Exigir confirmação" · selo/filtro de estado        │
│ InscricaoPublicaPage: passo 2 "Confirme seu telefone"                  │
│   ├─ botão Telegram → t.me/<bot>?start=<ref>                           │
│   ├─ WhatsApp: "Enviar código" → campo código → verificar              │
│   └─ polling GET /api/canais/confirmacao/:ref                          │
└───────────┬───────────────────────────────┬────────────────────────────┘
            │ Bearer                        │ público (ref = capability)
            ▼                               ▼
┌─ Backend Perl ─────────────────────────────────────────────────────────┐
│ Plugin::API::Gestor  PATCH lista (exige_confirmacao)                   │
│ Plugin::API::Canais  GET/POST confirmacao/:ref[/whatsapp[/verificar]]  │
│                      POST telegram/webhook (secret_token)              │
│ Roles::Business::Canal::Confirmacao (novo)                             │
│   abre ref · conclui (membro→confirmado) · conflito · estado           │
│ EduMaps::Channel::Telegram::Updates (novo)                             │
│   trata update: /start <ref> → request_contact; contact → conclui      │
│ Task::TelegramPolling (Minion, modo polling)                           │
│   getUpdates(offset, timeout=25) → Updates → reagenda a si mesmo       │
│ Channel::WhatsApp  + _deliver_template (authentication)                │
│ Channel::Confirmation  (reuso: código WhatsApp; hash da ref)           │
└───────────┬────────────────────────────────────────────────────────────┘
            ▼
     PostgreSQL clean.*  ·  api.telegram.org  ·  graph.facebook.com
```

**Separação de responsabilidades:** o tratamento de um update do Telegram é uma
função pura sobre o update (`Updates->handle($update)`), chamada pelos dois modos
de recebimento — o webhook e o job de polling só diferem na origem do update.

## Modelo de dados

Uma change Sqitch **nova**, anexada ao fim do plano:
`canal_confirmacao_listas [canal_listas_autoinscricao]`. Nenhuma change já
deployada é editada (só `ALTER` em tabelas existentes, numa change nova).

```sql
-- lista: exigência por lista (RF-101)
ALTER TABLE clean.canal_listas
  ADD COLUMN exige_confirmacao boolean NOT NULL DEFAULT false;

-- membro: estado da confirmação (RF-102/106); validado continua sendo o
-- booleano "telefone confirmado" e passa a ser preenchido pela confirmação.
ALTER TABLE clean.canal_lista_membros
  ADD COLUMN confirmado_em    timestamptz,
  ADD COLUMN confirmado_via   text CHECK (confirmado_via IN ('telegram','whatsapp')),
  ADD COLUMN telegram_chat_id bigint;        -- só quando confirmado via Telegram

-- referência pública de confirmação, ligada à inscrição (RF-102..105)
CREATE TABLE clean.canal_confirmacao_refs (
  id            bigserial   PRIMARY KEY,
  inscricao_id  bigint      NOT NULL REFERENCES clean.canal_inscricoes (id) ON DELETE CASCADE,
  membro_id     bigint      NOT NULL REFERENCES clean.canal_lista_membros (id) ON DELETE CASCADE,
  ref_hash      text        NOT NULL UNIQUE, -- sha256 da ref; a ref em claro só vai ao inscrito
  expira_em     timestamptz NOT NULL,
  usada_em      timestamptz,                 -- uso único
  invalidada_em timestamptz,                 -- nova inscrição do mesmo membro
  envios_whatsapp integer   NOT NULL DEFAULT 0,
  telegram_chat_pendente bigint,           -- chat que abriu /start <ref>, aguardando o contato
  created_at    timestamptz NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_canal_confirmacao_refs_membro ON clean.canal_confirmacao_refs (membro_id);

-- estado do recebimento do bot (modo polling)
CREATE TABLE clean.canal_telegram_estado (
  bot_username text   PRIMARY KEY,
  update_offset bigint NOT NULL DEFAULT 0,
  updated_at    timestamptz NOT NULL DEFAULT NOW()
);
```

Estado derivado do membro (não é coluna): `nao_exigida` se a lista não exige e
`confirmado_em IS NULL`; `confirmado` se `confirmado_em IS NOT NULL`; senão
`pendente`. O código do WhatsApp continua em `canal_confirmacoes` (reuso direto
de `Channel::Confirmation`, com `endereco = telefone_norm` e `canal='whatsapp'`).

`verify` no estilo gate (`DO $$ … RAISE EXCEPTION`), colunas checadas por
`pg_attribute`; `revert` com `DROP`/`ALTER … DROP COLUMN`.

## Endpoints da API

**Gestão (Bearer + posse do `cod_inep`):**

| Método | Rota | Mudança |
|---|---|---|
| POST | `/api/gestor/:cod_inep/canais/listas` | aceita `exige_confirmacao` |
| PATCH | `/api/gestor/:cod_inep/canais/listas/:id` | **novo**: `nome`, `descricao`, `exige_confirmacao` |
| GET | `/api/gestor/:cod_inep/canais/listas[/:id]` | + `exige_confirmacao`, `membros_confirmados`, `membros_pendentes` |
| GET | `/api/gestor/:cod_inep/canais/listas/:id/inscricoes` | + `estado`, `confirmado_via`, `confirmado_em` |

**Público (sem auth):**

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| POST | `/api/canais/inscricao/:token` | (Fase 0) | (Fase 0) + `confirmacao?: {ref, estado, canais:[{canal, url?}], expira_em}` |
| GET | `/api/canais/confirmacao/:ref` | — | `200 {estado, canais, expira_em}` · `404` |
| POST | `/api/canais/confirmacao/:ref/whatsapp` | — | `202 {enviado:1, expira_em}` · `404` · `409` (canal indisponível) · `429` |
| POST | `/api/canais/confirmacao/:ref/whatsapp/verificar` | `{codigo}` | `200 {estado:"confirmado"}` · `400` · `410` |
| POST | `/api/canais/telegram/webhook` | update do Telegram | `200` · `401` (secret inválido) · `404` (modo ≠ webhook) |

**Admin (Bearer admin):** `POST /api/admin/canais/telegram/webhook` (registra
`setWebhook` com `secret_token`) e `DELETE` (chama `deleteWebhook`).

Erros genéricos para `ref` inválida/expirada/usada (não revelar existência).

## Fluxos

**Telegram (principal):**
1. `POST inscricao` numa lista que exige → membro pendente + `ref` (hash gravado)
   → resposta com `url = https://t.me/<bot>?start=<ref>`.
2. Inscrito toca no botão → Telegram abre o bot → envia `/start <ref>`.
3. Update chega (webhook ou polling) → `Updates->handle`: resolve `ref` (válida,
   não usada) → grava `telegram_chat_pendente = chat_id` na `ref` (persistido,
   sobrevive a reinício do worker) → responde com teclado `request_contact`.
4. Inscrito compartilha o contato → `handle`: localiza a `ref` pendente pelo
   `chat_id`, confere `contact.user_id == from.id`, normaliza `phone_number` e compara com `telefone_norm` →
   conclui: `ref.usada_em`, membro `confirmado_em/via/telegram_chat_id`,
   `validado=true` → responde "Telefone confirmado". Divergência → `conflito`.
5. Página pública, consultando `GET confirmacao/:ref`, vê `confirmado`.

**WhatsApp:**
1. Página: "Enviar código" → `POST confirmacao/:ref/whatsapp` →
   `Channel::WhatsApp->confirm_start(telefone_norm)` com template
   (`type: template`, componente body com o código e botão *copy code*).
2. Inscrito digita o código → `POST …/verificar` →
   `Channel::Confirmation->verify` → conclui como no Telegram (via `whatsapp`).

**Polling (dev):** task Minion `telegram_polling` faz `getUpdates(offset,
timeout=25)`, trata cada update, persiste o `offset` e **reagenda a si mesma**
(`enqueue` com `delay` curto). Um único job ativo por bot (lock Minion
`telegram_polling:<bot>`). Ao ligar o modo polling, o admin dispara o primeiro
job (ação no painel ou no boot do worker se `recebimento=polling`).

## Telas/UX mínimas

- **ListasPage:** checkbox "Exigir confirmação do telefone" no criar/editar;
  coluna **Estado** (Confirmado · Pendente · Não exigida) com selo e canal;
  filtro por estado; contadores no cabeçalho da lista.
- **InscricaoPublicaPage — passo 2 "Confirme seu telefone":** texto curto do
  que é compartilhado; botão **Confirmar pelo Telegram** (link); bloco
  **Receber código pelo WhatsApp** (enviar → campo de 6 dígitos com
  `inputmode="numeric"` e `autocomplete="one-time-code"` → verificar);
  estados: aguardando, confirmado, expirado, sem canais ("a escola confirmará
  depois"), erro. Link "Confirmar depois" encerra com a mensagem de pendência.
- **ConfigPage:** novos itens aparecem automaticamente pela árvore do AppConfig;
  ação "Registrar webhook" no grupo do Telegram (só no modo webhook).

## Validações

- `ref`: 32 hex; hash existente; não expirada, não usada, não invalidada.
- Código WhatsApp: 6 dígitos.
- Update do Telegram: só `message` com `/start <ref>` ou `contact`; demais tipos
  ignorados com `200` (o Telegram não deve reenviar).
- Telefone do Telegram: normalização igual à da Fase 0 + tolerância ao prefixo
  `55` (comparar com e sem o código do país).

## Autenticação / Autorização

- Gestão: inalterada (`_require_gestor` + posse).
- Público: a `ref` é a capability; concede apenas ler o estado e confirmar.
- Webhook: `X-Telegram-Bot-Api-Secret-Token` (comparação em tempo constante).
- Admin: registrar/desregistrar webhook exige papel admin.

## Testes

- **Backend:**
  - `t/02-models/canal_confirmacao.t`: abrir `ref` (hash, validade,
    invalidação ao reinscrever), concluir (membro confirmado, `validado=true`),
    conflito (número divergente), `ref` usada/expirada, estado derivado.
  - `t/03-plugins/channel/telegram_updates.t`: `/start` válido/inválido,
    contato próprio × de terceiro, número igual × divergente, mensagens fora do
    fluxo — com `Bots::Telegram` mockado (sem rede).
  - `t/03-plugins/channel/whatsapp_template.t`: payload do template
    (`Mojo::UserAgent` mockado), canal indisponível sem template.
  - `t/04-api/canais/confirmacao.t`: contrato público (200/202/400/404/409/410/
    429), webhook (401 sem secret, 404 fora do modo), compatibilidade da Fase 0
    (lista sem exigência → resposta sem `confirmacao`).
  - `t/04-api/canais/gestao.t`: `PATCH`, contadores, campos de estado.
  - `t/05-tasks/telegram_polling.t`: offset persistido e reagendamento (mock).
  - Migrations: `ci_db.sh` com `sqitch verify` gate; `revert` testado.
- **Frontend (`vitest`):** passo 2 da `InscricaoPublicaPage` (canais
  disponíveis, envio/verificação do código, polling até confirmado, sem canais,
  expirado); `ListasPage` (toggle, selo, filtro).
- **e2e (CDP):** lista com exigência → inscrição → passo 2 visível → confirmação
  WhatsApp com provedor mockado **ou** simulação de update do Telegram via
  `POST` no webhook de teste → página mostra confirmado → gestor vê selo. O
  passo real no app do Telegram é validado manualmente pelo developer com um bot
  de teste.

## Estratégia de rollout

1. Tudo atrás de config: sem `canais.telegram.enabled` e sem template WhatsApp,
   nenhuma lista oferece canal (membros ficam pendentes) — e o default
   `exige_confirmacao=false` deixa a Fase 0 intacta.
2. Deploy: `deploy_db_dev` → `deploy_backend_dev` + `deploy_minion_dev` →
   `deploy_frontend_dev`; imagens locais `sqitch`, `backend`, `minion`,
   `frontend`.
3. Dev: bot de teste no @BotFather, modo polling, uma lista piloto com
   exigência.
4. Produção (futuro): modo webhook com HTTPS público; WhatsApp só após template
   aprovado.
5. Rollback: desligar `canais.telegram.enabled` / remover template; listas
   voltam a não oferecer canais, sem perda de dados.

## Execução sugerida (ondas)

| Onda | Trilha | Itens |
|---|---|---|
| 1 | db/backend | migration; `Roles::Business::Canal::Confirmacao`; extensão da inscrição; PATCH/estado na gestão |
| 1 | frontend | toggle/selo/filtro na `ListasPage`; passo 2 na `InscricaoPublicaPage` (contra o contrato acima) |
| 2 | backend | `Telegram::Updates` + webhook + task de polling + config `canais.telegram.*` |
| 2 | backend | `WhatsApp` template + endpoints de código |
| 3 | coord. | integração, e2e, bot de teste em dev, deploy, docs funcionais, PR |

O registro mutável (WBS, DAG, log) fica em
`2026-10-11-confirmacao-posse-listas-qr.execucao.md`, criado no início da
execução.
