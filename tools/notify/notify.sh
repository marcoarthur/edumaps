#!/usr/bin/env bash
# tools/notify/notify.sh
#
# NOTIFICAÇÃO: Este script envia mensagens ao Telegram e comenta no GitHub.
# ⚠️ NÃO execute durante testes ou demonstrações do agente.
# Rode apenas quando o ciclo de desenvolvimento estiver realmente concluído.
#
# Notifica o developer (usuário) do fim de ciclo / fim de etapa / bloqueios,
# via Telegram (Bot API gratuita) e, em bloqueios, com reforço comentando no
# PR/issue do ciclo via `gh` (GitHub mobile).
#
# Uso:
#   notify.sh --event done    --title "..." [--msg "..."]
#   notify.sh --event stage   --title "..." [--msg "..."]
#   notify.sh --event blocked --title "..." [--msg "..."] [--no-github]
#   notify.sh --help
#
# Opções:
#   --event     done | stage | blocked   (obrigatório)
#   --title     cabeçalho curto          (obrigatório)
#   --msg       corpo opcional (multilinha via $'...\n...')
#   --github    força comentário no GitHub (default: só em blocked)
#   --no-github desliga o comentário no GitHub (inclusive em blocked)
#   --dry-run   mostra o que enviaria, sem enviar
#   --env FILE  arquivo .env alternativo (default: tools/notify/.env)
#
# Config (tools/notify/.env — NÃO versionado; .gitignore cobre .env):
#   TELEGRAM_BOT_TOKEN=...      # do @BotFather
#   TELEGRAM_CHAT_ID=...        # seu chat_id (ver README.md)
#   ENABLE_TELEGRAM=1
#   GITHUB_REF=auto             # 'auto' = PR do branch atual; ou número/URL fixo
#
# Comportamento: se o canal não estiver configurado, degrada CALADO (exit 0,
# aviso no stderr) — nunca quebra o ciclo de desenvolvimento.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${NOTIFY_ENV_FILE:-$DIR/.env}"

EVENT=""
TITLE=""
MSG=""
GITHUB_MODE=""       # '' = default (blocked apenas), 'force' ou 'off'
DRY_RUN=0

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --event)    EVENT="$2";        shift 2 ;;
    --title)    TITLE="$2";        shift 2 ;;
    --msg)      MSG="$2";          shift 2 ;;
    --github)   GITHUB_MODE="force"; shift ;;
    --no-github) GITHUB_MODE="off"; shift ;;
    --dry-run)  DRY_RUN=1;         shift ;;
    --env)      ENV_FILE="$2";     shift 2 ;;
    --help|-h)  usage 0 ;;
    *) echo "notify: opcao desconhecida: $1" >&2; usage 2 ;;
  esac
done

# --- validação ----------------------------------------------------------------
case "$EVENT" in
  done|stage|blocked) ;;
  "") echo "notify: --event obrigatório (done|stage|blocked)" >&2; usage 2 ;;
  *)  echo "notify: --event inválido: $EVENT" >&2; usage 2 ;;
esac
[[ -z "$TITLE" ]] && { echo "notify: --title obrigatório" >&2; usage 2; }

# --- config -------------------------------------------------------------------
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

EMOJI=; LABEL=;
case "$EVENT" in
  done)    EMOJI="✅"; LABEL="fim de ciclo" ;;
  stage)   EMOJI="🚧"; LABEL="etapa concluída" ;;
  blocked) EMOJI="⛔"; LABEL="BLOQUEIO — precisa de você" ;;
esac

# origin do repo p/ contexto
REPO="edumaps"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$ROOT" ]]; then
  URL="$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null || true)"
  [[ -n "$URL" ]] && REPO="$(basename "$URL" .git)"
fi

TEXT="${EMOJI} [${REPO}] ${LABEL}
${TITLE}"
[[ -n "$MSG" ]] && TEXT="${TEXT}

${MSG}"

# --- canal: Telegram ----------------------------------------------------------
TELEGRAM_OK=0
if [[ "${ENABLE_TELEGRAM:-0}" == "1" && -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  TELEGRAM_OK=1
fi

if [[ "$TELEGRAM_OK" == "1" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "telegram: (dry-run) enviaria ->" >&2
    echo "$TEXT" >&2
  else
    if "$DIR/telegram.sh" "${TELEGRAM_BOT_TOKEN}" "${TELEGRAM_CHAT_ID}" "${TEXT}" >&2 2>/dev/null; then
      echo "notify: telegram enviado ($EVENT)" >&2
    else
      echo "notify: falha ao enviar telegram (ignore; segue o ciclo)" >&2
    fi
  fi
else
  echo "notify: telegram não configurado (ENABLE_TELEGRAM/token/chat_id) — pulando; setup em tools/notify/README.md" >&2
fi

# --- canal: GitHub (reforço em bloqueios) --------------------------------------
DO_GITHUB=0
if [[ "$GITHUB_MODE" == "force" ]]; then
  DO_GITHUB=1
elif [[ "$GITHUB_MODE" == "off" ]]; then
  DO_GITHUB=0
elif [[ "$EVENT" == "blocked" ]]; then
  DO_GITHUB=1
fi

if [[ "$DO_GITHUB" == "1" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "github: (dry-run) comentaria no PR/issue (ref=${GITHUB_REF:-auto}) ->" >&2
    echo "$TEXT" >&2
  else
    "$DIR/github.sh" "${GITHUB_REF:-auto}" "${TEXT}" >&2 2>/dev/null || \
      echo "notify: falha no comentário github (ignore; segue o ciclo)" >&2
  fi
fi

exit 0