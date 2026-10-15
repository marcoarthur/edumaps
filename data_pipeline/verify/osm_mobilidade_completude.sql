SELECT CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END
FROM pg_proc
WHERE proname = 'iv_mobilidade_completude_malha'
  AND pronamespace = 'clean'::regnamespace;
