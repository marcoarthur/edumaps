#!/usr/bin/env bash
# Rodada 2 da #295 — RJ, reaproveitando setores.csv do SP (Sudeste inteiro).
#
# O export de setores do SP cobre ES,MG,RJ,SP — logo serve ao RJ sem re-export.
# Aqui rodamos só os passos 2–4 do piloto_es.sh:
#   2. isócronas no Valhalla (tiles do Sudeste, :8003) + arealização
#   3. carga idempotente em clean.isocrona_escolar
#   4. resumo
#
# Pré-condições: /home/itaipu/Code/Data/osm/piloto_sp/setores.csv já exportado
# (Sudeste inteiro) e Valhalla do Sudeste de pé em $VALHALLA.
set -euo pipefail

SSH_DB=${EDUMAPS_DB_SSH:-root@database.edumaps}
DB=${EDUMAPS_DB_NAME:-edumaps_dev}
DB_USER=${EDUMAPS_DB_USER:-edumaps}
DB_PASS=${EDUMAPS_DB_PASS:-change_me}
VALHALLA=${VALHALLA:-http://localhost:8003}
UF=${UF:-RJ}
SNAPSHOT=${SNAPSHOT:-2026-10-21}
TILESET_BUILD_DATE=${TILESET_BUILD_DATE:-$SNAPSHOT}
# De qual extract vieram os tiles — gravado em tileset_origin (proveniência).
TILESET_ORIGIN=${TILESET_ORIGIN:-geofabrik_sudeste_2026-10}
TRABALHO=${TRABALHO:-/home/itaipu/Code/Data/osm/piloto_rj}
SETORES_ORIGEM=${SETORES_ORIGEM:-/home/itaipu/Code/Data/osm/piloto_sp/setores.csv}
DIR_REPO=$(cd "$(dirname "$0")/../.." && pwd)
PY=${PY:-/home/itaipu/Code/Data/osm/.venv/bin/python}

mkdir -p "$TRABALHO"

psql_remoto() {
  ssh -o ConnectTimeout=20 "$SSH_DB" \
    "sudo -u postgres psql -d $DB -q -v ON_ERROR_STOP=1 -c \"$1\"" \
    2>/dev/null
}

echo "[1/3] reaproveitando setores do Sudeste de $SETORES_ORIGEM..."
test -s "$SETORES_ORIGEM" || { echo "ERRO: setores.csv ausente/vazio"; exit 1; }
ln -sf "$SETORES_ORIGEM" "$TRABALHO/setores.csv"

echo "[2/3] exportando escolas de $UF..."
psql_remoto "
  COPY (
    SELECT s.co_entidade,
           s.co_municipio::text AS codigo_ibge,
           s.longitude, s.latitude
      FROM clean.censo_escolas s
     WHERE s.nu_ano_censo = 2025
       AND s.sg_uf = '$UF'
       AND s.tp_situacao_funcionamento = 1
       AND s.latitude IS NOT NULL
       AND s.longitude IS NOT NULL
       AND EXISTS (SELECT 1 FROM clean.mapbiomas_escola_risco r
                    WHERE r.co_entidade = s.co_entidade
                      AND r.nu_ano_censo = 2025 AND r.raio_m = 1000)
     ORDER BY s.co_entidade
  ) TO STDOUT WITH (FORMAT csv, HEADER)" > "$TRABALHO/escolas.csv"
echo "  escolas: $(($(wc -l < "$TRABALHO/escolas.csv") - 1))"

echo "[3/3] isócronas + arealização..."
"$PY" "$DIR_REPO/db/isocrona/extrair_isocronas.py" \
  --escolas "$TRABALHO/escolas.csv" \
  --setores "$TRABALHO/setores.csv" \
  --saida "$TRABALHO/isocrona_escolar.csv" \
  --valhalla "$VALHALLA" \
  --retomar

echo "[4/4] carregando em clean.isocrona_escolar..."
scp -q -o ConnectTimeout=20 "$TRABALHO/isocrona_escolar.csv" \
  "$SSH_DB:/tmp/isocrona_escolar.csv"
scp -q -o ConnectTimeout=20 "$DIR_REPO/db/isocrona/carregar.sql" \
  "$SSH_DB:/tmp/carregar_isocrona.sql"
# Carga DESTACADA no host do banco (`systemd-run`): a transação leva ~20 min
# e uma queda da sessão SSH faz ROLLBACK TOTAL (medido a 2026-10-22, com perda
# de 16,6 M linhas). `setsid nohup` NÃO bastou; um serviço transiente do
# systemd é imune ao fim da conexão. O log fica no journal da unit.
ssh -o ConnectTimeout=20 "$SSH_DB" \
  "systemctl reset-failed carga-$UF 2>/dev/null; \
   systemd-run --unit=carga-$UF --collect --property=Type=oneshot \
     --property=WorkingDirectory=/tmp --setenv=PGPASSWORD='$DB_PASS' \
     /usr/bin/psql -h localhost -U '$DB_USER' -d '$DB' -v ON_ERROR_STOP=1 \
       -v snapshot='$SNAPSHOT' -v build_date='$TILESET_BUILD_DATE' \
       -v origin='$TILESET_ORIGIN' -f /tmp/carregar_isocrona.sql" 2>/dev/null

echo "  aguardando a carga (systemd unit carga-$UF)..."
while :; do
  est=$(ssh -o ConnectTimeout=20 "$SSH_DB" "systemctl is-active carga-$UF" 2>/dev/null || echo unknown)
  case "$est" in activating|active) sleep 20 ;; *) break ;; esac
done
ssh -o ConnectTimeout=20 "$SSH_DB" \
  "journalctl -u carga-$UF --no-pager -n 6 2>/dev/null | tail -4" 2>/dev/null

echo "[resumo]"
psql_remoto "
  SELECT '$UF — escolas: ' || count(DISTINCT co_entidade) ||
         ' | linhas: ' || count(*) ||
         ' | 15min: ' || count(*) FILTER (WHERE tempo_minutos = 15) ||
         ' | 45min: ' || count(*) FILTER (WHERE tempo_minutos = 45)
    FROM clean.isocrona_escolar
   WHERE dt_snapshot = '$SNAPSHOT'"
