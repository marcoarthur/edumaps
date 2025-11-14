-- Deploy edumaps:raw_siope to pg
-- requires: extensions

BEGIN;

  CREATE TABLE clean.remuneracao_municipal(
    categoria           TEXT,
    tipo                TEXT,
    ano                 INT,
    mes                 TEXT,
    nome_profissional   TEXT,
    cod_municipio       BIGINT,
    cod_inep            BIGINT,
    escola              TEXT,
    carga_horaria       INT,
    cpf                 TEXT,
    situacao            TEXT,
    segmento_ensino     TEXT,
    rede                VARCHAR(12),
    salario_base        NUMERIC,
    salario_fundeb_max  NUMERIC,
    salario_fundeb_min  NUMERIC,
    salario_outros      NUMERIC,
    salario_total       NUMERIC
  );

  -- Adicionar a nova coluna
  -- ALTER TABLE clean.remuneracao_municipal
  -- ADD COLUMN rede VARCHAR(12);
  --
  -- -- Popular a coluna rede com 'Municipal', pois os dados, vieram da rede
  -- UPDATE clean.remuneracao_municipal
  -- SET rede = 'Municipal';


-- Opcional: Adicionar comentário na coluna
COMMENT ON COLUMN clean.municipios_sp.codigo_ibge_antigo 
  CREATE INDEX ix_remuneracao_cod_inep ON clean.remuneracao_municipal(cod_inep);
  CREATE INDEX ix_remuneracao_cod_municipio ON clean.remuneracao_municipal(cod_municipio);
  CREATE INDEX ix_remuneracao_categoria ON clean.remuneracao_municipal(categoria);

  -- Comentários para documentação
  COMMENT ON TABLE clean.remuneracao_municipal IS 'Dados com as remunerações dos profissionais da educação da rede municipal';
  COMMENT ON COLUMN clean.remuneracao_municipal.categoria IS 'Categoria do profissional com detalhes';
  COMMENT ON COLUMN clean.remuneracao_municipal.tipo IS 'Categoria tipificada';
  COMMENT ON COLUMN clean.remuneracao_municipal.ano IS 'Ano do pagamento';
  COMMENT ON COLUMN clean.remuneracao_municipal.mes IS 'Mês do pagamento';
  COMMENT ON COLUMN clean.remuneracao_municipal.nome_profissional IS 'Nome completo do profissional';
  COMMENT ON COLUMN clean.remuneracao_municipal.cod_municipio IS 'Código do município formato antigo 6 dígitos do IBGE';
  COMMENT ON COLUMN clean.remuneracao_municipal.cod_inep IS 'Código do INEP referente à escola';
  COMMENT ON COLUMN clean.remuneracao_municipal.escola IS 'Nome da Escola';
  COMMENT ON COLUMN clean.remuneracao_municipal.carga_horaria IS 'Carga horária semanal do profissional';
  COMMENT ON COLUMN clean.remuneracao_municipal.cpf IS 'CPF do profissional';
  COMMENT ON COLUMN clean.remuneracao_municipal.situacao IS 'Situação de contrato';
  COMMENT ON COLUMN clean.remuneracao_municipal.segmento_ensino IS 'Segmento do ensino onde atua';
  COMMENT ON COLUMN clean.remuneracao_municipal.salario_base IS 'Salário Base do profissional';
  COMMENT ON COLUMN clean.remuneracao_municipal.salario_fundeb_max IS 'Com participação de 70% do Fundeb';
  COMMENT ON COLUMN clean.remuneracao_municipal.salario_fundeb_min IS 'Com participação de 30% do Fundeb';
  COMMENT ON COLUMN clean.remuneracao_municipal.salario_outros IS 'Outras fontes de receita no salário';
  COMMENT ON COLUMN clean.remuneracao_municipal.salario_total IS 'Total Salarial do profissional';

COMMIT;
