# Nota técnica — Painel de Configuração (admin) com chave do Assistente do Censo

> Data: 2026-09-25 · Ciclo: data_pipeline (Sqitch/PostgreSQL) + backend (Perl/Mojolicious) + analytics (R) + frontend (Svelte 5) · PR #98

## 1. Contexto

A plataforma não dispunha de um espaço administrativo para configurar a
instalação de forma global. A primeira configuração funcional entrega é a
**chave de API do provedor de linguagem** (LLM) usada pelo Assistente do Censo
— antes fixa apenas via variáveis de ambiente no deploy (R/analytics). Este
ciclo cria o **Painel de Configuração** ponta a ponta: árvore de categorias na
SPA, API admin com autenticação por papel, armazenamento cifrado no banco e a
superposição dinâmica dessa config sobre o R no momento do `ask_censo`.

## 2. Decisões (alinhadas com o usuário)

| Ponto | Decisão |
|---|---|
| Onde cifrar a chave | `pgp_sym_encrypt/decrypt` no PostgreSQL (sem coluna de texto plano) |
| Master key | `EDUMAPS_CONFIG_MASTER_KEY` via env/systemd — **nunca no repo nem no banco** |
| Descobrir a master key no servidor | Guardada no serviço systemd (`edumaps-web/minion/minion-analytics`); deploy Rex injeta a partir de `$ENV` |
| Auto em rotas admin | 401 sem sessão; 403 gestor comum sem `access_role = 'admin'` (novo gatilho `_require_admin`) |
| Como o secret aparece na API | *Nunca* o valor: respostas do tipo `secret` mascaram como `{set:0}`/`{set:1}`, com `updated_at`/`updated_by` |
| Provedor/model neo no catálogo | Só item funcional hoje: `integrations.assistant_censo.api_key`; demais nós da árvore marcam **"Em breve"** no frontend |
| Fallback sem painel | Se o Painel de Configuração não tiver item configurado, o R usa os defaults de `EDUMAPS_LLM_*` — instalações antigas continuam funcionando |
| Cache do chat | Incluir `config_version` (hash canonical da config LLM) — trocar provedor/chave invalida o cache sem vazar segredo na chave |

## 3. Implementação

### 3.1 Banco (Sqitch)

- **`app_config`** (deploy/verify/revert): schema `app_config` + tabela `items`
  (`key` PK, `category`, `label`, `description`, `example`, `value_type`,
  `sensitive` bool, `secret` bytea, `enabled` bool, `updated_by`, `updated_at`).
- **`gestor_access_role`**: `clean.gestores.access_role` default `'gestor'`
  (papel `'admin'` habilita o painel).

### 3.2 Backend

- **`Plugin/API/Admin.pm`** + **`Controller/Admin.pm`**: rotas
  `GET /api/admin/config/tree`, `GET|PUT /api/admin/config/{key}`,
  `POST /api/admin/config/{key}/validate`. `PUT` grava via upsert cifrado e
  registra `updated_by`; `validate` só revalida o formato/host (não chama o
  provedor). Validação do segredo: mínimo de comprimento para chaves LLM.
- **`Model/AppConfig.pm`**: helpers da árvore, `get_item` (mascara secrets),
  `set_item` (cifra), `chat_llm_config` (descriptografa só o que for
  necessário para o job do Assistente).
- **`Controller/Gestor.pm`**: novo `_require_admin` (valida sessão + papel);
  `login_gestor`/`sessao_valida` expõem `access_role` (default `'gestor'`).
- **`Task/Chat.pm`**: `_chat_ask` injeta `config => chat_llm_config` no R.
- **`Analytics/Client.pm`**: `run_chat` envia `config` no body e usa
  `config_version` (sha1 canonical) como parte da chave de cache — o segredo
  nunca vira chave de cache.

### 3.3 Analytics (R)

- **`config.R`**: `chat_config(override)` aplica os campos do Painel sobre os
  defaults de ambiente e **recalcula `engine` pelo provider efetivo**
  (correção de bug: antes usava a env). `chat_db_connection(cfg)` aceita a
  config já resolvida.
- **`chat-translate.R`**: `ask_censo(..., config)` repassa ao `chat_config`.
- **`endpoint.R`**: `/ask` aceita `config`.

### 3.4 Frontend (Svelte 5)

- **Rota `/config`** + item de menu "Configurações". Página exige sessão de
  gestor admin (`_require_admin` no cliente exibe o `GestorLoginCard` quando
  não autenticado).
- **`ConfigPage.svelte`** + `ConfigArvore` (categorias Sistema/Integrações/
  Aparência/Comportamento/Outros, tooltip "?" de descrição) + `ConfigEditor`
  (campo tipo `secret` com "Chave atualmente definida", botões Salvar/Validar).
- **MSW**: handlers/fixtures para as rotas admin em desenvolvimento.

### 3.5 Deploy

- **`Rexfile`**: `set config_master_key => $ENV{EDUMAPS_CONFIG_MASTER_KEY} || ''`.
- **Templates systemd** (`edumaps-web/minion/minion-analytics.service`):
  `Environment=EDUMAPS_CONFIG_MASTER_KEY=<%= $config_master_key %>`.

## 4. Validação

- **Banco**: migrações aplicadas e verificadas nos **dois** bancos de dev
  (container `database.edumaps` + `ubatexu.lan`).
- **Backend**: `t/02-models/app-config.t` + `t/04-api/admin/config.t` (**13 ok**) —
  auth 401/403/200, árvore, mascaração de secret, PUT → set:1, validate.
- **R**: `test-config.R` novo (**15 ok**) + `test-chat-translate.R` (**44 ok**).
- **Frontend**: `ConfigPage.test.js` (**5 ok**) + rota `/config` em `routes.test.js`;
  suíte completa **63 files / 337 testes** (1 erro pré-existente de `@carbon/charts`).
- **E2E real** (Chrome CDP, PASS 2026-09-25): `/config` com sessão admin → árvore
  + editor; chave salva e confirmada **cifrada** no banco (descriptografável com
  a master key). Fluxo API completo validado no container.

## 5. Riscos lembrados

- Duplicidade de fontes de config (env vs banco): ambiente explícito
  (`EDUMAPS_CHAT_ENGINE` etc.) tem prioridade sobre o R; o Painel só sobrepõe
  o que não estiver fixado por env. Manter a documentação de prioridade.
- Segredo via `pgp_sym_encrypt` pode vazar em logs/SQL se alguém rodar
  `pgp_sym_decrypt` em uma sessão com a master key disponível — mitigado por
  não logar valores e por pontos de acesso restritos a admin.

## 6. Pendências

- Nenhuma pendência no ciclo; backlog do projeto segue com o único issue aberto
  **#1 (GH Actions)**.