-- Deploy edumaps:dados_ibge to pg
-- requires: raw_municipios_sp

BEGIN;

  CREATE TABLE clean.dados_ibge (
    codigo_ibge TEXT NOT NULL,
    ano INTEGER NOT NULL,

    pib_total NUMERIC,
    governo NUMERIC,
    industria NUMERIC,
    agro NUMERIC,

    data_acessada TIMESTAMPTZ DEFAULT now(),

    industria_percent NUMERIC,
    agro_percent NUMERIC,
    governo_percent NUMERIC,
    servicos_percent NUMERIC,

    CONSTRAINT dados_ibge_pk PRIMARY KEY (ano, codigo_ibge)
  );

  CREATE INDEX idx_dados_ibge_codigo ON clean.dados_ibge (codigo_ibge);


  -- Comentários da tabela
  COMMENT ON TABLE clean.dados_ibge IS
  'Dados do PIB municipal (SIDRA/IBGE), incluindo valores absolutos e participação percentual por setor econômico.';

  -- Colunas principais
  COMMENT ON COLUMN clean.dados_ibge.codigo_ibge IS
  'Código IBGE do município (7 dígitos), usado como chave de integração com outras tabelas geográficas.';

  COMMENT ON COLUMN clean.dados_ibge.ano IS
  'Ano de referência dos dados do PIB municipal.';

  -- Valores absolutos
  COMMENT ON COLUMN clean.dados_ibge.pib_total IS
  'Produto Interno Bruto total do município no ano, em reais correntes.';

  COMMENT ON COLUMN clean.dados_ibge.governo IS
  'Valor adicionado bruto da administração pública (setor governo), em reais correntes.';

  COMMENT ON COLUMN clean.dados_ibge.industria IS
  'Valor adicionado bruto do setor industrial, em reais correntes.';

  COMMENT ON COLUMN clean.dados_ibge.agro IS
  'Valor adicionado bruto da agropecuária, em reais correntes.';

  -- Metadado
  COMMENT ON COLUMN clean.dados_ibge.data_acessada IS
  'Timestamp indicando quando os dados foram coletados do SIDRA.';

  -- Percentuais
  COMMENT ON COLUMN clean.dados_ibge.industria_percent IS
  'Participação do setor industrial no PIB municipal (industria / pib_total).';

  COMMENT ON COLUMN clean.dados_ibge.agro_percent IS
  'Participação da agropecuária no PIB municipal (agro / pib_total).';

  COMMENT ON COLUMN clean.dados_ibge.governo_percent IS
  'Participação da administração pública no PIB municipal (governo / pib_total).';

  COMMENT ON COLUMN clean.dados_ibge.servicos_percent IS
  'Participação estimada do setor de serviços no PIB municipal, calculada como complemento dos demais setores (1 - soma dos percentuais conhecidos).';

COMMIT;

