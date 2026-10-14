-- Revert edumaps:censo_label from pg
--
-- Remove os helpers e devolve os COMMENTs das colunas enum ao texto de
-- deploy/censo_escolar_2025.sql (rótulos reescritos à mão).

BEGIN;

DROP FUNCTION IF EXISTS clean.censo_code(text, text, text);
DROP FUNCTION IF EXISTS clean.censo_label(text, text, text);
DROP FUNCTION IF EXISTS clean.censo_labels(text, text);

COMMENT ON COLUMN clean.censo_escolas.tp_dependencia IS
  'Dependência administrativa: 1-Federal,2-Estadual,3-Municipal,4-Privada';
COMMENT ON COLUMN clean.censo_escolas.tp_categoria_escola_privada IS
  'Categoria da escola privada: 1-Particular,2-Comunitária,3-Confessional,4-Filantrópica';
COMMENT ON COLUMN clean.censo_escolas.tp_localizacao IS
  'Localização: 1-Urbana,2-Rural';
COMMENT ON COLUMN clean.censo_escolas.tp_localizacao_diferenciada IS
  'Localização diferenciada: 1-Assentamento,2-Terra Indígena,3-Quilombo,4-Área remanescente de quilombos, etc.';

COMMIT;
