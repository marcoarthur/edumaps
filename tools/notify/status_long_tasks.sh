#!/usr/bin/env bash
# Status periódico (Telegram) das tarefas longas de execução — chamada
# do developer durante ciclos longos (a cada 20 min).
#
# Tarefas monitoradas (ajustar conforme o ciclo):
#   - F do IVET: ingestão por região imediata (drive em curso — SP, ou a
#     cadeia nacional encadeada em /var/tmp/f_nacional.sh)   -> backend.edumaps
#   - #268: re-materialização do entorno por UF               -> database.edumaps
#
# Uso: bash status_long_tasks.sh [intervalo_segundos]   (default 1200 = 20 min)
# Encerra sozinho quando AS DUAS estiverem paradas (ativo=1 se ao menos
# uma estiver [rodando] — uma parada no meio do ciclo não derruba o loop).
#
# Depende de tools/notify/notify.sh (+ .env configurado; degrada em
# silêncio se não configurado, nunca bloqueia).
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NOTIFY="$REPO/tools/notify/notify.sh"
INTERVALO="${1:-1200}"
SSHOPTS=(-o BatchMode=yes -o ConnectTimeout=15)

# IMPORTANTE: os hosts (backend/database.edumaps) correm em UTC e o host
# local em UTC-3 — os timestamps dos logs remotos são ~3h à frente do
# relógio local; não confundir com atraso do loop.

f_status() {
  ssh "${SSHOPTS[@]}" root@backend.edumaps '
    l=/var/tmp/risco_sp.log
    if [ ! -f "$l" ]; then echo "(sem log)"; exit 0; fi
    echo "F: OK=$(grep -ac "<<< .* OK" "$l") falhas=$(grep -ac FALHOU "$l") puladas=$(grep -ac pulando "$l")"
    grep -aE ">>>|---" "$l" | tail -2
    if pgrep -f "^bash script/ingestao/mapbiomas_risco\.sh" >/dev/null; then
      echo "[rodando]"
    else
      echo "[parado]"
    fi
  ' 2>/dev/null
}

e_status() {
  ssh "${SSHOPTS[@]}" root@database.edumaps '
    l=/tmp/refresh_entorno.log
    if [ ! -f "$l" ]; then echo "(sem log)"; exit 0; fi
    echo "entorno: UFs=$(grep -ac "UF=" "$l")"
    grep -a "UF=" "$l" | tail -1
    if pgrep -f "^/bin/bash /tmp/refresh_entorno\.sh$" >/dev/null; then
      echo "[rodando]"
    else
      echo "[parado]"
    fi
  ' 2>/dev/null
}

while :; do
  f="$(f_status)"; e="$(e_status)"
  ativo=0
  case "$f$e" in *rodando*) ativo=1;; esac

  msg="F (IVET) no backend.edumaps:
$f

#268 (entorno) no database.edumaps:
$e"

  "$NOTIFY" --event stage --no-github \
    --title "Tarefas longas — $(date '+%H:%M')" --msg "$msg" >/dev/null 2>&1 || true
  printf '\n=== %s ativo=%s ===\n%s\n' "$(date '+%F %T')" "$ativo" "$msg"

  if [ "$ativo" = 0 ]; then echo "nenhuma rodando — encerrando o loop"; break; fi
  sleep "$INTERVALO"
done
