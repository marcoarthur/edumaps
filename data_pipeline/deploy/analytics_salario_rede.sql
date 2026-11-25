-- Deploy edumaps:analytics_salario_rede to pg
-- requires: remuneracao_nomes_utf8
--
-- #595: o salário do magistério da rede municipal (#571/#575), pré-calculado.
-- A conta (medianas por pessoa-mês e a mediana por pessoa para o piso) levava
-- ~1,2 s em cada tela da base de análise com UF e em cada painel financeiro.
-- A folha só muda numa carga do SIOPE, que chama
-- analytics.refresh_salario_rede() no fim (EduMaps::Task::Siope).
--
-- O piso de cada ano e o mínimo de meses continuam no Perl
-- (EduMaps::BaseAnalise, %PISO_MAGISTERIO e $MESES_MIN_PISO): a segunda view
-- guarda quantas pessoas têm cada (meses pagos, base por 40 h) e a contagem
-- abaixo do piso é feita na consulta. Nenhuma das duas tem CPF ou nome.

BEGIN;

-- Por município e ano: as medianas do pagamento mensal (dezembro fora: 13º).
CREATE MATERIALIZED VIEW analytics.mv_salario_rede AS
WITH pm AS (
  SELECT cod_municipio::text AS cod6, ano::int AS ano, left(mes, 3) AS m, cpf, nome_profissional,
         sum(salario_total) AS t, sum(salario_base) AS b, sum(carga_horaria) AS ch
    FROM clean.remuneracao_municipal
   WHERE tipo = 'Profissionais do magistério' AND left(mes, 3) <> 'Dez'
   GROUP BY 1, 2, 3, 4, 5
)
SELECT cod6, ano,
       count(DISTINCT (cpf, nome_profissional))::int AS pessoas,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY t))::float8 AS total,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY b))::float8 AS base,
       (mode() WITHIN GROUP (ORDER BY ch))::float8 AS carga,
       -- #572: a maioria dos pagamentos com carga abaixo de 20 não parece
       -- estar em horas semanais
       (avg((ch < 20)::int) > 0.5) AS suspeita
  FROM pm
 GROUP BY 1, 2;

CREATE UNIQUE INDEX ux_mv_salario_rede ON analytics.mv_salario_rede (cod6, ano);

COMMENT ON MATERIALIZED VIEW analytics.mv_salario_rede IS
'Salário do magistério da rede municipal por município e ano (#571, #572): medianas do pagamento mensal (sem dezembro) do total e do base, a carga mais comum e se ela parece não estar em horas semanais. Fonte: clean.remuneracao_municipal (SIOPE). Atualizada por analytics.refresh_salario_rede() no fim de cada carga (#595).';
COMMENT ON COLUMN analytics.mv_salario_rede.cod6 IS 'Código IBGE do município com 6 dígitos (o do SIOPE).';
COMMENT ON COLUMN analytics.mv_salario_rede.pessoas IS 'Pessoas distintas (CPF e nome) no magistério da rede no ano.';
COMMENT ON COLUMN analytics.mv_salario_rede.total IS 'Mediana do salário total mensal por pessoa (R$).';
COMMENT ON COLUMN analytics.mv_salario_rede.base IS 'Mediana do salário base mensal por pessoa (R$).';
COMMENT ON COLUMN analytics.mv_salario_rede.carga IS 'Carga horária mais comum dos pagamentos.';
COMMENT ON COLUMN analytics.mv_salario_rede.suspeita IS 'A maioria dos pagamentos com carga abaixo de 20: a carga não parece estar em horas semanais (#572).';

-- Por município e ano: quantas pessoas têm cada (meses pagos, salário base
-- por 40 h no mês típico), e se tiveram escola no ano (#575).
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

CREATE FUNCTION analytics.refresh_salario_rede() RETURNS void
LANGUAGE plpgsql
SET work_mem = '64MB'
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_salario_rede;
  REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_salario_rede_md;
END;
$$;

COMMENT ON FUNCTION analytics.refresh_salario_rede() IS
'Recalcula analytics.mv_salario_rede e analytics.mv_salario_rede_md sem bloquear a leitura (#595). Chamada no fim de cada carga da folha do SIOPE.';

COMMIT;
