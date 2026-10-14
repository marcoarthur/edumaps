-- Deploy edumaps:censo_label to pg
-- requires: censo_data_dictionary_inep
--
-- Helper canônico dos rótulos do Censo (issue #228).
--
-- Depois da #134 o dicionário oficial do INEP passou a ser a fonte dos rótulos
-- (`clean.censo_data_dictionary.value_domain`), e o backend Perl já lê de lá
-- (EduMaps::Model::Domain::CensoLabels). Faltavam as camadas SQL e R, que
-- reescreviam `1 => 'Federal'`, `1 => 'Urbana'` à mão em vários lugares.
--
-- Aqui nasce o helper dessas camadas: `clean.censo_label()` (código -> rótulo),
-- `clean.censo_code()` (rótulo -> código) e `clean.censo_labels()` (o domínio
-- inteiro). Todos leem a linha vigente do dicionário — maior year_introduced
-- com year_deprecated IS NULL — exatamente como o backend.
--
-- Os COMMENTs das colunas enum deixam de repetir a lista de rótulos e passam a
-- apontar para o dicionário: o texto oficial fica num só lugar.

BEGIN;

-- Domínio completo (código, rótulo) de uma coluna, na linha vigente.
CREATE OR REPLACE FUNCTION clean.censo_labels(p_table text, p_column text)
RETURNS TABLE(code text, label text)
LANGUAGE sql STABLE AS $$
  SELECT e.key, e.value
  FROM clean.censo_data_dictionary d
  CROSS JOIN LATERAL jsonb_each_text(d.value_domain) AS e(key, value)
  WHERE d.table_name = p_table
    AND d.column_name = p_column
    AND d.year_deprecated IS NULL
    AND d.year_introduced = (
        SELECT max(d2.year_introduced)
        FROM clean.censo_data_dictionary d2
        WHERE d2.table_name = d.table_name
          AND d2.column_name = d.column_name
          AND d2.year_deprecated IS NULL
    );
$$;

COMMENT ON FUNCTION clean.censo_labels(text, text) IS
  'Domínio canônico (código, rótulo) de uma coluna do Censo, da linha vigente do dicionário.';

-- Código -> rótulo. Código desconhecido ou nulo devolve NULL.
CREATE OR REPLACE FUNCTION clean.censo_label(p_table text, p_column text, p_code text)
RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT label FROM clean.censo_labels(p_table, p_column) WHERE code = p_code;
$$;

COMMENT ON FUNCTION clean.censo_label(text, text, text) IS
  'Rótulo canônico de um código do Censo (ex.: censo_label(''clean.censo_escolas'', ''tp_dependencia'', ''3'') = ''Municipal'').';

-- Rótulo -> código, case-insensitive (ex.: LOWER(rede) do IDEB -> código).
CREATE OR REPLACE FUNCTION clean.censo_code(p_table text, p_column text, p_label text)
RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT code FROM clean.censo_labels(p_table, p_column)
  WHERE p_label IS NOT NULL AND lower(label) = lower(p_label)
  LIMIT 1;
$$;

COMMENT ON FUNCTION clean.censo_code(text, text, text) IS
  'Código canônico de um rótulo do Censo (busca case-insensitive, ex.: ''Federal'' -> ''1'').';

-- Os rótulos vivem no dicionário; o COMMENT só aponta para lá.
COMMENT ON COLUMN clean.censo_escolas.tp_dependencia IS
  'Dependência administrativa. Domínio canônico em clean.censo_data_dictionary (clean.censo_escolas.tp_dependencia).';
COMMENT ON COLUMN clean.censo_escolas.tp_localizacao IS
  'Localização da escola. Domínio canônico em clean.censo_data_dictionary (clean.censo_escolas.tp_localizacao).';
COMMENT ON COLUMN clean.censo_escolas.tp_categoria_escola_privada IS
  'Categoria da escola privada. Domínio canônico em clean.censo_data_dictionary (clean.censo_escolas.tp_categoria_escola_privada).';
COMMENT ON COLUMN clean.censo_escolas.tp_localizacao_diferenciada IS
  'Localização diferenciada da escola. Domínio canônico em clean.censo_data_dictionary (clean.censo_escolas.tp_localizacao_diferenciada).';

COMMIT;
