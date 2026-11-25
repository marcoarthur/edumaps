-- Deploy edumaps:analytics_salario_rede_situacao to pg
-- requires: analytics_salario_rede
--
-- #597 (QB-01 da P2): a contagem abaixo do piso aberta pela situação
-- (efetivo, temporário, outros) e o perfil de quem fica abaixo (a carga mais
-- comum e a mediana do salário base). analytics.mv_salario_rede_md ganha, por
-- pessoa e ano: a situação (a dos mais meses; empate: a do último mês), a
-- carga mais comum dos meses e a mediana do salário base mensal. Continua sem
-- CPF nem nome. A função de refresh (#595) segue a mesma.

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
  SELECT cod6, ano, cpf, nome_profissional, bool_or(esc) AS esc, count(*)::int AS meses,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY b / ch * 40) AS md,
         mode() WITHIN GROUP (ORDER BY ch) AS carga,
         round(percentile_cont(0.5) WITHIN GROUP (ORDER BY b)::numeric, 2) AS base
    FROM pm WHERE ch > 0 AND b IS NOT NULL
   GROUP BY cod6, ano, cpf, nome_profissional
), sm AS (
  -- a situação de cada mês da pessoa (efetivo, temporario ou outros)
  SELECT cod_municipio::text AS cod6, ano::int AS ano, cpf, nome_profissional,
         CASE situacao WHEN 'Efetivo' THEN 'efetivo' WHEN 'Temporário' THEN 'temporario' ELSE 'outros' END AS sit,
         array_position(ARRAY['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov'], left(mes, 3)) AS mn
    FROM clean.remuneracao_municipal
   WHERE tipo = 'Profissionais do magistério' AND left(mes, 3) <> 'Dez'
   GROUP BY 1, 2, 3, 4, 5, 6
), ps AS (
  -- a situação dos mais meses; empate: a do último mês
  SELECT DISTINCT ON (cod6, ano, cpf, nome_profissional) cod6, ano, cpf, nome_profissional, sit
    FROM (SELECT cod6, ano, cpf, nome_profissional, sit, count(*) AS n, max(mn) AS ult
            FROM sm GROUP BY 1, 2, 3, 4, 5) x
   ORDER BY cod6, ano, cpf, nome_profissional, n DESC, ult DESC NULLS LAST, sit
)
SELECT pp.cod6, pp.ano, pp.esc, pp.meses, pp.md, coalesce(ps.sit, 'outros') AS situacao,
       pp.carga::float8 AS carga, pp.base::float8 AS base, count(*)::int AS n
  FROM pp
  LEFT JOIN ps USING (cod6, ano, cpf, nome_profissional)
 GROUP BY 1, 2, 3, 4, 5, 6, 7, 8;

CREATE UNIQUE INDEX ux_mv_salario_rede_md
    ON analytics.mv_salario_rede_md (cod6, ano, esc, meses, md, situacao, carga, base) NULLS NOT DISTINCT;

COMMENT ON MATERIALIZED VIEW analytics.mv_salario_rede_md IS
'Distribuição do salário base por 40 h do magistério da rede municipal (#575): por município e ano, quantas pessoas (n) têm cada mediana mensal (md), meses pagos, se tiveram escola no ano (esc; falso = só a Secretaria), a situação (#597: efetivo, temporario ou outros; a dos mais meses, empate: a do último mês), a carga mais comum e a mediana do salário base mensal. A comparação com o piso e o mínimo de meses ficam na consulta (EduMaps::BaseAnalise). Sem CPF nem nome. Atualizada por analytics.refresh_salario_rede() (#595).';
COMMENT ON COLUMN analytics.mv_salario_rede_md.situacao IS 'Situação da pessoa no ano (#597): efetivo, temporario ou outros (Outros, Cedido e vazio). A dos mais meses; empate: a do último mês.';
COMMENT ON COLUMN analytics.mv_salario_rede_md.carga IS 'Carga horária mais comum dos meses da pessoa.';
COMMENT ON COLUMN analytics.mv_salario_rede_md.base IS 'Mediana do salário base mensal da pessoa, sem conversão para 40 horas (R$).';

COMMIT;
