#!/usr/bin/env bash
# tools/notify/github.sh
#
# Comenta no PR/issue do ciclo via `gh` (dispara push no GitHub mobile).
# Uso interno do notify.sh:
#   github.sh "<ref>" "<texto>"
#
#   ref: 'auto'        = detecta o PR do branch atual (gh pr view)
#        '<número>'    = PR/issue número N do repositório atual
#        '<URL>'       = URL completa do PR/issue
#
# Se não houver PR aberto no branch (ref=auto), sai em silêncio — o evento
# já foi coberto pelo Telegram nesse caso.
set -euo pipefail

REF="${1:?github.sh: ref ausente}"
TEXT="${2:?github.sh: texto ausente}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$ROOT" ]]; then
  cd "$ROOT"
fi

post() { # post <target> <texto>
  local target="$1" txt="$2"
  if gh pr comment "$target" --body "$txt" >/dev/null 2>&1; then
    echo "github.sh: comentário no PR $target ok" >&2
  elif gh issue comment "$target" --body "$txt" >/dev/null 2>&1; then
    echo "github.sh: comentário na issue $target ok" >&2
  else
    echo "github.sh: falha ao comentar em $target (ignore; segue o ciclo)" >&2
  fi
}

case "$REF" in
  auto)
    n="$(gh pr view --json number -q .number 2>/dev/null || true)"
    if [[ -z "$n" ]]; then
      echo "github.sh: nenhum PR aberto no branch atual — sem comentário (já coberto pelo Telegram)" >&2
      exit 0
    fi
    post "$n" "$TEXT"
    ;;
  *)
    post "$REF" "$TEXT"
    ;;
esac