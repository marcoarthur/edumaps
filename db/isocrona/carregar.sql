-- Carga do piloto de isócrona (#278/#295) em clean.isocrona_escolar.
-- Roda no host do banco (o CSV foi enviado para /tmp).
--
-- Variáveis obrigatórias (passadas pelo driver com -v):
--   :snapshot     dt_snapshot da carga — igual para TODAS as UFs de uma mesma
--                 rodada (a view nacional do IVET filtra por max(dt_snapshot))
--   :build_date   tileset_build_date — data de build dos tiles usados
--   :origin       tileset_origin — de qual extract vieram os tiles. OBRIGATÓRIO:
--                 o Sudeste usa 'geofabrik_sudeste_2026-10' e o Nordeste
--                 'geofabrik_nordeste_2026-10' (NÃO deixar hardcoded — a
--                 proveniência de um ficaria mentindo sobre o outro).
--
-- O CSV de entrada é SEMPRE /tmp/isocrona_escolar.csv: o `\copy` do psql NÃO
-- expande variáveis (:'var' vira o caminho literal ':'), então o caminho é
-- fixo e cada driver copia o seu CSV para esse mesmo nome no host do banco.
--
-- Idempotente: substitui as linhas das escolas presentes no CSV — recarregar
-- o piloto não duplica (PK: co_entidade, tempo_minutos, grid_id, dt_snapshot).
--
-- RESILIÊNCIA (2 pontos, ambos medidos em 2026-10-22/23):
--   1. Rodar SEMPRE destacado do terminal (`systemd-run --unit=...`) no host
--      do banco. A carga leva ~20 min; uma queda da sessão SSH faz ROLLBACK
--      TOTAL (aconteceu com o SP: 16,6 M linhas perdidas).
--   2. SEM temp table de dados. O CSV traz só as 6 colunas de dados; as 5 de
--      metadados são constantes por carga e entram por DEFAULT temporário,
--      deixando o COPY ir DIRETO na tabela de destino. A abordagem antiga
--      (COPY p/ temp table + INSERT ... SELECT) exigia ~2 GB extras de pico
--      numa carga de 28 M linhas, o que não cabe no disco do banco.

BEGIN;

-- Compressão de WAL: reduz o pico de disco do COPY (dados muito repetitivos).
SET LOCAL wal_compression = on;

-- Defaults TEMPORÁRIOS para os metadados constantes da carga. São removidos
-- no fim da transação; se algo falhar, o ROLLBACK também desfaz os ALTER.
ALTER TABLE clean.isocrona_escolar ALTER COLUMN tileset_origin SET DEFAULT :'origin';
ALTER TABLE clean.isocrona_escolar ALTER COLUMN tileset_build_date SET DEFAULT :'build_date'::date;
ALTER TABLE clean.isocrona_escolar ALTER COLUMN engine SET DEFAULT 'valhalla';
ALTER TABLE clean.isocrona_escolar ALTER COLUMN engine_version SET DEFAULT '3.5.1';
ALTER TABLE clean.isocrona_escolar ALTER COLUMN dt_snapshot SET DEFAULT :'snapshot'::date;

-- Idempotência: apaga só as escolas presentes no CSV. A lista tem ~46 mil
-- linhas (uma por escola, não por célula) — minúscula perto dos 28 M de linhas
-- que o COPY vai inserir. O CSV vem ordenado por co_entidade, então `uniq`
-- resolve em streaming (sem sort/temp em disco).
CREATE TEMP TABLE tmp_escolas (co_entidade BIGINT) ON COMMIT DROP;
COPY tmp_escolas (co_entidade)
  FROM PROGRAM 'tail -n +2 /tmp/isocrona_escolar.csv | cut -d, -f1 | uniq'
  WITH (FORMAT csv);

DELETE FROM clean.isocrona_escolar e
 USING tmp_escolas t
 WHERE e.co_entidade = t.co_entidade;

-- Carga direta (server-side COPY), sem temp table de dados.
COPY clean.isocrona_escolar (
  co_entidade, codigo_ibge, tempo_minutos, grid_id, resolucao_h3,
  populacao_grade
) FROM '/tmp/isocrona_escolar.csv' WITH (FORMAT csv, HEADER);

-- Restaura o schema: nenhum default permanente fica na tabela.
ALTER TABLE clean.isocrona_escolar ALTER COLUMN tileset_origin DROP DEFAULT;
ALTER TABLE clean.isocrona_escolar ALTER COLUMN tileset_build_date DROP DEFAULT;
ALTER TABLE clean.isocrona_escolar ALTER COLUMN engine DROP DEFAULT;
ALTER TABLE clean.isocrona_escolar ALTER COLUMN engine_version DROP DEFAULT;
ALTER TABLE clean.isocrona_escolar ALTER COLUMN dt_snapshot DROP DEFAULT;

SELECT 'linhas: ' || count(*) ||
       ' | escolas: ' || count(DISTINCT co_entidade) ||
       ' | com população: ' || count(*) FILTER (WHERE populacao_grade IS NOT NULL)
  FROM clean.isocrona_escolar
 WHERE dt_snapshot = :'snapshot'::date;

COMMIT;
