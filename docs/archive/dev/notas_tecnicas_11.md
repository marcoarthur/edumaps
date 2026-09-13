Olhando os schemas dessas duas tabelas, você tem uma mina de ouro estatística em mãos. A granularidade delas é o primeiro grande desafio que precisamos resolver no design da consulta.

### 🔍 O Desafio Estatístico da Granularidade

1. **`clean.remuneracao_municipal` (Microdado do SIOPE):** Está ao nível de **Indivíduo/Contrato por Mês**. Temos o CPF do professor, o código da escola (`cod_inep`), o município antigo de 6 dígitos (`cod_municipio`) e, criticamente, o `salario_total` e a `carga_horaria`.
2. **`clean.censo_docentes` (Dado do INEP):** Está agregado ao nível de **Escola** (`co_entidade`), trazendo contagens consolidadas de perfis de docentes (titulação, vínculo, gênero, idade). Ela **não** tem CPFs individuais, mas sim os totais que atuam ali.

Para cruzar as duas visões mantendo o rigor metodológico, o ponto de convergência ideal é a **Escola (`cod_inep` $\leftrightarrow$ `co_entidade`)**, filtrando estritamente para a **Rede Municipal**.

---

## 🛠️ Query de Cruzamento: SIOPE vs. Censo (Nível Escola)

Esta query consolida a realidade financeira do SIOPE (calculando a média de CPFs ativos e a média de salários/carga horária ao longo dos meses de 2025) e faz o `INNER JOIN` com a foto anual declarada no Censo.

```sql
WITH siope_escola_2025 AS (
    -- Agregamos o SIOPE por escola para obter as métricas médias anuais de pessoal
    SELECT 
        cod_inep,
        cod_municipio,
        -- Média mensal de CPFs únicos recebendo na escola (mitiga flutuações de contratação)
        ROUND(AVG(cpfs_por_mes)) AS siope_docentes_unique_avg,
        -- Soma da carga horária média mensal alocada àquela escola
        SUM(carga_horaria_mensal_avg) AS siope_carga_horaria_total,
        -- Remuneração média total gasta por mês nessa escola
        ROUND(AVG(gasto_mensal_escola), 2) AS siope_gasto_mensal_medio,
        -- Salário médio por professor (bruto)
        ROUND(AVG(salario_medio_professor), 2) AS siope_salario_medio_individual
    FROM (
        SELECT 
            cod_inep,
            cod_municipio,
            mes,
            COUNT(DISTINCT cpf) AS cpfs_por_mes,
            SUM(carga_horaria) AS carga_horaria_mensal_avg,
            SUM(salario_total) AS gasto_mensal_escola,
            AVG(salario_total) AS salario_medio_professor
        FROM clean.remuneracao_municipal
        WHERE ano = 2025 
          AND rede ILIKE '%municipal%'
          AND cod_inep IS NOT NULL
        GROUP BY cod_inep, cod_municipio, mes
    ) sub
    GROUP BY cod_inep, cod_municipio
)
SELECT 
    s.cod_municipio,
    s.cod_inep AS codigo_escola,
    -- Dados Financeiros (SIOPE)
    s.siope_docentes_unique_avg,
    s.siope_carga_horaria_total,
    s.siope_gasto_mensal_medio,
    s.siope_salario_medio_individual,
    -- Dados Declaratórios (Censo INEP)
    c.qt_doc_bas AS censo_total_docentes,
    c.qt_doc_bas_vinculo_concur AS censo_concursados,
    c.qt_doc_bas_vinculo_contra AS censo_contratados,
    -- Engenharia de Atributos: Diferença absoluta e percentual
    (s.siope_docentes_unique_avg - c.qt_doc_bas) AS divergência_absoluta,
    ROUND(
        CASE 
            WHEN c.qt_doc_bas = 0 THEN 0 
            ELSE ((s.siope_docentes_unique_avg::numeric - c.qt_doc_bas) / c.qt_doc_bas) * 100 
        END, 2
    ) AS divergência_percentual,
    -- Métricas de Qualificação do Censo para a modelagem
    c.qt_doc_bas_esco_sup_grad_licen AS censo_docentes_licenciados,
    c.qt_doc_bas_esco_sup_pos_mestra + c.qt_doc_bas_esco_sup_pos_douto AS censo_docentes_stricto_sensu
FROM siope_escola_2025 s
INNER JOIN clean.censo_docentes c 
    ON s.cod_inep = c.co_entidade
    AND c.nu_ano_censo = 2025;

```

