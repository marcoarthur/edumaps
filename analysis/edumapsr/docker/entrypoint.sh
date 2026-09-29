#!/bin/sh
# Entrypoint do serviço analítico no compose local.
#
# Gera o /root/.pg_service.conf (edumaps / edumaps_local / edumaps_leitor) a
# partir das variáveis do compose, habilita LOGIN+senha da role leitora
# (espelha o `deploy_db_dev`, que faz o mesmo no deploy real) e sobe o
# Plumber em :8000 com locale/fuso corretos.
set -e

DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-5432}"

cat > /root/.pg_service.conf <<EOF
[edumaps]
host=${DB_HOST}
port=${DB_PORT}
user=${DB_USER}
dbname=${DB_NAME}
password=${DB_PASS}

[edumaps_local]
host=${DB_HOST}
port=${DB_PORT}
user=${DB_USER}
dbname=${DB_NAME}
password=${DB_PASS}

[edumaps_leitor]
host=${DB_HOST}
port=${DB_PORT}
user=edumaps_leitor
dbname=${DB_NAME}
password=${DB_PASS}
EOF
chmod 600 /root/.pg_service.conf

export TZ="${TZ:-America/Sao_Paulo}"
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"
export EDUMAPS_ANALYTICS_DB_SERVICE="${EDUMAPS_ANALYTICS_DB_SERVICE:-edumaps_local}"
export EDUMAPS_CHAT_DB_SERVICE="${EDUMAPS_CHAT_DB_SERVICE:-edumaps_leitor}"
export EDUMAPS_R_PORT="${EDUMAPS_R_PORT:-8000}"

# A migration cria a role `edumaps_leitor` NOLOGIN (sem credencial no repo) e
# o deploy habilita LOGIN+senha no `deploy_db_dev`. Aqui fazemos o mesmo para
# o assistente NL/SQL funcionar no compose. Best-effort: se falhar, o serviço
# sobe mesmo assim (só o /ask fica sem acesso).
Rscript -e '
ok <- tryCatch({
  con <- DBI::dbConnect(RPostgres::Postgres(), service = "edumaps_local")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbExecute(con, sprintf("ALTER ROLE edumaps_leitor LOGIN PASSWORD %s",
                              DBI::dbQuoteString(con, Sys.getenv("DB_PASS"))))
  TRUE
}, error = function(e) FALSE)
if (!ok) cat("[analytic] aviso: nao habilitei LOGIN da edumaps_leitor\n")
' || true

exec Rscript inst/plumber/run.R
