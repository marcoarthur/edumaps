#!/usr/bin/env bash
# Rodada 2 da #295 — Região Nordeste de uma vez.
#
# O extract do Nordeste (Geofabrik) cobre BA, MA, PE, CE, PB, PI, RN, AL, SE.
# Como o tileset é regional, exportamos as 9 UFs numa ÚNICA passada de
# extração (o Python aceita um escolas.csv com todas) — uma corrida só, em vez
# de 9. Os setores são da região inteira (corrige o viés de fronteira, #295).
#
# Pré-condições: tiles do Nordeste de pé em $VALHALLA (valhalla_nordeste,
# :8004) e o extract nordeste-latest.osm.pbf já usado no build.
set -euo pipefail

SSH_DB=${EDUMAPS_DB_SSH:-root@database.edumaps}
DB=${EDUMAPS_DB_NAME:-edumaps_dev}
DB_USER=${EDUMAPS_DB_USER:-edumaps}
DB_PASS=${EDUMAPS_DB_PASS:-change_me}
VALHALLA=${VALHALLA:-http://localhost:8004}
SNAPSHOT=${SNAPSHOT:-2026-10-21}
TILESET_BUILD_DATE=${TILESET_BUILD_DATE:-$SNAPSHOT}
# De qual extract vieram os tiles — gravado em tileset_origin (proveniência).
TILESET_ORIGIN=${TILESET_ORIGIN:-geofabrik_nordeste_2026-10}
TRABALHO=${TRABALHO:-/home/itaipu/Code/Data/osm/piloto_nordeste}
DIR_REPO=$(cd "$(dirname "$0")/../.." && pwd)
PY=${PY:-/home/itaipu/Code/Data/osm/.venv/bin/python}
# UFs do Nordeste que o extract cobre (todas as 9).
UFS_NORDESTE=${UFS_NORDESTE:-BA,MA,PE,CE,PB,PI,RN,AL,SE}

mkdir -p "$TRABALHO"

psql_remoto() {
  ssh -o ConnectTimeout=20 "$SSH_DB" \
    "sudo -u postgres psql -d $DB -q -v ON_ERROR_STOP=1 -c \"$1\"" \
    2>/dev/null
}

echo "[1/4] exportando escolas e setores do Nordeste ($UFS_NORDESTE)..."
psql_remoto "
  COPY (
    SELECT s.co_entidade,
           s.co_municipio::text AS codigo_ibge,
           s.longitude,
           s.latitude
      FROM clean.censo_escolas s
     WHERE s.nu_ano_censo = 2025
       AND s.sg_uf = ANY (string_to_array('$UFS_NORDESTE', ','))
       AND s.tp_situacao_funcionamento = 1
       AND s.latitude IS NOT NULL AND s.longitude IS NOT NULL
       AND EXISTS (SELECT 1 FROM clean.mapbiomas_escola_risco r
                    WHERE r.co_entidade = s.co_entidade
                      AND r.nu_ano_censo = 2025 AND r.raio_m = 1000)
     ORDER BY s.co_entidade
  ) TO STDOUT WITH (FORMAT csv, HEADER)" > "$TRABALHO/escolas.csv"

psql_remoto "
  COPY (
    SELECT m.codigo_setor,
           s.pop_total,
           encode(ST_AsBinary(ST_Transform(m.geometry, 4326)), 'hex') AS wkb
      FROM clean.malha_setor_censitario m
      LEFT JOIN clean.censo2022_setor s USING (codigo_setor)
     WHERE m.sigla_uf = ANY (string_to_array('$UFS_NORDESTE', ','))
  ) TO STDOUT WITH (FORMAT csv, HEADER)" > "$TRABALHO/setores.csv"

echo "  escolas: $(($(wc -l < "$TRABALHO/escolas.csv") - 1))" \
     " setores: $(($(wc -l < "$TRABALHO/setores.csv") - 1))"

echo "[2/4] isócronas + arealização (Nordeste inteiro)..."
"$PY" "$DIR_REPO/db/isocrona/extrair_isocronas.py" \
  --escolas "$TRABALHO/escolas.csv" \
  --setores "$TRABALHO/setores.csv" \
  --saida "$TRABALHO/isocrona_escolar.csv" \
  --valhalla "$VALHALLA" \
  --retomar

echo "[3/4] carregando em clean.isocrona_escolar..."
scp -q -o ConnectTimeout=20 "$TRABALHO/isocrona_escolar.csv" \
  "$SSH_DB:/tmp/isocrona_escolar.csv"
scp -q -o ConnectTimeout=20 "$DIR_REPO/db/isocrona/carregar.sql" \
  "$SSH_DB:/tmp/carregar_isocrona.sql"
# Carga DESTACADA no host do banco (`systemd-run`): a transação leva ~40 min
# (Nordeste ~28 M linhas). À prova de queda de SSH — imune ao fim da conexão.
# `setsid nohup` NÃO bastou no passado (rollback total medido 2026-10-22).
ssh -o ConnectTimeout=20 "$SSH_DB" \
  "systemctl reset-failed carga-nordeste 2>/dev/null; \
   systemd-run --unit=carga-nordeste --collect --property=Type=oneshot \
     --property=WorkingDirectory=/tmp --setenv=PGPASSWORD='$DB_PASS' \
     /usr/bin/psql -h localhost -U '$DB_USER' -d '$DB' -v ON_ERROR_STOP=1 \
       -v snapshot='$SNAPSHOT' -v build_date='$TILESET_BUILD_DATE' \
       -v origin='$TILESET_ORIGIN' -f /tmp/carregar_isocrona.sql" 2>/dev/null

echo "  aguardando a carga (systemd unit carga-nordeste)..."
while :; do
  est=$(ssh -o ConnectTimeout=20 "$SSH_DB" "systemctl is-active carga-nordeste" 2>/dev/null || echo unknown)
  case "$est" in activating|active) sleep 30 ;; *) break ;; esac
done
ssh -o ConnectTimeout=20 "$SSH_DB" \
  "journalctl -u carga-nordeste --no-pager -n 6 2>/dev/null | tail -4" 2>/dev/null

echo "[4/4] resumo:"
psql_remoto "
  SELECT 'Nordeste — escolas: ' || count(DISTINCT co_entidade) ||
         ' | linhas: ' || count(*) ||
         ' | 15min: ' || count(*) FILTER (WHERE tempo_minutos = 15) ||
         ' | 45min: ' || count(*) FILTER (WHERE tempo_minutos = 45)
    FROM clean.isocrona_escolar
   WHERE dt_snapshot = '$SNAPSHOT'"
