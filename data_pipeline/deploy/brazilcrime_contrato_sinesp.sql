-- Deploy edumaps:brazilcrime_contrato_sinesp to pg
-- requires: brazilcrime_municipio

BEGIN;

-- =================================================================
-- CORREÇÃO DO CONTRATO DE COLUNAS — BrazilCrime/SINESP
-- Issue #164
--
-- A tabela clean.brazilcrime_municipio foi desenhada contra a taxonomia
-- da série antiga SSP/Ministério da Segurança Pública. A fonte que
-- existe hoje — o pacote R BrazilCrime 0.3.0, que embrulha o SINESP
-- VDE — publica 30 eventos que não cobrem esse conjunto.
--
-- Medi a correspondência evento->coluna (issue #164) e o resultado e:
-- 5 colunas nao tem evento nenhum na fonte, e 2 sao mais estreitas do
-- que o nome promete.
--
-- Este change NAO e cosmetico. Uma coluna que existe mas nunca tem
-- valor, ou que tem valor mas significa outra coisa, e a mesma forma
-- do defeito que a change analytics_ausencia_visivel removeu das views
-- (issue #154): infra-estrutura correcta a prometer algo que nao faz.
-- =================================================================

-- -----------------------------------------------------------------
-- 1. Colunas sem qualquer evento na fonte — removidas
--
--   homicide_culposo   nao publicado pelo SINESP VDE
--    furto_outros         o pacote so publica "Furto de veiculo"
--    estelionato          nao publicado pelo SINESP VDE
--    ameaca               nao publicado pelo SINESP VDE
--    violacao_domicilio   nao publicado pelo SINESP VDE
--
-- A tabela esta vazia (0 linhas), portanto nao ha dado a perder. O
-- guard em verify/brazilcrime_contrato_sinesp.sql falha se alguma vez
-- isso deixar de ser verdade sem um dump accompanyar este change.
-- -----------------------------------------------------------------
ALTER TABLE clean.brazilcrime_municipio
  DROP COLUMN IF EXISTS homicidio_culposo,
  DROP COLUMN IF EXISTS furto_outros,
  DROP COLUMN IF EXISTS estelionato,
  DROP COLUMN IF EXISTS ameaca,
  DROP COLUMN IF EXISTS violacao_domicilio;

-- -----------------------------------------------------------------
-- 2. Colunas mais estreitas do que o nome — renomeadas
--
-- lesao_corporal: a unica fonte e "Lesao corporal seguida de morte",
-- que e o subconjunto fatal. "Lesao corporal" sem qualificacao
-- suggeste todos os registos de lesao. O nome passa a dizer o que e.
--
-- roubo_outros: o pacote so publica "Roubo a instituicao financeira".
-- Nao ha outros tipos de roubo na fonte, portanto "outros" nao
-- descreve o conteudo — descreve a nossa falta de informacao.
-- -----------------------------------------------------------------
ALTER TABLE clean.brazilcrime_municipio
  RENAME COLUMN lesao_corporal TO lesao_corporal_seguida_de_morte;

ALTER TABLE clean.brazilcrime_municipio
  RENAME COLUMN roubo_outros TO roubo_instituicao_financeira;

-- -----------------------------------------------------------------
-- 3. Comentarios corrigidos
--
-- O COMMENT antigo dizia "dados oficiais SSP/IBGE". A fonte e o SINESP
-- VDE, empacotado num pacote CRAN. Tambem dizia "snapshot mensal",
-- mas a chave e anual e o snapshot e a data da extraccao.
-- -----------------------------------------------------------------
COMMENT ON TABLE clean.brazilcrime_municipio IS
  'Criminalidade agregada por municipio/ano. Fonte: SINESP VDE (violencia letal e patrimonial), empacotado no pacote R BrazilCrime 0.3.0 (CRAN) - ver issue #164. ATENCAO: os dados sao um snapshot embutido no pacote, congelado na versao publicada; nao ha sincronizacao automatica com o SINESP. O grao por municipio/ano e o maximo que a fonte permite: NAO expor por escola, nem agregada. Supressao de celula pequena (count < 5) obrigatoria, sinalizada em supressao_celula_pequena - que NAO e zero. Municipios que a fonte nao cobre ficam com NULL, nunca com 0.';

COMMENT ON COLUMN clean.brazilcrime_municipio.homicidio_doloso IS
  'Vitimas de Homicidio doloso no ano (evento "Homicidio doloso" do SINESP VDE, categoria vitimas)';

COMMENT ON COLUMN clean.brazilcrime_municipio.latrocinio IS
  'Vitimas de roubo seguido de morte / latrocinio (evento "Roubo seguido de morte (latrocinio)")';

COMMENT ON COLUMN clean.brazilcrime_municipio.roubo_veiculo IS
  'Vitimas de roubo de veiculo (evento "Roubo de veiculo")';

COMMENT ON COLUMN clean.brazilcrime_municipio.roubo_carga IS
  'Vitimas de roubo de carga (evento "Roubo de carga")';

COMMENT ON COLUMN clean.brazilcrime_municipio.roubo_instituicao_financeira IS
  'Vitimas de roubo a instituicao financeira (evento "Roubo a instituicao financeira"). ATENCAO: apesar do nome antigo roubo_outros, a fonte NAO publica outros tipos de roubo - esta coluna nao e um agregado, e so este evento';

COMMENT ON COLUMN clean.brazilcrime_municipio.furto_veiculo IS
  'Vitimas de furto de veiculo (evento "Furto de veiculo"). A fonte nao publica outros tipos de furto';

COMMENT ON COLUMN clean.brazilcrime_municipio.lesao_corporal_seguida_de_morte IS
  'Vitimas de lesao corporal SEGUIDA DE MORTE (evento homonimo do SINESP VDE). NAO e o total de lesoes corporais com vitima';

COMMENT ON COLUMN clean.brazilcrime_municipio.supressao_celula_pequena IS
  'TRUE = algum valor desta linha foi suprimido por sigilo estatistico (count < 5). NAO e zero: zero significa que a fonte cobre este municipio e nao registou';

COMMENT ON COLUMN clean.brazilcrime_municipio.dt_snapshot IS
  'Data da extraccao dos dados (chave de versionamento). NAO e um snapshot mensal: a fonte e anual e o que versiona e quando foi extraido';

COMMIT;