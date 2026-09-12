# Skill: postgres-postgis

## Purpose
Auxiliar na modelagem e consultas PostgreSQL/PostGIS do projeto EduMaps.

## Conexão
```bash
PGPASSWORD=senhaboa123 psql -h ubatexu.lan -U devel -d edumaps_dev
```
Sqitch target: `dev_super`

## Schemas
- `clean.*` — views limpas com dados do INEP, Censo, OSM, IPEA
- `analytics.*` — MVs agregadas (ranking, rede escolar, scores)
- `staging.*` — dados brutos temporários (temp tables dos jobs de análise R)
- `public.*` — funções utilitárias, event_store

## Padrões importantes

### Materialized Views
```sql
-- Deploy: CREATE MATERIALIZED VIEW analytics.mv_foo AS SELECT ...;
-- Refresh: CREATE OR REPLACE FUNCTION analytics.refresh_foo() LANGUAGE SQL AS $$ REFRESH MV ...; $$;
-- Index: CREATE UNIQUE INDEX ON analytics.mv_foo (col1, col2);
-- Verify: SELECT 1 ... (COUNT(*) FROM pg_matviews + pg_proc)

-- Deploy com dependências: deploy/analytics_rede_escolas.sql [censo_escolar_2025 ideb_notas_escolas]
```

### PostGIS / GeoJSON
```sql
-- Coluna geometry: SRID 4674 (SIRGAS 2000 /geocentrico)
-- GeoJSON via SQL:
SELECT ST_AsGeoJSON(geometry)::json FROM clean.escolas WHERE ...;
-- json_build_object com properties qualificadas para evitar ambiguidade:
SELECT json_build_object(
  'type', 'FeatureCollection',
  'features', json_agg(json_build_object(
    'geometry', ST_AsGeoJSON(me.geometry)::json,
    'properties', json_build_object('escola', me.escola, 'municipio', me.municipio)
  ))
) AS feature FROM clean.escolas me JOIN clean.municipios_sp m ON m.codigo_ibge = me.co_municipio;

-- IMPORTANTE: em json_build_object, qualificar colunas com alias (me.coluna)
-- para evitar ambiguidade com tabelas JOINadas (ex: coluna 'municipio' vs alias 'municipio')
```

### Tratamento de encoding
```sql
-- Dados limpos: valores capitalizados (Estadual/Federal/Municipal/Privada)
-- Se Double-encoding detectado em coluna text:
SELECT convert_from(convert_to(col, 'LATIN1'), 'UTF8') FROM ...;
```

### Filtros frequentes
```sql
-- Rede administrativa: tp_dependencia = 1(Federal),2(Estadual),3(Municipal),4(Privada)
-- IDEB: ideb_fund_i, ideb_fund_ii, ideb_medio, ano_ideb
-- Anos censo: nu_ano_censo ∈ {2020,2021,2022,2023,2024,2025}
```

## Consultas úteis
```sql
-- Verificar MVs materializadas:
SELECT matviewname, ispopulated FROM pg_matviews WHERE schemaname = 'analytics';

-- Contar registros por tabela:
SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_tables WHERE schemaname IN ('clean','analytics') ORDER BY n_live_tup DESC LIMIT 20;
```
