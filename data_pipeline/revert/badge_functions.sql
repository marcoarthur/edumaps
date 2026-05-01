-- Revert edumaps:badge_functions from pg

BEGIN;
  DROP FUNCTION IF EXISTS clean.infra_badge_bag(bigint) CASCADE;
  DROP FUNCTION IF EXISTS clean.accessibility_badge_bag(bigint) CASCADE;
  DROP FUNCTION IF EXISTS clean.internet_badge_bag(bigint) CASCADE;
  DROP FUNCTION IF EXISTS clean.typification_badge(bigint) CASCADE;
  DROP FUNCTION IF EXISTS clean.quick_score_avaliation(bigint) CASCADE;
COMMIT;
