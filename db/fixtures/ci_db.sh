#!/usr/bin/env bash
# Sobe o banco de CI: Postgres/PostGIS com o fixture de db/fixtures montado em
# /data, mais o espelho HTTPS local que a migration raw_countries consome.
#
# É o mesmo caminho que o workflow .github/workflows/backend-tests.yml faz, só
# que em um script — assim dá para reproduzir localmente o banco do CI e
# depurar a suíte sem depender do GitHub.
#
#   db/fixtures/ci_db.sh up        # sobe do zero (imagem, rede, espelho, banco,
#                                  # sqitch deploy)
#   db/fixtures/ci_db.sh verify    # roda sqitch verify: o gate das migrations
#                                  # (cada change tem de passar a sua verificação)
#   db/fixtures/ci_db.sh down      # derruba tudo
#   db/fixtures/ci_db.sh status    # mostra o que está de pé
#   db/fixtures/ci_db.sh shell     # psql no banco do CI
#   db/fixtures/ci_db.sh logs      # log do espelho (o que o GDAL pede)
#
# Depois de `up`, a suíte roda com:
#
#   cd backend
#   EDUMAPS_CONF=./t/ci/edu_maps.conf \
#   EDUMAPS_DB_HOST=127.0.0.1 EDUMAPS_DB_PORT=$PORTA \
#   EDUMAPS_DB_NAME=edumaps_ci EDUMAPS_DB_USER=ci EDUMAPS_DB_PASS=ci \
#   EDUMAPS_FIXTURES=1 prove -r -l t/
#
# Variáveis de ambiente:
#   EDUMAPS_CI_PORT    porta do Postgres no host (padrão 5432)
#   EDUMAPS_CI_STATE   diretorio de estado: CA, certificado e docroot (padrão
#                      ${TMPDIR:-/tmp}/edumaps-ci)
set -euo pipefail

# O banco do CI é descartável por construção: pode ser derrubado e recriado a
# qualquer momento sem encostar no banco de desenvolvimento.
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES="$RAIZ/db/fixtures"
PIPELINE="$RAIZ/data_pipeline"

REDE=edumaps-ci-net
IMAGEM=edumaps-db:ci
CONT_DB=edumaps-ci-db
CONT_MIRROR=edumaps-ci-mirror
IMAGEM_SQITCH=sqitch/sqitch:latest
IMAGEM_PY=python:3-alpine

PORTA="${EDUMAPS_CI_PORT:-5432}"
STATE="${EDUMAPS_CI_STATE:-${TMPDIR:-/tmp}/edumaps-ci}"

DB_NAME=edumaps_ci
DB_USER=ci
DB_PASS=ci
# O sqitch roda num container na rede do Docker, então fala com o Postgres pelo
# nome do container — o DNS da rede criada pelo Docker resolve. A porta do host
# é só para o Perl falar de fora.
URI_DEPLOY="db:pg://${DB_USER}:${DB_PASS}@${CONT_DB}/${DB_NAME}"

log() { printf '\033[1;34m[ci-db]\033[0m %s\n' "$*"; }
erro() { printf '\033[1;31m[ci-db]\033[0m %s\n' "$*" >&2; }

# --------------------------------------------------------------------------
imagem() {
  if docker image inspect "$IMAGEM" >/dev/null 2>&1; then
    return 0
  fi
  # O Docker Hub regula o acesso anónimo por IP e responde 429 Too Many
  # Requests à resolução de manifest em rajada (medido no CI a 2026-10-09:
  # o build da base pgvector/pgvector:pg16-bookworm derrubou o job sem
  # retry). O build é idempotente, logo repetir com backoff cobre o rate
  # limit transitório sem mudar o resultado.
  local tentativa
  for tentativa in 1 2 3 4 5; do
    log "construindo $IMAGEM a partir de db/Dockerfile (tentativa ${tentativa}/5)"
    if docker build -f "$RAIZ/db/Dockerfile" -t "$IMAGEM" "$RAIZ/db"; then
      return 0
    fi
    if [[ $tentativa -eq 5 ]]; then
      break
    fi
    log "build falhou (tentativa ${tentativa}/5); aguardando $((tentativa * 10))s e repetindo"
    sleep "$((tentativa * 10))"
  done
  erro "build da imagem $IMAGEM falhou após 5 tentativas"
  return 1
}

rede() {
  if ! docker network inspect "$REDE" >/dev/null 2>&1; then
    log "criando a rede $REDE"
    docker network create "$REDE" >/dev/null
  fi
}

# A migration raw_countries lê o GeoJSON por /vsicurl contra cdn.jsdelivr.net.
# Cloudflare responde chunked sem Content-Length e o vsicurl recusa esse
# framing, então o hostname precisa resolver para um espelho local que serve o
# mesmo arquivo por HTTPS — com Range, senão o GDAL aborta. Ver o docstring de
# db/fixtures/mirror_countries.py.
espelho() {
  if [[ ! -f "$STATE/srv.crt" ]]; then
    log "gerando a CA e o certificado em $STATE"
    mkdir -p "$STATE"
    "$FIXTURES/mirror_countries.py" cert "$STATE" >/dev/null
  fi
  docker rm -f "$CONT_MIRROR" >/dev/null 2>&1 || true
  log "subindo o espelho como cdn.jsdelivr.net na rede $REDE"
  # --network-alias resolve o hostname que a migration pede sem mexer no
  # /etc/hosts do container do Postgres.
  docker run -d --name "$CONT_MIRROR" --network "$REDE" \
    --network-alias cdn.jsdelivr.net \
    -v "$STATE:/m" -v "$FIXTURES:/f:ro" \
    "$IMAGEM_PY" python3 /f/mirror_countries.py serve /m 443 \
      --de /f/countries.geo.json >/dev/null
}

