# Nota técnica 89 — Bot Telegram Fase 1B: config na AppConfig + endpoint de teste (#183)

**Data**: 2026-10-07
**Escopo**: PR #186 — persistência da config do bot, API de teste de envio, editor multiselect no Painel de Configuração.
**Issues**: #183 (fase 1B; 1A já mergeada no #184).

## Resumo

A fase 1B eliminou a fragilidade exposta na 1A (config do bot montada à mão por
quem chama) integrando a persistência ao **sistema AppConfig existente**, em vez
de criar tabela e endpoints paralelos como o issue original previa. Decisão
alinhada com o developer no planning.

## Decisões de design

1. **Reuso do AppConfig, não tabela `bot_config`**. O projeto já tinha
   `app_config.items` (secrets cifrados com pgcrypto + master key do ambiente),
   árvore tipada, API admin autenticada e a ConfigPage no frontend. Criar uma
   tabela nova duplicaria mascaramento de segredo, auth e UI — o token do
   Telegram é exatamente o caso de uso de `sensitive`. Resultado: 4 folhas no
   grupo `bot_telegram` (`token` secret, `chat_id`, `enabled`,
   `allowed_actions`).

2. **Novo tipo de folha `multiselect`**. A árvore tinha
   `text|secret|number|boolean|select`. A lista de ações permitidas é uma
   multi-escolha com whitelist fechada — criamos `multiselect` com `options`
   vindo da `Policy::Actions->available` e validação estrita no
   `config_validate` (lista não-vazia, ação conhecida, sem duplicadas). O
   frontend ganhou o branch equivalente no `ConfigEditor` (checkboxes).

3. **`bot_telegram_config()` como fonte única de verdade**. O endpoint de teste
   (e futuramente os pontos de alerta da 1C/1D) monta a config efetiva lendo a
   AppConfig: `enabled=0` por omissão, token decifrado em memória via
   `EDUMAPS_CONFIG_MASTER_KEY` — nunca exposto por API.

4. **`POST /api/admin/bot/telegram/test` sob o `under` admin existente**. Falha
   alto: 400 se desativado/incompleto, 502 se a API do Telegram recusar. A
   resposta nunca contém o token.

## Entregas

- `Roles/Business/Config/AppConfig.pm`: grupo `bot_telegram` (4 folhas), tipo
  `multiselect` + validação, `bot_telegram_config()`, correção de warning
  numérico pré-existente no boolean (`== 1` → `eq '1'`).
- `Controller/Admin.pm`: `bot_telegram_test`.
- `Plugin/API/Admin.pm`: rota `POST /api/admin/bot/telegram/test`.
- `frontend ConfigEditor.svelte`: branch multiselect + `$effect` de
  re-preenchimento (bug exposto: `onMount` só roda uma vez no Svelte 5).
- Fixtures/handlers MSW e testes vitest do grupo Bot Telegram.
- Docs funcionais: `plataforma/bot-telegram.md` (nova capacidade) e Painel de
  Configuração/índice atualizados (lacuna da 1A).

## Validação

- Backend: `t/04-api/admin/bot.t` novo; `app-config.t` estendido — 29 PASS nos
  4 arquivos afetados; gate `perl -c` RC=0.
- Frontend: vitest config 8/8; suíte completa 396/396.
- CI: backend 10m26s (PASS), frontend 1m1s (PASS).
- Smoke manual: token real persistido via PUT → envio de teste → 200, mensagem
  confirmada pelo developer no Telegram; token nunca em claro na BD.

## Pendências

- #183 Fase 1C: integrar envios a pontos de alerta reais (stall do
  `ingestion_runner`, etc.) respeitando as ações permitidas.
- #183 Fase 1D: recebimento de mensagens (fora do escopo da fase 1).
- Comentário no #183 pendente por incidente transitório no GitHub
  (GraphQL/REST de comentários com erro 500 na janela 16:53–16:58) — registrar
  assim que o endpoint voltar.