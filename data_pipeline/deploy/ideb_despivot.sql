-- Deploy edumaps:ideb_despivot to pg
-- requires: raw_inep

BEGIN;

  -- Cria uma nova tabela organizada com escola, ano e notas
  -- Tabela desnormalizada no formato long para facilitar análises temporais
  CREATE TABLE clean.inep_notas_desagregadas AS
  SELECT 
      -- Colunas de identificação da escola
      i.id_escola,        -- ID único da escola no censo escolar
      i.no_escola,        -- Nome completo da escola
      i.codigo_ibge,      -- Código IBGE de 7 dígitos do município
      i.no_municipio,     -- Nome do município
      i.sg_uf,           -- Sigla da Unidade Federativa (2 caracteres)
      i.rede,            -- Rede de ensino (Pública Federal, Estadual, Municipal ou Privada)
      
      -- Ano extraído do nome da coluna
      v.ano,             -- Ano de aplicação da prova (2005-2023, anos ímpares)
      
      -- Notas para o ano específico
      v.nota_mat,        -- Nota padronizada em Matemática (escala SAEB)
      v.nota_por,        -- Nota padronizada em Língua Portuguesa (escala SAEB)
      v.nota_media,      -- Média simples das notas de Matemática e Português
      
      -- Mantém o campo de auditoria original se necessário
      i.linha_original   -- Número da linha original na tabela fonte (para rastreabilidade)
      
  FROM clean.inep i
  CROSS JOIN LATERAL (
      -- Para cada ano, seleciona as três notas correspondentes
      -- Usa o padrão de nome das colunas: vl_nota_*_AAAA
      -- Converte estrutura wide (colunas por ano) para long (linhas por ano)
      VALUES 
          (2005, i.vl_nota_matematica_2005, i.vl_nota_portugues_2005, i.vl_nota_media_2005),
          (2007, i.vl_nota_matematica_2007, i.vl_nota_portugues_2007, i.vl_nota_media_2007),
          (2009, i.vl_nota_matematica_2009, i.vl_nota_portugues_2009, i.vl_nota_media_2009),
          (2011, i.vl_nota_matematica_2011, i.vl_nota_portugues_2011, i.vl_nota_media_2011),
          (2013, i.vl_nota_matematica_2013, i.vl_nota_portugues_2013, i.vl_nota_media_2013),
          (2015, i.vl_nota_matematica_2015, i.vl_nota_portugues_2015, i.vl_nota_media_2015),
          (2017, i.vl_nota_matematica_2017, i.vl_nota_portugues_2017, i.vl_nota_media_2017),
          (2019, i.vl_nota_matematica_2019, i.vl_nota_portugues_2019, i.vl_nota_media_2019),
          (2021, i.vl_nota_matematica_2021, i.vl_nota_portugues_2021, i.vl_nota_media_2021),
          (2023, i.vl_nota_matematica_2023, i.vl_nota_portugues_2023, i.vl_nota_media_2023)
  ) AS v(ano, nota_mat, nota_por, nota_media)

  -- Filtra apenas linhas onde pelo menos uma das notas não é nula
  WHERE v.nota_mat IS NOT NULL 
     OR v.nota_por IS NOT NULL 
     OR v.nota_media IS NOT NULL;

  -- Comentário da tabela
  COMMENT ON TABLE clean.inep_notas_desagregadas IS 
  'Tabela de notas desagregadas por ano do SAEB/Prova Brasil (2005-2023). 
  Contém as notas padronizadas de Matemática e Língua Portuguesa por escola/ano.
  Fonte: Microdados do INEP transformados de formato wide para long.
  Última atualização: DD/MM/AAAA.';

  -- Comentários das colunas
  COMMENT ON COLUMN clean.inep_notas_desagregadas.id_escola IS 
  'Identificador único da escola no Censo Escolar (código INEP). 
  Usado como chave estrangeira para outras tabelas do sistema.';

  COMMENT ON COLUMN clean.inep_notas_desagregadas.no_escola IS 
  'Nome oficial da escola conforme registro no Censo Escolar.';

  COMMENT ON COLUMN clean.inep_notas_desagregadas.codigo_ibge IS 
  'Código IBGE do município (7 dígitos). 
  Os 2 primeiros dígitos representam a UF, os 5 restantes o município.';

  COMMENT ON COLUMN clean.inep_notas_desagregadas.no_municipio IS 
  'Nome do município onde a escola está localizada.';

  COMMENT ON COLUMN clean.inep_notas_desagregadas.sg_uf IS 
  'Sigla da Unidade Federativa (2 letras). Ex: SP, RJ, MG.';

  COMMENT ON COLUMN clean.inep_notas_desagregadas.rede IS 
  'Rede de ensino a que pertence a escola. 
  Valores possíveis: Pública Federal, Pública Estadual, Pública Municipal, Privada.';

  COMMENT ON COLUMN clean.inep_notas_desagregadas.ano IS 
  'Ano de aplicação da prova SAEB/Prova Brasil. 
  Série histórica de 2005 a 2023 (anos ímpares). 
  Formato: YYYY.';

  COMMENT ON COLUMN clean.inep_notas_desagregadas.nota_mat IS 
  'Nota padronizada em Matemática na escala SAEB. 
  Escala: 0-500 pontos. 
  Valores nulos indicam ausência de dados para o ano/escola.';

  COMMENT ON COLUMN clean.inep_notas_desagregadas.nota_por IS 
  'Nota padronizada em Língua Portuguesa na escala SAEB. 
  Escala: 0-500 pontos. 
  Valores nulos indicam ausência de dados para o ano/escola.';

  COMMENT ON COLUMN clean.inep_notas_desagregadas.nota_media IS 
  'Média aritmética simples das notas de Matemática e Português. 
  Calculada como (nota_mat + nota_por) / 2. 
  Pode ser nula se uma das notas for nula.';

  COMMENT ON COLUMN clean.inep_notas_desagregadas.linha_original IS 
  'Número da linha na tabela original clean.inep. 
  Mantido para fins de auditoria e rastreabilidade. 
  Permite vincular ao registro fonte em caso de necessidade.';

  -- Adiciona uma chave primária composta para a nova tabela
  ALTER TABLE clean.inep_notas_desagregadas 
  ADD PRIMARY KEY (id_escola, ano);

  COMMENT ON CONSTRAINT inep_notas_desagregadas_pkey ON clean.inep_notas_desagregadas IS 
  'Chave primária composta: combinação única de escola e ano. 
  Garante que não existam duplicatas de escola/ano na tabela.';

  -- Cria índices para consultas frequentes
  CREATE INDEX ix_inep_notas_ano ON clean.inep_notas_desagregadas(ano);
  COMMENT ON INDEX ix_inep_notas_ano IS 
  'Índice para consultas filtradas por ano. 
  Otimiza queries que analisam tendências temporais.';

  CREATE INDEX ix_inep_notas_municipio ON clean.inep_notas_desagregadas(codigo_ibge);
  COMMENT ON INDEX ix_inep_notas_municipio IS 
  'Índice para consultas agregadas por município. 
  Facilita análises de desempenho municipal.';

  CREATE INDEX ix_inep_notas_rede ON clean.inep_notas_desagregadas(rede);
  COMMENT ON INDEX ix_inep_notas_rede IS 
  'Índice para consultas comparativas entre redes de ensino. 
  Melhora performance em análises de equidade educacional.';

COMMIT;
