#!/usr/bin/env bash
# Recarrega no banco um CSV de isócronas JÁ EXTRAÍDO, sem rotear de novo (#295).
#
# Uso: quando um snapshot novo foi gravado sem uma UF já coberta (ver README,
# "Snapshot novo precisa levar TODAS as UFs"). O CSV guarda as células e a
# população de cada escola; o roteamento (horas de Valhalla) não se repete.
#
#   UF=ES CSV=~/Code/Data/osm/piloto_es_s2/isocrona_escolar.csv \
#     SNAPSHOT=2026-10-21 bash db/isocrona/recarregar_csv.sh
#
# Variáveis:
#   UF                 rótulo da carga (nome da unit systemd: carga-<UF>)
#   CSV                CSV de saída do extrair_isocronas.py
#   SNAPSHOT           dt_snapshot da carga — o VIGENTE do banco
#   TILESET_BUILD_DATE data de build dos tiles usados na extração do CSV
#   TILESET_ORIGIN     extract de onde vieram os tiles
#   EDUMAPS_DB_SSH, EDUMAPS_DB_NAME, EDUMAPS_DB_USER, EDUMAPS_DB_PASS  como nos
#                      drivers
#
# A carga roda DESTACADA no host do banco (systemd-run), como nos drivers: uma
# queda da sessão SSH no meio da transação faz rollback total.
set -euo pipefail

: "${UF:?defina UF}"
: "${CSV:?defina CSV}"
: "${SNAPSHOT:?defina SNAPSHOT (o snapshot vigente do banco)}"
TILESET_BUILD_DATE=${TILESET_BUILD_DATE:-$SNAPSHOT}
TILESET_ORIGIN=${TILESET_ORIGIN:-geofabrik_sudeste_2026-10}
SSH_DB=${EDUMAPS_DB_SSH:-root@database.edumaps}
DB=${EDUMAPS_DB_NAME:-edumaps_dev}
DB_USER=${EDUMAPS_DB_USER:-edumaps}
DB_PASS=${EDUMAPS_DB_PASS:-change_me}
DIR_REPO=$(cd "$(dirname "$0")/../.." && pwd)

test -s "$CSV" || { echo "ERRO: CSV ausente ou vazio: $CSV" >&2; exit 1; }
cabecalho=$(head -1 "$CSV")
esperado="co_entidade,codigo_ibge,tempo_minutos,grid_id,resolucao_h3,populacao_grade"
[ "$cabecalho" = "$esperado" ] || {
  echo "ERRO: cabeçalho inesperado em $CSV: $cabecalho" >&2; exit 1; }

# O snapshot pedido precisa ser o vigente: carregar num anterior não aparece no
# painel, e num posterior tiraria do painel todas as outras UFs.
vigente=$(ssh -o ConnectTimeout=20 "$SSH_DB" \
  "sudo -u postgres psql -d $DB -qAt -c 'SELECT max(dt_snapshot) FROM clean.isocrona_escolar'")
[ "$vigente" = "$SNAPSHOT" ] || {
  echo "ERRO: SNAPSHOT=$SNAPSHOT, mas o vigente no banco é '$vigente'." >&2; exit 1; }

echo "[1/3] enviando $CSV ($(du -h "$CSV" | cut -f1)) para $SSH_DB..."
scp -q -o ConnectTimeout=20 "$CSV" "$SSH_DB:/tmp/isocrona_escolar.csv"
scp -q -o ConnectTimeout=20 "$DIR_REPO/db/isocrona/carregar.sql" \
  "$SSH_DB:/tmp/carregar_isocrona.sql"

echo "[2/3] carregando no snapshot $SNAPSHOT (unit carga-$UF)..."
ssh -o ConnectTimeout=20 "$SSH_DB" \
  "systemctl reset-failed carga-$UF 2>/dev/null; \
   systemd-run --unit=carga-$UF --collect --property=Type=oneshot \
     --property=WorkingDirectory=/tmp --setenv=PGPASSWORD='$DB_PASS' \
     /usr/bin/psql -h localhost -U '$DB_USER' -d '$DB' -v ON_ERROR_STOP=1 \
       -v snapshot='$SNAPSHOT' -v build_date='$TILESET_BUILD_DATE' \
       -v origin='$TILESET_ORIGIN' -f /tmp/carregar_isocrona.sql" >/dev/null
while :; do
  est=$(ssh -o ConnectTimeout=20 "$SSH_DB" "systemctl is-active carga-$UF" 2>/dev/null || echo unknown)
  case "$est" in activating|active) sleep 20 ;; *) break ;; esac
done
ssh -o ConnectTimeout=20 "$SSH_DB" \
  "journalctl -u carga-$UF --no-pager -n 6 2>/dev/null | tail -4" 2>/dev/null || true

echo "[3/3] cobertura por UF:"
EDUMAPS_DB_SSH="$SSH_DB" EDUMAPS_DB_NAME="$DB" \
  bash "$DIR_REPO/db/isocrona/cobertura_snapshot.sh" || true
