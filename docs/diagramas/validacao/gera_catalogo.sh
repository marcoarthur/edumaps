#!/bin/sh
# gera_catalogo.sh — gera os três insumos usados por valida.pl:
#
#   colunas.txt    schema.tabela|coluna|tipo_pg      (catálogo Postgres)
#   fks.txt        schema.tabela|coluna|schema.tabela|coluna
#   relacoes.tsv   SRC/COLS/REL minerados do código Perl dos Results DBIC
#
# Uso, de qualquer lugar do repositório:
#   sh docs/diagramas/validacao/gera_catalogo.sh [dir_saida]
#
# Ambiente (com defaults do projeto de desenvolvimento):
#   EDUMAPS_DB         contentor do Postgres   (default: edumaps-db)
#   EDUMAPS_DB_USER    usuário                 (default: devel)
#   EDUMAPS_DB_NAME    base                    (default: edumaps_dev)
#
# Nada aqui é gravado no banco: são consultas de catálogo (pg_class,
# pg_attribute, pg_constraint) e leitura de arquivos .pm.
set -e

SAIDA="${1:-docs/diagramas/validacao}"
DB="${EDUMAPS_DB:-edumaps-db}"
DBUSER="${EDUMAPS_DB_USER:-devel}"
DBNAME="${EDUMAPS_DB_NAME:-edumaps_dev}"

mkdir -p "$SAIDA"

# descobre a raiz do repositório a partir da localização deste script
RAIZ=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)

psql_cmd() {
    # o SQL vai por stdin: evita os problemas de quoting do shell em
    # comandos aninhados (sg -c + aspas)
    docker exec -i "$DB" psql -U "$DBUSER" -d "$DBNAME" -At
}

echo "gerando $SAIDA/colunas.txt ..."
psql_cmd > "$SAIDA/colunas.txt" <<'SQL'
SELECT n.nspname || '.' || c.relname || '|' || a.attname || '|' ||
       format_type(a.atttypid, a.atttypmod)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid
WHERE c.relkind IN ('r','v','m','p')
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY 1;
SQL

echo "gerando $SAIDA/fks.txt ..."
psql_cmd > "$SAIDA/fks.txt" <<'SQL'
SELECT quote_ident(sn.nspname) || '.' || quote_ident(sc.relname) || '|' || a.attname || '|' ||
       quote_ident(fn.nspname) || '.' || quote_ident(fc.relname) || '|' || af.attname
FROM pg_constraint c
JOIN pg_class sc ON sc.oid = c.conrelid
JOIN pg_namespace sn ON sn.oid = sc.relnamespace
JOIN pg_class fc ON fc.oid = c.confrelid
JOIN pg_namespace fn ON fn.oid = fc.relnamespace
JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS l(attnum, ord) ON true
JOIN LATERAL unnest(c.confkey) WITH ORDINALITY AS r(attnum, ord) ON r.ord = l.ord
JOIN pg_attribute a  ON a.attrelid  = c.conrelid AND a.attnum  = l.attnum
JOIN pg_attribute af ON af.attrelid = c.confrelid AND af.attnum = r.attnum
WHERE c.contype = 'f'
ORDER BY 1;
SQL

echo "gerando $SAIDA/relacoes.tsv ..."
( cd "$RAIZ/backend" && perl "$RAIZ/docs/diagramas/validacao/minerador_relacoes.pl" ) \
    > "$SAIDA/relacoes.tsv"

printf 'colunas: %s · fks: %s · relacoes: %s\n' \
    "$(wc -l < "$SAIDA/colunas.txt")" \
    "$(wc -l < "$SAIDA/fks.txt")" \
    "$(wc -l < "$SAIDA/relacoes.tsv")"

cat <<EOF

Próximo passo:
  perl docs/diagramas/validacao/valida.pl \\
       --colunas $SAIDA/colunas.txt \\
       --fks     $SAIDA/fks.txt \\
       --relacoes $SAIDA/relacoes.tsv
EOF
