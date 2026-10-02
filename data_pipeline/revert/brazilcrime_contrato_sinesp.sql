-- Revert edumaps:brazilcrime_contrato_sinesp to pg
-- requires: brazilcrime_contrato_sinesp

BEGIN;

-- =================================================================
-- Reverte a correccao do contrato de colunas (issue #164).
--
-- Recupera as 5 colunas que o SINESP VDE nao publica e os nomes
-- originais. As colunas voltam vazias (NULL), que e o que se pode
-- reconstruir. Qualquer consumidor que leia o contrato antigo volta a
-- encontrar as colunas — e volta a poder publica-las como zero, que e
-- o defeito que o change anterior removeu. Por isso o revert e fiel e
-- nao "corrigido".
--
-- A tabela esta vazia. Se deixar de estar, este revert tem de ser
-- acompanhado de um dump: as colunas readdidas ficam NULL e a
-- supressao de celula pequena nao e reaplicada a elas.
-- =================================================================

ALTER TABLE clean.brazilcrime_municipio
  ADD COLUMN IF NOT EXISTS homicidio_culposo  INTEGER,
  ADD COLUMN IF NOT EXISTS furto_outros      INTEGER,
  ADD COLUMN IF NOT EXISTS estelionato       INTEGER,
  ADD COLUMN IF NOT EXISTS ameaca            INTEGER,
  ADD COLUMN IF NOT EXISTS violacao_domicilio INTEGER;

ALTER TABLE clean.brazilcrime_municipio
  RENAME COLUMN lesao_corporal_seguida_de_morte TO lesao_corporal;

ALTER TABLE clean.brazilcrime_municipio
  RENAME COLUMN roubo_instituicao_financeira TO roubo_outros;

-- Comentarios originais, tal como estavam em brazilcrime_municipio.sql
COMMENT ON TABLE clean.brazilcrime_municipio IS 'Criminalidade agregada por município/ano (BrazilCrime/CRAN). AGREGAÇÃO OBRIGATÓRIA: por município, supressão count < 5. NUNCA expor por escola. Supressão de célula pequena (count < 5) indicada em supressao_celula_pequena.';

COMMENT ON COLUMN clean.brazilcrime_municipio.homicidio_doloso IS 'Homicídio doloso';
COMMENT ON COLUMN clean.brazilcrime_municipio.homicidio_culposo IS 'Homicídio culposo (trânsito)';
COMMENT ON COLUMN clean.brazilcrime_municipio.latrocinio IS 'Roubo seguido de morte (latrocínio)';
COMMENT ON COLUMN clean.brazilcrime_municipio.roubo_veiculo IS 'Roubo de veículo';
COMMENT ON COLUMN clean.brazilcrime_municipio.roubo_carga IS 'Roubo de carga';
COMMENT ON COLUMN clean.brazilcrime_municipio.roubo_outros IS 'Outros roubos';
COMMENT ON COLUMN clean.brazilcrime_municipio.furto_veiculo IS 'Furto de veículo';
COMMENT ON COLUMN clean.brazilcrime_municipio.furto_outros IS 'Outros furtos';
COMMENT ON COLUMN clean.brazilcrime_municipio.estelionato IS 'Estelionato';
COMMENT ON COLUMN clean.brazilcrime_municipio.ameaca IS 'Ameaça';
COMMENT ON COLUMN clean.brazilcrime_municipio.lesao_corporal IS 'Lesão corporal';
COMMENT ON COLUMN clean.brazilcrime_municipio.violacao_domicilio IS 'Violação de domicílio';
COMMENT ON COLUMN clean.brazilcrime_municipio.supressao_celula_pequena IS 'TRUE = valor suprimido por sigilo estatístico (count < 5), NÃO é zero';
COMMENT ON COLUMN clean.brazilcrime_municipio.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

COMMIT;