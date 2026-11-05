#!/bin/bash
set -e

# Proxies confiáveis para o X-Real-IP (EduMaps::Util::ClientIP), separados por
# espaço. Sem a variável, vale o padrão do código.
PROXIES_CONF=""
if [ -n "${EDUMAPS_PROXIES_CONFIAVEIS:-}" ]; then
  lista=""
  for p in $EDUMAPS_PROXIES_CONFIAVEIS; do
    [[ "$p" =~ ^[0-9A-Fa-f:./]+$ ]] || { echo "EDUMAPS_PROXIES_CONFIAVEIS: valor inválido: $p" >&2; exit 1; }
    lista+="'$p', "
  done
  PROXIES_CONF="auth_limite => { proxies_confiaveis => [ $lista] },"
fi

cat > /opt/edumaps/backend/edu_maps.conf <<EOF
{
  db_params => [
      'dbi:Pg:dbname=${DB_NAME};host=db;port=${DB_PORT:-5432}',
      '${DB_USER}',
      '${DB_PASS}',
 ],
  db_opts => {
    RaiseError          => 1,
    PrintError          => 0,
    AutoCommit          => 1,
    pg_server_prepare   => 1,
    pg_enable_utf8      => 1,
    pg_bytea            => 'escape',
    ShowErrorStatement  => 1,
    TraceLevel          => 0,
    pg_connect_timeout  => 10,
    pg_keepalive        => 1,
    pg_appname          => 'edumaps_dev',
  },
  db_url => 'postgresql://${DB_USER}:${DB_PASS}@db/${DB_NAME}',
  sentry => {
    dsn     => '${EDUMAPS_SENTRY_DSN:-}',
    release => '${EDUMAPS_SENTRY_RELEASE:-}',
  },
  ${PROXIES_CONF}
}
EOF

if [ "$1" = 'minion' ]; then
    exec carton exec ./script/edumaps.pl minion worker
else
    exec carton exec morbo script/edumaps.pl
fi
