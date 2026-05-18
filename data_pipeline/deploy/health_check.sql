-- Deploy edumaps:health_check to pg

BEGIN;

  CREATE OR REPLACE FUNCTION health_check_approx(schema_name TEXT, table_name TEXT)
  RETURNS TABLE (
      column_name TEXT,
      data_type TEXT,
      total_rows BIGINT,
      null_count BIGINT,
      non_null_count BIGINT,
      null_percentage NUMERIC(5,2),
      distinct_approx BIGINT,
      min_value TEXT,
      max_value TEXT
  ) LANGUAGE plpgsql AS $$
  DECLARE
      rec RECORD;
      v_total_rows BIGINT;
  BEGIN
      -- Obtém o número total de linhas rapidamente (estatísticas)
      SELECT reltuples::BIGINT INTO v_total_rows
      FROM pg_class
      WHERE oid = format('%I.%I', schema_name, table_name)::regclass;

      FOR rec IN
          SELECT 
              a.attname AS column_name,
              pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
              s.null_frac,
              s.n_distinct,
              -- Tenta obter mínimo/máximo das estatísticas extendidas (se disponível)
              s.most_common_vals IS NOT NULL AS has_stats
          FROM pg_attribute a
          LEFT JOIN pg_stats s ON s.schemaname = schema_name 
                              AND s.tablename = table_name 
                              AND s.attname = a.attname
          WHERE a.attrelid = format('%I.%I', schema_name, table_name)::regclass
            AND a.attnum > 0
            AND NOT a.attisdropped
          ORDER BY a.attnum
      LOOP
          column_name := rec.column_name;
          data_type := rec.data_type;
          total_rows := v_total_rows;

          -- Estima nulos a partir de null_frac
          null_count := (rec.null_frac * v_total_rows)::BIGINT;
          non_null_count := v_total_rows - null_count;
          null_percentage := (rec.null_frac * 100)::NUMERIC(5,2);

          -- Estima distintos: n_distinct negativo = fração, positivo = contagem real estimada
          IF rec.n_distinct < 0 THEN
              distinct_approx := (abs(rec.n_distinct) * v_total_rows)::BIGINT;
          ELSE
              distinct_approx := rec.n_distinct::BIGINT;
          END IF;

          -- Mínimo/máximo não estão em pg_stats por padrão (precisariam de extended stats)
          -- Deixamos NULL; se quiser, pode fazer uma consulta pontual só para essas colunas
          min_value := NULL;
          max_value := NULL;

          RETURN NEXT;
      END LOOP;
      RETURN;
  END;
  $$;
COMMIT;
