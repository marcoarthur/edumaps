-- Verify edumaps:consistent_schools_mv on pg

BEGIN;

  SELECT 1/COUNT(*) 
  FROM pg_matviews 
  WHERE matviewname = 'consistent_schools';

ROLLBACK;
