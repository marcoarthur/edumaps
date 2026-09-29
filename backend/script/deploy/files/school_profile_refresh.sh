#!/bin/sh
# Refresh batch do Perfil da Escola (issue #107 — Fase 2).
#
# Enfileira, via rota administrativa do backend, a materialização das:
#   1. referências comparativas (Brasil/rede/município);
#   2. percentis por cluster;
#   3. perfis das escolas ainda não materializadas (scope=pending, lote).
#
# Os jobs caem na fila Minion 'analytics' e são processados pelo
# edumaps-minion-analytics. Roda também em timer systemd.
set -e

BASE="${EDUMAPS_BASE_URL:-http://127.0.0.1:3000}"
LIMIT="${EDUMAPS_PROFILE_BATCH_LIMIT:-500}"

post() {
  curl -fsS -X POST "$BASE/api/task/school_profile" \
    -H 'Content-Type: application/json' \
    -d "$1"
  echo
}

post '{"mode":"reference"}'
post '{"mode":"cluster"}'
post "{\"mode\":\"profiles\",\"scope\":\"pending\",\"limit\":$LIMIT}"
