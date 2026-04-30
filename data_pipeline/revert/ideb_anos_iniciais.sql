-- Revert edumaps:ideb_anos_iniciais from pg

BEGIN;

  -- Remove apenas os dados de fundamental I (mantém fundamental II e ensino médio)
  DELETE FROM clean.ideb_notas_escolas WHERE etapa = 'fundamental_i';

COMMIT;
