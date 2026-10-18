-- Deploy edumaps:mapbiomas_escola to pg
-- requires: escola_influencia
--
-- #255 (bloco F do IVET): **cobertura do solo de 30 m na área de influência
-- da escola** — zonal statistics do raster nacional do MapBiomas sobre o
-- buffer materializado em clean.escola_influencia (metodologia
-- influencia-v1, docs/analises/influencia.md §4/§8).
--
-- Por que uma tabela e não PostGIS: o raster de 30 m não cabe no banco
-- (≈22 GB/ano descomprimido; ~750 MB/ano comprimido). A arealização lê o COG
-- em streaming, no host de ingestão, e grava só as frações. É o mesmo
-- princípio de "produto, não fonte" do bloco B — mas o produto aqui é o
-- raster, e a unidade é a classe-folha do MapBiomas.
--
-- Grão: uma linha por escola × ano do Censo × ano do raster × raio ×
-- classe-folha. A fração é a composição da área do buffer:
--
--   fracao = Σ_células(peso_célula_na_classe) / Σ_células(peso_célula)
--
-- Vazio ≠ zero (#154): buffer sem interseção com o raster (fora da cobertura,
-- tudo NoData) **não produz linha nenhuma** — nunca 0. Um consumo que precise
-- somar (vegetação natural, antrópico, água) usa a view de grupos.
--
-- A fonte (COG da Coleção 11, 1985–2025) é pinada no job MapBiomasEscola. A
-- legenda (classe → descrição) é a do MapBiomas e vive no script R; aqui só o
-- mapeamento classe → grupo materializa a taxonomia nível 1.

BEGIN;

DROP VIEW IF EXISTS clean.v_mapbiomas_escola_grupos;
DROP TABLE IF EXISTS clean.mapbiomas_escola;

CREATE TABLE clean.mapbiomas_escola (
    co_entidade  BIGINT       NOT NULL,
    nu_ano_censo INTEGER      NOT NULL,
    ano          SMALLINT     NOT NULL,
    raio_m       INTEGER      NOT NULL,
    classe       TEXT         NOT NULL,
    classe_desc  TEXT,
    fracao       NUMERIC(7,6) NOT NULL,
    colecao      TEXT         NOT NULL DEFAULT 'collection11',
    versao       TEXT         NOT NULL DEFAULT 'influencia-v1',
    computado_em TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT pk_mapbiomas_escola
      PRIMARY KEY (co_entidade, nu_ano_censo, ano, raio_m, classe),
    CONSTRAINT mapbiomas_escola_raio_ck CHECK (raio_m > 0),
    CONSTRAINT mapbiomas_escola_ano_ck  CHECK (ano BETWEEN 1985 AND 2025),
    CONSTRAINT mapbiomas_escola_fracao_ck CHECK (fracao >= 0 AND fracao <= 1)
);

COMMENT ON TABLE clean.mapbiomas_escola IS
'Cobertura do solo (raster MapBiomas 30 m, Coleção 11) arealizada sobre a área de influência da escola (#255, docs/analises/influencia.md §4 Tier 1/§8). Uma linha por escola × ano do Censo × ano do raster × raio × classe-folha; fracao = composição da área do buffer. Vazio ≠ zero (#154): sem interseção com o raster não há linha. Populada pelo job MapBiomasEscola.';
COMMENT ON COLUMN clean.mapbiomas_escola.co_entidade IS 'Código INEP da escola (clean.censo_escolas.co_entidade).';
COMMENT ON COLUMN clean.mapbiomas_escola.nu_ano_censo IS 'Ano do Censo Escolar da geometria de origem.';
COMMENT ON COLUMN clean.mapbiomas_escola.ano IS 'Ano do raster MapBiomas (1985–2025, Coleção 11).';
COMMENT ON COLUMN clean.mapbiomas_escola.raio_m IS 'Raio do buffer em metros (tier=buffer).';
COMMENT ON COLUMN clean.mapbiomas_escola.classe IS 'Código da classe-folha MapBiomas (ex.: ''3'', ''15''), alinhado a clean.mapbiomas_cobertura.classe.';
COMMENT ON COLUMN clean.mapbiomas_escola.classe_desc IS 'Descrição legível da classe-folha (legenda MapBiomas, nível 4).';
COMMENT ON COLUMN clean.mapbiomas_escola.fracao IS 'Fração da área do buffer com esta classe, em [0,1]; soma 1 por escola × ano × raio.';
COMMENT ON COLUMN clean.mapbiomas_escola.colecao IS 'Coleção MapBiomas do raster (FIXA: collection11).';
COMMENT ON COLUMN clean.mapbiomas_escola.versao IS 'Versão da metodologia de influência que define o buffer (influencia-v1).';
COMMENT ON COLUMN clean.mapbiomas_escola.computado_em IS 'Quando a arealização foi (re)calculada.';

