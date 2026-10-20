#!/usr/bin/env bash
# Driver de isócrona da #278/#295 — a pé 15 min + transporte 45 min.
#
# Roda em 4 passos, todos parametrizáveis por ambiente:
#   1. exporta as escolas do universo do IVET (da UF) e os setores
#      censitários da REGIÃO no banco dev (via ssh — o host local não alcança
#      o Postgres do LXC)
#   2. pede as isócronas ao Valhalla auto-hospedado e arealiza a população
#   3. carrega em clean.isocrona_escolar (idempotente por escola)
#   4. resume contagens
#
# Ambientes (além de VALHALLA/UF/TRABALHO):
#   SETORES_UFS        UFs dos setores exportados — padrão: só a UF-alvo.
#     A REGIÃO inteira é o que corrige o viés de fronteira (#295): célula em
#     UF vizinha precisa dos setores dela e das estradas dela (tiles da
#     região) senão a soma sai subestimada na borda. Ex.: SETORES_UFS=ES,MG,RJ,SP
#   SNAPSHOT            dt_snapshot da carga — padrão: hoje. TODAS as UFs de
#     uma mesma rodada precisam do mesmo valor: a view nacional do IVET filtra
#     por max(dt_snapshot) e um snapshot divergente faz a UF antiga sumir do
#     painel.
#   TILESET_BUILD_DATE  data de build dos tiles — padrão: $SNAPSHOT.
#
# Pré-condições: serviço Valhalla de pé em $VALHALLA cobrindo a REGIÃO toda
# (ver README.md — o driver não cria tiles).
set -euo pipefail

SSH_DB=${EDUMAPS_DB_SSH:-root@database.edumaps}
DB=${EDUMAPS_DB_NAME:-edumaps_dev}
VALHALLA=${VALHALLA:-http://localhost:8002}
UF=${UF:-ES}
SETORES_UFS=${SETORES_UFS:-$UF}
SNAPSHOT=${SNAPSHOT:-$(date +%F)}
TILESET_BUILD_DATE=${TILESET_BUILD_DATE:-$SNAPSHOT}
TRABALHO=${TRABALHO:-/home/itaipu/Code/Data/osm/piloto}
DIR_REPO=$(cd "$(dirname "$0")/../.." && pwd)
PY=${PY:-/home/itaipu/Code/Data/osm/.venv/bin/python}

mkdir -p "$TRABALHO"

psql_remoto() {  # $1 = SQL (uma instrução COPY), sai no stdout como CSV
  ssh -o ConnectTimeout=20 "$SSH_DB" \
    "sudo -u postgres psql -d $DB -q -v ON_ERROR_STOP=1 -c \"$1\"" \
    2>/dev/null
}

echo "[1/4] exportando escolas e setores de $UF..."
psql_remoto "
  COPY (
    SELECT s.co_entidade,
           s.co_municipio::text AS codigo_ibge,
           s.longitude,
           s.latitude
      FROM clean.censo_escolas s
     WHERE s.nu_ano_censo = 2025
       AND s.sg_uf = '$UF'
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
     WHERE m.sigla_uf = ANY (string_to_array('$SETORES_UFS', ','))
  ) TO STDOUT WITH (FORMAT csv, HEADER)" > "$TRABALHO/setores.csv"

echo "  escolas: $(($(wc -l < "$TRABALHO/escolas.csv") - 1))" \
     " setores: $(($(wc -l < "$TRABALHO/setores.csv") - 1))"

echo "[2/4] isócronas + arealização..."
"$PY" "$DIR_REPO/db/isocrona/extrair_isocronas.py" \
  --escolas "$TRABALHO/escolas.csv" \
  --setores "$TRABALHO/setores.csv" \
  --saida "$TRABALHO/isocrona_escolar.csv" \
  --valhalla "$VALHALLA" \
  --retomar   # retomada automática se o CSV já existe (queda não perde lote)

echo "[3/4] carregando em clean.isocrona_escolar..."
scp -q -o ConnectTimeout=20 "$TRABALHO/isocrona_escolar.csv" \
  "$SSH_DB:/tmp/isocrona_escolar.csv"
scp -q -o ConnectTimeout=20 "$DIR_REPO/db/isocrona/carregar.sql" \
  "$SSH_DB:/tmp/carregar_isocrona.sql"
ssh -o ConnectTimeout=20 "$SSH_DB" \
  "sudo -u postgres psql -d $DB -v ON_ERROR_STOP=1 \
     -v snapshot='$SNAPSHOT' -v build_date='$TILESET_BUILD_DATE' \
     -f /tmp/carregar_isocrona.sql" \
  2>/dev/null | tail -4

echo "[4/4] resumo:"
psql_remoto "
  SELECT 'escolas: ' || count(DISTINCT co_entidade) ||
         ' | linhas: ' || count(*) ||
         ' | 15min: ' || count(*) FILTER (WHERE tempo_minutos = 15) ||
         ' | 45min: ' || count(*) FILTER (WHERE tempo_minutos = 45)
    FROM clean.isocrona_escolar"
