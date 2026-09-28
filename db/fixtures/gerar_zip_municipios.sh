#!/usr/bin/env bash
# Gera o fixture BR_Municipios_2024.zip a partir do shapefile real do IBGE 2024.
#
# Por que um script e não o arquivo pronto
# ---------------------------------------
# O ZIP é binário e sai de um shapefile de 208 MB que não está no repositório
# (é `datasets/`, gitignored). Este script deixa a geração reproduzível: rodar
# de novo após uma atualização do IBGE regenera o fixture.
#
# Restrições que o fixture precisa respeitar
# -------------------------------------------
# A migration `raw_municipios_sp` é fixa e não pode ser alterada (o checksum do
# Sqitch já está em produção). Ela declara:
#   datasource '/vsizip///data/BR_Municipios_2024.zip', format 'ESRI Shapefile'
#   IMPORT FOREIGN SCHEMA ogr_all FROM SERVER ... INTO raw;
#   ... FROM raw.BR_Municipios_2024 ...
#
# Portanto o ZIP precisa conter um *shapefile* (o format é pinado, um GeoJSON
# seria recusado) cujo *layer* se chame BR_Municipios_2024, em EPSG:4674, com os
# campos cd_mun, nm_mun, cd_rgi, nm_rgi, cd_rgint, nm_rgint, cd_uf, nm_uf,
# sigla_uf, cd_regia, nm_regia, sigla_rg, cd_concu, nm_concu, area_km2 e geom.
#
# Uso
# ---
#   # com o gdal na máquina:
#   db/fixtures/gerar_zip_municipios.sh datasets/BR_Municipios_2024.zip
#
#   # ou via container, se não tiver gdal na máquina:
#   docker run --rm -v "$PWD/datasets:/d:ro" -v "$PWD/db/fixtures:/w" \
#     osgeo/gdal:latest bash /w/gerar_zip_municipios.sh /d/BR_Municipios_2024.zip /w
set -euo pipefail

ENTRADA="${1:?uso: gerar_zip_municipios.sh <zip_real> [zip_saida]}"
SAIDA="${2:-$(dirname "$(readlink -f "$0")")/BR_Municipios_2024.zip}"

# Os municípios do fixture, na mesma lista de db/fixtures/gerar.py. Se a lista
# divergir entre os dois arquivos, `sqitch deploy` quebra: a migration cruza
# raw.escolas com raw.BR_Municipios_2024 por nome/código e fica sem geometria.
# Cobrem as 5 regiões geográficas e as UFs 11 (RO) e 35 (SP) — requirements de
# t/02-models/school/geo.t (nuvem de pontos) e das agregações por região.
# Os códigos foram conferidos um a um contra o shapefile do IBGE 2024; atenção
# para Ubatuba (3555406), Taubaté (3554102) e Santa Cruz do Sul (4316808).
IN_LIST="('1100015','1100205','1200401','1302603','1501402','2104073','2111300','2302701','3106200','3509502','3550308','3553807','3554102','3555406','4106902','4316808','4316907','5107040')"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v ogr2ogr >/dev/null || { echo "ERRO: ogr2ogr ausente" >&2; exit 1; }

ogr2ogr -f "ESRI Shapefile" "$TMP/fx" "/vsizip/$ENTRADA" \
  -dialect SQLITE \
  -sql "SELECT * FROM BR_Municipios_2024 WHERE CD_MUN IN ${IN_LIST}" \
  -nln BR_Municipios_2024 \
  -nlt MULTIPOLYGON \
  -a_srs EPSG:4674 \
  -overwrite

# zip -j (junk paths) para que os arquivos fiquem na raiz do ZIP: o OGR não
# acha a camada se houver diretório intermediário.
(cd "$TMP/fx" && zip -q -j -X "$SAIDA" BR_Municipios_2024.*)

echo "gerado: $SAIDA ($(stat -c%s "$SAIDA") bytes)"
ogrinfo -ro -al -so "/vsizip/$SAIDA" 2>/dev/null | grep -E 'Feature Count|^Geometry'
ogrinfo -ro -q -geom=NO "/vsizip/$SAIDA" \
  -sql "SELECT CD_MUN, NM_MUN, CD_UF, CD_REGIA, SIGLA_RG FROM BR_Municipios_2024" 2>/dev/null \
  | grep -E 'CD_MUN |NM_MUN |CD_UF |CD_REGIA |SIGLA_RG ' | paste - - - - -