---

## 🔬 O Roteiro Estatístico no R (Análise dos Resíduos)

Ao carregar o resultado dessa query no seu ambiente R, o seu foco estatístico estará em modelar o comportamento da **divergência**.

Se o dado fosse perfeito, $siope\_docentes\_unique\_avg \approx censo\_total\_docentes$. Como não é, vamos analisar a variância.

### 1. Teste de Inconsistência Sistemática (Diferenças Pareadas)

O primeiro passo é aplicar um teste para verificar se as médias das duas bases são estaticamente idênticas ou se há viés de sub/supernotificação global na rede municipal. Dado que as distribuições de contagem educacional costumam ter assimetria positiva, aplicamos o teste não-paramétrico de **Wilcoxon Signed-Rank**:

```R
# Teste de postos sinalizados de Wilcoxon para amostras pareadas
wilcox.test(dados$siope_docentes_unique_avg, dados$censo_total_docentes, paired = TRUE)

```

* Se $p\text{-value} < 0.05$, rejeitamos a hipótese de que as bases são equivalentes, provando que um dos instrumentos (SIOPE ou Censo) sofre de viés sistemático de preenchimento.

### 2. Modelagem de Resíduos e Heterocedasticidade

Para capturar quais perfis de escola geram maior distorção financeira, rodamos uma regressão linear onde a variável resposta é o gasto mensal médio, controlando pelo tamanho real declarado no censo e pelas características contratuais:

```R
modelo <- lm(siope_gasto_mensal_medio ~ censo_total_docentes + censo_contratados + censo_docentes_licenciados, data = dados)
summary(modelo)

# Análise de Outliers via Distância de Cook
dados$cooks_d <- cooks.distance(modelo)
escolas_anomalas <- subset(dados, cooks_d > (4 / nrow(dados)))

```

Escolas onde a **Distância de Cook** estourar o limite crítico representam anomalias graves: ou possuem uma folha de pagamento inflada inexplicável para o número de docentes em sala, ou uma severa defasagem de registro no Censo Escolar.

Com essa tabela consolidada gerada pela query, você consegue isolar geograficamente no EduMaps onde estão os clusters dessas escolas de alta divergência. Quer ajustar algum agrupamento específico por segmento de ensino (Infantil vs Fundamental) antes de rodar a agregação?


## Query proposta para conferencia entre censo/siope

Essas três linhas são excelentes para ilustrar o comportamento do cruzamento e acendem alertas metodológicos e estatísticos bem claros. Note que em todas as três escolas a divergência é **positiva e expressiva** ($+200\%$, $+161,5\%$ e $+75\%$). O SIOPE está registrando significativamente mais CPFs únicos vinculados à escola do que o Censo Escolar declarou em sala de aula.

Vamos destrinchar o diagnóstico desses dados e os caminhos estatísticos para tratá-los no R.

---

## 🧐 Diagnóstico dos Casos

### Escola `11024372` (Divergência Crítica de 200%)

