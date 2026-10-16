-- Revert edumaps:censo2022_setor_instrucao_saneamento from pg
BEGIN;

ALTER TABLE clean.censo2022_setor
  DROP COLUMN IF EXISTS alf_sabe_15mais,
  DROP COLUMN IF EXISTS alf_nao_sabe_15mais,
  DROP COLUMN IF EXISTS dom_agua_rede,
  DROP COLUMN IF EXISTS dom_agua_poco_profundo,
  DROP COLUMN IF EXISTS dom_agua_poco_raso,
  DROP COLUMN IF EXISTS dom_agua_nascente,
  DROP COLUMN IF EXISTS dom_agua_carro_pipa,
  DROP COLUMN IF EXISTS dom_agua_chuva,
  DROP COLUMN IF EXISTS dom_agua_rio,
  DROP COLUMN IF EXISTS dom_agua_outra,
  DROP COLUMN IF EXISTS dom_esgoto_rede,
  DROP COLUMN IF EXISTS dom_esgoto_fossa_septica_rede,
  DROP COLUMN IF EXISTS dom_esgoto_fossa_septica,
  DROP COLUMN IF EXISTS dom_esgoto_fossa_rudimentar,
  DROP COLUMN IF EXISTS dom_esgoto_vala,
  DROP COLUMN IF EXISTS dom_esgoto_rio,
  DROP COLUMN IF EXISTS dom_esgoto_outra,
  DROP COLUMN IF EXISTS dom_esgoto_inexistente,
  DROP COLUMN IF EXISTS dom_lixo_coletado,
  DROP COLUMN IF EXISTS dom_lixo_cacamba,
  DROP COLUMN IF EXISTS dom_lixo_queimado,
  DROP COLUMN IF EXISTS dom_lixo_enterrado,
  DROP COLUMN IF EXISTS dom_lixo_jogado,
  DROP COLUMN IF EXISTS dom_lixo_outro,
  DROP COLUMN IF EXISTS dom_banheiro_exclusivo,
  DROP COLUMN IF EXISTS dom_sem_banheiro;

COMMIT;
