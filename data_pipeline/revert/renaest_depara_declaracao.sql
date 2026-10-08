-- Revert edumaps:renaest_depara_declaracao from pg

BEGIN;

-- 1. Desfaz a tabela das não resolvidas
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.renaest_localidade_nao_resolvida';

DROP TABLE IF EXISTS clean.renaest_localidade_nao_resolvida;

-- 2. Repõe os COMMENT que a change substituiu (estado original de
--    renaest_localidade_municipio, tal como a change de 2026-09-30 os criou).
COMMENT ON TABLE clean.renaest_localidade_municipio IS 'De-para RENAEST localidade → município IBGE. Chave: (localidade, uf) → codigo_ibge. match_type: exact/fuzzy/manual. match_score: 0-100. Construído por fuzzy matching + validação humana.';
COMMENT ON COLUMN clean.renaest_localidade_municipio.localidade IS 'Nome da localidade RENAEST (ex.: São Paulo, Campinas)';
COMMENT ON COLUMN clean.renaest_localidade_municipio.uf IS 'UF da localidade';
COMMENT ON COLUMN clean.renaest_localidade_municipio.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.renaest_localidade_municipio.match_type IS 'Tipo de match: exact (igual), fuzzy (aproximado), manual (validado humano)';
COMMENT ON COLUMN clean.renaest_localidade_municipio.match_score IS 'Score do fuzzy match (0-100)';
COMMENT ON COLUMN clean.renaest_localidade_municipio.validated_by IS 'Quem validou o match';
COMMENT ON COLUMN clean.renaest_localidade_municipio.validated_at IS 'Quando foi validado';

COMMIT;