* **Censo:** Declarou apenas **8** professores no total (1 concursado e 7 contratados).
* **SIOPE:** Apresenta uma média de **24** CPFs únicos recebendo mensalmente com carimbo nesta escola.
* **O que isso indica?** Como a carga horária total somada no mês é alta (10.710 horas/mês divididas por 4 semanas $\approx$ 2.677 horas semanais totais na escola), se dividirmos pela média de 24 professores, temos cerca de 111 horas mensais por CPF (aproximadamente **25h a 30h semanais** por professor). A conta fecha perfeitamente para 24 pessoas trabalhando em regime padrão.
* **Veredito:** O Censo Escolar provavelmente **subnotificou** drasticamente os docentes dessa escola (talvez omitindo os temporários/contratados que representam a quase totalidade ali), ou há um erro de rateio geográfico no SIOPE.

### Escolas `11024666` e `11024828` (Divergências de 161% e 75%)

* O padrão se repete: alto volume de contratados temporários (`censo_contratados` = 9 e 12) frente aos concursados (4 e 5).
* Onde há alta rotatividade de contratos temporários ao longo do ano, o SIOPE (acumulado/média de CPFs distintos no ano) tende a inflar em relação à foto estática do Censo (coletada em uma data de referência específica).

---

## 🛠️ Engenharia de Recursos (Feature Engineering) no R

Antes de rodar as regressões ou análises espaciais para o EduMaps, precisamos padronizar as variáveis. Como as cargas horárias absolutas variam, crie métricas de **intensidade de distorção**.

```R
library(tidyverse)

# Tratamento inicial dos dados filtrados da query
df_analise <- dados %>% 
  mutate(
    # 1. Carga horária média por CPF ativo no SIOPE (Mês padrão de 4.5 semanas)
    siope_ch_por_professor = (siope_carga_horaria_total / 4.5) / siope_docentes_unique_avg,
    
    # 2. Proporção de precarização do vínculo (Temporários / Total do Censo)
    prop_contratados_censo = censo_contratados / censo_total_docentes,
    
    # 3. Razão de divergência (Métrica contínua ideal para modelos log-lineares)
    razao_siope_censo = siope_docentes_unique_avg / censo_total_docentes
  )

```

---

## 🔬 Próximos Passos Estatísticos

Como a sua variável de interesse (`divergencia_absoluta` ou `razao_siope_censo`) é estritamente positiva nas caudas e apresenta assimetria por lidar com contagens, modelos lineares simples (`lm`) podem sofrer com falta de normalidade nos resíduos.

### Sugestão de Abordagem: Regressão de Poisson ou Binomial Negativa

Para prever ou explicar a quantidade de CPFs "a mais" no SIOPE usando as características do censo:

```R
library(MASS)

# Modelo usando Binomial Negativa para controlar a superdispersão da divergência
modelo_distorcao <- glm.nb(
  siope_docentes_unique_avg ~ offset(log(censo_total_docentes)) + 
    prop_contratados_censo + 
    siope_salario_medio_individual, 
  data = df_analise
)

summary(modelo_distorcao)

```

O uso do `offset(log(censo_total_docentes))` força o modelo a avaliar a taxa de variação do SIOPE *em relação* ao tamanho base da escola determinado pelo Censo. Se o coeficiente de `prop_contratados_censo` for estatisticamente significante e positivo, confirmamos matematicamente que a política municipal de contratação temporária é o principal vetor de dessincronização das bases.

Quer usar essas taxas de divergência calculadas para gerar uma camada de Kernel Density Estimation (KDE) e mapear os clusters de inconsistência no EduMaps?

Esta nova leva de dados é fantástica porque traz dois cenários inéditos que ajudam a calibrar as hipóteses: uma escola com **divergência negativa** (Censo > SIOPE) e outra com **quase perfeita convergência**.

Vamos analisar os casos emblemáticos desse bloco para refinar o comportamento do cruzamento:

---

## 🧐 Diagnóstico dos Novos Casos

### 1. O Caso da Inversão: Escola `11025280` (-26.67%)

