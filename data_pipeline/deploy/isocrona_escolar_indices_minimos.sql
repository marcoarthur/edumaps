-- Deploy edumaps:isocrona_escolar_indices_minimos to pg
-- requires: analytics_ivet_escola
--
-- #295: reduz o custo de armazenamento dos índices da isocrona antes da
-- rodada 2 (SP + RJ + Nordeste, ~50 M linhas). Medido em 2026-10-22: com 4,78 M
-- linhas os 5 índices secundários somavam 1.946 MB (426 B/linha), ~73% do
-- espaço da tabela. A rodada 2 completa exigiria ~20 GB só de índices, contra
-- 2,9 GB livres no host do banco.
--
-- Quais ficam e por quê:
--   pk_isocrona_escolar       (co_entidade, tempo_minutos, grid_id, dt_snapshot)
--                             — unicidade E acesso por escola (`co_entidade` é
--                             o prefixo; provado com EXPLAIN: um Index Only Scan
--                             pela PK cobre `co_entidade` sozinho e com
--                             `dt_snapshot`).
--   idx_isocrona_codigo_ibge  — agregação municipal (uso comprovado no EXPLAIN).
--
-- Quais saem (redundantes ou inúteis):
--   idx_isocrona_co_entidade  — prefixo da PK, coberto por ela.
--   idx_isocrona_grid         — grid_id não é filtro de nenhuma consulta.
--   idx_isocrona_tempo        — coluna de 2 valores, sem seletividade.
--   idx_isocrona_dt_snapshot  — filtro de baixa seletividade; a PK cobre.

BEGIN;

DROP INDEX IF EXISTS clean.idx_isocrona_co_entidade;
DROP INDEX IF EXISTS clean.idx_isocrona_grid;
DROP INDEX IF EXISTS clean.idx_isocrona_tempo;
DROP INDEX IF EXISTS clean.idx_isocrona_dt_snapshot;

COMMENT ON TABLE clean.isocrona_escolar IS 'Isocronas escolares (Valhalla auto-hospedado). Agregação em grade H3 (r9 ≈ 0,1 km² a pé; r7 ≈ 5,2 km² de carro), NUNCA por escola isolada. Índices mínimos desde #295: PK (co_entidade, tempo_minutos, grid_id, dt_snapshot) + codigo_ibge.';

COMMIT;
