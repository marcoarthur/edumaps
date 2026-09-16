-- Verify edumaps:column_descriptions on pg

BEGIN;

  -- Informa, por tabela alvo, quantas colunas seguem sem descricao.
  -- Apos o deploy esta contagem deve ser 0 em todas.
  SELECT
    n.nspname                    AS schema,
    c.relname                    AS tabela,
    count(*) FILTER (
      WHERE col_description(c.oid, a.attnum) IS NULL
    )::int                       AS sem_descricao
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
  WHERE (n.nspname, c.relname) IN (
    ('analytics', 'school_embedding'),
    ('clean',     'event_store'),
    ('clean',     'mv_escolas_scores'),
    ('clean',     'censo_escolas'),
    ('clean',     'school_indicators'),
    ('analytics', 'mv_rede_escolas')
  )
  GROUP BY n.nspname, c.relname
  ORDER BY n.nspname, c.relname;

ROLLBACK;