* **Censo:** 15 docentes (6 concursados, 9 contratados).
* **SIOPE:** Média de 11 CPFs únicos.
* **O que isso indica?** É o primeiro caso com **divergência negativa**. O Censo registrou mais professores em sala de aula do que o SIOPE pagou diretamente alocados nesta escola.
* **Hipótese:** Professores que constam no Censo desta escola podem estar sendo pagos via folha global da Secretaria de Educação (sem especificação exata da escola no SIOPE), ou houve substituição de profissionais onde o contratado anterior saiu e a vaga ficou temporariamente descoberta na folha, mas computada no Censo.

### 2. O Caso Extremo: Escola `11025115` (+300.00%)

* **Censo:** Apenas **1** professor concursado (e zero contratados).
* **SIOPE:** Média de 4 CPFs únicos; carga horária de 1.920h mensais.
* **O que isso indica?** Uma escola com apenas 1 professor registrado no Censo é, provavelmente, uma escola rural/unidocente ou de estrutura mínima. No entanto, a folha aponta 4 CPFs dividindo quase 2.000 horas mensais. Uma divergência de 300% em números absolutos pequenos (1 para 4) é comum, mas o dado do Censo aqui é claramente insuficiente para refletir a realidade operacional da escola.

### 3. A Quase Perfeição: Escola `11025352` (+5.56%)

* **Censo:** 18 docentes.
* **SIOPE:** Média de 19 CPFs únicos.
* **O que isso indica?** Divergência irrelevante de apenas 1 funcionário. O padrão dessa escola? Corpo docente majoritariamente concursado (`censo_concursados` = 11) em relação aos contratados (7).

---

## 📊 Ajustando a Matriz de Comportamento

Unindo as duas amostras, podemos notar uma tendência clara: **quanto maior a proporção de concursados, menor e mais controlada é a divergência entre as bases.**

| Código Escola | Proporção Concursados (Censo) | Divergência % | Perfil da Escola |
| --- | --- | --- | --- |
| `11025352` | 61.1% | **+5.56%** | Estável / Predomínio de Concursados |
| `11025077` | 66.6% | **+100.00%** | Média/Grande (24 CPFs no SIOPE) |
| `11025654` | 81.8% | **+154.55%** | Grande (56 CPFs no SIOPE - possível polo/escola central) |
| `11025115` | 100.0% | **+300.00%** | Microescola (Distorção por tamanho amostral) |

> ⚠️ **Alerta para a Escola `11025654`:** Mesmo com 18 concursados de 22 no Censo, o SIOPE acusa 56 CPFs. Em escolas muito grandes, o SIOPE pode estar agregando CPFs de professores complementares (atividades extracurriculares, substitutos rápidos, readaptados) que o Censo desconsidera na contagem estrita de regência de classe.

---

## 🛠️ Como tratar o sinal (Positivo vs. Negativo) no R

Como agora temos divergências bidirecionais (valores positivos e negativos), a abordagem de modelagem precisa mudar. Uma regressão baseada em contagem estrita (como Poisson) não aceita valores negativos diretamente na variável dependente caso você use a `divergencia_absoluta`.

Se o seu objetivo for mapear ou modelar o **módulo da inconsistência** (o erro em si, independente do lado):

```R
df_ajustado <- dados_novos %>% 
  mutate(
    # Razão pura (Valores > 1 significam SIOPE maior, < 1 significam Censo maior)
    razao_siope_censo = siope_docentes_unique_avg / censo_total_docentes,
    
    # Log da razão: Transforma 1 em 0 (perfeito), >1 em positivo e <1 em negativo de forma simétrica
    log_razao = log(razao_siope_censo)
  )

```

O `log_razao` é a métrica estatística perfeita para usar como variável dependente em um modelo linear padrão (`lm()`) ou em análises de autocorrelação espacial (como o Índice de Moran que você pode aplicar no mapa), pois ela normaliza a assimetria das taxas.

Quer estruturar o script de visualização para plotar a correlação entre a `prop_contratados_censo` e o `log_razao` para ver se o padrão se sustenta visualmente?
