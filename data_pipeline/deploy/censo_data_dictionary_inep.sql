-- Deploy edumaps:censo_data_dictionary_inep to pg
-- requires: censo_data_dictionary
--
-- GERADO por tools/censo-dicionario/gerar.py --sql — NÃO editar à mão.
-- Fonte: INEP, Dicionário de Variáveis do Censo Escolar da Educação Básica (Anexo I dos microdados 2025); Zotero 10296 / ICPJZK6R.
-- Dados: 834 variáveis das abas Escola, Matrícula, Docente e Gestor
-- (data_pipeline/dicionarios/censo_inep_variaveis.csv).
--
-- O que faz (issue #134, docs/specs/2026-10-13-dicionario-censo-inep.md):
--   1. coluna `origem` ('inep' | 'derivada');
--   2. registra colunas reais das 4 tabelas ainda ausentes do dicionário;
--   3. atualiza descrição, domínio, anos e notas a partir do INEP;
--   4. marca como 'derivada' o que não existe no INEP;
--   5. cria clean.censo_dict_violacoes().

BEGIN;

ALTER TABLE clean.censo_data_dictionary
    ADD COLUMN origem text NOT NULL DEFAULT 'inep'
    CONSTRAINT censo_data_dictionary_origem_chk CHECK (origem IN ('inep', 'derivada'));

COMMENT ON COLUMN clean.censo_data_dictionary.origem IS
'inep = variável do Dicionário de Variáveis do INEP; derivada = coluna criada pelo EduMaps';

-- A PK inclui year_introduced, que deixa de ser 2025 e passa ao ano de início
-- do INEP. O UPDATE só é seguro com uma linha por (tabela, coluna).
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM clean.censo_data_dictionary
        GROUP BY table_name, column_name HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'censo_data_dictionary tem mais de uma linha por (tabela, coluna); revisar antes da carga INEP';
    END IF;
END $$;

-- Colunas reais das 4 tabelas que ainda não estão no dicionário (ex.: criadas
-- por changes posteriores a censo_data_dictionary).
INSERT INTO clean.censo_data_dictionary (table_name, column_name, data_type, year_introduced)
SELECT 'clean.' || c.table_name, c.column_name, c.data_type, 2025
FROM information_schema.columns c
WHERE c.table_schema = 'clean'
  AND c.table_name IN ('censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor')
  AND NOT EXISTS (
      SELECT 1 FROM clean.censo_data_dictionary d
      WHERE d.table_name = 'clean.' || c.table_name AND d.column_name = c.column_name
  );

CREATE TEMP TABLE censo_inep_carga (
    table_name      text NOT NULL,
    column_name     text NOT NULL,
    description     text,
    value_domain    jsonb,
    year_introduced smallint,
    year_deprecated smallint,
    year_changed    smallint,
    notes           text,
    PRIMARY KEY (table_name, column_name)
) ON COMMIT DROP;

INSERT INTO censo_inep_carga
    (table_name, column_name, description, value_domain,
     year_introduced, year_deprecated, year_changed, notes)
VALUES
  ('clean.censo_escolas', 'nu_ano_censo', 'Ano do Censo', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'no_regiao', 'Nome da Região Geográfica', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_regiao', 'Código da Região Geográfica', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'no_uf', 'Nome da Unidade da Federação', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'sg_uf', 'Sigla da Unidade da Federação', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_uf', 'Código da Unidade da Federação', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'no_municipio', 'Nome do Município', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_municipio', 'Código do Município', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'no_regiao_geog_interm', 'Nome da Região Geográfica Intermediária', NULL::jsonb, 2019, NULL, NULL, 'A Fundação Instituto Brasileiro de Geografia e Estatísticas (IBGE), propôs em 2017 uma nova divisão geográfica regional do Brasil que corresponde às antigas Mesorregiões e Microrregiões. Assim, a partir de 2019, as regiões geográficas regionais são classificadas em Regiões Geográficas Intermediárias e Regiões Imediatas. No Censo Escolar, para fins de comparação ao longo dos anos, foram mantidas as variáveis de Mesorregiões e Microrregiões.
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'co_regiao_geog_interm', 'Código da Região Geográfica Intermediária', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'no_regiao_geog_imed', 'Nome da Região Geográfica Imediata', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'co_regiao_geog_imed', 'Código da Região Geográfica Imediata', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'no_mesorregiao', 'Nome da Mesorregião', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_mesorregiao', 'Código da Mesorregião', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'no_microrregiao', 'Nome da Microrregião', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_microrregiao', 'Código da Microrregião', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'no_distrito', 'Divisão Intramunicipal - Nome do Distrito', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_distrito', 'Divisão Intramunicipal - Código do Distrito', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'no_regiao_administrativa', 'Nome da Região Administrativa referente exclusivamente às regiões administrativas do Distrito Federal (DF)', NULL::jsonb, 2025, NULL, NULL, 'Coletada (INEP): 2025'),
  ('clean.censo_escolas', 'co_regiao_administrativa', 'Código da Região Administrativa referente exclusivamente às regiões administrativas do Distrito Federal (DF)', NULL::jsonb, 2025, NULL, NULL, 'Coletada (INEP): 2025'),
  ('clean.censo_escolas', 'no_entidade', 'Nome da Escola', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_entidade', 'Código da Escola', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_dependencia', 'Dependência Administrativa', '{"1": "Federal", "2": "Estadual", "3": "Municipal", "4": "Privada"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_categoria_escola_privada', 'Categoria da escola privada', '{"1": "Particular", "2": "Comunitária", "3": "Confessional", "4": "Filantrópica"}'::jsonb, 2007, NULL, NULL, 'NULL = Não aplicável para escolas públicas
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_localizacao', 'Localização', '{"1": "Urbana", "2": "Rural"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_localizacao_diferenciada', 'Localização diferenciada da escola', '{"0": "A escola não está em área de localização diferenciada", "1": "Área de assentamento", "2": "Terra indígena", "3": "Comunidade quilombola", "8": "Área onde se localizam povos e comunidades tradicionais"}'::jsonb, 2007, NULL, 2023, 'De 2007 a 2011:
0 - Não se aplica
1 - Área de assentamento
2 - Terra indígena
3 - Área remanescente de quilombos
De 2012 a 2018:
0 - A escola não está em área de localização diferenciada
1 - Área de assentamento
2 - Terra indígena
3 - Área remanescente de quilombos
4 - Unidade de uso sustentável
5 - Unidade de uso sustentável em terra indígena
6 - Unidade de uso sustentável em área remanescente de quilombos
De 2019 a 2022:
0 - A escola não está em área de localização diferenciada
1 - Área de assentamento
2 - Terra indígena
3 - Área onde se localiza comunidade remanescente de quilombos
Em 2023 foi adicionada a categoria 8:
8 - Área onde se localizam povos e comunidades tradicionais
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'ds_endereco', 'Endereço', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'nu_endereco', 'Número', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'ds_complemento', 'Complemento', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'no_bairro', 'Bairro', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_cep', 'CEP', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'nu_ddd', 'DDD', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'nu_telefone', 'Telefone', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'latitude', 'Georreferenciamento da Escola - Latitude', NULL::jsonb, 2007, NULL, NULL, 'Latitude registrada com base nos dados do Censo Escolar de 2024
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'longitude', 'Georreferenciamento da Escola - Longitude', NULL::jsonb, 2007, NULL, NULL, 'Longitude registrada com base nos dados do Censo Escolar de 2024
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_situacao_funcionamento', 'Situação de funcionamento', '{"1": "Em Atividade", "2": "Paralisada", "3": "Extinta (ano do Censo)", "4": "Extinta em Anos Anteriores"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_orgao_regional', 'Código do Órgão Regional de Ensino', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'dt_ano_letivo_inicio', 'Início do ano letivo', NULL::jsonb, 2008, NULL, NULL, 'Coletada (INEP): 2008-2025'),
  ('clean.censo_escolas', 'dt_ano_letivo_termino', 'Término (previsão) do ano letivo', NULL::jsonb, 2008, NULL, NULL, 'Coletada (INEP): 2008-2025'),
  ('clean.censo_escolas', 'in_vinculo_secretaria_educacao', 'Órgão ao qual a escola pública está vinculada - Secretaria de Educação/Ministério da Educação', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas privadas
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_vinculo_seguranca_publica', 'Órgão ao qual a escola pública está vinculada - Secretaria de Segurança Pública/Forças Armadas/Militar', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas privadas
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_vinculo_secretaria_saude', 'Órgão ao qual a escola pública está vinculada - Secretaria de Saúde/Ministério da Saúde', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas privadas
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_vinculo_outro_orgao', 'Órgão ao qual a escola pública está vinculada - Outro órgão da administração pública', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas privadas
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_poder_publico_parceria', 'Parceria ou convênio com o poder público (parceria ou convênio firmado entre a Administração Pública e instituições privadas ou instituições públicas de ensino, autarquias e fundações da administração indireta e demais instituições de educação profissional técnica de nível médio dos serviços sociais autônomos que integram o sistema federal de ensino, para financiamento do atendimento educacional ou para a oferta do itinerário de formação técnica e profissional do ensino médio)', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, 2022, 'Entre 2007 e 2021:
A variável IN_CONVENIADA_PP foi renomeada para:
IN_PODER_PUBLICO_PARCERIA
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_poder_publico_parceria', 'Poder público responsável pela parceria ou convênio entre a Administração Pública e outras instituições', '{"1": "Municipal", "2": "Estadual", "3": "Estadual e Municipal"}'::jsonb, 2007, NULL, 2022, 'Entre 2007 e 2021:
A variável TP_CONVENIO_PODER_PUBLICO foi renomeada para: TP_PODER_PUBLICO_PARCERIA
NULL = Não aplicável para escolas sem parceria ou convênio com o poder público
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_conveniada_pp', 'Conveniada com o poder público', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2021, NULL, 'NULL = Não aplicável para escolas públicas
Coletada (INEP): 2007-2021'),
  ('clean.censo_escolas', 'tp_convenio_poder_publico', 'Dependência do convênio com o poder público', '{"1": "Municipal", "2": "Estadual", "3": "Estadual e Municipal"}'::jsonb, 2008, 2021, NULL, 'NULL = Não aplicável para escolas públicas ou privadas não conveniadas
Coletada (INEP): 2008-2021'),
  ('clean.censo_escolas', 'in_forma_cont_termo_colabora', 'Forma de contratação entre a Administração Pública e outras instituições - Termo de colaboração (Lei nº 13.019/2014)', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'NULL = Não aplicável para escolas sem parceria/convênio
Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_forma_cont_termo_fomento', 'Forma de contratação entre a Administração Pública e outras instituições - Termo de fomento (Lei nº 13.019/2014)', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'NULL = Não aplicável para escolas sem parceria/convênio
Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_forma_cont_acordo_coop', 'Forma de contratação entre a Administração Pública e outras instituições - Acordo de cooperação (Lei nº 13.019/2014)', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'NULL = Não aplicável para escolas sem parceria/convênio
Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_forma_cont_prestacao_serv', 'Forma de contratação entre a Administração Pública e outras instituições - Contrato de prestação de serviço', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'NULL = Não aplicável para escolas sem parceria/convênio
Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_forma_cont_coop_tec_fin', 'Forma de contratação entre a Administração Pública e outras instituições - Termo de cooperação técnica e financeira', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'NULL = Não aplicável para escolas sem parceria/convênio
Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_forma_cont_consorcio_pub', 'Forma de contratação entre a Administração Pública e outras instituições - Contrato de consórcio público/Convênio de cooperação', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'NULL = Não aplicável para escolas sem parceria/convênio
Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_forma_cont_mu_termo_colab', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria municipal de educação - Termo de colaboração (Lei nº 13.019/2014)', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_mu_termo_fomento', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria municipal de educação - Termo de fomento (Lei nº 13.019/2014)', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_mu_acordo_coop', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria municipal de educação - Acordo de cooperação (Lei nº 13.019/2014)', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_mu_prest_serv', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria municipal de educação - Contrato de prestação de serviço', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_mu_coop_tec_fin', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria municipal de educação - Termo de cooperação técnica e financeira', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_mu_consorcio_pub', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria municipal de educação - Contrato de consórcio público/Convênio de cooperação', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_es_termo_colab', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria estadual de educação - Termo de colaboração (Lei nº 13.019/2014)', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_es_termo_fomento', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria estadual de educação - Termo de fomento (Lei nº 13.019/2014)', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_es_acordo_coop', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria estadual de educação - Acordo de cooperação (Lei nº 13.019/2014)', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_es_prest_serv', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria estadual de educação - Contrato de prestação de serviço', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_es_coop_tec_fin', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria estadual de educação - Termo de cooperação técnica e financeira', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_forma_cont_es_consorcio_pub', 'Forma(s) de contratação da parceria ou convênio entre a escola e a Secretaria estadual de educação - Contrato de consórcio público/Convênio de cooperação', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'NULL = Não aplicável para sem parceria/convênio
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_tipo_atend_escolarizacao', 'Tipo de atendimento ofertado por meio da parceria ou convênio - Escolarização', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, 2022, NULL, 'NULL = Não aplicável para escolas sem parceria/convênio
Coletada (INEP): 2022'),
  ('clean.censo_escolas', 'in_tipo_atend_ac', 'Tipo de atendimento ofertado por meio da parceria ou convênio - Atividade Complementar', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, 2022, NULL, 'NULL = Não aplicável para escolas sem parceria/convênio
Coletada (INEP): 2022'),
  ('clean.censo_escolas', 'in_tipo_atend_aee', 'Tipo de atendimento ofertado por meio da parceria ou convênio - Atendimento Educacional Especializado (AEE)', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, 2022, NULL, 'NULL = Não aplicável para escolas sem parceria/convênio
Coletada (INEP): 2022'),
  ('clean.censo_escolas', 'in_mant_escola_privada_emp', 'Mantenedora da escola privada - Empresa ou grupo empresarial do setor privado ou pessoa física', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'NULL = Não aplicável para escolas públicas
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_mant_escola_privada_ong', 'Mantenedora da escola privada - Organização Não Governamental (ONG) - internacional ou nacional', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas públicas
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_mant_escola_privada_oscip', 'Mantenedora da escola privada - Organização da Sociedade Civil de Interesse Público (Oscip)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas públicas
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_mant_escola_priv_ong_oscip', 'Mantenedora da escola privada - Organização Não Governamental (ONG) - internacional ou nacional. Organização da Sociedade Civil de Interesse Público (Oscip)', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, 2019, 'A partir de 2019:
Variável derivada juntando IN_MANT_ESCOLA_PRIVADA_ONG e IN_MANT_ESCOLA_PRIVADA_OSCIP
NULL = Não aplicável para escolas públicas
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_mant_escola_privada_sind', 'Mantenedora da escola privada - Sindicatos de trabalhadores ou patronais, associações e cooperativas', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'NULL = Não aplicável para escolas públicas
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_mant_escola_privada_sist_s', 'Mantenedora da escola privada - Sistema S (Sesi, Senai, Sesc, outros)', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'NULL = Não aplicável para escolas públicas
Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_mant_escola_privada_s_fins', 'Mantenedora da escola privada - Instituições sem fins lucrativos', '{"0": "Não", "1": "Sim"}'::jsonb, 2009, NULL, NULL, 'NULL = Não aplicável para escolas públicas
Coletada (INEP): 2009-2025'),
  ('clean.censo_escolas', 'nu_cnpj_escola_privada', 'Número do CNPJ da escola privada', NULL::jsonb, 2007, NULL, NULL, 'NULL = Não aplicável para escolas públicas
Valores especiais (INEP): 99999999999999 = Sem declaração
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'nu_cnpj_mantenedora', 'Número do CNPJ da mantenedora principal da escola privada', NULL::jsonb, 2010, NULL, NULL, 'NULL = Não aplicável para escolas públicas
Valores especiais (INEP): 99999999999999 = Sem declaração
Coletada (INEP): 2010-2025'),
  ('clean.censo_escolas', 'tp_regulamentacao', 'Regulamentação/Autorização no conselho ou órgão municipal, estadual ou federal de educação', '{"0": "Não", "1": "Sim", "2": "Em tramitação"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_responsavel_regulamentacao', 'Esfera administrativa do conselho ou órgão responsável pela Regulamentação/Autorização', '{"1": "Federal", "2": "Estadual", "3": "Municipal", "4": "Estadual e Municipal", "5": "Federal e Estadual", "6": "Federal, Estadual e Municipal", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas sem regulamentação
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'co_escola_sede_vinculada', 'Código da escola sede', NULL::jsonb, 2015, NULL, NULL, 'NULL = Não aplicável para escolas que não possuem vínculo
Coletada (INEP): 2015-2025'),
  ('clean.censo_escolas', 'co_ies_ofertante', 'Código da IES vinculada à escola', NULL::jsonb, 2015, NULL, NULL, 'NULL = Não aplicável para escolas que não possuem vínculo
Coletada (INEP): 2015-2025'),
  ('clean.censo_escolas', 'in_local_func_predio_escolar', 'Local de funcionamento da escola - Prédio Escolar', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_ocupacao_predio_escolar', 'Forma de ocupação do Prédio escolar', '{"1": "Próprio", "2": "Alugado", "3": "Cedido"}'::jsonb, 2011, NULL, NULL, 'NULL = Não aplicável para escolas que não ocupam prédio escolar
Coletada (INEP): 2011-2025'),
  ('clean.censo_escolas', 'in_local_func_salas_empresa', 'Local de funcionamento da escola - Salas de empresa', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_local_func_socioeducativo', 'Local de funcionamento da escola - Unidade de Atendimento socioeducativo', '{"0": "Não", "1": "Sim"}'::jsonb, 2013, NULL, NULL, 'Coletada (INEP): 2013-2025'),
  ('clean.censo_escolas', 'in_local_func_unid_prisional', 'Local de funcionamento da escola - Unidade Prisional', '{"0": "Não", "1": "Sim"}'::jsonb, 2013, NULL, NULL, 'Coletada (INEP): 2013-2025'),
  ('clean.censo_escolas', 'in_local_func_prisional_socio', 'Local de funcionamento da escola - Unidade Prisional ou Unidade de atendimento socioeducativo', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_local_func_templo_igreja', 'Local de funcionamento da escola - Templo/Igreja', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_local_func_casa_professor', 'Local de funcionamento da escola - Casa do professor', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_local_func_galpao', 'Local de funcionamento da escola - Galpão/Rancho/Paiol/Barracão', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_ocupacao_galpao', 'Forma de ocupação do Galpão/Rancho/Paiol/Barracão', '{"1": "Próprio", "2": "Alugado", "3": "Cedido", "9": "Não informado"}'::jsonb, 2011, NULL, NULL, 'NULL = Não aplicável para escolas que não ocupam Galpão/Rancho/Paiol/Barracão
Coletada (INEP): 2011-2025'),
  ('clean.censo_escolas', 'in_local_func_salas_outra_esc', 'Local de funcionamento da escola - Salas em outra escola', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_local_func_outros', 'Local de funcionamento da escola - Outros', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_predio_compartilhado', 'Prédio compartilhado com outra escola', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'NULL = Não aplicável para escolas que não ocupam prédio escolar
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_agua_filtrada', 'Água consumida pelos alunos', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_agua_potavel', 'Fornece água potável para o consumo humano', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_agua_rede_publica', 'Abastecimento de água - Rede pública', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_agua_poco_artesiano', 'Abastecimento de água - Poço artesiano', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_agua_cacimba', 'Abastecimento de água - Cacimba/Cisterna/Poço', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_agua_fonte_rio', 'Abastecimento de água - Fonte/Rio/Igarapé/Riacho/Córrego', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_agua_inexistente', 'Abastecimento de água - Não há abastecimento de água', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_agua_carro_pipa', 'Abastecimento de água - Carro-pipa', '{"0": "Não", "1": "Sim"}'::jsonb, 2024, NULL, NULL, 'Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_energia_rede_publica', 'Abastecimento de energia elétrica - Rede pública', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_energia_gerador', 'Abastecimento de energia elétrica - Gerador', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_energia_gerador_fossil', 'Abastecimento de energia elétrica - Gerador movido a combustível fóssil', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_energia_outros', 'Abastecimento de energia elétrica - Outros (Energia alternativa)', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_energia_renovavel', 'Abastecimento de energia elétrica - Fontes de energia renováveis ou alternativas (gerador a biocombustível e/ou biodigestores, eólica, solar, outras)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_energia_inexistente', 'Abastecimento de energia elétrica - Não há energia elétrica', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esgoto_rede_publica', 'Esgoto sanitário - Rede pública', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esgoto_fossa_septica', 'Esgoto sanitário - Fossa Séptica', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_esgoto_fossa_comum', 'Esgoto sanitário - Fossa rudimentar/comum', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_esgoto_fossa', 'Esgoto sanitário - Fossa', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, 2019, 'A partir de 2019:
Variável derivada juntando IN_ESGOTO_FOSSA_SEPTICA e IN_ESGOTO_FOSSA_COMUM
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esgoto_inexistente', 'Esgoto sanitário - Não há esgotamento sanitário', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_lixo_servico_coleta', 'Destinação do lixo - Serviço de coleta', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_lixo_queima', 'Destinação do lixo - Queima', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_lixo_enterra', 'Destinação do lixo - Enterra', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_lixo_destino_final_publico', 'Destinação do lixo - Leva a uma destinação final financiada pelo poder público', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_lixo_descarta_outra_area', 'Destinação do lixo - Descarta em outra área', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_lixo_joga_outra_area', 'Destinação do lixo - Joga em outra área', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_lixo_outros', 'Destinação do lixo - Outros', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_lixo_recicla', 'Tratamento do lixo/resíduos que a escola realiza - Reciclagem', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_tratamento_lixo_separacao', 'Tratamento do lixo/resíduos que a escola realiza - Separação do lixo/resíduos', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_tratamento_lixo_reutiliza', 'Tratamento do lixo/resíduos que a escola realiza - Reaproveitamento/reutilização', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_tratamento_lixo_reciclagem', 'Tratamento do lixo/resíduos que a escola realiza - Reciclagem', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_tratamento_lixo_inexistente', 'Tratamento do lixo/resíduos que a escola realiza - Não faz tratamento', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_almoxarifado', 'Dependências físicas existentes e utilizadas na escola - Almoxarifado', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_area_verde', 'Dependências físicas existentes e utilizadas na escola - Área de vegetação ou gramado', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_area_plantio', 'Dependências físicas existentes e utilizadas na escola - Área de horta, plantio e/ou produção agrícola', '{"0": "Não", "1": "Sim"}'::jsonb, 2024, NULL, NULL, 'Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_auditorio', 'Dependências físicas existentes e utilizadas na escola - Auditório', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_banheiro_fora_predio', 'Dependências físicas existentes e utilizadas na escola - Banheiro fora do prédio', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_banheiro_dentro_predio', 'Dependências físicas existentes e utilizadas na escola - Banheiro dentro do prédio', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_banheiro', 'Dependências físicas existentes e utilizadas na escola - Banheiro', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_banheiro_ei', 'Dependências físicas existentes e utilizadas na escola - Banheiro adequado à educação infantil', '{"0": "Não", "1": "Sim"}'::jsonb, 2009, NULL, NULL, 'Coletada (INEP): 2009-2025'),
  ('clean.censo_escolas', 'in_banheiro_pne', 'Dependências físicas existentes e utilizadas na escola - Banheiro acessível, adequado ao uso de pessoas com deficiência ou mobilidade reduzida', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_banheiro_funcionarios', 'Dependências físicas existentes e utilizadas na escola - Banheiro exclusivo para os funcionários', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_banheiro_chuveiro', 'Dependências físicas existentes e utilizadas na escola - Banheiro ou vestiário com chuveiro', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, 2019, 'De 2012 a 2018: "Banheiro com chuveiro"
A partir de 2019: "Banheiro ou vestiário com chuveiro"
Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_bercario', 'Dependências físicas existentes e utilizadas na escola - Berçário', '{"0": "Não", "1": "Sim"}'::jsonb, 2009, 2018, NULL, 'Coletada (INEP): 2009-2018'),
  ('clean.censo_escolas', 'in_biblioteca', 'Dependências físicas existentes e utilizadas na escola - Biblioteca', '{"0": "Não", "1": "Sim"}'::jsonb, 2009, NULL, NULL, 'Coletada (INEP): 2009-2025'),
  ('clean.censo_escolas', 'in_biblioteca_sala_leitura', 'Dependências físicas existentes e utilizadas na escola - Biblioteca e/ou Sala de leitura', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_cozinha', 'Dependências físicas existentes e utilizadas na escola - Cozinha', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_despensa', 'Dependências físicas existentes e utilizadas na escola - Despensa', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_dormitorio_aluno', 'Dependências físicas existentes e utilizadas na escola - Dormitório de aluno(a)', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, 2019, 'De 2012 a 2018: "Alojamento de aluno"
A partir de 2019: "Dormitório de aluno(a)
Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_dormitorio_professor', 'Dependências físicas existentes e utilizadas na escola - Dormitório de professor(a)', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, 2019, 'De 2012 a 2018: "Alojamento de professor"
A partir de 2019: "Dormitório de professor(a)"
Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_laboratorio_ciencias', 'Dependências físicas existentes e utilizadas na escola - Laboratório de ciências', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_laboratorio_informatica', 'Dependências físicas existentes e utilizadas na escola - Laboratório de informática', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_laboratorio_educ_prof', 'Dependências físicas existentes e utilizadas na escola - Laboratório específico para a Educação Profissional', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_patio_coberto', 'Dependências físicas existentes e utilizadas na escola - Pátio coberto', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_patio_descoberto', 'Dependências físicas existentes e utilizadas na escola - Pátio descoberto', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_parque_infantil', 'Dependências físicas existentes e utilizadas na escola - Parque infantil', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_piscina', 'Dependências físicas existentes e utilizadas na escola - Piscina', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_quadra_esportes', 'Dependências físicas existentes e utilizadas na escola - Quadra de esportes coberta ou descoberta', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_quadra_esportes_coberta', 'Dependências físicas existentes e utilizadas na escola - Quadra de esportes coberta', '{"0": "Não", "1": "Sim"}'::jsonb, 2011, NULL, NULL, 'Coletada (INEP): 2011-2025'),
  ('clean.censo_escolas', 'in_quadra_esportes_descoberta', 'Dependências físicas existentes e utilizadas na escola - Quadra de esportes descoberta', '{"0": "Não", "1": "Sim"}'::jsonb, 2011, NULL, NULL, 'Coletada (INEP): 2011-2025'),
  ('clean.censo_escolas', 'in_refeitorio', 'Dependências físicas existentes e utilizadas na escola - Refeitório', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_sala_atelie_artes', 'Dependências físicas existentes e utilizadas na escola - Sala/ateliê de artes', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_sala_musica_coral', 'Dependências físicas existentes e utilizadas na escola - Sala de música/coral', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_sala_estudio_danca', 'Dependências físicas existentes e utilizadas na escola - Sala/estúdio de dança', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_sala_multiuso', 'Dependências físicas existentes e utilizadas na escola - Sala multiuso (música, dança e artes)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_sala_estudio_gravacao', 'Dependências físicas existentes e utilizadas na escola - Estúdio de gravação e edição', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_sala_oficinas_educ_prof', 'Dependências físicas existentes e utilizadas na escola - Salas de oficinas da Educação Profissional', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_sala_diretoria', 'Dependências físicas existentes e utilizadas na escola - Sala de Diretoria', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_sala_leitura', 'Dependências físicas existentes e utilizadas na escola - Sala de leitura', '{"0": "Não", "1": "Sim"}'::jsonb, 2009, NULL, NULL, 'Coletada (INEP): 2009-2025'),
  ('clean.censo_escolas', 'in_sala_professor', 'Dependências físicas existentes e utilizadas na escola - Sala de professores', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_sala_repouso_aluno', 'Dependências físicas existentes e utilizadas na escola - Sala de repouso para aluno(a)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_secretaria', 'Dependências físicas existentes e utilizadas na escola - Sala de Secretaria', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'in_sala_atendimento_especial', 'Dependências físicas existentes e utilizadas na escola - Sala de Recursos Multifuncionais para Atendimento Educacional Especializado (AEE)', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_terreirao', 'Dependências físicas existentes e utilizadas na escola - Terreirão (área para prática desportiva e recreação sem cobertura, sem piso e sem edificações)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_viveiro', 'Dependências físicas existentes e utilizadas na escola - Viveiro/criação de animais', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_dependencias_pne', 'Dependências físicas existentes e utilizadas na escola - Dependências e vias adequadas a alunos com deficiência ou mobilidade reduzida', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_lavanderia', 'Dependências físicas existentes e utilizadas na escola - Lavanderia', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, 2018, NULL, 'Coletada (INEP): 2012-2018'),
  ('clean.censo_escolas', 'in_dependencias_outras', 'Dependências existentes na escola - Nenhuma das dependências relacionadas', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_acessibilidade_corrimao', 'Recursos de acessibilidade para pessoas com deficiência ou mobilidade reduzida nas vias de circulação interna na escola - Corrimão e guarda corpos', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_acessibilidade_elevador', 'Recursos de acessibilidade para pessoas com deficiência ou mobilidade reduzida nas vias de circulação interna na escola - Elevador', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_acessibilidade_pisos_tateis', 'Recursos de acessibilidade para pessoas com deficiência ou mobilidade reduzida nas vias de circulação interna na escola - Pisos táteis', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_acessibilidade_vao_livre', 'Recursos de acessibilidade para pessoas com deficiência ou mobilidade reduzida nas vias de circulação interna na escola - Portas com vão livre de, no mínimo, 80 cm', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_acessibilidade_rampas', 'Recursos de acessibilidade para pessoas com deficiência ou mobilidade reduzida nas vias de circulação interna na escola - Rampas', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_acessibilidade_sinal_sonoro', 'Recursos de acessibilidade para pessoas com deficiência ou mobilidade reduzida nas vias de circulação interna na escola - Sinalização sonora', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_acessibilidade_sinal_tatil', 'Recursos de acessibilidade para pessoas com deficiência ou mobilidade reduzida nas vias de circulação interna na escola - Sinalização tátil (piso/paredes)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_acessibilidade_sinal_visual', 'Recursos de acessibilidade para pessoas com deficiência ou mobilidade reduzida nas vias de circulação interna na escola - Sinalização visual (piso/paredes)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_acessibilidade_inexistente', 'Recursos de acessibilidade para pessoas com deficiência ou mobilidade reduzida nas vias de circulação interna na escola - Nenhum dos recursos de acessibilidade listados', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_acessibilidade_sinalizacao', 'Recursos de acessibilidade para pessoas com deficiência ou mobilidade reduzida nas vias de circulação interna na escola - Sinalização/alarme luminoso', '{"0": "Não", "1": "Sim"}'::jsonb, 2024, NULL, NULL, 'Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'qt_salas_existentes', 'Número de salas de aula existentes na escola', NULL::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'qt_salas_utilizadas_dentro', 'Número de salas de aula utilizadas na escola - Dentro do prédio', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'qt_salas_utilizadas_fora', 'Número de salas de aula utilizadas na escola - Fora do prédio', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'qt_salas_utilizadas', 'Número de salas de aula utilizadas na escola (dentro e fora do prédio)', NULL::jsonb, 2007, NULL, 2019, 'A partir de 2019:
Variável derivada juntando QT_SALAS_UTILIZADAS_DENTRO e QT_SALAS_UTILIZADAS_FORA
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'qt_salas_utiliza_climatizadas', 'Condições das salas de aula utilizadas na escola (dentro e fora do prédio escolar) - Número de salas de aula climatizadas', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'qt_salas_utilizadas_acessiveis', 'Condições das salas de aula utilizadas na escola (dentro e fora do prédio escolar) - Número de salas de aula com acessibilidade para pessoas com deficiência ou mobilidade reduzida', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'qt_salas_leitura', 'Quantidade de salas de aula com Cantinho da Leitura para a Educação Infantil e o Ensino fundamental (Anos iniciais)', NULL::jsonb, 2025, NULL, NULL, 'Coletada (INEP): 2025'),
  ('clean.censo_escolas', 'in_equip_parabolica', 'Equipamentos existentes na escola para uso técnico e administrativo - Antena parabólica', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_computador', 'Equipamentos existentes na escola para uso técnico e administrativo - Computador', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_equip_copiadora', 'Equipamentos existentes na escola para uso técnico e administrativo - Copiadora', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_equip_impressora', 'Equipamentos existentes na escola para uso técnico e administrativo - Impressora', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_equip_impressora_mult', 'Equipamentos existentes na escola para uso técnico e administrativo - Impressora Multifuncional', '{"0": "Não", "1": "Sim"}'::jsonb, 2015, NULL, NULL, 'Coletada (INEP): 2015-2025'),
  ('clean.censo_escolas', 'in_equip_scanner', 'Equipamentos existentes na escola para uso técnico e administrativo - Scanner', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_equip_nenhum', 'Nenhum dos equipamentos listados para uso técnico e administrativo - Antena parabólica, Computador, Copiadora, Impressora, Impressora Multifuncional ou Scanner', '{"0": "Não", "1": "Sim"}'::jsonb, 2021, NULL, NULL, 'Coletada (INEP): 2021-2025'),
  ('clean.censo_escolas', 'in_equip_dvd', 'Equipamentos existentes na escola para o processo ensino e aprendizagem - DVD/Blu-ray', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'qt_equip_dvd', 'Quantidade de Aparelhos de DVD/Blu-ray', NULL::jsonb, 2013, NULL, 2019, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo de 4 equipamentos para cada 3 salas existentes - foram marcados apenas valores>3)
Coletada (INEP): 2013-2025'),
  ('clean.censo_escolas', 'in_equip_som', 'Equipamentos existentes na escola para o processo ensino e aprendizagem - Aparelho de som', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'qt_equip_som', 'Quantidade de Aparelhos de som', NULL::jsonb, 2013, NULL, 2019, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo de 4 equipamentos para cada 3 salas existentes - foram marcados apenas valores>3)
Coletada (INEP): 2013-2025'),
  ('clean.censo_escolas', 'in_equip_tv', 'Equipamentos existentes na escola para o processo ensino e aprendizagem - Aparelho de televisão', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'qt_equip_tv', 'Quantidade de Aparelhos de televisão', NULL::jsonb, 2013, NULL, 2019, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo de 4 equipamentos para cada 3 salas existentes - foram marcados apenas valores>3)
Coletada (INEP): 2013-2025'),
  ('clean.censo_escolas', 'in_equip_lousa_digital', 'Equipamentos existentes na escola para o processo ensino e aprendizagem - Lousa digital', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'qt_equip_lousa_digital', 'Quantidade de Lousas digitais', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo de 4 equipamentos para cada 3 salas existentes - foram marcados apenas valores>3)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_equip_multimidia', 'Equipamentos existentes na escola para o processo ensino e aprendizagem - Projetor Multimídia (Datashow)', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_escolas', 'qt_equip_multimidia', 'Quantidade de Projetores Multimídia (Datashow)', NULL::jsonb, 2013, NULL, 2019, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo de 4 equipamentos para cada 3 salas existentes - foram marcados apenas valores>3)
Coletada (INEP): 2013-2025'),
  ('clean.censo_escolas', 'in_equip_videocassete', 'Equipamentos existentes na escola - Videocassete', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_equip_retroprojetor', 'Equipamentos existentes na escola - Retroprojetor', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_equip_fax', 'Equipamentos existentes na escola - Fax', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, 2018, NULL, 'Coletada (INEP): 2012-2018'),
  ('clean.censo_escolas', 'in_equip_foto', 'Equipamentos existentes na escola - Máquina fotográfica/Filmadora', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, 2018, NULL, 'Coletada (INEP): 2012-2018'),
  ('clean.censo_escolas', 'qt_equip_videocassete', 'Quantidade de Videocassetes', NULL::jsonb, 2013, 2018, NULL, 'Coletada (INEP): 2013-2018'),
  ('clean.censo_escolas', 'qt_equip_parabolica', 'Quantidade de Antenas parabólicas', NULL::jsonb, 2013, 2018, NULL, 'Coletada (INEP): 2013-2018'),
  ('clean.censo_escolas', 'qt_equip_copiadora', 'Quantidade de Copiadoras', NULL::jsonb, 2013, 2018, NULL, 'Coletada (INEP): 2013-2018'),
  ('clean.censo_escolas', 'qt_equip_retroprojetor', 'Quantidade de Retroprojetores', NULL::jsonb, 2013, 2018, NULL, 'Coletada (INEP): 2013-2018'),
  ('clean.censo_escolas', 'qt_equip_impressora', 'Quantidade de Impressoras', NULL::jsonb, 2013, 2018, NULL, 'Coletada (INEP): 2013-2018'),
  ('clean.censo_escolas', 'qt_equip_impressora_mult', 'Quantidade de Impressoras Multifuncionais', NULL::jsonb, 2015, 2018, NULL, 'Coletada (INEP): 2015-2018'),
  ('clean.censo_escolas', 'qt_equip_fax', 'Quantidade de Fax', NULL::jsonb, 2013, 2018, NULL, 'Coletada (INEP): 2013-2018'),
  ('clean.censo_escolas', 'qt_equip_foto', 'Quantidade de Máquinas Fotográficas/ Filmadoras', NULL::jsonb, 2013, 2018, NULL, 'Coletada (INEP): 2013-2018'),
  ('clean.censo_escolas', 'qt_comp_aluno', 'Quantidade de computadores em uso pelos alunos', NULL::jsonb, 2007, 2018, NULL, 'NULL = Não aplicável para escolas que não possuem computador
Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_desktop_aluno', 'Computadores em uso pelos alunos - Computador de mesa (desktop)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'qt_desktop_aluno', 'Quantidade de computadores em uso pelos alunos - Computador de mesa (desktop)', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo de 4 equipamentos para cada 3 matrículas - foram marcados apenas valores>3)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_comp_portatil_aluno', 'Computadores em uso pelos alunos - Computador portátil', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'qt_comp_portatil_aluno', 'Quantidade de computadores em uso pelos alunos - Computador portátil', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo de 4 equipamentos para cada 3 matrículas - foram marcados apenas valores>3)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_tablet_aluno', 'Computadores em uso pelos alunos - Tablet', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'qt_tablet_aluno', 'Quantidade de computadores em uso pelos alunos - Tablet', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo de 4 equipamentos para cada 3 matrículas - foram marcados apenas valores>3)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'qt_computador', 'Quantidade de computadores na escola', NULL::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'qt_comp_administrativo', 'Quantidade de computadores de uso administrativo', NULL::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_internet', 'Acesso à Internet', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_internet_alunos', 'Acesso à Internet - Para uso dos alunos', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_internet_administrativo', 'Acesso à Internet - Para uso administrativo', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_internet_aprendizagem', 'Acesso à Internet - Para uso nos processos de ensino e aprendizagem', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_internet_comunidade', 'Acesso à Internet - Para uso da comunidade', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_acesso_internet_computador', 'Equipamentos que os alunos usam para acessar a internet da escola - Computadores de mesa, portáteis e tablets da escola (no laboratório de informática, biblioteca, sala de aula etc.)', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_aces_internet_disp_pessoais', 'Equipamentos que os alunos usam para acessar a internet da escola - Dispositivos pessoais (computadores portáteis, celulares, tablets etc.)', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'tp_rede_local', 'Rede local de interligação de computadores', '{"0": "Não há rede local interligando computadores", "1": "A cabo", "2": "Wireless", "3": "A cabo e Wireless", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_banda_larga', 'Internet Banda Larga', '{"0": "Não", "1": "Sim"}'::jsonb, 2008, NULL, NULL, 'NULL = Não aplicável para escolas sem acesso à internet
Coletada (INEP): 2008-2025'),
  ('clean.censo_escolas', 'qt_funcionarios', 'Total de funcionários da escola (inclusive profissionais escolares em sala de aula)', NULL::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_prof_administrativos', 'Profissionais que atuam na escola - Auxiliares de secretaria ou auxiliares administrativos, atendentes', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_administrativos', 'Quantidade de profissionais que atuam na escola - Auxiliares de secretaria ou auxiliares administrativos, atendentes', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_servicos_gerais', 'Profissionais que atuam na escola - Auxiliar de serviços gerais, porteiro(a), zelador(a), faxineiro(a), jardineiro(a)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_servicos_gerais', 'Total de profissionais que atuam na escola - Auxiliar de serviços gerais, porteiro(a), zelador(a), faxineiro(a), jardineiro(a)', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_bibliotecario', 'Profissionais que atuam na escola - Bibliotecário(a), auxiliar de biblioteca ou monitor(a) da sala de leitura', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_bibliotecario', 'Quantidade de profissionais que atuam na escola - Bibliotecário(a), auxiliar de biblioteca ou monitor(a) da sala de leitura', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_saude', 'Profissionais que atuam na escola - Bombeiro(a) brigadista, profissionais de assistência à saúde (urgência e emergência), Enfermeiro(a), Técnico(a) de enfermagem e socorrista', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_saude', 'Quantidade de profissionais que atuam na escola - Bombeiro(a) brigadista, profissionais de assistência à saúde (urgência e emergência), Enfermeiro(a), Técnico(a) de enfermagem e socorrista', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_coordenador', 'Profissionais que atuam na escola - Coordenador(a) de turno/disciplina', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_coordenador', 'Quantidade de profissionais que atuam na escola - Coordenador(a) de turno/disciplina', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_fonaudiologo', 'Profissionais que atuam na escola - Fonoaudiólogo(a)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_fonaudiologo', 'Quantidade de profissionais que atuam na escola - Fonoaudiólogo(a)', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_nutricionista', 'Profissionais que atuam na escola - Nutricionista', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_nutricionista', 'Quantidade de profissionais que atuam na escola - Nutricionista', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_psicologo', 'Profissionais que atuam na escola - Psicólogo(a) Escolar', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_psicologo', 'Quantidade de profissionais que atuam na escola - Psicólogo(a) Escolar', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_alimentacao', 'Profissionais que atuam na escola - Profissionais de preparação e segurança alimentar, cozinheiro(a), merendeiro(a) e auxiliar de cozinha', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_alimentacao', 'Quantidade de profissionais que atuam na escola - Profissionais de preparação e segurança alimentar, cozinheiro(a), merendeiro(a) e auxiliar de cozinha', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_pedagogia', 'Profissionais que atuam na escola - Profissionais de apoio e supervisão pedagógica: pedagogo(a), coordenador(a) pedagógico(a), orientador(a) educacional, supervisor(a) escolar e coordenador(a) de área de ensino', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_pedagogia', 'Quantidade de profissionais que atuam na escola - Profissionais de apoio e supervisão pedagógica: pedagogo(a), coordenador(a) pedagógico(a), orientador(a) educacional, supervisor(a) escolar e coordenador(a) de área de ensino', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_secretario', 'Profissionais que atuam na escola - Secretário(a) escolar', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_secretario', 'Quantidade de profissionais que atuam na escola - Secretário(a) escolar', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_seguranca', 'Profissionais que atuam na escola - Segurança, guarda ou segurança patrimonial', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_seguranca', 'Quantidade de profissionais que atuam na escola - Segurança, guarda ou segurança patrimonial', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_monitores', 'Profissionais que atuam na escola - Técnicos(as), monitores(as), supervisores(as) ou auxiliares de laboratório(s), de apoio a tecnologias educacionais ou em multimeios/multimídias eletrônico/digitais', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, 2024, NULL, 'Coletada (INEP): 2019-2024'),
  ('clean.censo_escolas', 'qt_prof_monitores', 'Quantidade de profissionais que atuam na escola - Técnicos(as), monitores(as), supervisores(as) ou auxiliares de laboratório(s), de apoio a tecnologias educacionais ou em multimeios/multimídias eletrônico/digitais', NULL::jsonb, 2019, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_prof_gestao', 'Profissionais que atuam na escola - Vice-diretor(a) ou diretor(a) adjunto(a), profissionais responsáveis pela gestão administrativa e/ou financeira', '{"0": "Não", "1": "Sim"}'::jsonb, 2021, 2024, NULL, 'Coletada (INEP): 2021-2024'),
  ('clean.censo_escolas', 'qt_prof_gestao', 'Quantidade de profissionais que atuam na escola - Vice-diretor(a) ou diretor(a) adjunto(a), profissionais responsáveis pela gestão administrativa e/ou financeira', NULL::jsonb, 2021, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2021-2025'),
  ('clean.censo_escolas', 'in_prof_assist_social', 'Profissionais que atuam na escola - Orientador(a) comunitário(a) ou assistente social', '{"0": "Não", "1": "Sim"}'::jsonb, 2021, 2024, NULL, 'Coletada (INEP): 2021-2024'),
  ('clean.censo_escolas', 'qt_prof_assist_social', 'Quantidade de profissionais que atuam na escola - Orientador(a) comunitário(a) ou assistente social', NULL::jsonb, 2021, NULL, NULL, 'Em 2019:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula)
Coletada (INEP): 2021-2025'),
  ('clean.censo_escolas', 'in_prof_trad_libras', 'Profissionais que atuam na escola - Tradutor e Intérprete de Libras para atendimento em outros ambientes da escola que não seja sala de aula', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, 2024, NULL, 'Coletada (INEP): 2023-2024'),
  ('clean.censo_escolas', 'qt_prof_trad_libras', 'Quantidade de profissionais que atuam na escola - Tradutor e Intérprete de Libras para atendimento em outros ambientes da escola que não seja sala de aula', NULL::jsonb, 2023, NULL, NULL, 'Em 2023:
primeiro ano em que foi aplicado tratamento de valores extremos, que são marcados com o código 88888.
Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula de aluno com surdez, deficiência auditiva ou surdocegueira).
Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_prof_agricola', 'Profissionais que atuam na escola - Agrônomos(as), horticultores(as), técnicos ou monitores(as) responsáveis pela gestão da área de horta, plantio e/ou produção agrícola', '{"0": "Não", "1": "Sim"}'::jsonb, 2024, 2024, NULL, 'Coletada (INEP): 2024'),
  ('clean.censo_escolas', 'qt_prof_agricola', 'Quantidade de profissionais que atuam na escola - Agrônomos(as), horticultores(as), técnicos ou monitores(as) responsáveis pela gestão da área de horta, plantio e/ou produção agrícola', NULL::jsonb, 2024, NULL, NULL, 'Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula).
Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_prof_revisor_braille', 'Profissionais que atuam na escola - Revisor de texto Braille, assistente vidente (assistente de revisão do texto em Braille)', '{"0": "Não", "1": "Sim"}'::jsonb, 2024, 2024, NULL, 'Coletada (INEP): 2024'),
  ('clean.censo_escolas', 'qt_prof_revisor_braille', 'Quantidade de profissionais que atuam na escola - Revisor de texto Braille, assistente vidente (assistente de revisão do texto em Braille)', NULL::jsonb, 2024, NULL, NULL, 'Valores especiais (INEP): 88888 = registro com marcação de valor extremo (valor superior ao limite máximo* definido com base na distribuição da razão de profissionais por matrícula de aluno com cegueira, surdo-cegueira ou baixa visão).
Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_alimentacao', 'Alimentação escolar para os alunos - PNAE/FNDE', '{"0": "Não oferece", "1": "Oferece"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_serie_ano', 'Forma de organização do ensino - Série/Ano (séries anuais)', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, 2021, NULL, 'NULL = Não aplicável para escolas sem matrículas de escolarização
Coletada (INEP): 2019-2021'),
  ('clean.censo_escolas', 'in_periodos_semestrais', 'Forma de organização do ensino - Períodos semestrais', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, 2021, NULL, 'NULL = Não aplicável para escolas sem matrículas de escolarização
Coletada (INEP): 2019-2021'),
  ('clean.censo_escolas', 'in_fundamental_ciclos', 'Forma de organização do ensino - Ciclo(s) do Ensino Fundamental', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2009, 2021, NULL, 'NULL = Não aplicável para escolas sem matrículas de escolarização
Coletada (INEP): 2009-2021'),
  ('clean.censo_escolas', 'in_grupos_nao_seriados', 'Forma de organização do ensino - Grupos não-seriados com base na idade ou competência (art. 23 LDB)', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, 2021, NULL, 'NULL = Não aplicável para escolas sem matrículas de escolarização
Coletada (INEP): 2019-2021'),
  ('clean.censo_escolas', 'in_modulos', 'Forma de organização do ensino - Módulos', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, 2021, NULL, 'NULL = Não aplicável para escolas sem matrículas de escolarização
Coletada (INEP): 2019-2021'),
  ('clean.censo_escolas', 'in_formacao_alternancia', 'Forma de organização do ensino - Alternância regular de períodos de estudos (proposta pedagógica de formação por alternância com tempo-escola e tempo-comunidade)', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2013, 2021, NULL, 'NULL = Não aplicável para escolas sem matrículas de escolarização
Coletada (INEP): 2013-2021'),
  ('clean.censo_escolas', 'in_material_ped_multimidia', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Acervo multimídia', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_infantil', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Brinquedos para Educação Infantil', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_cientifico', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Conjunto de materiais científicos', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_difusao', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Equipamento para amplificação e difusão de som/áudio', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_musical', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Instrumentos musicais para conjunto, banda/fanfarra e/ou aulas de música', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_jogos', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Jogos Educativos', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_artisticas', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Materiais para atividades culturais e artísticas', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_profissional', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Materiais para Educação Profissional', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_material_ped_desportiva', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Materiais para prática desportiva e recreação', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_indigena', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Indígena', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_etnico', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Materiais pedagógicos para a educação das relações étnico-raciais', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_campo', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Materiais pedagógicos para a educação do campo', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_material_ped_bil_surdos', 'Instrumentos, materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino aprendizagem - Materiais pedagógicos para a educação bilíngue de surdos', '{"0": "Não", "1": "Sim"}'::jsonb, 2023, NULL, NULL, 'Coletada (INEP): 2023-2025'),
  ('clean.censo_escolas', 'in_material_ped_agricola', 'Instrumentos, materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino aprendizagem - Equipamentos e instrumentos para atividades em área de horta, plantio e/ou produção agrícola', '{"0": "Não", "1": "Sim"}'::jsonb, 2024, NULL, NULL, 'Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_material_ped_quilombola', 'Instrumentos, materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino aprendizagem - Materiais pedagógicos para a educação escolar quilombola', '{"0": "Não", "1": "Sim"}'::jsonb, 2024, NULL, NULL, 'Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_material_ped_edu_esp', 'Instrumentos, materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino aprendizagem - Materiais pedagógicos para a educação especial', '{"0": "Não", "1": "Sim"}'::jsonb, 2024, NULL, NULL, 'Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_material_ped_nenhum', 'Instrumentos e materiais socioculturais e/ou pedagógicos em uso na escola para o desenvolvimento de atividades de ensino e aprendizagem - Nenhum', '{"0": "Não", "1": "Sim"}'::jsonb, 2021, NULL, NULL, 'Coletada (INEP): 2021-2025'),
  ('clean.censo_escolas', 'in_material_esp_quilombola', 'Materiais didáticos específicos para atendimento à diversidade sociocultural - Quilombolas', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_material_esp_indigena', 'Materiais didáticos específicos para atendimento à diversidade sociocultural - Indígena', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_material_esp_nao_utiliza', 'Materiais didáticos específicos para atendimento à diversidade sociocultural - Não utiliza', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, 2018, NULL, 'Coletada (INEP): 2007-2018'),
  ('clean.censo_escolas', 'in_educacao_indigena', 'Escola Indígena', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_indigena_lingua', 'Escola Indígena - Língua em que o ensino é ministrado (apenas para escola indígena)', '{"1": "Somente em Língua Indígena", "2": "Somente em Língua Portuguesa", "3": "Em Língua Indígena e em Língua Portuguesa"}'::jsonb, 2007, NULL, NULL, 'NULL = não aplicável (aplicável apenas para Escola Indígena)
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_lingua_indigena_1', 'Escola Indígena - Língua em que o ensino é ministrado (apenas para escola indígena) - Língua Indígena - Código da língua Indígena 1', NULL::jsonb, 2007, NULL, 2019, 'De 2007 a 2018: Apenas uma Língua Indígena
Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'co_lingua_indigena_2', 'Escola Indígena - Língua em que o ensino é ministrado (apenas para escola indígena) - Língua Indígena - Código da língua Indígena 2', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'co_lingua_indigena_3', 'Escola Indígena - Língua em que o ensino é ministrado (apenas para escola indígena) - Língua Indígena - Código da língua Indígena 3', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_brasil_alfabetizado', 'Escola cede espaço para turmas do Programa Brasil Alfabetizado', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, 2018, NULL, 'Coletada (INEP): 2012-2018'),
  ('clean.censo_escolas', 'in_final_semana', 'Escola abre aos finais de semana para a comunidade', '{"0": "Não", "1": "Sim"}'::jsonb, 2012, 2018, NULL, 'Coletada (INEP): 2012-2018'),
  ('clean.censo_escolas', 'in_exame_selecao', 'A escola faz exame de seleção para ingresso de seus alunos (avaliação por prova e/ou análise curricular)', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_reserva_ppi', 'Reserva de vagas por sistema de cotas para grupos específicos de alunos - Autodeclarado preto, pardo ou indígena (PPI)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas que não fazem exame de seleção
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_reserva_renda', 'Reserva de vagas por sistema de cotas para grupos específicos de alunos - Condição de Renda', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas que não fazem exame de seleção
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_reserva_publica', 'Reserva de vagas por sistema de cotas para grupos específicos de alunos - Oriundo de escola pública', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas que não fazem exame de seleção
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_reserva_pcd', 'Reserva de vagas por sistema de cotas para grupos específicos de alunos - Pessoa com deficiência (PCD)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas que não fazem exame de seleção
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_reserva_outros', 'Reserva de vagas por sistema de cotas para grupos específicos de alunos - Outros grupos', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas que não fazem exame de seleção
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_reserva_nenhuma', 'Reserva de vagas por sistema de cotas para grupos específicos de alunos - Sem reservas de vagas para sistema de cotas (ampla concorrência)', '{"0": "Não", "1": "Sim"}'::jsonb, 2019, NULL, NULL, 'NULL = Não aplicável para escolas que não fazem exame de seleção
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_redes_sociais', 'A escola possui site ou blog ou página em redes sociais para comunicação institucional', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_espaco_atividade', 'A escola compartilha espaços para atividades de integração escola-comunidade', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_espaco_equipamento', 'A escola usa espaços e equipamentos do entorno escolar para atividades regulares com os alunos', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_orgao_ass_pais', 'Órgãos colegiados em funcionamento na escola - Associação de Pais', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_orgao_ass_pais_mestres', 'Órgãos colegiados em funcionamento na escola - Associação de Pais e Mestres', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_orgao_conselho_escolar', 'Órgãos colegiados em funcionamento na escola - Conselho Escolar', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_orgao_gremio_estudantil', 'Órgãos colegiados em funcionamento na escola - Grêmio Estudantil', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_orgao_outros', 'Órgãos colegiados em funcionamento na escola - Outros', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_orgao_nenhum', 'Órgãos colegiados em funcionamento na escola - Não há órgãos colegiados em funcionamento', '{"0": "Não", "1": "Sim", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Em 2019:
Existe adicionalmente a categoria "9 - Não informado".
Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'tp_proposta_pedagogica', 'O projeto político pedagógico ou a proposta pedagógica da escola (conforme art. 12 da LDB) foi atualizado nos últimos 12 meses até a data de referência', '{"0": "Não", "1": "Sim", "2": "A escola não possui projeto político pedagógico/proposta pedagógica", "9": "Não informado"}'::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_escolas', 'in_educ_ambiental', 'A escola desenvolve ações na área de educação ambiental?', '{"0": "Não", "1": "Sim"}'::jsonb, 2024, NULL, NULL, 'Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_educ_amb_conteudo', 'Informe de qual(quais) forma(s) a educação ambiental é desenvolvida na escola: Como conteúdo dos componentes/campos de experiências presentes no currículo', '{"0": "Não", "1": "Sim", "9": "Não se aplica (escola sem ações de educação ambiental)"}'::jsonb, 2024, NULL, NULL, 'Complemento EduMaps ao domínio (código 9 ausente do dicionário do INEP): O INEP grava 9 nestas variáveis quando IN_EDUC_AMBIENTAL = 0 (medido: 88.321 escolas em 2025), mas o dicionário só lista 0/1.
Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_educ_amb_curricular', 'Informe de qual(quais) forma(s) a educação ambiental é desenvolvida na escola: Como um componente curricular especial, específico, flexível ou eletivo', '{"0": "Não", "1": "Sim", "9": "Não se aplica (escola sem ações de educação ambiental)"}'::jsonb, 2024, NULL, NULL, 'Complemento EduMaps ao domínio (código 9 ausente do dicionário do INEP): O INEP grava 9 nestas variáveis quando IN_EDUC_AMBIENTAL = 0 (medido: 88.321 escolas em 2025), mas o dicionário só lista 0/1.
Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_educ_amb_eixo', 'Informe de qual(quais) forma(s) a educação ambiental é desenvolvida na escola: Como um eixo estruturante do currículo', '{"0": "Não", "1": "Sim", "9": "Não se aplica (escola sem ações de educação ambiental)"}'::jsonb, 2024, NULL, NULL, 'Complemento EduMaps ao domínio (código 9 ausente do dicionário do INEP): O INEP grava 9 nestas variáveis quando IN_EDUC_AMBIENTAL = 0 (medido: 88.321 escolas em 2025), mas o dicionário só lista 0/1.
Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_educ_amb_eventos', 'Informe de qual(quais) forma(s) a educação ambiental é desenvolvida na escola: Em eventos', '{"0": "Não", "1": "Sim", "9": "Não se aplica (escola sem ações de educação ambiental)"}'::jsonb, 2024, NULL, NULL, 'Complemento EduMaps ao domínio (código 9 ausente do dicionário do INEP): O INEP grava 9 nestas variáveis quando IN_EDUC_AMBIENTAL = 0 (medido: 88.321 escolas em 2025), mas o dicionário só lista 0/1.
Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_educ_amb_projetos', 'Informe de qual(quais) forma(s) a educação ambiental é desenvolvida na escola: Em projetos transversais ou interdisciplinares', '{"0": "Não", "1": "Sim", "9": "Não se aplica (escola sem ações de educação ambiental)"}'::jsonb, 2024, NULL, NULL, 'Complemento EduMaps ao domínio (código 9 ausente do dicionário do INEP): O INEP grava 9 nestas variáveis quando IN_EDUC_AMBIENTAL = 0 (medido: 88.321 escolas em 2025), mas o dicionário só lista 0/1.
Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'in_educ_amb_nenhuma', 'Informe de qual(quais) forma(s) a educação ambiental é desenvolvida na escola: Nenhuma das opções listadas', '{"0": "Não", "1": "Sim", "9": "Não se aplica (escola sem ações de educação ambiental)"}'::jsonb, 2024, NULL, NULL, 'Complemento EduMaps ao domínio (código 9 ausente do dicionário do INEP): O INEP grava 9 nestas variáveis quando IN_EDUC_AMBIENTAL = 0 (medido: 88.321 escolas em 2025), mas o dicionário só lista 0/1.
Coletada (INEP): 2024-2025'),
  ('clean.censo_escolas', 'tp_aee', 'Atendimento Educacional Especializado (AEE)', '{"0": "Não oferece", "1": "Não exclusivamente", "2": "Exclusivamente"}'::jsonb, 2009, NULL, NULL, 'Coletada (INEP): 2009-2025'),
  ('clean.censo_escolas', 'tp_atividade_complementar', 'Atividade Complementar', '{"0": "Não oferece", "1": "Não exclusivamente", "2": "Exclusivamente"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'tp_itinerario_formativo', 'Itinerário formativo', '{"0": "Não oferece", "1": "Não exclusivamente", "2": "Exclusivamente"}'::jsonb, 2022, NULL, NULL, 'Ver nota sobre a não divulgação dos resultados em 2022: https://download.inep.gov.br/areas_de_atuacao/nota_informativa_censo_escolar_2022.pdf
Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_itinerario_aprofundamento', 'Escola oferece turma de Itinerário formativo de aprofundamento (IFA) - Percursos educacionais estruturados de livre escolha dos estudantes, que permite aos educandos o aprofundamento de suas aprendizagens e de seu desenvolvimento em uma ou em mais áreas do conhecimento. Deve realizar-se por meio da oferta de projetos interdisciplinares e integradores, organizados com ênfase nos componentes curriculares que compõem a(s) área(s) de conhecimento eleitas, de modo a ampliar o diálogo entre as dimensões teóricas e práticas dos conteúdos, a consideração e valorização da diversidade territorial e cultural do Brasil e as escolhas estabelecidas na proposta pedagógica de cada unidade escolar.', '{"0": "Não", "1": "Sim"}'::jsonb, 2025, NULL, NULL, 'Coletada (INEP): 2025'),
  ('clean.censo_escolas', 'in_itinerario_tecn_prof', 'Escola oferece turma de itinerário de formação técnica e profissional (IFTP) - É o percurso educacional destinado à educação profissional de nível médio, desenvolvido preferencialmente com oferta integrada ou concomitante intercomplementar, de modo integrado à Formação Geral Básica, observando a indissociabilidade entre a preparação para o mundo do trabalho, a preparação para a cidadania e a preparação para a continuidade dos estudos em nível superior.', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'Ver nota sobre a não divulgação dos resultados em 2022: https://download.inep.gov.br/areas_de_atuacao/nota_informativa_censo_escolar_2022.pdf
Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_escolarizacao', 'Escola possui uma ou mais matrículas de escolarização em alguma das seguintes etapas de ensino: Creche, Pré-Escola, Ensino Fundamental, Ensino Médio, Educação de Jovens e Adultos (EJA), Curso Técnico Concomitante, Curso Técnico Subsequente, Curso FIC Concomitante, Itinerário Formativo Técnico Profissional (IFTP) Exclusivo - Curso Técnico (não articulado ao ensino médio regular) e Itinerário Formativo Técnico Profissional Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular)', '{"0": "Não", "1": "Sim"}'::jsonb, 2022, NULL, NULL, 'Coletada (INEP): 2022-2025'),
  ('clean.censo_escolas', 'in_mediacao_presencial', 'Mediação didático-pedagógica oferecida pela escola - Presencial', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_mediacao_semipresencial', 'Mediação didático-pedagógica oferecida pela escola - Semipresencial', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_mediacao_ead', 'Mediação didático-pedagógica oferecida pela escola - Educação a Distância - EAD', '{"0": "Não", "1": "Sim"}'::jsonb, 2015, NULL, NULL, 'Coletada (INEP): 2015-2025'),
  ('clean.censo_escolas', 'in_especial_exclusiva', 'Classes Especiais - Escola possui classe especial exclusiva (ao menos uma turma exclusiva de alunos com deficiência, transtorno do espectro autista (TEA) ou altas habilidades/superdotação)', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_regular', 'Ensino Regular - Modo, maneira ou metodologia de ensino correspondente às turmas com etapas de escolarização consecutivas, Creche ao Ensino Médio', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_eja', 'Educação de Jovens e Adultos (EJA) - Modo, maneira ou metodologia de ensino correspondente às turmas destinadas a pessoas que não cursaram o ensino fundamental e/ou médio em idade própria.', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_profissionalizante', 'Educação Profissional - Modo profissionalizante de ensino correspondente às turmas do Ensino Médio articulado ao Itinerário Formativo Técnico Profissional - Curso Técnico, Ensino Médio Normal/Magistério, Curso Técnico Concomitante, Curso Técnico Subsequente, Curso Técnico Integrado à EJA de Nível Médio, Itinerário Formativo Técnico Profissional Exclusivo - Curso Técnico (não articulado ao ensino médio regular), Curso FIC Concomitante, Curso FIC Integrado à EJA de Nível Fundamental, Curso FIC Integrado à EJA de Nível Médio, Ensino Médio articulado ao Itinerário Formativo Técnico Profissional - Qualificação Profissional e Itinerário Formativo Técnico Profissional Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular).', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_creche', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Educação Infantil - Creche', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_pre', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Educação Infantil - Pré-Escola', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_fund_ai', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Anos Iniciais do Ensino Fundamental (1º ao 5º Ano)', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_fund_af', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Anos Finais do Ensino Fundamental (6º ao 9º Ano)', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_medio_medio', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Ensino Médio Propedêutico. A partir de 2025 considera apenas a oferta de ensino médio que não está articulada a curso de Itinerário de formação técnica e profissional (IFTP).', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_medio_integrado', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Ensino Médio Articulado ao itinerário Formativo Técnico Profissional - Curso Técnico. A partir de 2025 considera apenas a oferta de ensino médio articulado a um curso técnico do Itinerário de formação técnica e profissional (IFTP).', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_medio_fic', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Ensino Médio Articulado ao itinerário Formativo Técnico Profissional - Qualificação Profissional.', '{"0": "Não", "1": "Sim"}'::jsonb, 2025, NULL, NULL, 'Coletada (INEP): 2025'),
  ('clean.censo_escolas', 'in_comum_medio_normal', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Ensino Médio Normal/Magistério', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_creche', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Educação Infantil - Creche', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_pre', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Educação Infantil - Pré-Escola', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_fund_ai', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Anos Iniciais do Ensino Fundamental (1º ao 5º Ano)', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_fund_af', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Anos Finais do Ensino Fundamental (6º ao 9º Ano)', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_medio_medio', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Ensino Médio Propedêutico. A partir de 2025 considera apenas a oferta de ensino médio que não está articulada a curso de Itinerário de formação técnica e profissional (IFTP).', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_medio_integr', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Ensino Médio Articulado ao itinerário Formativo Técnico Profissional - Curso Técnico. A partir de 2025 considera apenas a oferta de ensino médio articulado a um curso técnico do Itinerário de formação técnica e profissional (IFTP).', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_medio_fic', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Ensino Médio Articulado ao itinerário Formativo Técnico Profissional - Qualificação Profissional.', '{"0": "Não", "1": "Sim"}'::jsonb, 2025, NULL, NULL, 'Coletada (INEP): 2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_medio_normal', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Ensino Médio Normal/Magistério', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_eja_fund', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Educação de Jovens e Adultos (EJA) Ensino Fundamental nos Anos Iniciais, Anos Finais e Curso FIC integrado à EJA de nível Fundamental', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_eja_medio', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Educação de Jovens e Adultos (EJA) Ensino Médio, Curso FIC integrado à EJA de nível Médio e Curso Técnico integrado à EJA de nível Médio', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_eja_prof', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Educação de Jovens e Adultos (EJA) Profissionalizante, Curso FIC integrado à EJA de nível Fundamental, Curso FIC integrado à EJA de nível Médio e Curso Técnico integrado à EJA de nível Médio', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_eja_fund', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Educação de Jovens e Adultos (EJA) Ensino Fundamental nos Anos Iniciais, Anos Finais e Curso FIC integrado à EJA de nível Fundamental', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_eja_medio', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Educação de Jovens e Adultos (EJA) Ensino Médio, Curso FIC integrado à EJA de nível Médio e Curso Técnico integrado à EJA de nível Médio', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_eja_prof', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Educação de Jovens e Adultos (EJA) Profissionalizante, Curso FIC integrado à EJA de nível Fundamental, Curso FIC integrado à EJA de nível Médio e Curso Técnico integrado à EJA de nível Médio', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_comum_prof', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Comuns - Educação Profissional, Curso Técnico Concomitante, Curso Técnico Subsequente, Curso FIC Concomitante, Itinerário Formativo Técnico Profissional Exclusivo - Curso Técnico (não articulado ao ensino médio regular) e Itinerário Formativo Técnico Profissional Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular).', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_escolas', 'in_esp_exclusiva_prof', 'Escola oferece matrículas de alunos com deficiência, transtorno do espectro autista (TEA), altas habilidades ou superdotação em Classes Exclusivas - Educação Profissional, Curso Técnico Concomitante, Curso Técnico Subsequente, Curso FIC Concomitante, Itinerário Formativo Técnico Profissional Exclusivo - Curso Técnico (não articulado ao ensino médio regular) e Itinerário Formativo Técnico Profissional Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular).', '{"0": "Não", "1": "Sim"}'::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'nu_ano_censo', 'Ano do Censo', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'co_entidade', 'Código da Escola', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas', 'Número de Matrículas da Educação Básica', NULL::jsonb, 2007, NULL, NULL, 'Não inclui matrículas em turmas exclusivas de atividade complementar e nem em turmas exclusivas de Atendimento Educacional Especializado. Em síntese, a Educação Básica compreende matrículas nas seguintes etapas e modalidades de ensino: Educação Infantil, Ensino Fundamental, Ensino Médio, Curso Técnico Concomitante, Curso Técnico Subsequente, Itinerário Formativo Técnico Profissional Exclusivo - Curso Técnico (não articulado ao ensino médio regular), Curso FIC Concomitante, Itinerário Formativo Técnico Profissional Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular) e Educação de Jovens e Adultos (EJA).
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf', 'Número de Matrículas da Educação Infantil', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_cre', 'Número de Matrículas da Educação Infantil - Creche', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_pre', 'Número de Matrículas da Educação Infantil - Pré-Escola', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund', 'Número de Matrículas do Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai_1', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais - 1º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai_2', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais - 2º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai_3', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais - 3º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai_4', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais - 4º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai_5', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais - 5º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_af', 'Número de Matrículas do Ensino Fundamental - Anos Finais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_af_6', 'Número de Matrículas do Ensino Fundamental - Anos Finais - 6º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_af_7', 'Número de Matrículas do Ensino Fundamental - Anos Finais - 7º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_af_8', 'Número de Matrículas do Ensino Fundamental - Anos Finais - 8º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_af_9', 'Número de Matrículas do Ensino Fundamental - Anos Finais - 9º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med', 'Número de Matrículas do Ensino Médio Regular', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_prop', 'Número de Matrículas do Ensino Médio Regular - Propedêutico', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_prop_1', 'Número de Matrículas do Ensino Médio Regular - Propedêutico - 1º ano/1ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_prop_2', 'Número de Matrículas do Ensino Médio Regular - Propedêutico - 2º ano/2ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_prop_3', 'Número de Matrículas do Ensino Médio Regular - Propedêutico - 3º ano/3ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_prop_4', 'Número de Matrículas do Ensino Médio Regular - Propedêutico - 4º ano/4ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_prop_ns', 'Número de Matrículas do Ensino Médio Regular - Propedêutico - Não Seriado', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_ct', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_ct_1', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico - 1º ano/1ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_ct_2', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico - 2º ano/2ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_ct_3', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico - 3º ano/3ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_ct_4', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico - 4º ano/4ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_ct_ns', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico - Não Seriado', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_qp', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_qp_1', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional - 1º ano/1ª Série', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_qp_2', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional - 2º ano/2ª Série', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_qp_3', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional - 3º ano/3ª Série', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_qp_4', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional - 4º ano/4ª Série', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_iftp_qp_ns', 'Número de Matrículas do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional - Não Seriado', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_nm', 'Número de Matrículas do Ensino Médio Regular - Modalidade Normal/Magistério', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_nm_1', 'Número de Matrículas do Ensino Médio Regular - Modalidade Normal/Magistério - 1º ano/1ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_nm_2', 'Número de Matrículas do Ensino Médio Regular - Modalidade Normal/Magistério - 2º ano/2ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_nm_3', 'Número de Matrículas do Ensino Médio Regular - Modalidade Normal/Magistério - 3º ano/3ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_nm_4', 'Número de Matrículas do Ensino Médio Regular - Modalidade Normal/Magistério - 4º ano/4ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa', 'Número de Matrículas do Ensino Médio Regular - Itinerário formativo de aprofundamento (IFA). Percursos educacionais estruturados de livre escolha dos estudantes, que permite aos educandos o aprofundamento de suas aprendizagens e de seu desenvolvimento em uma ou em mais áreas do conhecimento. Deve realizar-se por meio da oferta de projetos interdisciplinares e integradores, organizados com ênfase nos componentes curriculares que compõem a(s) área(s) de conhecimento eleitas, de modo a ampliar o diálogo entre as dimensões teóricas e práticas dos conteúdos, a consideração e valorização da diversidade territorial e cultural do Brasil e as escolhas estabelecidas na proposta pedagógica de cada unidade escolar.', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_ling', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Linguagens e suas tecnologias', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_ling_mt', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Linguagens e suas tecnologias na mesma turma', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_ling_otme', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Linguagens e suas tecnologias em outra turma da mesma escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_ling_oe', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Linguagens e suas tecnologias em outra escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_mate', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Matemática e suas tecnologias', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_mate_mt', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Matemática e suas tecnologias na mesma turma', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_mate_otme', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Matemática e suas tecnologias em outra turma da mesma escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_mate_oe', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Matemática e suas tecnologias em outra escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_cienc', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Ciências da natureza e suas tecnologias', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_cienc_mt', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Ciências da natureza e suas tecnologias na mesma turma', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_cienc_otme', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Ciências da natureza e suas tecnologias em outra turma da mesma escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_cienc_oe', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Ciências da natureza e suas tecnologias em outra escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_huma', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Ciências humanas e sociais aplicadas', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_huma_mt', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Ciências humanas e sociais aplicadas na mesma turma', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_huma_otme', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Ciências humanas e sociais aplicadas em outra turma da mesma escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ifa_huma_oe', 'Número de Matrículas do Ensino Médio Regular - Área do Itinerário formativo de aprofundamento (IFA) - Ciências humanas e sociais aplicadas em outra escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_arti_iftp_ct', 'Número de Matrículas do Ensino Médio Regular (Propedêutico ou Normal/Magistério) articuladas ao Curso Técnico do Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_arti_iftp_ct_mt', 'Número de Matrículas do Ensino Médio Regular (Propedêutico ou Normal/Magistério) articuladas ao Curso Técnico do Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico na mesma turma', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_arti_iftp_ct_otme', 'Número de Matrículas do Ensino Médio Regular (Propedêutico ou Normal/Magistério) articuladas ao Curso Técnico do Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico em outra turma da mesma escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_arti_iftp_ct_oe', 'Número de Matrículas do Ensino Médio Regular (Propedêutico ou Normal/Magistério) articuladas ao Curso Técnico do Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico em outra escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_arti_iftp_qp', 'Número de Matrículas do Ensino Médio Regular (Propedêutico ou Normal/Magistério) articuladas ao Curso Técnico do Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_arti_iftp_qp_mt', 'Número de Matrículas do Ensino Médio Regular (Propedêutico ou Normal/Magistério) articuladas ao Curso Técnico do Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional na mesma turma', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_arti_iftp_qp_otme', 'Número de Matrículas do Ensino Médio Regular (Propedêutico ou Normal/Magistério) articuladas ao Curso Técnico do Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional em outra turma da mesma escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_med_arti_iftp_qp_oe', 'Número de Matrículas do Ensino Médio Regular (Propedêutico ou Normal/Magistério) articuladas ao Curso Técnico do Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional em outra escola', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Aplicável apenas para turmas de ensino médio regular (propedêutico ou normal/magistério)
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_prof', 'Número de Matrículas da Educação Profissional', NULL::jsonb, 2007, NULL, NULL, 'Modo profissionalizante de ensino correspondente às turmas de cursos técnicos de nível médio nas formas articuladas (integrada ou concomitante), ou subsequente ao ensino médio e de normal/magistério, e as turmas de cursos profissionalizantes não-técnicos. Inclui as seguintes etapas de ensino: Ensino Médio articulado ao Itinerário Formativo Técnico Profissional - Curso Técnico, Ensino Médio Normal/Magistério, Curso Técnico Concomitante, Curso Técnico Subsequente, Curso Técnico Integrado à EJA de Nível Médio, Itinerário Formativo Técnico Profissional Exclusivo - Curso Técnico (não articulado ao ensino médio regular), Curso FIC Concomitante, Curso FIC Integrado à EJA de Nível Fundamental, Curso FIC Integrado à EJA de Nível Médio, Ensino Médio articulado ao Itinerário Formativo Técnico Profissional - Qualificação Profissional e Itinerário Formativo Técnico Profissional Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular).
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec', 'Número de Matrículas da Educação Profissional Técnica', NULL::jsonb, 2007, NULL, NULL, 'Modo profissionalizante de ensino correspondente às turmas de cursos técnicos de nível médio nas formas articuladas (integrada ou concomitante), ou subsequente ao ensino médio e de normal/magistério. Inclui as seguintes etapas de ensino: Ensino Médio articulado ao Itinerário Formativo Técnico Profissional - Curso Técnico, Ensino Médio Normal/Magistério, Curso Técnico Concomitante, Curso Técnico Subsequente, Curso Técnico Integrado à EJA de Nível Médio, Itinerário Formativo Técnico Profissional Exclusivo - Curso Técnico (não articulado ao ensino médio regular).
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec_conc', 'Número de Matrículas da Educação Profissional Técnica - Curso Técnico Concomitante', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec_subs', 'Número de Matrículas da Educação Profissional Técnica - Curso Técnico Subsequente', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec_iftp_ct', 'Número de Matrículas da Educação Profissional Técnica - Itinerário Formativo Técnico Profissional (IFTP) Exclusivo - Curso Técnico (não articulado ao ensino médio regular)', NULL::jsonb, 2025, NULL, NULL, 'Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_nao_tec', 'Número de Matrículas da Educação Profissional Não-Técnica', NULL::jsonb, 2007, NULL, NULL, 'A Educação Profissional Não-Técnica inclui matrículas nas seguintes etapas de ensino: Curso FIC Concomitante, Curso FIC Integrado à EJA de Nível Fundamental, Curso FIC Integrado à EJA de Nível Médio, Ensino Médio articulado ao Itinerário Formativo Técnico Profissional - Qualificação Profissional e Itinerário Formativo Técnico Profissional Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular).
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_iftp_qp', 'Número de Matrículas da Educação Profissional - Itinerário Formativo Técnico Profissional (IFTP) Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular)', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_fic_conc', 'Número de Matrículas da Educação Profissional - Curso FIC Concomitante', NULL::jsonb, 2015, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2015-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja', 'Número de Matrículas da Educação de Jovens e Adultos (EJA)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_nprof', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Sem componente profissionalizante', NULL::jsonb, 2007, NULL, NULL, 'Não inclui as matrículas do Curso FIC Integrado na Modalidade EJA de Nível Fundamental
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_ai', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Anos Iniciais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_af', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Anos Finais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_pj', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Projovem Urbano', NULL::jsonb, 2012, 2018, NULL, 'Coletada (INEP): 2012-2018'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_aiaf', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Anos Iniciais e Anos Finais', NULL::jsonb, 2007, 2007, 2016, 'Categoria de etapa de ensino existente na base de matrículas apenas em 2007. De 2008 a 2015 os alunos de turmas da EJA Anos iniciais e Anos finais, foram registrados separadamente como EJA anos iniciais ou EJA anos finais do Ensino Fundamental.
Coletada (INEP): 2007'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_fic', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Curso FIC Integrado na Modalidade EJA de Nível Fundamental', NULL::jsonb, 2008, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2008-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_med', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Médio', NULL::jsonb, 2007, NULL, NULL, 'Inclui as matrículas da EJA - Ensino Médio, EJA - Ensino Médio - Curso FIC Integrado na Modalidade EJA de Nível Médio, e EJA - Ensino Médio - Curso Técnico Integrado na Modalidade EJA de Nível Médio
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_med_nprof', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Médio - Sem componente profissionalizante', NULL::jsonb, 2007, NULL, NULL, 'Não inclui as matrículas do Curso FIC Integrado na Modalidade EJA de Nível Médio e do Curso Técnico Integrado na Modalidade EJA de Nível Médio
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_med_fic', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Médio - Curso FIC Integrado na Modalidade EJA de Nível Médio', NULL::jsonb, 2015, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2015-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_med_tec', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Médio - Curso Técnico Integrado na Modalidade EJA de Nível Médio', NULL::jsonb, 2008, NULL, NULL, 'Categoria (INEP): Deve ser considerada também como uma etapa Profissional Técnica
Coletada (INEP): 2008-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp', 'Número de Matrículas da Educação Especial', NULL::jsonb, 2007, NULL, NULL, 'Número de matrículas de alunos com alguma deficiência, transtorno do espectro autista ou altas habilidades/superdotação.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_inf', 'Número de Matrículas da Educação Especial - Educação Infantil', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_inf_cre', 'Número de Matrículas da Educação Especial - Educação Infantil - Creche', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_inf_pre', 'Número de Matrículas da Educação Especial - Educação Infantil - Pré-Escola', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_fund', 'Número de Matrículas da Educação Especial - Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_fund_ai', 'Número de Matrículas da Educação Especial - Ensino Fundamental - Anos Iniciais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_fund_af', 'Número de Matrículas da Educação Especial - Ensino Fundamental - Anos Finais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_med', 'Número de Matrículas da Educação Especial - Ensino Médio', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_prof', 'Número de Matrículas da Educação Especial - Educação Profissional', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_prof_tec', 'Número de Matrículas da Educação Especial - Educação Profissional Técnica', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_eja', 'Número de Matrículas da Educação Especial - Educação de Jovens e Adultos (EJA)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_eja_fund', 'Número de Matrículas da Educação Especial - Educação de Jovens e Adultos (EJA) - Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_eja_med', 'Número de Matrículas da Educação Especial - Educação de Jovens e Adultos (EJA) - Ensino Médio', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc', 'Número de Matrículas da Educação Especial em Classes Comuns', NULL::jsonb, 2007, NULL, NULL, 'Número de matrículas de alunos com alguma deficiência, transtorno do espectro autista ou altas habilidades/superdotação em Classes Comuns do Ensino Regular e/ou Educação de Jovens Adultos (EJA).
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_inf', 'Número de Matrículas da Educação Especial em Classes Comuns - Educação Infantil', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_inf_cre', 'Número de Matrículas da Educação Especial em Classes Comuns - Educação Infantil - Creche', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_inf_pre', 'Número de Matrículas da Educação Especial em Classes Comuns - Educação Infantil - Pré-Escola', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_fund', 'Número de Matrículas da Educação Especial em Classes Comuns - Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_fund_ai', 'Número de Matrículas da Educação Especial em Classes Comuns - Ensino Fundamental - Anos Iniciais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_fund_af', 'Número de Matrículas da Educação Especial em Classes Comuns - Ensino Fundamental - Anos Finais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_med', 'Número de Matrículas da Educação Especial em Classes Comuns - Ensino Médio', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_prof', 'Número de Matrículas da Educação Especial em Classes Comuns - Educação Profissional', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_prof_tec', 'Número de Matrículas da Educação Especial em Classes Comuns - Educação Profissional Técnica', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_eja', 'Número de Matrículas da Educação Especial em Classes Comuns - Educação de Jovens e Adultos (EJA)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_eja_fund', 'Número de Matrículas da Educação Especial em Classes Comuns - Educação de Jovens e Adultos (EJA) - Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_eja_med', 'Número de Matrículas da Educação Especial em Classes Comuns - Educação de Jovens e Adultos (EJA) - Ensino Médio', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce', 'Número de Matrículas da Educação Especial em Classes Exclusivas', NULL::jsonb, 2007, NULL, NULL, 'Número de matrículas de alunos com alguma deficiência, transtorno do espectro autista ou altas habilidades/superdotação em Classes Exclusivas (Escolas exclusivamente especializadas e/ou em classes especiais do Ensino Regular e/ou Educação de Jovens e Adultos (EJA))
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_inf', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Educação Infantil', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_inf_cre', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Educação Infantil - Creche', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_inf_pre', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Educação Infantil - Pré-Escola', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_fund', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_fund_ai', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Ensino Fundamental - Anos Iniciais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_fund_af', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Ensino Fundamental - Anos Finais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_med', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Ensino Médio', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_prof', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Educação Profissional', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_prof_tec', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Educação Profissional Técnica', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_eja', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Educação de Jovens e Adultos (EJA)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_eja_fund', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Educação de Jovens e Adultos (EJA) - Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_eja_med', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Educação de Jovens e Adultos (EJA) - Ensino Médio', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_fem', 'Número de Matrículas da Educação Básica - Feminino', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_masc', 'Número de Matrículas da Educação Básica - Masculino', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_nd', 'Número de Matrículas da Educação Básica - Cor/Raça Não Declarada', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_branca', 'Número de Matrículas da Educação Básica - Cor/Raça Branca', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_preta', 'Número de Matrículas da Educação Básica - Cor/Raça Preta', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_parda', 'Número de Matrículas da Educação Básica - Cor/Raça Parda', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_amarela', 'Número de Matrículas da Educação Básica - Cor/Raça Amarela', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_indigena', 'Número de Matrículas da Educação Básica - Cor/Raça Indígena', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_0_3', 'Número de Matrículas da Educação Básica - Até 3 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Faixa etária calculada com base na idade do aluno na data de referência do Censo Escolar (última quarta-feira do mês de maio)
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_4_5', 'Número de Matrículas da Educação Básica - Entre 4 e 5 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_6_10', 'Número de Matrículas da Educação Básica - Entre 6 e 10 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_11_14', 'Número de Matrículas da Educação Básica - Entre 11 e 14 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_15_17', 'Número de Matrículas da Educação Básica - Entre 15 e 17 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_18_mais', 'Número de Matrículas da Educação Básica - Com 18 ou mais anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_0_3_ref_31_03', 'Número de Matrículas da Educação Básica - Até 3 anos de idade na data de referência (31 de março de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Faixa etária calculada com base na idade do aluno na data de referência fixada pelo Conselho Nacional de Educação, correspondente a 31 de março, em conformidade com a Resolução CNE/CEB nº 05/2009
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_4_5_ref_31_03', 'Número de Matrículas da Educação Básica - Entre 4 e 5 anos de idade na data de referência (31 de março de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_6_10_ref_31_03', 'Número de Matrículas da Educação Básica - Entre 6 e 10 anos de idade na data de referência (31 de março de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_11_14_ref_31_03', 'Número de Matrículas da Educação Básica - Entre 11 e 14 anos de idade na data de referência (31 de março de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_15_17_ref_31_03', 'Número de Matrículas da Educação Básica - Entre 15 e 17 anos de idade na data de referência (31 de março de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_18_mais_ref_31_03', 'Número de Matrículas da Educação Básica - Com 18 ou mais anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_d', 'Número de Matrículas da Educação Básica - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_dm', 'Número de Matrículas da Educação Básica - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_dv', 'Número de Matrículas da Educação Básica - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_n', 'Número de Matrículas da Educação Básica - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_ead', 'Número de Matrículas da Educação Básica - Turno não aplicável para turmas semipresenciais ou de Educação a Distância (EAD)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_cre_d', 'Número de Matrículas da Educação Infantil - Creche - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_cre_dm', 'Número de Matrículas da Educação Infantil - Creche - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_cre_dv', 'Número de Matrículas da Educação Infantil - Creche - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_cre_n', 'Número de Matrículas da Educação Infantil - Creche - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_pre_d', 'Número de Matrículas da Educação Infantil - Pré-Escola - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_pre_dm', 'Número de Matrículas da Educação Infantil - Pré-Escola - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_pre_dv', 'Número de Matrículas da Educação Infantil - Pré-Escola - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_pre_n', 'Número de Matrículas da Educação Infantil - Pré-Escola - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_d', 'Número de Matrículas do Ensino Fundamental - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_dm', 'Número de Matrículas do Ensino Fundamental - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_dv', 'Número de Matrículas do Ensino Fundamental - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_n', 'Número de Matrículas do Ensino Fundamental - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai_d', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai_dm', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai_dv', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai_n', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_af_d', 'Número de Matrículas do Ensino Fundamental - Anos Finais - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_af_dm', 'Número de Matrículas do Ensino Fundamental - Anos Finais - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_af_dv', 'Número de Matrículas do Ensino Fundamental - Anos Finais - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_af_n', 'Número de Matrículas do Ensino Fundamental - Anos Finais - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_d', 'Número de Matrículas do Ensino Médio - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_dm', 'Número de Matrículas do Ensino Médio - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_dv', 'Número de Matrículas do Ensino Médio - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_n', 'Número de Matrículas do Ensino Médio - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_ead', 'Número de Matrículas do Ensino Médio - Turno não aplicável para turmas semipresenciais ou de Educação a Distância (EAD)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_d', 'Número de Matrículas da Educação Profissional - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_dm', 'Número de Matrículas da Educação Profissional - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_dv', 'Número de Matrículas da Educação Profissional - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_n', 'Número de Matrículas da Educação Profissional - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_ead', 'Número de Matrículas da Educação Profissional - Turno não aplicável para turmas semipresenciais ou de Educação a Distância (EAD)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec_d', 'Número de Matrículas da Educação Profissional Técnica - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec_dm', 'Número de Matrículas da Educação Profissional Técnica - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec_dv', 'Número de Matrículas da Educação Profissional Técnica - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec_n', 'Número de Matrículas da Educação Profissional Técnica - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec_ead', 'Número de Matrículas da Educação Profissional Técnica - Turno não aplicável para turmas semipresenciais ou de Educação a Distância (EAD)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_d', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_dm', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_dv', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_n', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_ead', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Turno não aplicável para turmas semipresenciais ou de Educação a Distância (EAD)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_d', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_dm', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_dv', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_n', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_ead', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Turno não aplicável para turmas semipresenciais ou de Educação a Distância (EAD)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_med_d', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Médio - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_med_dm', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Médio - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_med_dv', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Médio - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_med_n', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Médio - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_med_ead', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Médio - Turno não aplicável para turmas semipresenciais ou de Educação a Distância (EAD)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_d', 'Número de Matrículas da Educação Especial - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_dm', 'Número de Matrículas da Educação Especial - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_dv', 'Número de Matrículas da Educação Especial - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_n', 'Número de Matrículas da Educação Especial - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ead', 'Número de Matrículas da Educação Especial - Turno não aplicável para turmas semipresenciais ou de Educação a Distância (EAD)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_d', 'Número de Matrículas da Educação Especial em Classes Comuns - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_dm', 'Número de Matrículas da Educação Especial em Classes Comuns - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_dv', 'Número de Matrículas da Educação Especial em Classes Comuns - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_n', 'Número de Matrículas da Educação Especial em Classes Comuns - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_ead', 'Número de Matrículas da Educação Especial em Classes Comuns - Turno não aplicável para turmas semipresenciais ou de Educação a Distância (EAD)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_d', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Turno Diurno', NULL::jsonb, 2007, NULL, NULL, 'Diurno - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_dm', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Turno Diurno - Matutino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Matutino - Quando a maior parte das atividades da turma são realizadas no período entre 6h e 11:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_dv', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Turno Diurno - Vespertino', NULL::jsonb, 2007, NULL, NULL, 'Diurno Vespertino - Quando a maior parte das atividades da turma são realizadas no período entre 12h e 17:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_n', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Turno Noturno', NULL::jsonb, 2007, NULL, NULL, 'Noturno - quando a maior parte das atividades da turma são realizadas entre 18h e 5:59h.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_ead', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Turno não aplicável para turmas semipresenciais ou de Educação a Distância (EAD)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_int', 'Número de Matrículas da Educação Básica - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_int', 'Número de Matrículas da Educação Infantil - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Considera-se em tempo integral, o tempo de permanência semanal do aluno na turma de escolarização presencial (minutos/semana) maior ou igual a 35 horas semanais, e os que estão em turmas de escolarização presenciais com carga horária menor que 35 horas semanais, mas que somado ao tempo de permanência semanal em turmas de atividade complementar (mesma rede ou outra rede), de atendimento educacional especializado (mesma rede ou outra rede) e em turmas exclusivas de itinerário formativo (mesma rede ou outra rede), atinja as 35 horas ou mais.
Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_cre_int', 'Número de Matrículas da Educação Infantil - Creche - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_inf_pre_int', 'Número de Matrículas da Educação Infantil - Pré-Escola - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_int', 'Número de Matrículas do Ensino Fundamental - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_ai_int', 'Número de Matrículas do Ensino Fundamental - Anos Iniciais - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_fund_af_int', 'Número de Matrículas do Ensino Fundamental - Anos Finais - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_med_int', 'Número de Matrículas do Ensino Médio - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_int', 'Número de Matrículas da Educação Profissional - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec_int', 'Número de Matrículas da Educação Profissional Técnica - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_int', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_fund_int', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_eja_med_int', 'Número de Matrículas da Educação de Jovens e Adultos (EJA) - Ensino Médio - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_int', 'Número de Matrículas da Educação Especial - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_cc_int', 'Número de Matrículas da Educação Especial em Classes Comuns - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_esp_ce_int', 'Número de Matrículas da Educação Especial em Classes Exclusivas - Tempo Integral', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_bas_libras', 'Número de Matrículas da Educação Básica - Classe bilíngue de surdos tendo a Libras (Língua Brasileira de Sinais) como língua de instrução, ensino, comunicação e interação e a língua portuguesa escrita como segunda língua', NULL::jsonb, 2022, NULL, NULL, 'Coletada (INEP): 2022-2025'),
  ('clean.censo_matriculas', 'qt_mat_zr_urb', 'Número de Matrículas da Educação Básica - Localização/Zona de residência do Aluno - Urbana', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_zr_rur', 'Número de Matrículas da Educação Básica - Localização/Zona de residência do Aluno - Rural', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_mat_zr_na', 'Número de Matrículas da Educação Básica - Localização/Zona de residência do Aluno - Não aplicável para alunos residentes no exterior', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_transp_publico', 'Número de Matrículas da Educação Básica de alunos que utilizam transporte escolar público', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_transp_resp_est', 'Número de Matrículas da Educação Básica segundo o poder público responsável pelo transporte escolar - Estadual', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_matriculas', 'qt_transp_resp_mun', 'Número de Matrículas da Educação Básica segundo o poder público responsável pelo transporte escolar - Municipal', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'nu_ano_censo', 'Ano do Censo', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'co_entidade', 'Código da Escola', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas', 'Número de Docentes da Educação Básica', NULL::jsonb, 2007, NULL, NULL, 'Docentes referem-se aos indivíduos que estavam em efetiva regência de classe na data de referência do Censo Escolar da Educação Básica, incluindo somente o Docente em sala de aula presencial e o Docente Titular - coordenador de tutoria (de módulo ou disciplina) - EAD
Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_inf', 'Número de Docentes da Educação Infantil', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_inf_cre', 'Número de Docentes da Educação Infantil - Creche', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_inf_pre', 'Número de Docentes da Educação Infantil - Pré-Escola', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund', 'Número de Docentes do Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_ai', 'Número de Docentes do Ensino Fundamental - Anos Iniciais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_ai_1', 'Número de Docentes do Ensino Fundamental - Anos Iniciais - 1º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_ai_2', 'Número de Docentes do Ensino Fundamental - Anos Iniciais - 2º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_ai_3', 'Número de Docentes do Ensino Fundamental - Anos Iniciais - 3º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_ai_4', 'Número de Docentes do Ensino Fundamental - Anos Iniciais - 4º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_ai_5', 'Número de Docentes do Ensino Fundamental - Anos Iniciais - 5º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_ai_multietapa', 'Número de Docentes do Ensino Fundamental - Educação Infantil e Ensino Fundamental Multietapa', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_af', 'Número de Docentes do Ensino Fundamental - Anos Finais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_af_6', 'Número de Docentes do Ensino Fundamental - Anos Finais - 6º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_af_7', 'Número de Docentes do Ensino Fundamental - Anos Finais - 7º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_af_8', 'Número de Docentes do Ensino Fundamental - Anos Finais - 8º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_af_9', 'Número de Docentes do Ensino Fundamental - Anos Finais - 9º Ano', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_af_multi', 'Número de Docentes do Ensino Fundamental - Multi', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_fund_af_corrfluxo', 'Número de Docentes do Ensino Fundamental - Correção de Fluxo', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med', 'Número de Docentes do Ensino Médio Regular', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_prop', 'Número de Docentes do Ensino Médio Regular - Propedêutico', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_prop_1', 'Número de Docentes do Ensino Médio Regular - Propedêutico - 1º ano/1ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_prop_2', 'Número de Docentes do Ensino Médio Regular - Propedêutico - 2º ano/2ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_prop_3', 'Número de Docentes do Ensino Médio Regular - Propedêutico - 3º ano/3ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_prop_4', 'Número de Docentes do Ensino Médio Regular - Propedêutico - 4º ano/4ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_prop_ns', 'Número de Docentes do Ensino Médio Regular - Propedêutico - Não Seriado', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_ct', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_ct_1', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico - 1º ano/1ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_ct_2', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico - 2º ano/2ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_ct_3', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico - 3º ano/3ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_ct_4', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico - 4º ano/4ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_ct_ns', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Curso Técnico - Não Seriado', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_qp', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_qp_1', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional - 1º ano/1ª Série', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_qp_2', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional - 2º ano/2ª Série', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_qp_3', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional - 3º ano/3ª Série', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_qp_4', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional - 4º ano/4ª Série', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_docentes', 'qt_doc_med_iftp_qp_ns', 'Número de Docentes do Ensino Médio Regular - Ensino Médio Regular articulado ao Itinerário Formativo Técnico Profissional (IFTP) - Qualificação Profissional - Não Seriado', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_docentes', 'qt_doc_med_nm', 'Número de Docentes do Ensino Médio Regular - Modalidade Normal/Magistério', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_nm_1', 'Número de Docentes do Ensino Médio Regular - Modalidade Normal/Magistério - 1º ano/1ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_nm_2', 'Número de Docentes do Ensino Médio Regular - Modalidade Normal/Magistério - 2º ano/2ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_nm_3', 'Número de Docentes do Ensino Médio Regular - Modalidade Normal/Magistério - 3º ano/3ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_med_nm_4', 'Número de Docentes do Ensino Médio Regular - Modalidade Normal/Magistério - 4º ano/4ª Série', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_prof', 'Número de Docentes da Educação Profissional', NULL::jsonb, 2007, NULL, NULL, 'Modo profissionalizante de ensino correspondente às turmas de cursos técnicos de nível médio nas formas articuladas (integrada ou concomitante), ou subsequente ao ensino médio e de normal/magistério, e as turmas de cursos profissionalizantes não-técnicos. Inclui as seguintes etapas de ensino: Ensino Médio articulado ao Itinerário Formativo Técnico Profissional - Curso Técnico, Ensino Médio Normal/Magistério, Curso Técnico Concomitante, Curso Técnico Subsequente, Curso Técnico Misto (Concomitante e Subsequente), Curso Técnico Integrado à EJA de Nível Médio, Itinerário Formativo Técnico Profissional Exclusivo - Curso Técnico (não articulado ao ensino médio regular), Curso FIC Concomitante, Curso FIC Integrado à EJA de Nível Fundamental, Curso FIC Integrado à EJA de Nível Médio, Ensino Médio articulado ao Itinerário Formativo Técnico Profissional - Qualificação Profissional e Itinerário Formativo Técnico Profissional Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular).
Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_prof_tec', 'Número de Docentes da Educação Profissional Técnica', NULL::jsonb, 2007, NULL, NULL, 'Modo profissionalizante de ensino correspondente às turmas de cursos técnicos de nível médio nas formas articuladas (integrada ou concomitante), ou subsequente ao ensino médio e de normal/magistério. Inclui as seguintes etapas de ensino: Ensino Médio articulado ao Itinerário Formativo Técnico Profissional - Curso Técnico, Ensino Médio Normal/Magistério, Curso Técnico Concomitante, Curso Técnico Subsequente, Curso Técnico Misto (Concomitante e Subsequente), Curso Técnico Integrado à EJA de Nível Médio, Itinerário Formativo Técnico Profissional Exclusivo - Curso Técnico (não articulado ao ensino médio regular).
Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_prof_tec_conc', 'Número de Docentes da Educação Profissional Técnica - Curso Técnico Concomitante', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_prof_tec_subs', 'Número de Docentes da Educação Profissional Técnica - Curso Técnico Subsequente', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_prof_tec_misto', 'Número de Docentes da Educação Profissional Técnica - Curso Técnico Misto (Concomitante e Subsequente)', NULL::jsonb, 2010, NULL, NULL, 'Coletada (INEP): 2010-2025'),
  ('clean.censo_docentes', 'qt_doc_prof_tec_iftp_ct', 'Número de Docentes da Educação Profissional Técnica - Itinerário Formativo Técnico Profissional (IFTP) Exclusivo - Curso Técnico (não articulado ao ensino médio regular)', NULL::jsonb, 2025, NULL, NULL, 'Coletada (INEP): 2025'),
  ('clean.censo_docentes', 'qt_doc_prof_nao_tec', 'Número de Docentes da Educação Profissional Não-Técnica', NULL::jsonb, 2007, NULL, NULL, 'A Educação Profissional Não -Técnica inclui as seguintes etapas de ensino: Curso FIC Concomitante, Curso FIC Integrado à EJA de Nível Fundamental, Curso FIC Integrado à EJA de Nível Médio, Ensino Médio articulado ao Itinerário Formativo Técnico Profissional - Qualificação Profissional e Itinerário Formativo Técnico Profissional Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular).
Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_prof_iftp_qp', 'Número de Docentes da Educação Profissional - Itinerário Formativo Técnico Profissional (IFTP) Exclusivo - Qualificação Profissional (não articulado ao ensino médio regular)', NULL::jsonb, 2025, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2025'),
  ('clean.censo_docentes', 'qt_doc_prof_fic_conc', 'Número de Docentes da Educação Profissional - Curso FIC Concomitante', NULL::jsonb, 2015, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2015-2025'),
  ('clean.censo_docentes', 'qt_doc_eja', 'Número de Docentes da Educação de Jovens e Adultos (EJA)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_eja_fund', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_eja_fund_nprof', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Sem componente profissionalizante', NULL::jsonb, 2007, NULL, NULL, 'Não inclui turmas do Curso FIC Integrado na Modalidade EJA de Nível Fundamental
Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_eja_fund_ai', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Anos Iniciais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_eja_fund_af', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Anos Finais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_eja_fund_pj', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Projovem Urbano', NULL::jsonb, 2012, 2018, NULL, 'Coletada (INEP): 2012-2018'),
  ('clean.censo_docentes', 'qt_doc_eja_fund_aiaf', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Anos Iniciais e Anos Finais', NULL::jsonb, 2007, 2007, 2016, 'Categoria de etapa de ensino existente na base de matrículas apenas em 2007. De 2008 a 2015 os alunos de turmas da EJA Anos iniciais e Anos finais, foram registrados separadamente como EJA anos iniciais ou EJA anos finais do Ensino Fundamental.
Coletada (INEP): 2007'),
  ('clean.censo_docentes', 'qt_doc_eja_fund_fic', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Fundamental - Curso FIC Integrado na Modalidade EJA de Nível Fundamental', NULL::jsonb, 2008, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2008-2025'),
  ('clean.censo_docentes', 'qt_doc_eja_med', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Médio', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_eja_med_nprof', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Médio - Sem componente profissionalizante', NULL::jsonb, 2007, NULL, NULL, 'Não inclui turmas do Curso FIC Integrado na Modalidade EJA de Nível Médio e do Curso Técnico Integrado na Modalidade EJA de Nível Médio
Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_eja_med_fic', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Médio - Curso FIC Integrado na Modalidade EJA de Nível Médio', NULL::jsonb, 2015, NULL, NULL, 'Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2015-2025'),
  ('clean.censo_docentes', 'qt_doc_eja_med_tec', 'Número de Docentes da Educação de Jovens e Adultos (EJA) - Ensino Médio - Curso Técnico Integrado na Modalidade EJA de Nível Médio', NULL::jsonb, 2007, NULL, NULL, 'Categoria (INEP): Deve ser considerada também como uma etapa Profissional Técnica
Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_esp', 'Número de Docentes da Educação Especial', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_esp_cc', 'Número de Docentes da Educação Especial em Classes Comuns', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_esp_ce', 'Número de Docentes da Educação Especial em Classes Exclusivas', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_fem', 'Número de Docentes da Educação Básica - Feminino', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_masc', 'Número de Docentes da Educação Básica - Masculino', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_nd', 'Número de Docentes da Educação Básica - Cor/Raça Não Declarada', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_branca', 'Número de Docentes da Educação Básica - Cor/Raça Branca', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_preta', 'Número de Docentes da Educação Básica - Cor/Raça Preta', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_parda', 'Número de Docentes da Educação Básica - Cor/Raça Parda', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_amarela', 'Número de Docentes da Educação Básica - Cor/Raça Amarela', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_indigena', 'Número de Docentes da Educação Básica - Cor/Raça Indígena', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_0_24', 'Número de Docentes da Educação Básica - Até 24 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Faixa etária calculada com base na idade do aluno na data de referência do Censo Escolar (última quarta-feira do mês de maio)
Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_25_29', 'Número de Docentes da Educação Básica - Entre 25 e 29 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_30_39', 'Número de Docentes da Educação Básica - Entre 30 e 39 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_40_49', 'Número de Docentes da Educação Básica - Entre 40 e 49 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_50_54', 'Número de Docentes da Educação Básica - Entre 50 e 54 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_55_59', 'Número de Docentes da Educação Básica - Entre 55 e 59 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_60_mais', 'Número de Docentes da Educação Básica - Com 60 ou mais anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_pcd', 'Número de Docentes da Educação Básica com alguma deficiência, transtorno do espectro autista (TEA) ou superdotação', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_zr_urb', 'Número de Docentes da Educação Básica - Localização/Zona de residência do Docente - Urbana', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_zr_rur', 'Número de Docentes da Educação Básica - Localização/Zona de residência do Docente - Rural', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_zr_na', 'Número de Docentes da Educação Básica - Localização/Zona de residência do Docente - Não aplicável para Docentes residentes no exterior', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_esco_ef', 'Número de Docentes da Educação Básica - Maior nível de Escolaridade concluída - Ensino Fundamental', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_esco_em', 'Número de Docentes da Educação Básica - Maior nível de Escolaridade concluída - Ensino Médio', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_esco_sup_grad', 'Número de Docentes da Educação Básica - Maior nível de Escolaridade concluída - Educação Superior (Graduação)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_esco_sup_grad_licen', 'Número de Docentes da Educação Básica - Número de Docentes da Educação Básica - Maior nível de Escolaridade concluída - Educação Superior Licenciatura', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_esco_sup_grad_slicen', 'Número de Docentes da Educação Básica - Número de Docentes da Educação Básica - Maior nível de Escolaridade concluída - Educação Superior Sem Licenciatura', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_esco_sup_pos_espec', 'Número de Docentes da Educação Básica - Pós-Graduação concluída - Especialização', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_esco_sup_pos_mestra', 'Número de Docentes da Educação Básica - Pós-Graduação concluída - Mestrado', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_esco_sup_pos_douto', 'Número de Docentes da Educação Básica - Pós-Graduação concluída - Doutorado', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_esco_sup_pos_nenhum', 'Número de Docentes da Educação Básica - Pós-Graduação concluída - Não tem pós-graduação concluída', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_vinculo_concur', 'Número de Docentes da Educação Básica - Situação Funcional/Regime de contratação/Tipo de Vínculo (Apenas para docente de escola pública) - Concursado/efetivo/estável', NULL::jsonb, 2011, NULL, NULL, 'Coletada (INEP): 2011-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_vinculo_contra', 'Número de Docentes da Educação Básica - Situação Funcional/Regime de contratação/Tipo de Vínculo (Apenas para docente de escola pública) - Contrato temporário', NULL::jsonb, 2011, NULL, NULL, 'Coletada (INEP): 2011-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_vinculo_terceir', 'Número de Docentes da Educação Básica - Situação Funcional/Regime de contratação/Tipo de Vínculo (Apenas para docente de escola pública) - Contrato terceirizado', NULL::jsonb, 2011, NULL, NULL, 'Coletada (INEP): 2011-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_vinculo_clt', 'Número de Docentes da Educação Básica - Situação Funcional/Regime de contratação/Tipo de Vínculo (Apenas para docente de escola pública) - Contrato CLT', NULL::jsonb, 2011, NULL, NULL, 'Coletada (INEP): 2011-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_docente', 'Número de Docentes da Educação Básica - Função que o Profissional Exerce em Sala de Aula - Docente', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_auxiliar', 'Número de Docentes da Educação Básica - Função que o Profissional Exerce em Sala de Aula - Auxiliar/Assistente Educacional', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_profi_monitor', 'Número de Docentes da Educação Básica - Função que o Profissional Exerce em Sala de Aula - Profissional/Monitor de atividade complementar', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_tradutor_libras', 'Número de Docentes da Educação Básica - Função que o Profissional Exerce em Sala de Aula - Tradutor Intérprete de Libras', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_titular_ead', 'Número de Docentes da Educação Básica - Função que o Profissional Exerce em Sala de Aula - Docente Titular - coordenador de tutoria (de módulo ou disciplina) - EAD', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_tutor_aux_ead', 'Número de Docentes da Educação Básica - Função que o Profissional Exerce em Sala de Aula - Docente Tutor - Auxiliar (de módulo ou disciplina) - EAD', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_guia_interprete', 'Número de Docentes da Educação Básica - Função que o Profissional Exerce em Sala de Aula - Guia intérprete', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_apoio_pcd', 'Número de Docentes da Educação Básica - Função que o Profissional Exerce em Sala de Aula - Profissional de apoio escolar para alunos com deficiência (Lei 13.146/2015)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_instrutor_ep', 'Número de Docentes da Educação Básica - Função que o Profissional Exerce em Sala de Aula - Instrutor de educação profissional', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_cre', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para creche (0 a 3 anos)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_pre_escola', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para pré-escola (4 e 5 anos)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_anos_iniciais', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para anos iniciais do ensino fundamental', NULL::jsonb, 2011, NULL, NULL, 'Coletada (INEP): 2011-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_anos_finais', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para anos finais do ensino fundamental', NULL::jsonb, 2011, NULL, NULL, 'Coletada (INEP): 2011-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_ens_medio', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para ensino médio', NULL::jsonb, 2011, NULL, NULL, 'Coletada (INEP): 2011-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_eja', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para educação de jovens e adultos', NULL::jsonb, 2011, NULL, NULL, 'Coletada (INEP): 2011-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_ed_especial', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para educação especial', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_bil_surdos', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação bilíngue de surdos', NULL::jsonb, 2007, 2022, NULL, 'Coletada (INEP): 2007-2022'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_ed_indigena', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para educação indígena', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_campo', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação do Campo', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_ambiental', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação Ambiental', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_dir_humanos', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação em direitos humanos', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_div_sexual', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Gênero e Diversidade Sexual', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_dir_adolesc', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Direitos de criança e adolescente', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_afro', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação para as relações étnico-raciais e história e cultura afro-brasileira e africana', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_gestao', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Gestão escolar', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_educ_tic', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação e Tecnologia de Informação e Comunicação (TIC)', NULL::jsonb, 2023, NULL, NULL, 'Coletada (INEP): 2023-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_outros', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Outros', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_espec_nenhum', 'Número de Docentes da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Nenhum', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_lingua_port', 'Número de Docentes da Educação Básica - Disciplina que atua - Áreas do conhecimento/Componentes curriculares - Língua/ Literatura Portuguesa', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_educ_fisica', 'Número de Docentes da Educação Básica - Disciplina que atua - Áreas do conhecimento/Componentes curriculares - Educação Física', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_artes', 'Número de Docentes da Educação Básica - Disciplina que atua - Áreas do conhecimento/Componentes curriculares - Artes (Educação Artística, Teatro, Dança, Música, Artes Plásticas e outras)', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_lingua_ing', 'Número de Docentes da Educação Básica - Disciplina que atua - Áreas do conhecimento/Componentes curriculares - Língua/ Literatura estrangeira - Inglês', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_lingua_espa', 'Número de Docentes da Educação Básica - Disciplina que atua - Áreas do conhecimento/Componentes curriculares - Língua/ Literatura estrangeira - Espanhol', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_lingua_franc', 'Número de Docentes da Educação Básica - Disciplina que atua - Áreas do conhecimento/Componentes curriculares - Língua/ Literatura estrangeira - Francês', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_lingua_outra', 'Número de Docentes da Educação Básica - Disciplina que atua - Áreas do conhecimento/Componentes curriculares - Língua/ Literatura estrangeira - Outra', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_libras', 'Número de Docentes da Educação Básica - Disciplina que atua - Áreas do conhecimento/Componentes curriculares - Libras', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_lingua_indig', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Língua Indígena', NULL::jsonb, 2009, NULL, NULL, 'Coletada (INEP): 2009-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_port_seg_lingua', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Língua Portuguesa como segunda língua', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_matematica', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Matemática', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_ciencias', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Ciências', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_fisica', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Física', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_quimica', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Química', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_biologia', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Biologia', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_historia', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - História', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_geografia', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Geografia', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_sociologia', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Sociologia', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_filosofia', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Filosofia', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_est_sociais', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Estudos Sociais', NULL::jsonb, 2012, NULL, NULL, 'Coletada (INEP): 2012-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_est_sociais_soci', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Estudos Sociais ou Sociologia', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_info_computacao', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Informática / Computação', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_ensino_religioso', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Ensino Religioso', NULL::jsonb, 2009, NULL, NULL, 'Coletada (INEP): 2009-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_profissiona', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Disciplinas dos cursos técnicos profissionais', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_estagio_super', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Estágio curricular supervisionado', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_pedagogicas', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Disciplinas pedagógicas', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_projeto_de_vida', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Projeto de vida', NULL::jsonb, 2022, NULL, NULL, 'Coletada (INEP): 2022-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_disc_outras', 'Número de Docentes da Educação Básica - Disciplina que atua - /Componentes curriculares - Outras disciplinas', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_docentes', 'qt_doc_bas_libras', 'Número de Docentes da Educação Básica - Classe bilíngue de surdos tendo a Libras (Língua Brasileira de Sinais) como língua de instrução, ensino, comunicação e interação e a língua portuguesa escrita como segunda língua', NULL::jsonb, 2007, NULL, NULL, 'Coletada (INEP): 2007-2025'),
  ('clean.censo_gestor', 'nu_ano_censo', 'Ano do Censo', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'co_entidade', 'Código da Escola', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas', 'Número de Gestores Escolares da Educação Básica', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_fem', 'Número de Gestores Escolares da Educação Básica - Feminino', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_masc', 'Número de Gestores Escolares da Educação Básica - Masculino', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_nd', 'Número de Gestores Escolares da Educação Básica - Cor/Raça Não Declarada', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_branca', 'Número de Gestores Escolares da Educação Básica - Cor/Raça Branca', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_preta', 'Número de Gestores Escolares da Educação Básica - Cor/Raça Preta', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_parda', 'Número de Gestores Escolares da Educação Básica - Cor/Raça Parda', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_amarela', 'Número de Gestores Escolares da Educação Básica - Cor/Raça Amarela', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_indigena', 'Número de Gestores Escolares da Educação Básica - Cor/Raça Indígena', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_nacio_brasileira', 'Número de Gestores Escolares da Educação Básica - Nacionalidade - Brasileira', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_nacio_estrang', 'Número de Gestores Escolares da Educação Básica - Nacionalidade - Estrangeira', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_0_24', 'Número de Gestores Escolares da Educação Básica - Até 24 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2019, NULL, NULL, 'Faixa etária calculada com base na idade do aluno na data de referência do Censo Escolar (última quarta-feira do mês de maio)
Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_25_29', 'Número de Gestores Escolares da Educação Básica - Entre 25 e 29 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_30_39', 'Número de Gestores Escolares da Educação Básica - Entre 30 e 39 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_40_49', 'Número de Gestores Escolares da Educação Básica - Entre 40 e 49 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_50_54', 'Número de Gestores Escolares da Educação Básica - Entre 50 e 54 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_55_59', 'Número de Gestores Escolares da Educação Básica - Entre 55 e 59 anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_60_mais', 'Número de Gestores Escolares da Educação Básica - Com 60 ou mais anos de idade na data de referência do Censo Escolar (última quarta-feira do mês de maio de 2025)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_pcd', 'Número de Gestores Escolares da Educação Básica com alguma deficiência, transtorno do espectro autista (TEA) ou superdotação', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_zr_urb', 'Número de Gestores Escolares da Educação Básica - Localização/Zona de residência do Gestor Escolar - Urbana', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_zr_rur', 'Número de Gestores Escolares da Educação Básica - Localização/Zona de residência do Gestor Escolar - Rural', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_zr_na', 'Número de Gestores Escolares da Educação Básica - Localização/Zona de residência do Gestor Escolar - Não aplicável para Gestores Escolares residentes no exterior', NULL::jsonb, 2025, NULL, NULL, 'Coletada (INEP): 2025'),
  ('clean.censo_gestor', 'qt_gest_bas_esco_ef', 'Número de Gestores Escolares da Educação Básica - Maior nível de Escolaridade concluída - Ensino Fundamental', NULL::jsonb, 2025, NULL, NULL, 'Coletada (INEP): 2025'),
  ('clean.censo_gestor', 'qt_gest_bas_esco_em', 'Número de Gestores Escolares da Educação Básica - Maior nível de Escolaridade concluída - Ensino Médio', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_esco_sup_grad', 'Número de Gestores Escolares da Educação Básica - Maior nível de Escolaridade concluída - Educação Superior (Graduação)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_esco_sup_grad_licen', 'Número de Gestores Escolares da Educação Básica - Número de Gestores Escolares da Educação Básica - Maior nível de Escolaridade concluída - Educação Superior Licenciatura', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_esco_sup_grad_slicen', 'Número de Gestores Escolares da Educação Básica - Número de Gestores Escolares da Educação Básica - Maior nível de Escolaridade concluída - Educação Superior Sem Licenciatura', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_esco_sup_pos_espec', 'Número de Gestores Escolares da Educação Básica - Pós-Graduação concluída - Especialização', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_esco_sup_pos_mestra', 'Número de Gestores Escolares da Educação Básica - Pós-Graduação concluída - Mestrado', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_esco_sup_pos_douto', 'Número de Gestores Escolares da Educação Básica - Pós-Graduação concluída - Doutorado', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_esco_sup_pos_nenhum', 'Número de Gestores Escolares da Educação Básica - Pós-Graduação concluída - Não tem pós-graduação concluída', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_vinculo_concur', 'Número de Gestores Escolares da Educação Básica - Situação Funcional/Regime de contratação/Tipo de Vínculo (Só é aplicável para o cargo de diretor nas escolas públicas) - Concursado/efetivo/estável', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_vinculo_contra', 'Número de Gestores Escolares da Educação Básica - Situação Funcional/Regime de contratação/Tipo de Vínculo (Só é aplicável para o cargo de diretor nas escolas públicas) - Contrato temporário', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_vinculo_terceir', 'Número de Gestores Escolares da Educação Básica - Situação Funcional/Regime de contratação/Tipo de Vínculo (Só é aplicável para o cargo de diretor nas escolas públicas) - Contrato terceirizado', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_vinculo_clt', 'Número de Gestores Escolares da Educação Básica - Situação Funcional/Regime de contratação/Tipo de Vínculo (Só é aplicável para o cargo de diretor nas escolas públicas) - Contrato CLT', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_diretor', 'Número de Gestores Escolares da Educação Básica - Cargo do gestor escolar - Diretor', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_outro', 'Número de Gestores Escolares da Educação Básica - Cargo do gestor escolar - Outro Cargo', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_acesso_cargo_prop', 'Número de Gestores Escolares da Educação Básica - Critério de acesso ao cargo/função - Ser proprietário ou sócio-proprietário da escola (exclusivo para escola privada)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_acesso_cargo_indic', 'Número de Gestores Escolares da Educação Básica - Critério de acesso ao cargo/função - Exclusivamente por indicação/escolha da gestão', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_acesso_cargo_sel', 'Número de Gestores Escolares da Educação Básica - Critério de acesso ao cargo/função - Processo seletivo qualificado e escolha/nomeação da gestão', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_acesso_cargo_conc', 'Número de Gestores Escolares da Educação Básica - Critério de acesso ao cargo/função - Concurso público específico para o cargo de gestor escolar (exclusivo para escola pública)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_acesso_cargo_eleic', 'Número de Gestores Escolares da Educação Básica - Critério de acesso ao cargo/função - Exclusivamente por processo eleitoral com a participação da comunidade escolar (exclusivo para escola pública)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_acesso_cargo_p_sel', 'Número de Gestores Escolares da Educação Básica - Critério de acesso ao cargo/função - Processo seletivo qualificado e eleição com participação da comunidade escolar (exclusivo para escola pública)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_acesso_cargo_outro', 'Número de Gestores Escolares da Educação Básica - Critério de acesso ao cargo/função - Outro', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_cre', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para creche (0 a 3 anos)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_pre_escola', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para pré-escola (4 e 5 anos)', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_anos_iniciais', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para anos iniciais do ensino fundamental', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_anos_finais', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para anos finais do ensino fundamental', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_ens_medio', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para ensino médio', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_eja', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para educação de jovens e adultos', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_ed_especial', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para educação especial', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_bil_surdos', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação bilíngue de surdos', NULL::jsonb, 2023, NULL, NULL, 'Coletada (INEP): 2023-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_ed_indigena', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Específico para educação indígena', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_campo', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação do Campo', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_ambiental', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação Ambiental', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_dir_humanos', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação em direitos humanos', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_div_sexual', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Gênero e Diversidade Sexual', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_dir_adolesc', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Direitos de criança e adolescente', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_afro', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação para as relações étnico-raciais e história e cultura afro-brasileira e africana', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_gestao', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Gestão escolar', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_educ_tic', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Educação e Tecnologia de Informação e Comunicação (TIC)', NULL::jsonb, 2023, NULL, NULL, 'Coletada (INEP): 2023-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_outros', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Outros', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_espec_nenhum', 'Número de Gestores Escolares da Educação Básica - Outros cursos - Formação Continuada com no mínimo 80 horas - Nenhum', NULL::jsonb, 2019, NULL, NULL, 'Coletada (INEP): 2019-2025'),
  ('clean.censo_docentes', 'qt_doc_prof_fic_con', 'Número de Docentes da Educação Profissional - Curso FIC Concomitante', NULL::jsonb, 2015, NULL, NULL, 'Nome oficial no INEP: QT_DOC_PROF_FIC_CONC (a coluna do EduMaps tem nome diferente).
Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2015-2025'),
  ('clean.censo_docentes', 'qt_doc_prof_tec_con', 'Número de Docentes da Educação Profissional Técnica - Curso Técnico Concomitante', NULL::jsonb, 2007, NULL, NULL, 'Nome oficial no INEP: QT_DOC_PROF_TEC_CONC (a coluna do EduMaps tem nome diferente).
Coletada (INEP): 2007-2025'),
  ('clean.censo_gestor', 'qt_gest_bas_acesso_cargo_conca', 'Número de Gestores Escolares da Educação Básica - Critério de acesso ao cargo/função - Concurso público específico para o cargo de gestor escolar (exclusivo para escola pública)', NULL::jsonb, 2019, NULL, NULL, 'Nome oficial no INEP: QT_GEST_BAS_ACESSO_CARGO_CONC (a coluna do EduMaps tem nome diferente).
Coletada (INEP): 2019-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_fic_con', 'Número de Matrículas da Educação Profissional - Curso FIC Concomitante', NULL::jsonb, 2015, NULL, NULL, 'Nome oficial no INEP: QT_MAT_PROF_FIC_CONC (a coluna do EduMaps tem nome diferente).
Categoria (INEP): Educação Profissional Não-Técnica
Coletada (INEP): 2015-2025'),
  ('clean.censo_matriculas', 'qt_mat_prof_tec_con', 'Número de Matrículas da Educação Profissional Técnica - Curso Técnico Concomitante', NULL::jsonb, 2007, NULL, NULL, 'Nome oficial no INEP: QT_MAT_PROF_TEC_CONC (a coluna do EduMaps tem nome diferente).
Coletada (INEP): 2007-2025');

UPDATE clean.censo_data_dictionary d
SET description     = c.description,
    value_domain    = c.value_domain,
    year_introduced = coalesce(c.year_introduced, d.year_introduced),
    year_deprecated = c.year_deprecated,
    year_changed    = c.year_changed,
    notes           = c.notes,
    origem          = 'inep',
    source_file     = 'data_pipeline/dicionarios/censo_inep_variaveis.csv',
    source_url      = 'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar',
    source_license  = 'Material de referência público do INEP (dados abertos)',
    retrieved_at    = '2026-05-08T18:25:13Z',  -- anexo entrou no Zotero (10296)
    updated_at      = now()
FROM censo_inep_carga c
WHERE d.table_name = c.table_name
  AND d.column_name = c.column_name;

-- Sem correspondência no INEP: coluna do EduMaps.
UPDATE clean.censo_data_dictionary d
SET origem       = 'derivada',
    value_domain = NULL,
    notes        = coalesce(x.nota, 'Coluna criada pelo EduMaps; sem correspondência no Dicionário de Variáveis do INEP.'),
    updated_at   = now()
FROM clean.censo_data_dictionary d2
LEFT JOIN (VALUES
  ('cluster_id', 'Agrupamento calculado pela análise do EduMaps (edumapsr).'),
  ('geometry', 'Ponto (EPSG:4674) construído pelo EduMaps a partir de LATITUDE/LONGITUDE.'),
  ('linha_id', 'Chave substituta do EduMaps: número da linha no arquivo de origem.'),
  ('nro_etapas', 'Contagem de etapas de ensino ofertadas, calculada pelo EduMaps.'),
  ('nro_participacoes_exame', 'Contagem de participações em exames, calculada pelo EduMaps.')
) AS x(coluna, nota) ON x.coluna = d2.column_name
WHERE d.table_name = d2.table_name
  AND d.column_name = d2.column_name
  AND d.year_introduced = d2.year_introduced
  AND d.table_name IN ('clean.censo_escolas', 'clean.censo_matriculas',
                       'clean.censo_docentes', 'clean.censo_gestor')
  AND NOT EXISTS (
      SELECT 1 FROM censo_inep_carga c
      WHERE c.table_name = d.table_name AND c.column_name = d.column_name
  );

-- -----------------------------------------------------------------
-- Violações do dicionário nas 4 tabelas do Censo
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION clean.censo_dict_violacoes()
RETURNS TABLE (tipo text, tabela text, coluna text, valor text, n bigint)
LANGUAGE plpgsql STABLE
SET search_path = pg_catalog, pg_temp
AS $fn$
DECLARE
    t      text;
    cols   text;
    alvo   regclass;
BEGIN
    -- 1) Coluna real sem linha no dicionário.
    RETURN QUERY
    SELECT 'coluna_sem_dicionario'::text, 'clean.' || cl.relname::text, a.attname::text,
           NULL::text, NULL::bigint
    FROM pg_attribute a
    JOIN pg_class cl ON cl.oid = a.attrelid
    JOIN pg_namespace ns ON ns.oid = cl.relnamespace
    WHERE ns.nspname = 'clean'
      AND cl.relname IN ('censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor')
      AND a.attnum > 0 AND NOT a.attisdropped
      AND NOT EXISTS (
          SELECT 1 FROM clean.censo_data_dictionary d
          WHERE d.table_name = 'clean.' || cl.relname AND d.column_name = a.attname
      )
    ORDER BY 2, 3;

    -- 2) Valores fora do domínio. Uma varredura por tabela: as colunas
    --    codificadas viram pares (coluna, valor::text) e só os distintos são
    --    comparados com o domínio. in_* sem domínio → {0,1}.
    FOREACH t IN ARRAY ARRAY['censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor'] LOOP
        alvo := to_regclass(format('clean.%I', t));
        CONTINUE WHEN alvo IS NULL;

        SELECT string_agg(format('(%L, x.%I::text)', a.attname, a.attname), ', ' ORDER BY a.attnum)
        INTO cols
        FROM pg_attribute a
        WHERE a.attrelid = alvo AND a.attnum > 0 AND NOT a.attisdropped
          AND (a.attname LIKE 'in\_%' OR EXISTS (
                SELECT 1 FROM clean.censo_data_dictionary d
                WHERE d.table_name = 'clean.' || t AND d.column_name = a.attname
                  AND d.value_domain IS NOT NULL));
        CONTINUE WHEN cols IS NULL;

        RETURN QUERY EXECUTE format($q$
            WITH valores AS (
                SELECT v.coluna, v.valor, count(*) AS n
                FROM %s x
                CROSS JOIN LATERAL (VALUES %s) AS v(coluna, valor)
                WHERE v.valor IS NOT NULL
                GROUP BY 1, 2
            ),
            dominio AS (
                SELECT DISTINCT ON (d.column_name) d.column_name, d.value_domain
                FROM clean.censo_data_dictionary d
                WHERE d.table_name = %L
                ORDER BY d.column_name, d.year_introduced DESC
            )
            SELECT CASE WHEN v.coluna LIKE 'in\_%%' THEN 'binaria_invalida'
                        ELSE 'codigo_fora_do_dominio' END,
                   %L, v.coluna, v.valor, v.n
            FROM valores v
            LEFT JOIN dominio dm ON dm.column_name = v.coluna
            WHERE CASE
                    WHEN dm.value_domain IS NOT NULL THEN NOT (dm.value_domain ? v.valor)
                    ELSE v.valor NOT IN ('0', '1')
                  END
            ORDER BY v.coluna, v.valor
        $q$, alvo, cols, 'clean.' || t, 'clean.' || t);
    END LOOP;
END
$fn$;

COMMENT ON FUNCTION clean.censo_dict_violacoes() IS
'Violações do dicionário nas tabelas clean.censo_{escolas,matriculas,docentes,gestor}:
coluna_sem_dicionario (coluna real ausente do dicionário), codigo_fora_do_dominio
(valor não nulo fora de value_domain) e binaria_invalida (in_* fora de {0,1} ou do
seu domínio). Vazia = dicionário coerente com os dados (#134).';

UPDATE clean.import_metadata
SET notes = 'Dicionário gerado do catálogo e atualizado pelo Dicionário de Variáveis do INEP (censo_data_dictionary_inep)'
WHERE table_name = 'clean.censo_data_dictionary';

COMMIT;
