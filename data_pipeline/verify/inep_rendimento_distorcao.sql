-- Verify edumaps:inep_rendimento_distorcao on pg

DO $$
BEGIN
  PERFORM cod_inep, ano, etapa, aprovacao, reprovacao, abandono FROM clean.inep_rendimento_escola WHERE FALSE;
  PERFORM cod_inep, ano, etapa, distorcao FROM clean.inep_distorcao_escola WHERE FALSE;
  IF (SELECT count(*) FROM analytics.indicadores_meta_catalogo WHERE grupo = 'fluxo') <> 12 THEN
    RAISE EXCEPTION 'catálogo sem os 12 códigos de fluxo (#376)';
  END IF;
  IF NOT has_table_privilege('edumaps_leitor', 'clean.inep_rendimento_escola', 'SELECT') THEN
    RAISE EXCEPTION 'edumaps_leitor sem SELECT em clean.inep_rendimento_escola';
  END IF;
  IF position('inep_rendimento_escola' IN pg_get_viewdef('analytics.escola_indicadores_meta'::regclass)) = 0 THEN
    RAISE EXCEPTION 'escola_indicadores_meta não lê as taxas de rendimento';
  END IF;
END
$$;
