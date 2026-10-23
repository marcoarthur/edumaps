#!/usr/bin/env bash
# Monitor do piloto de isócronas (#295 rodada 2) — progresso + MEMÓRIA, via
# Telegram a cada N segundos (default 1200 = 20 min).
#
# Por que a memória importa: o `valhalla_service` vaza (~1,5–2 GB/h de uso
# intenso) e, quando chega aos ~12 GB dos 15 GB da máquina, o kernel mata a
# extração Python **em silêncio** (foi assim que MG e SP caíram). Este monitor
# mostra a RSS de cada Valhalla e a memória do sistema, para o teto do watchdog
# ser visível antes de a rodada morrer.
#
# Uso: bash db/isocrona/status_piloto.sh [intervalo_s] [log]
#   intervalo default 1200s; log default /tmp/isocrona_sp.log
# Encerra sozinho quando a extração terminou (processo ausente E log com "pronto:").
# Depende de tools/notify/notify.sh (degrada em silêncio se não configurado).
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NOTIFY="$REPO/tools/notify/notify.sh"
INTERVALO="${1:-1200}"
LOG="${2:-/tmp/isocrona_sp.log}"
WATCHDOG_TETO_MB="${WATCHDOG_TETO_MB:-5000}"

# Detalhes por rodada (ajustar por UF)
UF="${UF:-SP}"
CSV="${CSV:-/home/itaipu/Code/Data/osm/piloto_sp/isocrona_escolar.csv}"
ALVO="${ALVO:-27109}"
VALHALLA_CONTAINER="${VALHALLA_CONTAINER:-valhalla-sudeste}"

rss_gb() {  # $1 = container → RSS do valhalla_service em GB (ou "?")
  local pid
  pid=$(sg docker -c "docker inspect -f '{{.State.Pid}}' $1" 2>/dev/null || echo "")
  [ -z "$pid" ] || [ "$pid" = "0" ] && { echo "?"; return; }
  awk '/VmRSS/{printf "%.2f", $2/1048576}' /proc/"$pid"/status 2>/dev/null || echo "?"
}

mem_linha() {
  free -m | awk 'NR==2{printf "sistema: usada=%.1fGB livre=%.1fGB disp=%.1fGB", $3/1024, $4/1024, $7/1024}'
}

# Barra de progresso textual de 20 blocos.
barra() {  # $1 = % (0-100)
  awk -v p="$1" 'BEGIN{
    n=int(p/5); if(n>20)n=20; if(n<0)n=0;
    s=""; for(i=0;i<n;i++)s=s"#"; for(i=n;i<20;i++)s=s"."; printf "[%s]", s
  }'
}

# Ritmo: compara o nº de escolas extraídas com o tempo desde a 1ª leitura,
# para estimar o ETA. Guarda o estado em arquivo entre iterações.
RITMO_FILE="/tmp/status_piloto_ritmo_${UF}.txt"

while :; do
  fim=0
  # progresso do script
  pid_py=$(pgrep -f "^/home/itaipu/Code/Data/osm/.venv/bin/python .*extrair_isocronas.py" | head -1)
  if [ -n "$pid_py" ]; then
    estado="[rodando]"
    py_rss=$(awk '/VmRSS/{printf "%.2f", $2/1048576}' /proc/"$pid_py"/status 2>/dev/null || echo "?")
  else
    estado="[parado]"
    py_rss="-"
    grep -aq "pronto:" "$LOG" 2>/dev/null && fim=1
  fi

  feitas=$(awk -F, 'NR>1 && !seen[$1]++{n++} END{print n+0}' "$CSV" 2>/dev/null)
  linhas=$(wc -l < "$CSV" 2>/dev/null || echo 0)
  pct=$(awk -v f="$feitas" -v a="$ALVO" 'BEGIN{printf "%.1f", (a>0? f*100/a : 0)}')
  b=$(barra "$pct")

  # ETA a partir do ritmo (escolas/min) desde a iteração anterior.
  agora=$(date +%s)
  eta="?"
  if [ -f "$RITMO_FILE" ]; then
    read -r t0 f0 < "$RITMO_FILE"
    if [ -n "$t0" ] && [ -n "$f0" ] && [ "$f0" -gt 0 ] 2>/dev/null; then
      dt=$((agora - t0)); df=$((feitas - f0))
      if [ "$dt" -gt 0 ] && [ "$df" -gt 0 ]; then
        restam=$((ALVO - feitas))
        seg=$(awk -v r="$restam" -v df="$df" -v dt="$dt" 'BEGIN{printf "%d", r*dt/df}')
        eta=$(awk -v s="$seg" 'BEGIN{
          d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60);
          if(d>0) printf "%dd %dh", d, h; else if(h>0) printf "%dh %dm", h, m; else printf "%dm", m
        }')
      fi
    fi
  fi
  printf '%s %s\n' "$agora" "$feitas" > "$RITMO_FILE"

  rss_sud=$(rss_gb valhalla-sudeste)
  rss_nor=$(rss_gb valhalla-nordeste)
  wd=$(pgrep -f valhalla_watchdog.sh >/dev/null && echo "on" || echo "OFF")

  ultimo=$(grep -a "escolas (" "$LOG" 2>/dev/null | tail -1 | tr -d '\n')
  [ -z "$ultimo" ] && ultimo=$(tail -1 "$LOG" 2>/dev/null | tr -d '\n')

  msg="$UF — $estado  ${pct}%  ${b}
${feitas}/${ALVO} escolas  |  CSV ${linhas} linhas  |  ETA ${eta}
python RSS: ${py_rss}GB
último log: ${ultimo}

MEMÓRIA:
valhalla-sudeste: ${rss_sud}GB  (teto watchdog ${WATCHDOG_TETO_MB}MB)
valhalla-nordeste: ${rss_nor}GB
watchdogs: ${wd}
$(mem_linha)"

  "$NOTIFY" --event stage --no-github \
    --title "Piloto $UF — ${pct}% (${feitas}/${ALVO})" --msg "$msg" >/dev/null 2>&1 || true
  printf '\n=== %s fim=%s ===\n%s\n' "$(date '+%F %T')" "$fim" "$msg"

  if [ "$fim" = 1 ]; then
    "$NOTIFY" --event done --no-github \
      --title "Piloto isócrona $UF — terminou" \
      --msg "$(tail -3 "$LOG" | tr '\n' ' ')" >/dev/null 2>&1 || true
    echo "extração terminada — encerrando o monitor"
    break
  fi
  sleep "$INTERVALO"
done
