-- Verify edumaps:escolas_scores_versao on pg
--
-- Falha de verdade (DO + RAISE, #160) se o comentário da MV não trouxer a
-- versão dos índices.

BEGIN;

  DO $$
  BEGIN
      IF coalesce(obj_description('clean.mv_escolas_scores'::regclass, 'pg_class'), '') !~ 'VERSÃO indices-v[0-9]+ ' THEN
          RAISE EXCEPTION 'comentário de clean.mv_escolas_scores sem a versão dos índices (indices-vN)';
      END IF;
  END $$;

ROLLBACK;
