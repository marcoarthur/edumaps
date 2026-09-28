#!/usr/bin/env bash
# tools/notify/telegram.sh
#
# Envia mensagem via Telegram Bot API (gratuita).
# Uso interno do notify.sh:
#   telegram.sh "<bot_token>" "<chat_id>" "<texto>"
#
# Não imprime nada na saída padrão; avisos vão para o stderr.
set -euo pipefail

TOKEN="${1:?telegram.sh: token ausente}"
CHAT_ID="${2:?telegram.sh: chat_id ausente}"
TEXT="${3:?telegram.sh: texto ausente}"

resp="$(
  curl -fsS --max-time 15 \
    -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${TEXT}" \
    2>/dev/null
)" || {
  echo "telegram.sh: falha no sendMessage (token/chat_id inválidos ou sem rede?)" >&2
  exit 1
}

echo "$resp" | grep -q '"ok":true' || {
  echo "telegram.sh: resposta sem ok:true: $resp" >&2
  exit 1
}