-- Deploy edumaps:ranking_escola_empates to pg
-- requires: ranking_escolas

-- #506 (RC-01): o tamanho do empate de cada escola em cada escopo, para o
-- "acima de X% das escolas" contar só as de valor menor. A posição é um
-- RANK(): as empatadas recebem a melhor posição, e o percentil antigo
-- (total − posição)/(total − 1) contava as empatadas como abaixo (as 52.164
-- escolas com sustentabilidade 0 apareciam "acima de 29%").
-- empate_* = escolas com o mesmo valor no escopo, contando a própria.

BEGIN;

ALTER TABLE analytics.ranking_escola
  ADD COLUMN empate_municipio integer,
  ADD COLUMN empate_estado    integer,
  ADD COLUMN empate_nacional  integer;

COMMENT ON COLUMN analytics.ranking_escola.empate_municipio IS
  'Escolas do município com o mesmo valor no indicador, contando a própria (#506)';
COMMENT ON COLUMN analytics.ranking_escola.empate_estado IS
  'Escolas da UF com o mesmo valor no indicador, contando a própria (#506)';
COMMENT ON COLUMN analytics.ranking_escola.empate_nacional IS
  'Escolas do Brasil com o mesmo valor no indicador, contando a própria (#506)';

COMMIT;
