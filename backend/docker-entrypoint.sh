#!/bin/bash
set -e
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
}
EOF

if [ "$1" = 'minion' ]; then
    exec carton exec ./edu_maps.pl minion worker
else
    exec carton exec morbo edu_maps.pl
fi