CREATE INDEX ix_mapbiomas_escola_ano
  ON clean.mapbiomas_escola (ano, raio_m);
CREATE INDEX ix_mapbiomas_escola_escola
  ON clean.mapbiomas_escola (co_entidade, nu_ano_censo);

-- ---------------------------------------------------------------------------
-- Grupos (taxonomia MapBiomas nível 1, agrupada para o IVET).
--
-- O mapeamento é por CÓDIGO, não pelo prefixo de classe_desc: o prefixo não é
-- confiável (6 = "1.4 Floodable Forest" sem ponto; 29 e 50 partilham "2.4").
--   vegetacao_natural  nível 1 (floresta) + nível 2 (formação natural não florestal)
--   agropecuario       nível 3 (agricultura/pastagem/mosaico)
--   urbano_infra       nível 4 antrópico (24 urbano, 25 outros, 30 mineração, 75 fotovoltaica)
--   agua               nível 5 (31 aquicultura, 33 rio/lago/oceano)
--   outros_naturais    nível 4 natural (23 praia/duna/areia)
--   nao_observado      0
--   outros             código ausente da taxonomia carregada (nunca silencioso)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW clean.v_mapbiomas_escola_grupos AS
SELECT co_entidade, nu_ano_censo, ano, raio_m, grupo,
       sum(fracao) AS fracao
FROM (
  SELECT m.co_entidade, m.nu_ano_censo, m.ano, m.raio_m, m.fracao,
         CASE
           WHEN m.classe IN ('3','4','5','6','49')                THEN 'vegetacao_natural'
           WHEN m.classe IN ('11','12','13','29','32','50')       THEN 'vegetacao_natural'
           WHEN m.classe IN ('9','15','20','21','35','39','40','41','46','47','48','62') THEN 'agropecuario'
           WHEN m.classe IN ('24','25','30','75')                 THEN 'urbano_infra'
           WHEN m.classe IN ('31','33')                           THEN 'agua'
           WHEN m.classe = '23'                                   THEN 'outros_naturais'
           WHEN m.classe = '0'                                    THEN 'nao_observado'
           ELSE 'outros'
         END AS grupo
    FROM clean.mapbiomas_escola m
) s
GROUP BY co_entidade, nu_ano_censo, ano, raio_m, grupo;

COMMENT ON VIEW clean.v_mapbiomas_escola_grupos IS
'Cobertura do solo agrupada na taxonomia MapBiomas nível 1 adaptada ao IVET (#255): vegetacao_natural, agropecuario, urbano_infra, agua, outros_naturais, nao_observado, outros. Soma de frações por escola × ano × raio. Classe fora da taxonomia nunca desaparece: cai em ''outros''.';

-- Estado da fonte antes da primeira carga (#231): o registro existe e diz que
-- ainda não foi carregada, em vez de simplesmente não existir.
INSERT INTO clean.import_metadata (table_name, source_file, ultimo_status, ultimo_motivo)
VALUES ('clean.mapbiomas_escola', '(nenhuma carga registrada)', 'nao_carregada',
        'aguarda a primeira execução do job MapBiomasEscola (#255)')
ON CONFLICT (table_name) DO NOTHING;

COMMIT;
