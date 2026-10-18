#!/bin/bash
# =============================================================================
# Aplica a extração de EXPOSIÇÃO A RISCO (MapBiomas Fogo + Solo) sobre a área
# de influência da escola — POR ESTADO e EM BLOCOS (região imediata).
# Issue #278 (bloco F do IVET).
# =============================================================================
#
# Por que em blocos: cada raster tem ~2 GB e a arealização recorta o raster à
# área dos buffers antes de extrair. Rodar o país inteiro de uma vez é lento e
# consome memória; uma região imediata (8–47 municípios) é um bloco pequeno e
# terminável. A carga é idempotente (UPSERT por ano × raio), então re-rodar um
# bloco não duplica.
#
# RETOMÁVEL: antes de cada bloco, conta quantas escolas da região ainda não têm
# linha para o ano × raio e pula as completas. Interromper e re-rodar o mesmo
# comando continua de onde parou (a carga de um bloco é uma transação).
#
# Uso (a partir de backend/, com o Minion/runner disponível):
#
#   script/ingestao/mapbiomas_risco.sh SP             # todas as regiões de SP
#   script/ingestao/mapbiomas_risco.sh SP 2020 1000   # ano e raio explícitos
#   script/ingestao/mapbiomas_risco.sh SP 2020 1000 "São José dos Campos"
#                                                     # uma região só
#
# O estado do progresso fica no log (uma linha por bloco).
set -uo pipefail

UF="${1:?uso: mapbiomas_risco.sh <UF> [ano] [raio] [regiao]}"
ANO="${2:-2020}"
RAIO="${3:-1000}"
SO_REGIAO="${4:-}"

AQUI="$(cd "$(dirname "$0")" && pwd)"
BACKEND="$(cd "$AQUI/../.." && pwd)"
cd "$BACKEND"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

log "MapBiomasRisco UF=$UF ano=$ANO raio=$RAIO${SO_REGIAO:+ regiao='$SO_REGIAO'}"

# Regiões imediatas da UF, os seus municípios e quantos ainda faltam carregar.
mapfile -t REGIOES < <(carton exec -- perl "$AQUI/regioes_do_estado.pl" "$UF" "$ANO" "$RAIO" 2>/dev/null)
if [ "${#REGIOES[@]}" -eq 0 ]; then
  log "ERRO: não listei regiões para $UF"
  exit 1
fi

falhas=0
for linha in "${REGIOES[@]}"; do
  regiao="${linha%%$'\t'*}"
  resto="${linha#*$'\t'}"
  munis="${resto%%$'\t'*}"
  pendentes="${resto#*$'\t'}"
  [ "$pendentes" = "$resto" ] && pendentes=""   # sem 3º campo
  if [ -n "$SO_REGIAO" ] && [ "$regiao" != "$SO_REGIAO" ]; then
    continue
  fi
  if [ "$pendentes" = "0" ]; then
    log "--- $regiao: já carregada (0 pendentes), pulando"
    continue
  fi

  ini=$(date +%s)
  log ">>> $regiao${pendentes:+ ($pendentes pendentes)}"
  if carton exec -- perl ingestion_runner.pl \
       --job=MapBiomasRisco \
       --arg "ano=$ANO" --arg "raio=$RAIO" --arg "uf=$UF" --arg "municipios=$munis"; then
    log "<<< $regiao OK ($(( $(date +%s) - ini ))s)"
  else
    log "<<< $regiao FALHOU ($(( $(date +%s) - ini ))s)"
    falhas=$((falhas + 1))
  fi
done

log "FIM UF=$UF (blocos com falha: $falhas)"
exit "$falhas"
