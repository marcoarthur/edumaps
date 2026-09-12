# Skill: sqitch-migrations

## Purpose
Auxiliar na criação e manutenção de migrations Sqitch do projeto EduMaps.

## Alvos
```bash
cd data_pipeline
sqitch deploy dev_super    # deploy no dev
sqitch revert dev_super    # revert no dev
sqitch verify dev_super    # verifica integridade
```

## Estrutura de uma migration

```
data_pipeline/
├── deploy/<name>.sql        # CREATE / ALTER
├── revert/<name>.sql        # DROP / ALTER reverso
├── verify/<name>.sql        # verificação (sempre SELECT 1 ou COUNT)
└── sqitch.plan              # registry de todas as migrations
```

## sqitch.plan
```
<nome> [dep1 dep2 ...] <timestamp> <autor> # <descrição>
```
- Dependencies listadas entre colchetes `[dep1 dep2]`
- Timestamp em UTC: `2026-09-11T12:00:00Z`
- Autor: `Marco Arthur <arthurpbs@gmail.com>`
- Descrição após `#` em PT-BR

## Padrões do deploy

### Materialized View
```sql
-- deploy/analytics_foo.sql
-- requires: dependencias
-- requires: id_dependencia
BEGIN;

CREATE MATERIALIZED VIEW analytics.mv_foo AS
  SELECT col1, col2, SUM(col3) AS soma
  FROM clean.fonte
  JOIN clean.outra USING (co_chave)
  GROUP BY col1, col2;

CREATE UNIQUE INDEX ON analytics.mv_foo (col1, col2);

CREATE OR REPLACE FUNCTION analytics.refresh_foo()
RETURNS void LANGUAGE SQL AS $$
  REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_foo;
$$;

COMMIT;
```

### Revert
```sql
-- revert/analytics_foo.sql
BEGIN;
DROP FUNCTION IF EXISTS analytics.refresh_foo();
DROP MATERIALIZED VIEW IF EXISTS analytics.mv_foo;
COMMIT;
```

### Verify
```sql
-- verify/analytics_foo.sql
-- requires: id_dependencia
SELECT CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END
FROM pg_matviews
WHERE matviewname = 'mv_foo' AND schemaname = 'analytics';
```

## Regras
- Sempre BEGIN/COMMIT (transacional)
- Nunca fazer commit parcial; migrations são atômicas
- Verificar existência antes de DROP (`IF EXISTS`)
- Índices em MVs: sempre UNIQUE quando possível (permite CONCURRENTLY refresh)
- Dados de teste: nunca popular MVs em migrations (usar scripts separados)
