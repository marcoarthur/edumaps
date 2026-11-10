#!/usr/bin/env bash
# Cobertura da isócrona por UF e por snapshot (#295).
#
# A view do IVET (analytics.mobilidade_escola) só lê o snapshot MAIS RECENTE
# de clean.isocrona_escolar. Uma UF carregada só num snapshot anterior some do
# painel sem erro nenhum: foi o que aconteceu com ES e MG quando a rodada 2
# gravou SP/RJ/Nordeste em 2026-10-21 e o snapshot 2026-10-20 foi apagado.
# Este script lista escolas por UF em cada snapshot e marca as UFs que estão
# fora do vigente. Sai com código 1 se houver alguma.
#
# Uso: bash db/isocrona/cobertura_snapshot.sh
#   EDUMAPS_DB_SSH (padrão root@database.edumaps) e EDUMAPS_DB_NAME (padrão
#   edumaps_dev), as mesmas variáveis dos drivers.
set -euo pipefail

SSH_DB=${EDUMAPS_DB_SSH:-root@database.edumaps}
DB=${EDUMAPS_DB_NAME:-edumaps_dev}

SQL="
WITH por_uf AS (
  SELECT left(codigo_ibge, 2) AS cod_uf, dt_snapshot,
         count(DISTINCT co_entidade) AS escolas
    FROM clean.isocrona_escolar
   GROUP BY 1, 2
), vigente AS (SELECT max(dt_snapshot) AS s FROM clean.isocrona_escolar)
SELECT p.cod_uf, p.dt_snapshot, p.escolas,
       CASE WHEN p.dt_snapshot = v.s THEN 'vigente'
            WHEN NOT EXISTS (SELECT 1 FROM por_uf q
                              WHERE q.cod_uf = p.cod_uf AND q.dt_snapshot = v.s)
            THEN 'FORA DO PAINEL'
            ELSE 'superado' END AS situacao
  FROM por_uf p, vigente v
 ORDER BY p.cod_uf, p.dt_snapshot;"

saida=$(ssh -o ConnectTimeout=20 "$SSH_DB" \
  "sudo -u postgres psql -d $DB -q -v ON_ERROR_STOP=1 -AF ' | ' -c \"$SQL\"")
echo "$saida"

if grep -q 'FORA DO PAINEL' <<<"$saida"; then
  echo "ATENÇÃO: há UF só em snapshot anterior ao vigente; ela não aparece no IVET." >&2
  echo "Recarregue essas UFs no snapshot vigente antes de apagar o antigo." >&2
  exit 1
fi
