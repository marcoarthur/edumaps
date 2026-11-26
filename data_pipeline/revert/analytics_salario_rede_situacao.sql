-- Revert edumaps:analytics_salario_rede_situacao from pg
-- Volta analytics.mv_salario_rede_md à forma da #595 (sem situação, carga e base).

BEGIN;

DROP MATERIALIZED VIEW analytics.mv_salario_rede_md;

CREATE MATERIALIZED VIEW analytics.mv_salario_rede_md AS
WITH pm AS (
  SELECT cod_municipio::text AS cod6, ano::int AS ano, left(mes, 3) AS m, cpf, nome_profissional,
         sum(salario_base) AS b, sum(carga_horaria) AS ch,
         bool_or(cod_inep <> 99999999) AS esc
    FROM clean.remuneracao_municipal
   WHERE tipo = 'Profissionais do magistério' AND left(mes, 3) <> 'Dez'
   GROUP BY 1, 2, 3, 4, 5
), pp AS (
  SELECT cod6, ano, bool_or(esc) AS esc, count(*)::int AS meses,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY b / ch * 40) AS md
    FROM pm WHERE ch > 0 AND b IS NOT NULL
   GROUP BY cod6, ano, cpf, nome_profissional
)
SELECT cod6, ano, esc, meses, md, count(*)::int AS n
  FROM pp
 GROUP BY 1, 2, 3, 4, 5;

CREATE UNIQUE INDEX ux_mv_salario_rede_md ON analytics.mv_salario_rede_md (cod6, ano, esc, meses, md) NULLS NOT DISTINCT;

COMMENT ON MATERIALIZED VIEW analytics.mv_salario_rede_md IS
'Distribuição do salário base por 40 h do magistério da rede municipal (#575): por município e ano, quantas pessoas (n) têm cada mediana mensal (md), meses pagos e se tiveram escola no ano (esc; falso = só a Secretaria). A comparação com o piso e o mínimo de meses ficam na consulta (EduMaps::BaseAnalise). Sem CPF nem nome. Atualizada por analytics.refresh_salario_rede() (#595).';

COMMIT;