banco() {
  docker rm -f "$CONT_DB" >/dev/null 2>&1 || true
  log "subindo o Postgres com o fixture montado em /data"
  docker run -d --name "$CONT_DB" --network "$REDE" \
    -p "127.0.0.1:${PORTA}:5432" \
    -e "POSTGRES_DB=${DB_NAME}" -e "POSTGRES_USER=${DB_USER}" \
    -e "POSTGRES_PASSWORD=${DB_PASS}" \
    -e CURL_CA_BUNDLE=/m/ca.crt \
    -v "$STATE/ca.crt:/m/ca.crt:ro" \
    -v "$FIXTURES:/data:ro" \
    "$IMAGEM" >/dev/null
  log "esperando o Postgres"
  for _ in $(seq 1 60); do
    if docker exec "$CONT_DB" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  erro "o Postgres nao ficou pronto; logs:"
  docker logs --tail 40 "$CONT_DB" >&2
  return 1
}

deploy() {
  log "rodando sqitch deploy (todas as migrations)"
  # O sqitch tambem roda em container: nao ha `sqitch` instalado na maquina de
  # dev nem no runner do GitHub.
  docker run --rm --network "$REDE" -v "$PIPELINE:/repo" -w /repo \
    "$IMAGEM_SQITCH" deploy "$URI_DEPLOY"
}

# Gate das migrations: cada change roda o seu verify/*.sql contra o banco
# recem-deployado. No banco do CI as changes estao em ordem de plano, portanto
# os erros "out of order" do registry de producao (ver AGENTS.md) nao aparecem.
# Os verify escrevem `DO $$ ... RAISE EXCEPTION $$`; um SELECT que devolve 'f'
# passaria como ok (issue #160), por isso o gate so vale com esse padrao.
verify() {
  log "rodando sqitch verify (gate das migrations)"
  docker run --rm --network "$REDE" -v "$PIPELINE:/repo" -w /repo \
    "$IMAGEM_SQITCH" verify "$URI_DEPLOY"
}

contagens() {
  docker exec "$CONT_DB" psql -U "$DB_USER" -d "$DB_NAME" -qtA -c "
    SELECT 'censo_escolas='       || (SELECT count(*) FROM clean.censo_escolas)
        || ' municipios='         || (SELECT count(*) FROM clean.municipios_sp)
        || ' ideb='               || (SELECT count(*) FROM clean.ideb_notas_escolas)
        || ' inep_desagregadas='  || (SELECT count(*) FROM clean.inep_notas_desagregadas)
        || ' countries='          || (SELECT count(*) FROM clean.countries)
        || ' mv_escolas_scores='  || (SELECT count(*) FROM clean.mv_escolas_scores)
        || ' school_embedding='   || (SELECT count(*) FROM analytics.school_embedding);"
}

cmd_up() {
  imagem
  rede
  espelho
  banco
  deploy
  log "pronto"
  contagens | sed 's/^/[ci-db]   /'
  cat <<EOF
[ci-db]
[ci-db]   cd backend
[ci-db]   env EDUMAPS_CONF=./t/ci/edu_maps.conf \\
[ci-db]       EDUMAPS_DB_HOST=127.0.0.1 EDUMAPS_DB_PORT=${PORTA} \\
[ci-db]       EDUMAPS_DB_NAME=${DB_NAME} EDUMAPS_DB_USER=${DB_USER} \\
[ci-db]       EDUMAPS_DB_PASS=${DB_PASS} EDUMAPS_FIXTURES=1 \\
[ci-db]       prove -r -l t/
EOF
}

cmd_down() {
  docker rm -f "$CONT_DB" "$CONT_MIRROR" >/dev/null 2>&1 || true
  docker network rm "$REDE" >/dev/null 2>&1 || true
  rm -rf "$STATE"
  log "derrubado (imagem $IMAGEM mantida)"
}

cmd_status() {
  for c in "$CONT_DB" "$CONT_MIRROR"; do
    if docker inspect -f '{{.State.Status}}' "$c" >/dev/null 2>&1; then
      log "$c: $(docker inspect -f '{{.State.Status}}' "$c")"
    else
      log "$c: inexistente"
    fi
  done
  if docker inspect "$CONT_DB" >/dev/null 2>&1; then
    contagens | sed 's/^/[ci-db]   /'
  fi
}

case "${1:-up}" in
  up)     cmd_up ;;
  verify) verify ;;
  down)   cmd_down ;;
  status) cmd_status ;;
  shell)  shift; docker exec -it "$CONT_DB" psql -U "$DB_USER" -d "$DB_NAME" "$@" ;;
  logs)   docker logs -f "$CONT_MIRROR" ;;
  *)      erro "uso: $0 {up|verify|down|status|shell|logs}"; exit 2 ;;
esac
