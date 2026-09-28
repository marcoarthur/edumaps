# tools/notify — notificações de ciclo (push para o developer)

Avisa o developer (você) quando o agente termina uma **etapa**, **bloqueia
esperando permissão** ou **fecha um ciclo completo**, via **Telegram**
(Bot API, gratuita) e, em bloqueios, com **reforço no GitHub mobile**
(comentário no PR/issue do ciclo via `gh`).

> Regra de localização: este é o único lugar do repo onde vive esse código.
> **Nada** em `backend/`, `data_pipeline/`, `frontend/` ou `db/`.

## 1) Criar o bot do Telegram (uma vez)

1. Abra o **@BotFather** no Telegram: <https://t.me/BotFather>.
2. Envie `/newbot` e siga o assistente:
   - **nome**: ex.: `EduMaps Ciclo`
   - **username**: ex.: `edumaps_cycle_bot` (termina em `bot`).
3. O BotFather responde com o **token** de acesso, algo como:
   `1234567890:AAHf...Xyz` — guarde-o.

## 2) Descobrir seu `chat_id` (uma vez)

1. Abra o chat do **seu bot** (pesquise pelo username) e envie qualquer
   mensagem (ex.: `/start` ou "oi").
2. Rode (trocando o token):
   ```bash
   curl "https://api.telegram.org/bot<TOKEN>/getUpdates"
   ```
3. Na resposta, procure `"chat":{"id":<NÚMERO>,...}` — o `<NÚMERO>` é o seu
   `chat_id` (se vier negativo, mantenha o sinal; ex.: `-100…` para grupos).
   O `chat_id` aparece no `message.chat.id` da sua mensagem.

> Dica: se `getUpdates` vier vazio, envie outra mensagem ao bot e repita.
> No seletor de grupos no Telegram, pra enviar pro seu próprio chat é o
> mesmo id da `message` normal.

## 3) Configurar

```bash
cd tools/notify
cp .env.example .env
# edite o .env: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
```

## 4) Testar

```bash
./tools/notify/notify.sh --event done --title "teste — configuração OK"
./tools/notify/notify.sh --event blocked --title "teste bloqueio" --no-github
# prévia sem enviar:
./tools/notify/notify.sh --event stage --title "prévia" --dry-run
```

## Uso no ciclo de desenvolvimento

| Quando | Comando |
|---|---|
| fim de **etapa/fase** | `notify.sh --event stage --title "Etapa 2/4 pronta" --msg "..."` |
| **bloqueio** esperando permissão | `notify.sh --event blocked --title "preciso decidir X" --msg "..."` (comenta no PR/issue via gh) |
| **fim de ciclo** (após PR merged + docs) | `notify.sh --event done --title "Ciclo concluído" --msg "PR #104 mergeado"` |

### Sobre o reforço no GitHub

- Em `blocked`, o `notify.sh` comenta no **PR/issue do ciclo** (default
  `GITHUB_REF=auto` = detecta o PR do branch atual via `gh pr view`).
- Desligar num caso específico: `--no-github`.
- Se não houver PR aberto no branch, o reforço é pulado em silêncio (o
  Telegram já cumpriu o papel).

## Degradação

- **Sem** `ENABLE_TELEGRAM=1` / token / chat_id → Telegram é pulado com um
  aviso no **stderr** e `exit 0`. **Nunca** quebra o ciclo.
- Falha de rede/API → mesma regra: aviso no stderr, ciclo segue.

## Dependências

- `curl` (Telegram), `gh` autenticado (GitHub), `bash`+`grep`. Sem libs.