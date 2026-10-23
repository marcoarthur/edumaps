#!/usr/bin/env bash
# Watchdog de memória do Valhalla (rodada #295).
#
# O `valhalla_service` tem um vazamento de memória conhecido e **rápido sob
# carga**: a RSS sobe ~0,2 GB/min de uso intenso de isócronas (medido
# 2026-10-21) e, sem intervenção, chega aos ~12 GB dos 15 GB da máquina — o
# kernel então mata o processo de extração (Python) e a rodada morre **em
# silêncio** (sem mensagem; foi assim que MG e SP caíram em 2026-10-20/21).
# Nenhuma linha de erro no dmesg legível sem root.
#
# Com ~5 GB de RAM disponível e o working set do Valhalla sob carga em ~4–5 GB,
# o teto seguro é **5 GB**: reinícios frequentes (a cada ~2–5 min sob carga) são
# o modo correto de operação — são inofensivos (a extração seguiu com
# "sem isórona: 0" apesar de dezenas de reinícios) e mantêm o Valhalla limitado.
#
# Este watchdog reinicia o container quando a RSS passa do teto e espera o
# serviço voltar. Reiniciar é seguro: os tiles são read-only e a extração
# retoma pelo `--retomar` (o CSV preserva o progresso).
#
# Uso: bash db/isocrona/valhalla_watchdog.sh <container> [teto_mb] [intervalo_s]
set -euo pipefail

CONTAINER=${1:?uso: valhalla_watchdog.sh <container> [teto_mb] [intervalo_s]}
TETO_MB=${2:-5000}
INTERVALO=${3:-120}
LOG=/tmp/valhalla_watchdog_${CONTAINER}.log

echo "$(date '+%F %T') watchdog iniciado (container=$CONTAINER teto=${TETO_MB}MB)" | tee -a "$LOG"

while true; do
  PID=$(sg docker -c "docker inspect -f '{{.State.Pid}}' $CONTAINER" 2>/dev/null || echo "")
  if [ -z "$PID" ] || [ "$PID" = "0" ]; then
    sleep "$INTERVALO"; continue
  fi
  RSS_MB=$(awk '/VmRSS/{print int($2/1024)}' /proc/"$PID"/status 2>/dev/null || echo 0)
  if [ "${RSS_MB:-0}" -ge "$TETO_MB" ]; then
    echo "$(date '+%F %T') RSS=${RSS_MB}MB ≥ teto → reiniciando $CONTAINER" | tee -a "$LOG"
    sg docker -c "docker restart $CONTAINER" >/dev/null 2>&1 || true
    sleep 20
    NOVO=$(sg docker -c "docker inspect -f '{{.State.Pid}}' $CONTAINER" 2>/dev/null || echo "")
    echo "$(date '+%F %T') reiniciado (novo pid=$NOVO)" | tee -a "$LOG"
  fi
  sleep "$INTERVALO"
done
