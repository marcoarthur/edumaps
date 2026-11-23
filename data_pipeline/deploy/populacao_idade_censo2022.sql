-- Deploy edumaps:populacao_idade_censo2022 to pg
-- requires: ibge_agregados
-- requires: raw_populacao_faixas_etarias
-- requires: leitor_grants_explicitos
--
-- #533 (QP-01 da P2): a população por idade do Censo Demográfico 2022
-- (SIDRA 9514), carregada pelo job IBGEPopulacaoIdade em
-- clean.ibge_agregados, somada nas idades das etapas: creche (0 a 3),
-- pré-escola (4 e 5), fundamental (6 a 14) e médio (15 a 17). É a base da
-- taxa de atendimento da educação infantil (meta 1 do PNE).
--
-- As faixas de clean.populacao_municipal (faixa_*) vêm de um CSV sem fonte
-- nem ano registrados e sem as faixas de 25 a 29 e de 90 a 94 anos; ficam
-- como estão (o IVET as lê), com o comentário dizendo isso (decisão B1).

BEGIN;

CREATE OR REPLACE VIEW clean.populacao_idade AS
SELECT
    codigo_ibge,
    ano,
    SUM(valor) FILTER (WHERE classificacao = 'Total')::integer AS populacao_total,
    SUM(valor) FILTER (WHERE classificacao IN ('Menos de 1 ano', '1 ano', '2 anos', '3 anos'))::integer AS populacao_0_3,
    SUM(valor) FILTER (WHERE classificacao IN ('4 anos', '5 anos'))::integer AS populacao_4_5,
    SUM(valor) FILTER (WHERE classificacao IN ('6 anos', '7 anos', '8 anos', '9 anos', '10 anos',
                                               '11 anos', '12 anos', '13 anos', '14 anos'))::integer AS populacao_6_14,
    SUM(valor) FILTER (WHERE classificacao IN ('15 anos', '16 anos', '17 anos'))::integer AS populacao_15_17
FROM clean.ibge_agregados
WHERE tabela_id = '9514' AND variavel = '93'
GROUP BY codigo_ibge, ano;

COMMENT ON VIEW clean.populacao_idade IS
  'População residente por idade das etapas, por município, do Censo Demográfico 2022 (IBGE, SIDRA tabela 9514), carregada pelo job IBGEPopulacaoIdade em clean.ibge_agregados (#533).';
COMMENT ON COLUMN clean.populacao_idade.ano IS 'Ano do Censo Demográfico (2022).';
COMMENT ON COLUMN clean.populacao_idade.populacao_total IS 'População residente total do município no Censo.';
COMMENT ON COLUMN clean.populacao_idade.populacao_0_3 IS 'Crianças de 0 a 3 anos, a idade da creche.';
COMMENT ON COLUMN clean.populacao_idade.populacao_4_5 IS 'Crianças de 4 e 5 anos, a idade da pré-escola.';
COMMENT ON COLUMN clean.populacao_idade.populacao_6_14 IS 'Crianças e adolescentes de 6 a 14 anos, a idade do ensino fundamental.';
COMMENT ON COLUMN clean.populacao_idade.populacao_15_17 IS 'Adolescentes de 15 a 17 anos, a idade do ensino médio.';

-- Pública (dado agregado do IBGE): leitura para o Assistente e os relatórios.
GRANT SELECT ON clean.populacao_idade TO edumaps_leitor;

-- B1: as faixas antigas ficam, com a origem dita.
DO $$
DECLARE
  col record;
BEGIN
  FOR col IN
    SELECT attname FROM pg_attribute
     WHERE attrelid = 'clean.populacao_municipal'::regclass
       AND attname LIKE 'faixa\_%' AND NOT attisdropped
  LOOP
    EXECUTE format(
      'COMMENT ON COLUMN clean.populacao_municipal.%I IS %L',
      col.attname,
      'Faixa etária de um CSV sem fonte nem ano registrados (raw_populacao_faixas_etarias); faltam as faixas de 25 a 29 e de 90 a 94 anos. Para a população por idade, use clean.populacao_idade (Censo 2022, #533).');
  END LOOP;
END $$;

COMMIT;
