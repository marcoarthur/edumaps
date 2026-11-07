-- Deploy edumaps:staging_schema to pg
-- requires: leitor_grants_explicitos
--
-- Schema de trabalho dos jobs de análise: o cálculo de similaridade
-- (EduMaps::Roles::DB::ProcessedJob), os jobs de clustering/similaridade e o
-- motor R gravam ali tabelas temporárias de entrada e as apagam depois.
-- Nenhuma migração o criava: existia nos bancos antigos, mas uma instalação
-- nova (Docker local, CI) ficava sem ele.
--
-- IF NOT EXISTS: nos bancos em que o schema já existe, nada muda.
-- O papel edumaps_leitor não recebe acesso (só cópias temporárias).

BEGIN;

  CREATE SCHEMA IF NOT EXISTS staging;

  COMMENT ON SCHEMA staging IS
    'Tabelas temporárias de entrada dos jobs de análise (similaridade, clustering, motor R). Criadas e apagadas pelos próprios jobs.';

COMMIT;
