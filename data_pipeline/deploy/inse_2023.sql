-- Deploy edumaps:inse_2023 to pg

BEGIN;

  CREATE TABLE clean.inse (
      nu_ano_saeb       INTEGER NOT NULL,  -- Ano do SAEB (2023)
      co_uf             INTEGER,           -- Código da UF (IBGE)
      sg_uf             VARCHAR(2),        -- Sigla da UF
      no_uf             VARCHAR(100),      -- Nome da UF
      co_municipio      INTEGER,           -- Código do município (IBGE)
      no_municipio      VARCHAR(100),      -- Nome do município
      id_escola         BIGINT NOT NULL,   -- Código único da escola (Censo Escolar)
      no_escola         VARCHAR(200),      -- Nome da escola
      tp_tipo_rede      INTEGER,           -- Tipo de rede: 1 = Federal, 2 = Estadual, 3 = Municipal, 4 = Privada
      tp_localizacao    INTEGER,           -- Localização: 1 = Urbana, 2 = Rural
      tp_capital        INTEGER,           -- Capital? 1 = Sim, 2 = Não
      qtd_alunos_inse   INTEGER,           -- Número de alunos da escola com INSE apurado
      media_inse        NUMERIC(5,2),      -- Média do INSE da escola (varia de 0 a 10, quanto maior, maior o nível socioeconômico)
      inse_classificacao VARCHAR(20),      -- Classificação: Nível I a Nível VIII (quanto maior o nível, melhor o INSE)
      pc_nivel_1        NUMERIC(5,2),      -- Percentual de alunos no Nível I (muito baixo)
      pc_nivel_2        NUMERIC(5,2),      -- Percentual de alunos no Nível II
      pc_nivel_3        NUMERIC(5,2),      -- Percentual de alunos no Nível III
      pc_nivel_4        NUMERIC(5,2),      -- Percentual de alunos no Nível IV
      pc_nivel_5        NUMERIC(5,2),      -- Percentual de alunos no Nível V
      pc_nivel_6        NUMERIC(5,2),      -- Percentual de alunos no Nível VI
      pc_nivel_7        NUMERIC(5,2),      -- Percentual de alunos no Nível VII
      pc_nivel_8        NUMERIC(5,2),      -- Percentual de alunos no Nível VIII (muito alto)
      PRIMARY KEY (nu_ano_saeb, id_escola)
  );

  -- 3. Comentários nas colunas (explicação do INSE e dos níveis)
  COMMENT ON TABLE clean.inse IS 'Dados do Índice de Nível Socioeconômico (INSE) das escolas, calculado a partir do SAEB 2023.
  O INSE varia de 0 a 10 e é classificado em oito níveis (I a VIII). Quanto maior o nível, maior o capital econômico, cultural e social médio dos alunos da escola.
  Fonte: Microdados do SAEB / Inep. Arquivo original: inse_2023.csv.';

  COMMENT ON COLUMN clean.inse.nu_ano_saeb IS 'Ano de referência do SAEB (2023).';
  COMMENT ON COLUMN clean.inse.co_uf IS 'Código da unidade da federação (IBGE).';
  COMMENT ON COLUMN clean.inse.sg_uf IS 'Sigla da unidade da federação.';
  COMMENT ON COLUMN clean.inse.no_uf IS 'Nome da unidade da federação.';
  COMMENT ON COLUMN clean.inse.co_municipio IS 'Código do município (IBGE, 7 dígitos).';
  COMMENT ON COLUMN clean.inse.no_municipio IS 'Nome do município.';
  COMMENT ON COLUMN clean.inse.id_escola IS 'Código único da escola no Censo Escolar (INEP).';
  COMMENT ON COLUMN clean.inse.no_escola IS 'Nome da escola.';
  COMMENT ON COLUMN clean.inse.tp_tipo_rede IS 'Tipo de rede de ensino: 1 = Federal, 2 = Estadual, 3 = Municipal, 4 = Privada.';
  COMMENT ON COLUMN clean.inse.tp_localizacao IS 'Localização da escola: 1 = Urbana, 2 = Rural.';
  COMMENT ON COLUMN clean.inse.tp_capital IS 'Indicador de capital: 1 = Sim (escola em capital de estado), 2 = Não.';
  COMMENT ON COLUMN clean.inse.qtd_alunos_inse IS 'Quantidade de alunos da escola que responderam ao questionário socioeconômico e tiveram INSE calculado.';
  COMMENT ON COLUMN clean.inse.media_inse IS 'Média do INSE dos alunos da escola (0 a 10). Valores mais altos indicam maior nível socioeconômico.';
  COMMENT ON COLUMN clean.inse.inse_classificacao IS 'Classificação da média da escola em níveis: Nível I (mais baixo) a Nível VIII (mais alto).';
  COMMENT ON COLUMN clean.inse.pc_nivel_1 IS 'Percentual (%) de alunos da escola classificados no Nível I de INSE (muito baixo).';
  COMMENT ON COLUMN clean.inse.pc_nivel_2 IS 'Percentual (%) de alunos no Nível II.';
  COMMENT ON COLUMN clean.inse.pc_nivel_3 IS 'Percentual (%) de alunos no Nível III.';
  COMMENT ON COLUMN clean.inse.pc_nivel_4 IS 'Percentual (%) de alunos no Nível IV.';
  COMMENT ON COLUMN clean.inse.pc_nivel_5 IS 'Percentual (%) de alunos no Nível V.';
  COMMENT ON COLUMN clean.inse.pc_nivel_6 IS 'Percentual (%) de alunos no Nível VI.';
  COMMENT ON COLUMN clean.inse.pc_nivel_7 IS 'Percentual (%) de alunos no Nível VII.';
  COMMENT ON COLUMN clean.inse.pc_nivel_8 IS 'Percentual (%) de alunos no Nível VIII (muito alto).';

  -- 4. Tabela de metadados da importação (rastreabilidade)
  CREATE TABLE IF NOT EXISTS clean.import_metadata (
      id_import SERIAL PRIMARY KEY,
      table_name TEXT NOT NULL,
      source_file TEXT NOT NULL,
      import_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      row_count_loaded BIGINT,
      notes TEXT
  );

  -- 5. Importação dos dados usando COPY (com tratamento de decimais e campos vazios)
  -- Cria uma tabela temporária para receber os dados brutos do CSV (todos como texto)
  CREATE TEMP TABLE tmp_inse_raw (
      nu_ano_saeb TEXT,
      co_uf TEXT,
      sg_uf TEXT,
      no_uf TEXT,
      co_municipio TEXT,
      no_municipio TEXT,
      id_escola TEXT,
      no_escola TEXT,
      tp_tipo_rede TEXT,
      tp_localizacao TEXT,
      tp_capital TEXT,
      qtd_alunos_inse TEXT,
      media_inse TEXT,
      inse_classificacao TEXT,
      pc_nivel_1 TEXT,
      pc_nivel_2 TEXT,
      pc_nivel_3 TEXT,
      pc_nivel_4 TEXT,
      pc_nivel_5 TEXT,
      pc_nivel_6 TEXT,
      pc_nivel_7 TEXT,
      pc_nivel_8 TEXT
  );

  -- Ajuste o caminho conforme necessário. Recomenda-se usar variável de ambiente ou path relativo ao projeto.
  -- Se estiver usando Sqitch, o arquivo deve estar em $SQITCH_DEPLOY_DIR/../data/inse_2023.csv
  COPY tmp_inse_raw FROM '/data/inse_2023.csv' DELIMITER ';' CSV HEADER ENCODING 'UTF-8';

  -- Inserção na tabela final com conversões
  INSERT INTO clean.inse (
      nu_ano_saeb,
      co_uf,
      sg_uf,
      no_uf,
      co_municipio,
      no_municipio,
      id_escola,
      no_escola,
      tp_tipo_rede,
      tp_localizacao,
      tp_capital,
      qtd_alunos_inse,
      media_inse,
      inse_classificacao,
      pc_nivel_1,
      pc_nivel_2,
      pc_nivel_3,
      pc_nivel_4,
      pc_nivel_5,
      pc_nivel_6,
      pc_nivel_7,
      pc_nivel_8
  )
  SELECT
      NULLIF(nu_ano_saeb, '')::INTEGER,
      NULLIF(co_uf, '')::INTEGER,
      NULLIF(sg_uf, ''),
      NULLIF(no_uf, ''),
      NULLIF(co_municipio, '')::INTEGER,
      NULLIF(no_municipio, ''),
      NULLIF(id_escola, '')::BIGINT,
      NULLIF(no_escola, ''),
      NULLIF(tp_tipo_rede, '')::INTEGER,
      NULLIF(tp_localizacao, '')::INTEGER,
      NULLIF(tp_capital, '')::INTEGER,
      NULLIF(qtd_alunos_inse, '')::INTEGER,
      NULLIF(REPLACE(media_inse, ',', '.'), '')::NUMERIC(5,2),
      NULLIF(inse_classificacao, ''),
      NULLIF(REPLACE(pc_nivel_1, ',', '.'), '')::NUMERIC(5,2),
      NULLIF(REPLACE(pc_nivel_2, ',', '.'), '')::NUMERIC(5,2),
      NULLIF(REPLACE(pc_nivel_3, ',', '.'), '')::NUMERIC(5,2),
      NULLIF(REPLACE(pc_nivel_4, ',', '.'), '')::NUMERIC(5,2),
      NULLIF(REPLACE(pc_nivel_5, ',', '.'), '')::NUMERIC(5,2),
      NULLIF(REPLACE(pc_nivel_6, ',', '.'), '')::NUMERIC(5,2),
      NULLIF(REPLACE(pc_nivel_7, ',', '.'), '')::NUMERIC(5,2),
      NULLIF(REPLACE(pc_nivel_8, ',', '.'), '')::NUMERIC(5,2)
  FROM tmp_inse_raw
  -- Opcional: evitar duplicatas (embora a PK garanta)
  ON CONFLICT (nu_ano_saeb, id_escola) DO NOTHING;

  -- 6. Registrar metadados da importação
  DO $$
  DECLARE
      loaded_rows BIGINT;
  BEGIN
      SELECT COUNT(*) INTO loaded_rows FROM clean.inse WHERE nu_ano_saeb = 2023;
      INSERT INTO clean.import_metadata (table_name, source_file, row_count_loaded, notes)
      VALUES ('clean.inse', 'inse_2023.csv', loaded_rows, 
              'Importação via Sqitch - deploy add_inse_2023. Dados do SAEB/INSE 2023.');
  END $$;

  -- 7. Limpeza
  DROP TABLE tmp_inse_raw;

  -- 8. (Opcional) Criar índices para consultas comuns
  CREATE INDEX IF NOT EXISTS idx_inse_uf ON clean.inse (sg_uf);
  CREATE INDEX IF NOT EXISTS idx_inse_municipio ON clean.inse (co_municipio);
  CREATE INDEX IF NOT EXISTS idx_inse_classificacao ON clean.inse (inse_classificacao);
COMMIT;
