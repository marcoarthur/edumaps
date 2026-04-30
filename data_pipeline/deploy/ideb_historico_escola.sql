-- Deploy edumaps:ideb_historico_escola to pg

BEGIN;

  CREATE OR REPLACE FUNCTION clean.ideb_historico_escola(p_co_entidade BIGINT)
  RETURNS JSON AS $$
  DECLARE
      result_json JSON;
  BEGIN
      WITH 
      -- Dados por etapa
      etapa_dados AS (
          SELECT 
              etapa,
              json_agg(
                  json_build_object('ano', ano, 'nota_ideb', ideb_observado)
                  ORDER BY ano
              ) AS serie_historica,
              json_build_object(
                  'max', MAX(ideb_observado),
                  'min', MIN(ideb_observado),
                  'media', ROUND(AVG(ideb_observado), 2),
                  'total_anos', COUNT(*)
              ) AS estatisticas
          FROM clean.ideb_notas_escolas
          WHERE id_escola = p_co_entidade
            AND ideb_observado IS NOT NULL
          GROUP BY etapa
      )
      SELECT 
          COALESCE(
              json_agg(
                  json_build_object(
                      'etapa', CASE ed.etapa
                          WHEN 'fundamental_i' THEN 'Ensino Fundamental - Anos Iniciais (1º ao 5º ano)'
                          WHEN 'fundamental_ii' THEN 'Ensino Fundamental - Anos Finais (6º ao 9º ano)'
                          WHEN 'ensino_medio' THEN 'Ensino Médio'
                          ELSE ed.etapa
                      END,
                      'serie_historica', ed.serie_historica,
                      'valores', ed.estatisticas
                  )
                  ORDER BY ed.etapa
              ),
              json_build_object(
                  'erro', 'Nenhum dado IDEB encontrado para a escola',
                  'co_entidade', p_co_entidade
              )
          ) INTO result_json
      FROM etapa_dados ed;
      
      RETURN result_json;
  END;
  $$ LANGUAGE plpgsql;

  COMMENT ON FUNCTION clean.ideb_historico_escola(BIGINT) IS 'Retorna série histórica do IDEB para uma escola, com estatísticas (max, min, média) por etapa de ensino';

COMMIT;
