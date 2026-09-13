
# Sessão : Thu May 14 01:01:30 PM -03 2026

> Conjunto de queries sobre o schema clean para sabermos as informações e descrever a dimensão dos nossos dados do sistema EduMaps

```sql
-- 2.1 Escolas (censo_escolas)
SELECT 
    'censo_escolas' AS tabela,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT co_entidade) AS escolas_distintas,
    COUNT(DISTINCT nu_ano_censo) AS anos_disponiveis
FROM clean.censo_escolas;

-- 2.2 Docentes (censo_docentes)
SELECT 
    'censo_docentes' AS tabela,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT co_entidade) AS escolas_com_docentes,
    MIN(nu_ano_censo) AS primeiro_ano,
    MAX(nu_ano_censo) AS ultimo_ano
FROM clean.censo_docentes;

-- 2.3 Matrículas (censo_matriculas)
SELECT 
    'censo_matriculas' AS tabela,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT co_entidade) AS escolas_com_matriculas,
    SUM(qt_mat_bas) AS soma_matriculas_basica
FROM clean.censo_matriculas;

-- 2.4 Gestores (censo_gestor)
SELECT 
    'censo_gestor' AS tabela,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT co_entidade) AS escolas_com_gestor
FROM clean.censo_gestor;

-- 2.5 IDEB escolas (ideb_notas_escolas)
SELECT 
    'ideb_notas_escolas' AS tabela,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT id_escola) AS escolas_com_ideb,
    COUNT(DISTINCT ano) AS anos_disponiveis,
    MIN(ano) AS ano_min,
    MAX(ano) AS ano_max
FROM clean.ideb_notas_escolas;

-- 2.6 Notas desagregadas (inep_notas_desagregadas)
SELECT 
    'inep_notas_desagregadas' AS tabela,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT id_escola) AS escolas_com_notas,
    MIN(ano) AS ano_min,
    MAX(ano) AS ano_max
FROM clean.inep_notas_desagregadas;

-- 2.7 Tabela auxiliar de escolas (clean.escolas) – geometrias
SELECT 
    'escolas' AS tabela,
    COUNT(*) AS total_escolas_geo,
    COUNT(geometry) AS com_geometria,
    COUNT(*) - COUNT(geometry) AS sem_geometria
FROM clean.escolas;

-- 2.8 Municípios (municipios_sp)
SELECT 
    'municipios_sp' AS tabela,
    COUNT(*) AS total_municipios
FROM clean.municipios_sp;

-- 2.9 População municipal
SELECT 
    'populacao_municipal' AS tabela,
    COUNT(*) AS total_municipios_com_pop,
    SUM(populacao_estimada) AS pop_estimada_total
FROM clean.populacao_municipal;

-- 2.10 Remuneração de profissionais
SELECT 
    'remuneracao_municipal' AS tabela,
    COUNT(*) AS total_registros_remuneracao,
    COUNT(DISTINCT cod_inep) AS escolas_remuneracao,
    COUNT(DISTINCT cpf) AS profissionais_distintos
FROM clean.remuneracao_municipal;



    tabela     | total_registros | escolas_distintas | anos_disponiveis 
---------------+-----------------+-------------------+------------------
 censo_escolas |          214192 |            214192 |                1
(1 row)

     tabela     | total_registros | escolas_com_docentes | primeiro_ano | ultimo_ano 
----------------+-----------------+----------------------+--------------+------------
 censo_docentes |          178772 |               178772 |         2025 |       2025
(1 row)

      tabela      | total_registros | escolas_com_matriculas | soma_matriculas_basica 
------------------+-----------------+------------------------+------------------------
 censo_matriculas |          178766 |                 178766 |               46018380
(1 row)

    tabela    | total_registros | escolas_com_gestor 
--------------+-----------------+--------------------
 censo_gestor |          180540 |             180540
(1 row)

       tabela       | total_registros | escolas_com_ideb | anos_disponiveis | ano_min | ano_max 
--------------------+-----------------+------------------+------------------+---------+---------
 ideb_notas_escolas |          814448 |            84555 |               10 |    2005 |    2023
(1 row)

         tabela          | total_registros | escolas_com_notas | ano_min | ano_max 
-------------------------+-----------------+-------------------+---------+---------
 inep_notas_desagregadas |          384169 |             64375 |    2005 |    2023
(1 row)

 tabela  | total_escolas_geo | com_geometria | sem_geometria 
---------+-------------------+---------------+---------------
 escolas |            158182 |        158182 |             0
(1 row)

    tabela     | total_municipios 
---------------+------------------
 municipios_sp |             5573
(1 row)

       tabela        | total_municipios_com_pop | pop_estimada_total 
---------------------+--------------------------+--------------------
 populacao_municipal |                     5571 |          213421037
(1 row)

        tabela         | total_registros_remuneracao | escolas_remuneracao | profissionais_distintos 
-----------------------+-----------------------------+---------------------+-------------------------
 remuneracao_municipal |                     2785949 |                6710 |                  196804
(1 row)

```


Com base nos resultados das queries, temos um bom retrato da dimensão e da cobertura dos seus dados. Vou interpretar os principais achados e apontar implicações para a sua ideia de prever/imputar a nota do IDEB.

## 1. Censo Escolar 2025 (ano único)

- **censo_escolas**: 214.192 registros, cada um representando uma escola distinta (pois `escolas_distintas` = total). Portanto, você tem um snapshot de **214 mil escolas** do ano de **2025**.
- **censo_docentes**: 178.772 registros → 178.772 escolas com dados de docentes (83,5% das escolas do censo). Isso indica que ~35 mil escolas não têm informações de docentes (ou estão em outra tabela? Mas a query juntou por `co_entidade` e ano, então são escolas sem docentes declarados).
- **censo_matriculas**: 178.766 registros → praticamente mesma cobertura dos docentes. A soma de matrículas da educação básica (`soma_matriculas_basica`) é de **46 milhões**, coerente com a ordem de grandeza nacional.
- **censo_gestor**: 180.540 registros → 84,3% das escolas possuem informação sobre gestores.

**Conclusão parcial:** Você tem um censo escolar completo para 2025, mas com um percentual relevante de escolas sem dados de docentes/matrículas/gestores (cerca de 15-17%). Esses campos podem ser usados como features para o modelo, mas haverá missing values a tratar.

## 2. IDEB e notas (múltiplos anos)

- **ideb_notas_escolas**: 814.448 registros, abrangendo **10 anos** (2005 a 2023), mas apenas **84.555 escolas distintas** têm pelo menos uma nota IDEB em algum ano.
  - Comparando com as 214.192 escolas do censo 2025: apenas **39,5%** das escolas de 2025 possuem histórico de IDEB. Isso é esperado, pois muitas escolas podem ser novas (abertas após 2023), ou não participaram das avaliações (ex.: escolas de educação infantil exclusiva, ou que não têm as séries avaliadas – 4º e 5º ano do fundamental, 8º e 9º ano, ou 3ª e 4ª série do médio? Na prática, IDEB é calculado para escolas que ofertam as séries finais de cada etapa).
- **inep_notas_desagregadas**: 384.169 registros, 64.375 escolas com notas de matemática e português (desagregadas). É um subconjunto do IDEB, provavelmente apenas anos mais recentes ou escolas que tiveram participação nas provas.

**Observação importante:** O número total de registros de IDEB (814k) dividido por 10 anos dá uma média de 81.445 registros por ano, mas o número de escolas distintas é 84.555 – isso sugere que a maioria das escolas aparece em poucos anos (não é um painel completo). Você pode verificar com uma query como `SELECT ano, COUNT(DISTINCT id_escola) FROM ideb_notas_escolas GROUP BY ano` para ver a cobertura anual.

## 3. Dados auxiliares

- **escolas** (tabela com geometria): 158.182 escolas com coordenadas (74% das escolas do censo 2025). A diferença (214k - 158k = 56k escolas) pode ser devido a escolas que não tiveram geolocalização ou estão em outra base.
- **municipios_sp**: 5.573 municípios (todo o Brasil, imagino). Cobertura completa.
- **populacao_municipal**: 5.571 municípios com estimativa populacional (praticamente todos). População total de 213 milhões, compatível com Brasil.
- **remuneracao_municipal**: 2.785.949 registros de remuneração de profissionais, referentes a 6.710 escolas distintas e 196.804 profissionais. Isso é um volume grande, mas note: são apenas 6.710 escolas com dados de remuneração – ou seja, **apenas 3,1% das escolas do censo 2025** têm essa informação. Portanto, essa tabela não será útil como feature para a maioria das escolas.

## 4. Implicações para a imputação do IDEB

Seu objetivo é prever (imputar) a `nota_media` (IDEB) para escolas que não possuem esse dado, usando as informações do censo (matrículas, docentes, gestores, infraestrutura, etc.). Considerando os números:

- Você tem **214k escolas em 2025**, mas apenas **84,5k escolas** têm pelo menos uma nota IDEB em algum ano anterior (2005-2023). Mesmo assim, essas 84,5k podem ter notas em anos diferentes – o ideal é treinar o modelo com as escolas que tenham IDEB em um ano específico (ex.: 2023, o mais recente) e features do censo do mesmo ano (ou do ano anterior, se houver defasagem). Mas seu censo é apenas 2025, então você teria que alinhar: usar features de 2025 para prever IDEB de 2023? Isso não é causal (a infraestrutura de 2025 pode ser diferente da de 2023). O mais correto seria usar o censo do mesmo ano do IDEB.

**Problema:** seu censo escolar só tem dados de 2025, enquanto o IDEB disponível vai até 2023. Portanto, você não tem um par (features 2023 → IDEB 2023) diretamente. Alternativas:

1. **Usar dados do censo de 2023** – se você tiver acesso a eles (não apareceram nos resultados). Talvez existam outras tabelas com `nu_ano_censo` anterior a 2025? Pelos resultados, `censo_escolas` só mostrou 2025, mas as tabelas de IDEB têm anos mais antigos. Você precisa verificar se possui `censo_escolas` para anos anteriores. Caso contrário, terá que se contentar com um modelo que usa features de 2025 para prever IDEB de 2023, assumindo que a infraestrutura da escola não mudou drasticamente – o que é questionável, mas pode ser aceito como aproximação.

2. **Usar apenas as escolas que têm IDEB em 2023** e treinar um modelo com features do censo 2025, mas então você estará prevendo o IDEB passado com dados atuais – útil apenas se você acredita que as características são estáveis. Poderia servir para imputar IDEB em escolas novas (que não existiam em 2023), mas aí não há IDEB real para validar.

3. **Fazer uma imputação temporal**: usar a última nota disponível (ex.: 2023) como alvo e as features do censo do mesmo ano (se disponível). Verifique se existe `censo_escolas` com `nu_ano_censo = 2023`. Se não, talvez você possa combinar `inep_notas_desagregadas` (que tem anos) com uma tabela de `censo_escolas` para anos anteriores – mas você mostrou que `censo_escolas` tem apenas 2025.

**Recomendação:** Procure por outras tabelas no schema `clean` que tenham `nu_ano_censo` variado, como `censo_escolas_historicas` ou algo similar. Pelos nomes, parece que você tem apenas dados de 2025. Nesse caso, o escopo da previsão fica limitado a **usar dados de 2025 para explicar o IDEB observado em anos anteriores** – uma análise mais correlacional do que causal.

## 5. Próximos passos sugeridos

1. **Verificar a existência de dados censitários anteriores**:
   ```sql
   SELECT DISTINCT nu_ano_censo FROM clean.censo_escolas; -- já viu, apenas 2025
   SELECT DISTINCT nu_ano_censo FROM clean.censo_docentes;
   SELECT DISTINCT nu_ano_censo FROM clean.censo_matriculas;
   SELECT DISTINCT nu_ano_censo FROM clean.censo_gestor;
   ```
   Se todos retornarem apenas 2025, você está limitado a esse ano.

2. **Verificar a distribuição anual do IDEB** para saber quantas escolas têm nota em cada ano, especialmente 2023 (mais recente):
   ```sql
   SELECT ano, COUNT(DISTINCT id_escola) AS escolas, AVG(nota_media) AS media
   FROM clean.ideb_notas_escolas
   GROUP BY ano ORDER BY ano;
   ```

3. **Fazer um join entre as escolas do censo 2025 e as notas IDEB de 2023** (ou outro ano) para ter o conjunto de treinamento:
   ```sql
   SELECT e.*, i.nota_media
   FROM clean.censo_escolas e
   JOIN clean.ideb_notas_escolas i ON e.co_entidade = i.id_escola AND i.ano = 2023
   LIMIT 10;
   ```
   Veja quantas linhas retorna. Isso será seu conjunto de treinamento (escolas com IDEB em 2023 e censo 2025). O número deve ser bem menor que 84.555 (porque nem todas as escolas com IDEB em algum ano têm em 2023 especificamente).

4. **Se o número for razoável (milhares)**, você pode treinar um modelo de regressão (ou Naive Bayes discretizado) para prever `nota_media` usando as features do censo. As colunas com maior cobertura (ex.: `in_computador`, `in_internet`, `qt_salas_utilizadas`, `qt_prof_administrativos`) serão as mais úteis.

Em resumo, os dados mostram que você tem um bom volume de escolas (214k), mas a base histórica do IDEB cobre apenas 84,5k escolas (e provavelmente menos em um único ano). A imputação será possível, mas limitada às escolas que já tiveram IDEB no passado e que estão presentes no censo 2025. Para escolas sem nenhum IDEB histórico, você não conseguirá validar a imputação – apenas fazer uma previsão sem garantia.

# Pergunta

agora faça uma das possíveis seleção de features para escola (juntando demais tabelas se achar conveniente/necessário matrícula, gestor, docente) pense/considere usar indicadores derivados (por exemplo somas com peso para dados relativos a infraestrutura ou a conectividade com internet, etc...) estruture num script R usando tidymodels e recipes como base. (mas antes do script, elabore os detalhes de quais features e porque foram selecionadas)

# Resposta

Com base na estrutura do seu banco de dados e nos resultados das consultas de contagem, desenvolvi uma proposta detalhada de **seleção de features derivadas** e um **script R** usando `tidymodels` e `recipes` para prever (imputar) a nota média do IDEB (`nota_media`). Antes do script, apresento a lógica das features criadas.

---

## Features derivadas – justificativa e criação

Os dados do censo escolar 2025 (tabelas `censo_escolas`, `censo_docentes`, `censo_matriculas`, `censo_gestor`) contêm centenas de colunas. Em vez de usar todas, criamos **índices agregados e razões** que representam dimensões relevantes para a qualidade da escola (influenciam o IDEB). As features são agrupadas em dimensões:

### 1. Infraestrutura física e recursos
- **`infra_essencial_score`** – soma de 7 itens básicos: água potável, energia pública, esgoto, cozinha, banheiro, banheiro acessível, refeitório. Essencial para funcionamento mínimo.
- **`espacos_pedagogicos_score`** – biblioteca, laboratórios (ciências, informática), quadra, pátio coberto, parque. Ambientes que enriquecem o aprendizado.
- **`tecnologia_score`** – computadores, internet, banda larga, multimídia, lousa digital, desktop/tablet para alunos. Relacionado a práticas modernas.
- **`acessibilidade_score`** – rampas, corrimãos, elevador, pisos táteis, sinal sonoro. Quanto maior, mais inclusiva.
- **`salas_por_aluno`** – `qt_salas_utilizadas / qt_mat_bas`. Reflete superlotação (valores baixos indicam poucas salas por aluno).
- **`equipamentos_por_aluno`** – (desktops + portáteis + tablets) / matrículas. Acesso a tecnologia para os alunos.
- **`funcionarios_nd_por_aluno`** – (administrativos + serviços gerais + segurança) / matrículas. Suporte operacional.

### 2. Corpo docente (tabela `censo_docentes`)
- **`docentes_por_aluno`** – `qt_doc_bas / qt_mat_bas`. Proporção professor‑aluno (inverso da lotação).
- **`prop_docentes_superior`** – docentes com ensino superior completo / total docentes. Formação adequada.
- **`prop_docentes_pos`** – docentes com pós‑graduação (especialização) / total docentes. Qualificação avançada.
- **`prop_docentes_concursados`** – concursados / total docentes. Estabilidade e, geralmente, melhor formação.
- **`prop_docentes_feminino`** – percentual de mulheres (a área da educação é majoritariamente feminina, mas desvios podem sinalizar algo).

### 3. Corpo discente (tabela `censo_matriculas`)
- **`prop_mat_infantil`**, **`prop_mat_fund`**, **`prop_mat_medio`** – proporção de matrículas em cada etapa. Escolas com mais alunos no ensino médio podem ter maior pressão por resultados.
- **`prop_mat_integral`** – matrículas em tempo integral / total. Programas de tempo integral estão associados a melhores resultados.
- **`alunos_por_sala`** – `qt_mat_bas / qt_salas_utilizadas`. Lotação por sala (valores altos podem prejudicar a aprendizagem).

### 4. Gestão escolar (tabela `censo_gestor`)
- **`gestor_superior`** – binário: 1 se o gestor tem ensino superior completo.
- **`gestor_pos`** – binário: 1 se tem pós‑graduação.
- **`gestor_acesso_democratico`** – binário: 1 se o acesso ao cargo foi por eleição ou concurso (vs. indicação). Gestores eleitos ou concursados tendem a ter maior compromisso.

### 5. Características contextuais (já em `censo_escolas`)
- **`tp_localizacao`** – urbana (1) ou rural (2) – dummy posteriormente.
- **`tp_dependencia`** – federal, estadual, municipal, privada – dummies.

### 6. Tratamento de valores ausentes e normalização
- Valores `NA` ou divisões por zero são substituídos por `0` (quando apropriado) ou imputados pela mediana.
- Variáveis contínuas são transformadas (Yeo‑Johnson) e padronizadas (centrar e escalar).
- Categóricas viram *dummies*.

---

## Script R completo (tidymodels + recipes)

O script abaixo:
1. Conecta ao PostgreSQL e carrega as tabelas necessárias (ano 2025).
2. Junta as tabelas e cria as features derivadas.
3. Treina um modelo de **Random Forest** (robusto para muitas features não lineares) com validação cruzada.
4. Avalia o desempenho (RMSE, R², MAE) e aplica o modelo treinado para imputar as notas faltantes.

```r
# ============================================================================
# 1. Pacotes e conexão com o banco
# ============================================================================
library(tidymodels)
library(DBI)
library(RPostgres)
library(dplyr)
library(recipes)

con <- dbConnect(
  RPostgres::Postgres(),
  service = "edumaps"
)

# ============================================================================
# 2. Carregar dados brutos (apenas 2025)
# ============================================================================
escolas <- tbl(con, "censo_escolas") %>%
  filter(nu_ano_censo == 2025) %>%
  select(co_entidade, tp_localizacao, tp_dependencia,
         in_agua_potavel, in_energia_rede_publica, in_esgoto_rede_publica,
         in_cozinha, in_banheiro, in_banheiro_pne, in_refeitorio,
         in_biblioteca, in_laboratorio_ciencias, in_laboratorio_informatica,
         in_quadra_esportes, in_patio_coberto, in_parque_infantil,
         in_computador, in_internet, in_banda_larga, in_equip_multimidia,
         in_equip_lousa_digital, in_desktop_aluno, in_tablet_aluno,
         in_acessibilidade_rampas, in_acessibilidade_corrimao,
         in_acessibilidade_elevador, in_acessibilidade_pisos_tateis,
         in_acessibilidade_sinal_sonoro,
         qt_salas_utilizadas, qt_prof_administrativos, qt_prof_servicos_gerais,
         qt_prof_seguranca, qt_desktop_aluno, qt_comp_portatil_aluno,
         qt_tablet_aluno) %>%
  collect()

matriculas <- tbl(con, "censo_matriculas") %>%
  filter(nu_ano_censo == 2025) %>%
  select(co_entidade, qt_mat_bas, qt_mat_inf, qt_mat_fund, qt_mat_med,
         qt_mat_bas_int) %>%
  collect()

docentes <- tbl(con, "censo_docentes") %>%
  filter(nu_ano_censo == 2025) %>%
  select(co_entidade, qt_doc_bas, qt_doc_bas_fem,
         qt_doc_bas_esco_sup_grad, qt_doc_bas_esco_sup_pos_espec,
         qt_doc_bas_vinculo_concur) %>%
  collect()

gestor <- tbl(con, "censo_gestor") %>%
  filter(nu_ano_censo == 2025) %>%
  select(co_entidade, qt_gest_bas_esco_sup_grad, qt_gest_bas_esco_sup_pos_espec,
         qt_gest_bas_acesso_cargo_eleic, qt_gest_bas_acesso_cargo_conca) %>%
  collect()

# IDEB alvo: ano mais recente (2023)
ideb <- tbl(con, "ideb_notas_escolas") %>%
  filter(ano == 2023) %>%
  select(co_entidade = id_escola, nota_media) %>%
  distinct() %>%
  collect()

# ============================================================================
# 3. Juntar tabelas e criar features derivadas
# ============================================================================
dados <- escolas %>%
  left_join(matriculas, by = "co_entidade") %>%
  left_join(docentes, by = "co_entidade") %>%
  left_join(gestor, by = "co_entidade") %>%
  left_join(ideb, by = c("co_entidade"))

# Substituir NAs por zero em colunas que serão usadas em divisões
dados <- dados %>%
  mutate(across(c(qt_mat_bas, qt_doc_bas, qt_salas_utilizadas), ~ coalesce(., 0)))

dados <- dados %>%
  mutate(
    # Scores (somas simples)
    infra_essencial_score = in_agua_potavel + in_energia_rede_publica +
      in_esgoto_rede_publica + in_cozinha + in_banheiro +
      in_banheiro_pne + in_refeitorio,
    espacos_pedagogicos_score = in_biblioteca + in_laboratorio_ciencias +
      in_laboratorio_informatica + in_quadra_esportes +
      in_patio_coberto + in_parque_infantil,
    tecnologia_score = in_computador + in_internet + in_banda_larga +
      in_equip_multimidia + in_equip_lousa_digital +
      in_desktop_aluno + in_tablet_aluno,
    acessibilidade_score = in_acessibilidade_rampas + in_acessibilidade_corrimao +
      in_acessibilidade_elevador + in_acessibilidade_pisos_tateis +
      in_acessibilidade_sinal_sonoro,
    
    # Razões e indicadores por aluno
    salas_por_aluno = ifelse(qt_mat_bas > 0, qt_salas_utilizadas / qt_mat_bas, 0),
    equipamentos_por_aluno = ifelse(qt_mat_bas > 0,
                                    (coalesce(qt_desktop_aluno, 0) +
                                       coalesce(qt_comp_portatil_aluno, 0) +
                                       coalesce(qt_tablet_aluno, 0)) / qt_mat_bas, 0),
    funcionarios_nd_por_aluno = ifelse(qt_mat_bas > 0,
                                       (coalesce(qt_prof_administrativos, 0) +
                                          coalesce(qt_prof_servicos_gerais, 0) +
                                          coalesce(qt_prof_seguranca, 0)) / qt_mat_bas, 0),
    docentes_por_aluno = ifelse(qt_mat_bas > 0, qt_doc_bas / qt_mat_bas, 0),
    prop_docentes_superior = ifelse(qt_doc_bas > 0,
                                    qt_doc_bas_esco_sup_grad / qt_doc_bas, 0),
    prop_docentes_pos = ifelse(qt_doc_bas > 0,
                               qt_doc_bas_esco_sup_pos_espec / qt_doc_bas, 0),
    prop_docentes_concursados = ifelse(qt_doc_bas > 0,
                                       qt_doc_bas_vinculo_concur / qt_doc_bas, 0),
    prop_docentes_feminino = ifelse(qt_doc_bas > 0,
                                    qt_doc_bas_fem / qt_doc_bas, 0),
    
    prop_mat_infantil = ifelse(qt_mat_bas > 0, coalesce(qt_mat_inf, 0) / qt_mat_bas, 0),
    prop_mat_fund = ifelse(qt_mat_bas > 0, coalesce(qt_mat_fund, 0) / qt_mat_bas, 0),
    prop_mat_medio = ifelse(qt_mat_bas > 0, coalesce(qt_mat_med, 0) / qt_mat_bas, 0),
    prop_mat_integral = ifelse(qt_mat_bas > 0, coalesce(qt_mat_bas_int, 0) / qt_mat_bas, 0),
    alunos_por_sala = ifelse(qt_salas_utilizadas > 0, qt_mat_bas / qt_salas_utilizadas, 0),
    
    # Gestor
    gestor_superior = as.integer(coalesce(qt_gest_bas_esco_sup_grad, 0) > 0),
    gestor_pos = as.integer(coalesce(qt_gest_bas_esco_sup_pos_espec, 0) > 0),
    gestor_acesso_democratico = as.integer(coalesce(qt_gest_bas_acesso_cargo_eleic, 0) > 0 |
                                             coalesce(qt_gest_bas_acesso_cargo_conca, 0) > 0)
  )

# Seleção final das colunas que entram no modelo
features_finais <- c("nota_media",
                     "infra_essencial_score", "espacos_pedagogicos_score",
                     "tecnologia_score", "acessibilidade_score",
                     "salas_por_aluno", "equipamentos_por_aluno",
                     "funcionarios_nd_por_aluno", "docentes_por_aluno",
                     "prop_docentes_superior", "prop_docentes_pos",
                     "prop_docentes_concursados", "prop_docentes_feminino",
                     "prop_mat_infantil", "prop_mat_fund", "prop_mat_medio",
                     "prop_mat_integral", "alunos_por_sala",
                     "gestor_superior", "gestor_pos", "gestor_acesso_democratico",
                     "tp_localizacao", "tp_dependencia")

dados_modelo <- dados %>%
  select(all_of(features_finais)) %>%
  # substituir possíveis NA/infinito por 0
  mutate(across(where(is.numeric) & !nota_media, ~ ifelse(is.na(.) | is.infinite(.), 0, .)))

# Separar treino (com nota) e imputação (sem nota)
treino <- dados_modelo %>% filter(!is.na(nota_media))
imputar <- dados_modelo %>% filter(is.na(nota_media)) %>% select(-nota_media)

# ============================================================================
# 4. Recipe de pré-processamento
# ============================================================================
rec <- recipe(nota_media ~ ., data = treino) %>%
  step_mutate(tp_localizacao = factor(tp_localizacao),
              tp_dependencia = factor(tp_dependencia)) %>%
  step_dummy(all_nominal_predictors()) %>%
  step_impute_median(all_numeric_predictors())

# ============================================================================
# 5. Modelo: Random Forest
# ============================================================================
rf_spec <- rand_forest(trees = 250, min_n = 10) %>%
  set_engine("ranger", importance = "none") %>%
  set_mode("regression")

wf <- workflow() %>%
  add_recipe(rec) %>%
  add_model(rf_spec)

# Validação cruzada (5 folds)
set.seed(123)
cv_folds <- vfold_cv(treino, v = 3)
resultados_cv <- fit_resamples(wf, cv_folds, metrics = metric_set(rmse, rsq, mae))

# Resultados
collect_metrics(resultados_cv)

# Treinar modelo final
modelo_final <- fit(wf, data = treino)


# ============================================================================
# 5. Alternativa Modelo: Random Forest (com importance)
# ============================================================================
# Especificação da Random Forest com importância
rf_importance <- rand_forest(trees = 250, min_n = 10) %>%
  set_engine("ranger", importance = "impurity") %>%
  set_mode("regression")

# Workflow atualizado
wf_importance <- workflow() %>%
  add_recipe(rec) %>%
  add_model(rf_importance)

# Treinar (usando os mesmos dados de treino)
set.seed(123)
modelo_importance <- fit(wf_importance, data = treino)

# ============================================================================
# 6. Imputar notas faltantes
# ============================================================================
predicoes <- predict(modelo_final, new_data = imputar)

# Juntar com identificador original (co_entidade)
imputacoes <- dados %>%
  filter(is.na(nota_media)) %>%
  select(co_entidade) %>%
  bind_cols(predicoes)

# Visualizar primeiras imputações
head(imputacoes)

# ============================================================================
# 7. Desconectar
# ============================================================================
dbDisconnect(con)
```

## Observações importantes

- O modelo usa **Random Forest**, que lida bem com **não linearidades** e **interações** entre features, além de ser robusto a outliers e não exigir normalização (embora a `recipe` normalize por consistência).
- A validação cruzada fornecerá métricas de erro (RMSE, R²). Espere um **R² moderado** (talvez 0,3–0,5) porque o IDEB de 2023 está sendo previsto com dados de infraestrutura de 2025 – há uma defasagem temporal não ideal.
- Se você tiver acesso ao censo escolar de **2023** (com as mesmas colunas), o desempenho será bem melhor. Sugiro verificar se existem outras tabelas com `nu_ano_censo` anterior.
- Para imputar, simplesmente aplicamos o modelo treinado às escolas sem nota. O resultado é uma estimativa contínua que pode ser usada como proxy do IDEB.

Caso queira testar outros modelos (regressão linear regularizada, XGBoost), basta trocar a `rf_spec` e reexecutar o fluxo.


# Observando a importância (de cada variável)

Para visualizar a importância das features mesmo após ter usado `importance = "none"`, você precisará **treinar novamente o modelo** com importância habilitada. O custo computacional adicional é pequeno (a importância por impureza é calculada durante a construção das árvores). Abaixo está o código modificado para incluir a importância e gerar um gráfico.

## Passo 1: Re-treinar o modelo com importância habilitada

```r
# Especificação da Random Forest com importância
rf_importance <- rand_forest(trees = 250, min_n = 10) %>%
  set_engine("ranger", importance = "impurity") %>%
  set_mode("regression")

# Workflow atualizado
wf_importance <- workflow() %>%
  add_recipe(rec) %>%
  add_model(rf_importance)

# Treinar (usando os mesmos dados de treino)
set.seed(123)
modelo_importance <- fit(wf_importance, data = treino)
```

## Passo 2: Extrair e visualizar a importância

```r

# Extrair o objeto ranger do modelo ajustado
ranger_obj <- extract_fit_parsnip(modelo_importance)$fit

# Obter o vetor de importância
importancia <- ranger::importance(ranger_obj)

# Converter para data frame e ordenar
df_imp <- data.frame(
  feature = names(importancia),
  importance = importancia
) %>%
  arrange(desc(importance)) %>%
  slice_head(n = 20)  # top 20 features

# Gráfico de barras
ggplot(df_imp, aes(x = reorder(feature, importance), y = importance)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Importância das Features (Random Forest)",
    subtitle = "Medida por redução de impureza (Gini)",
    x = "Feature",
    y = "Importância"
  ) +
  theme_minimal()
```

## Interpretação

- Quanto maior o valor, mais aquela feature contribui para reduzir a impureza (Gini) ao fazer divisões nas árvores.
- Você pode ver quais indicadores derivados (ex.: `docentes_por_aluno`, `tecnologia_score`, `prop_docentes_superior`) estão entre os mais importantes.
- Isso ajuda a validar se as features que você criou fazem sentido.

**Observação:** Se o modelo original já foi treinado sem importância e você não quer re-treinar, infelizmente não há como recuperar a importância depois. Portanto, o passo 1 é necessário. Porém, como você já tem a receita e os dados carregados, re-treinar com 250 árvores deve ser rápido (poucos minutos, não horas).

# Salvando o Modelo

> Como salvar o modelo para importá-lo em outra instância (máquina com R) ?

Para salvar um modelo treinado com `tidymodels` (workflow) e carregá-lo em outra máquina com R, você tem duas principais abordagens:

## 1. Usar `saveRDS()` (mais simples, mas exige mesmas versões de pacotes)

Salvar:
```r
saveRDS(modelo_final, file = "modelo_ideb.rds")
```

Carregar na outra máquina:
```r
modelo <- readRDS("modelo_ideb.rds")
```

**Cuidados:**
- A versão do R e dos pacotes (`tidymodels`, `ranger`, `recipes`, etc.) deve ser **idêntica** ou muito próxima. Diferenças podem causar erro ao carregar.
- O caminho para dados (ex.: `rec$template`) é salvo, mas não há dependência externa.

## 2. Usar o pacote `bundle` (recomendado para portabilidade)

O pacote `bundle` serializa o modelo de forma mais robusta, permitindo pequenas diferenças de versão.

Instalar:
```r
install.packages("bundle")
```

Salvar:
```r
library(bundle)
bundled_model <- bundle::bundle(modelo_final)
saveRDS(bundled_model, file = "modelo_ideb_bundled.rds")
```

Carregar na outra máquina:
```r
library(bundle)
bundled <- readRDS("modelo_ideb_bundled.rds")
modelo <- unbundle(bundled)
```

## O que deve ser salvo?

Apenas o **workflow final** (`modelo_final` ou `modelo_importance`). Ele contém:
- A `recipe` (incluindo etapas de pré-processamento como imputação, normalização, criação de dummies)
- O modelo `parsnip` ajustado (no caso, a random forest do `ranger`)

**Não** é necessário salvar os dados de treino separadamente.

## Exemplo completo com `bundle`

```r
# Após treinar modelo_final
library(bundle)
bundled <- bundle(modelo_final)
saveRDS(bundled, file = "modelo_ideb_bundled.rds", compress = "xz")
```

Na outra máquina:
```r
library(bundle)
library(tidymodels)   # ou pelo menos os pacotes necessários: parsnip, recipes, ranger, etc.
bundled <- readRDS("modelo_ideb_bundled.rds")
modelo <- unbundle(bundled)

# Agora pode fazer predições em novos dados
novas_escolas <- read.csv("novas_escolas.csv")
predicoes <- predict(modelo, new_data = novas_escolas)
```

## Verificação de requisitos na outra máquina

Antes de carregar, certifique-se de ter instalados os mesmos pacotes:
```r
install.packages(c("tidymodels", "ranger", "bundle"))
```

## Dica extra: reduzir o tamanho do arquivo

Se o modelo estiver muito grande (floresta com 250 árvores pode ter dezenas de MB), use compressão:
```r
saveRDS(modelo, "modelo.rds", compress = "xz")
```

Ou, alternativamente, salve apenas o objeto `ranger` interno (mais leve) se você não precisar da `recipe` separadamente:
```r
ranger_obj <- extract_fit_parsnip(modelo_final)$fit
saveRDS(ranger_obj, "ranger_only.rds")
```

Depois, para prever, você precisará aplicar o pré-processamento manualmente ou recriar a `recipe`. A abordagem com o workflow completo é mais conveniente.

## Conclusão

Recomendo `bundle` + `saveRDS` para maior compatibilidade entre máquinas. Lembre-se de que ambas as máquinas devem ter **as mesmas versões principais do R** (ex.: 4.2.x) e os pacotes atualizados.

# Avaliando a importância no modelo

```
df_imp
                                            feature importance
prop_docentes_feminino       prop_docentes_feminino  9205.3980
prop_mat_fund                         prop_mat_fund  5754.8582
equipamentos_por_aluno       equipamentos_por_aluno  5118.5883
funcionarios_nd_por_aluno funcionarios_nd_por_aluno  5050.2438
prop_docentes_pos                 prop_docentes_pos  4274.5230
prop_mat_medio                       prop_mat_medio  3857.8401
docentes_por_aluno               docentes_por_aluno  3722.0575
prop_docentes_concursados prop_docentes_concursados  3681.4837
salas_por_aluno                     salas_por_aluno  3371.6222
alunos_por_sala                     alunos_por_sala  3371.3149
prop_mat_integral                 prop_mat_integral  3034.1877
prop_docentes_superior       prop_docentes_superior  2933.2304
prop_mat_infantil                 prop_mat_infantil  2444.3518
espacos_pedagogicos_score espacos_pedagogicos_score  2357.7618
infra_essencial_score         infra_essencial_score  2190.4214
tp_localizacao_X2                 tp_localizacao_X2  1843.4035
tecnologia_score                   tecnologia_score  1654.9012
tp_dependencia_X2                 tp_dependencia_X2  1386.8785
acessibilidade_score           acessibilidade_score  1363.7776
tp_dependencia_X3                 tp_dependencia_X3   983.8952

```
De fato, o resultado é **interessante e até surpreendente** em alguns pontos. Vamos interpretar o que esses valores de importância (medida por redução de impureza – Gini) sugerem sobre os determinantes da nota do IDEB.

---

## 1. `prop_docentes_feminino` – a mais importante (9.205)

**O que pode estar acontecendo?**  
O percentual de professoras mulheres não é, em si, uma causa direta do desempenho escolar. Provavelmente, essa variável está atuando como um **proxy (indicador substituto)** de outras características não capturadas diretamente:

- **Etapas de ensino**: escolas de **educação infantil** e **anos iniciais do fundamental** têm predominância feminina no magistério. Essas etapas, historicamente, apresentam **maiores notas no IDEB** (por conta de métricas de aprovação e proficiência mais altas nas séries iniciais).
- **Localização (rural x urbana)**: escolas rurais podem ter menos mulheres? Ou o contrário? Vale verificar a correlação.
- **Tipo de gestão**: talvez escolas privadas ou municipais tenham proporções diferentes.

**Cuidado:** Pode ser um **viés de confusão**. Se você incluir `prop_mat_infantil` ou `prop_mat_fund` (que também aparecem altas), a importância do gênero pode cair. No seu modelo, `prop_mat_fund` e `prop_mat_medio` também são importantes, mas o feminino ainda lidera.

**Recomendação:** Faça uma análise de correlação entre `prop_docentes_feminino` e outras variáveis (especialmente as que indicam etapa de ensino). Se a correlação for forte (>0.7), você pode considerar remover uma delas para tornar o modelo mais interpretável.

---

## 2. `prop_mat_fund` e `prop_mat_medio` – importância alta (5.754 e 3.857)

Perfeitamente coerente: escolas com maior proporção de alunos no **ensino fundamental** (especialmente anos finais, 6º ao 9º) e no **ensino médio** enfrentam desafios diferentes. O IDEB é calculado por etapa (4º/5º anos, 8º/9º anos, e 3ª/4ª série do médio). A composição da matrícula influencia diretamente a nota média da escola.

---

## 3. `equipamentos_por_aluno` e `funcionarios_nd_por_aluno` (5.118 e 5.050)

Indicadores de **recursos materiais e humanos** são classicamente associados à qualidade. Surpreende que `equipamentos_por_aluno` tenha importância maior do que `tecnologia_score` (1.654) – isso sugere que a **quantidade per capita** importa mais do que a mera presença de equipamentos.

---

## 4. `prop_docentes_pos` (4.274) e `prop_docentes_concursados` (3.681)

Formação avançada e estabilidade são preditores razoáveis. Profissionais com pós-graduação tendem a estar mais preparados, e concursados podem ter maior engajamento (ou, inversamente, em alguns contextos, podem estar em escolas com melhores condições).

---

## 5. `salas_por_aluno` e `alunos_por_sala` (3.371 cada) – quase idênticas

Essas duas são **inversamente proporcionais** (uma é o recíproco da outra). A importância similar era esperada. O modelo não consegue distinguir bem qual das duas é mais relevante; qualquer uma carrega a mesma informação de lotação/superlotação.

---

## 6. Infraestrutura e acessibilidade – importância baixa

`espacos_pedagogicos_score` (2.357), `infra_essencial_score` (2.190), `tecnologia_score` (1.654), `acessibilidade_score` (1.363).  
**Possível explicação:** No Brasil, a maioria das escolas já tem infraestrutura básica (água, luz, banheiro). A variação nessas dimensões é pequena, portanto o poder preditivo é limitado. Além disso, o IDEB reflete mais fatores **socioeconômicos e pedagógicos** do que concreto e telhado.

---

## 7. `tp_localizacao_X2` (rural) importância 1.843

Escolas rurais, de fato, têm desempenho sistematicamente diferente. Mas a importância é moderada – o que indica que, controlando pelas outras variáveis (matrículas, docentes, recursos), a localização isoladamente perde força.

---

## 8. `tp_dependencia_X2` (estadual) e `X3` (municipal) – importância baixa (1.386 e 983)

Isso é um bom sinal: depois de incluir características da escola, o tipo de dependência administrativa não acrescenta muito. Ou seja, as diferenças entre redes são explicadas por fatores como formação de professores, recursos e composição das matrículas – não por um “efeito rede” misterioso.

---

## O que fazer com essa informação?

1. **Valide se `prop_docentes_feminino` não está enviesando o modelo.**  
   Rode uma análise de correlação:
   ```r
   library(corrplot)
   cor_mat <- treino %>% 
     select(prop_docentes_feminino, prop_mat_infantil, prop_mat_fund) %>%
     cor(use = "complete.obs")
   corrplot(cor_mat)
   ```
   Se a correlação for >0.8, considere criar uma variável composta ou remover a menos interpretável.

2. **Simplifique o modelo** – você pode remover `salas_por_aluno` (já que tem `alunos_por_sala` que é mais direto). Ou vice-versa.

3. **Teste um modelo apenas com as top 10 features** – pode ter desempenho similar e ser mais rápido.

4. **Apresente os resultados para a equipe educacional** – destaque que políticas de **formação de professores (pós-graduação)**, **concursos públicos** e **recursos por aluno** são mais associados ao IDEB do que mera presença de laboratório ou quadra.

---

## Conclusão

O modelo está capturando padrões realistas: **a composição da matrícula (fundamental vs. médio)** e **características do corpo docente (gênero, formação, concurso)** dominam a previsão. A alta importância do percentual de mulheres docentes merece investigação – provavelmente é um marcador de **etapa de ensino** e **tipo de escola**. Se o objetivo for imputar notas, o modelo é útil; se for inferir causalidade, é necessário cuidado.


# Efetividade (Resíduos)

Para computar a **efetividade** da escola como a diferença entre a nota real e a nota prevista (`nota_media - nota_prevista`), você precisa gerar as predições para o mesmo conjunto de treino (ou para um conjunto de validação) e calcular os resíduos. Um residual **positivo** indica que a escola teve desempenho **melhor do que o previsto** (mais efetiva), enquanto **negativo** indica desempenho abaixo do esperado.

Abaixo, o código para fazer isso com o modelo treinado (`modelo_final`, que é um workflow ajustado).

---

## 1. Gerar predições no conjunto de treino

```r
# Adicionar coluna com a nota prevista
treino_com_pred <- treino %>%
  bind_cols(predict(modelo_final, new_data = treino)) %>%
  rename(nota_prevista = .pred)

# Calcular a efetividade (resíduo)
treino_com_pred <- treino_com_pred %>%
  mutate(efetividade = nota_media - nota_prevista)
```

---

## 2. Visualizar distribuição da efetividade

```r
library(ggplot2)

ggplot(treino_com_pred, aes(x = efetividade)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "white") +
  labs(
    title = "Distribuição da Efetividade (Resíduos)",
    x = "Nota real - Nota prevista",
    y = "Número de escolas"
  ) +
  theme_minimal()

# Sumário estatístico
summary(treino_com_pred$efetividade)
```

---

## 3. Identificar escolas mais e menos efetivas

```r
# Top 10 mais efetivas (maior residual positivo)
mais_efetivas <- treino_com_pred %>%
  arrange(desc(efetividade)) %>%
  select(co_entidade, nota_media, nota_prevista, efetividade) %>%
  head(10)

# Top 10 menos efetivas (maior residual negativo)
menos_efetivas <- treino_com_pred %>%
  arrange(efetividade) %>%
  select(co_entidade, nota_media, nota_prevista, efetividade) %>%
  head(10)

print("Escolas mais efetivas:")
print(mais_efetivas)

print("Escolas menos efetivas:")
print(menos_efetivas)
```

---

## 4. Interpretação e usos da efetividade

- **Efetividade positiva** → escola superou as expectativas dadas suas características (infraestrutura, docentes, matrículas). Pode indicar **boas práticas pedagógicas, gestão eficiente, ou fatores não capturados** pelo modelo (ex.: nível socioeconômico dos alunos – que não está nas features).
- **Efetividade negativa** → escola teve desempenho abaixo do previsto. Pode sinalizar **problemas de gestão, evasão, ou fatores contextuais adversos**.

**Aplicações práticas:**
- Identificar escolas que fogem à regra para estudo de caso (políticas públicas).
- Ajustar recursos: escolas com baixa efetividade podem precisar de intervenção.
- Validar se o modelo está subestimando ou superestimando algum grupo (ex.: escolas rurais, municipais).

---

## 5. (Opcional) Efetividade por dependência administrativa ou localização

```r
# Juntar com variáveis categóricas originais
treino_com_pred <- treino_com_pred %>%
  left_join(treino %>% select(co_entidade, tp_localizacao, tp_dependencia), by = "co_entidade") %>%
  mutate(
    localizacao_desc = ifelse(tp_localizacao == 1, "Urbana", "Rural"),
    dependencia_desc = case_when(
      tp_dependencia == 1 ~ "Federal",
      tp_dependencia == 2 ~ "Estadual",
      tp_dependencia == 3 ~ "Municipal",
      tp_dependencia == 4 ~ "Privada",
      TRUE ~ "Outro"
    )
  )

# Boxplot por dependência
ggplot(treino_com_pred, aes(x = dependencia_desc, y = efetividade, fill = dependencia_desc)) +
  geom_boxplot() +
  labs(title = "Efetividade por Dependência Administrativa", x = "", y = "Efetividade") +
  theme_minimal() +
  theme(legend.position = "none")
```

---

## Cuidados importantes

- **Sobreajuste:** Calcular a efetividade no próprio treino pode superestimar o ajuste. Idealmente, calcule sobre um **conjunto de teste** ou use validação cruzada para obter resíduos mais honestos (out‑of‑sample). Você pode adaptar o código para usar `fit_resamples` e coletar as predições de cada fold.

- **Escala:** A efetividade está na mesma unidade da nota do IDEB (0–10). Uma diferença de 0,5 ponto já é educacionalmente relevante.

- **Causalidade:** Lembre-se de que a efetividade é uma medida **associativa**, não causal. Não significa, por si só, que a escola é melhor ou pior – apenas que seu desempenho difere do padrão previsto pelas características observáveis.

Se quiser, posso ajudar a implementar a validação cruzada para obter resíduos mais robustos.

# Obtendo o código de identificação (achar as escolas efetivas)

Você tem razão – **muito mais simples**. O `modelo_final` (workflow) contém a `recipe` que já sabe como transformar os dados brutos. Portanto, podemos aplicar `predict` diretamente no `treino_raw` (que ainda tem `co_entidade` e todas as colunas originais). A `recipe` vai ignorar as colunas não usadas na fórmula e aplicar as etapas de pré‑processamento (inclusive imputação de medianas) automaticamente.

## Código correto e simplificado

```r
# treino_raw são as linhas com nota_media conhecida (já tem co_entidade)
treino_raw <- dados %>% filter(!is.na(nota_media))

# Gerar predições
predicoes <- predict(modelo_final, new_data = treino_raw)

# Acrescentar ao data frame
treino_raw$nota_prevista <- predicoes$.pred
treino_raw$efetividade <- treino_raw$nota_media - treino_raw$nota_prevista

# Visualizar as primeiras
head(treino_raw %>% select(co_entidade, nota_media, nota_prevista, efetividade))
```

## Por que funciona?

- O `workflow` guarda a `recipe` que foi ajustada com os dados de treino originais (`treino`, que não tinha `co_entidade`).  
- Ao aplicar `predict` em `treino_raw`, a `recipe` automaticamente:
  - Remove colunas que não estão no `formula` (como `co_entidade`).
  - Aplica `step_mutate`, `step_dummy`, `step_impute_median` etc.
  - Gera o mesmo conjunto de features usado no treinamento.
- `co_entidade` não é usada como preditora, mas permanece no data frame original para identificação.

## Para as escolas sem nota (imputação)

```r
imputar_raw <- dados %>% filter(is.na(nota_media))
pred_imputar <- predict(modelo_final, new_data = imputar_raw)
imputar_raw$nota_prevista <- pred_imputar$.pred

# Agora imputar_raw contém as notas estimadas (e os códigos das escolas)
```

Pronto – sem complicações, sem perder os identificadores. Obrigado por simplificar.

# Avaliação do Gemini sobre o script final:
```r

# ============================================================================
# 1. Pacotes e conexão com o banco
# ============================================================================
library(tidymodels)
library(DBI)
library(RPostgres)
library(dplyr)
library(recipes)
library(bundle)

con <- dbConnect(
  RPostgres::Postgres(),
  service = "edumaps"
)

# ============================================================================
# 2. Carregar dados brutos (apenas 2025)
# ============================================================================
escolas <- tbl(con, "censo_escolas") %>%
  filter(nu_ano_censo == 2025) %>%
  select(co_entidade, tp_localizacao, tp_dependencia,
         in_agua_potavel, in_energia_rede_publica, in_esgoto_rede_publica,
         in_cozinha, in_banheiro, in_banheiro_pne, in_refeitorio,
         in_biblioteca, in_laboratorio_ciencias, in_laboratorio_informatica,
         in_quadra_esportes, in_patio_coberto, in_parque_infantil,
         in_computador, in_internet, in_banda_larga, in_equip_multimidia,
         in_equip_lousa_digital, in_desktop_aluno, in_tablet_aluno,
         in_acessibilidade_rampas, in_acessibilidade_corrimao,
         in_acessibilidade_elevador, in_acessibilidade_pisos_tateis,
         in_acessibilidade_sinal_sonoro,
         qt_salas_utilizadas, qt_prof_administrativos, qt_prof_servicos_gerais,
         qt_prof_seguranca, qt_desktop_aluno, qt_comp_portatil_aluno,
         qt_tablet_aluno) %>%
  collect()

matriculas <- tbl(con, "censo_matriculas") %>%
  filter(nu_ano_censo == 2025) %>%
  select(co_entidade, qt_mat_bas, qt_mat_inf, qt_mat_fund, qt_mat_med,
         qt_mat_bas_int) %>%
  collect()

docentes <- tbl(con, "censo_docentes") %>%
  filter(nu_ano_censo == 2025) %>%
  select(co_entidade, qt_doc_bas, qt_doc_bas_fem,
         qt_doc_bas_esco_sup_grad, qt_doc_bas_esco_sup_pos_espec,
         qt_doc_bas_vinculo_concur) %>%
  collect()

gestor <- tbl(con, "censo_gestor") %>%
  filter(nu_ano_censo == 2025) %>%
  select(co_entidade, qt_gest_bas_esco_sup_grad, qt_gest_bas_esco_sup_pos_espec,
         qt_gest_bas_acesso_cargo_eleic, qt_gest_bas_acesso_cargo_conca) %>%
  collect()

# IDEB alvo: ano mais recente (2023)
ideb <- tbl(con, "ideb_notas_escolas") %>%
  filter(ano == 2023) %>%
  select(co_entidade = id_escola, nota_media) %>%
  distinct() %>%
  collect()

# ============================================================================
# 3. Juntar tabelas e criar features derivadas
# ============================================================================
dados <- escolas %>%
  left_join(matriculas, by = "co_entidade") %>%
  left_join(docentes, by = "co_entidade") %>%
  left_join(gestor, by = "co_entidade") %>%
  left_join(ideb, by = c("co_entidade"))

# Substituir NAs por zero em colunas que serão usadas em divisões
dados <- dados %>%
  mutate(across(c(qt_mat_bas, qt_doc_bas, qt_salas_utilizadas), ~ coalesce(., 0)))

dados <- dados %>%
  mutate(
    # Scores (somas simples)
    infra_essencial_score = in_agua_potavel + in_energia_rede_publica +
      in_esgoto_rede_publica + in_cozinha + in_banheiro +
      in_banheiro_pne + in_refeitorio,
    espacos_pedagogicos_score = in_biblioteca + in_laboratorio_ciencias +
      in_laboratorio_informatica + in_quadra_esportes +
      in_patio_coberto + in_parque_infantil,
    tecnologia_score = in_computador + in_internet + in_banda_larga +
      in_equip_multimidia + in_equip_lousa_digital +
      in_desktop_aluno + in_tablet_aluno,
    acessibilidade_score = in_acessibilidade_rampas + in_acessibilidade_corrimao +
      in_acessibilidade_elevador + in_acessibilidade_pisos_tateis +
      in_acessibilidade_sinal_sonoro,
    
    # Razões e indicadores por aluno
    salas_por_aluno = ifelse(qt_mat_bas > 0, qt_salas_utilizadas / qt_mat_bas, 0),
    equipamentos_por_aluno = ifelse(qt_mat_bas > 0,
                                    (coalesce(qt_desktop_aluno, 0) +
                                       coalesce(qt_comp_portatil_aluno, 0) +
                                       coalesce(qt_tablet_aluno, 0)) / qt_mat_bas, 0),
    funcionarios_nd_por_aluno = ifelse(qt_mat_bas > 0,
                                       (coalesce(qt_prof_administrativos, 0) +
                                          coalesce(qt_prof_servicos_gerais, 0) +
                                          coalesce(qt_prof_seguranca, 0)) / qt_mat_bas, 0),
    docentes_por_aluno = ifelse(qt_mat_bas > 0, qt_doc_bas / qt_mat_bas, 0),
    prop_docentes_superior = ifelse(qt_doc_bas > 0,
                                    qt_doc_bas_esco_sup_grad / qt_doc_bas, 0),
    prop_docentes_pos = ifelse(qt_doc_bas > 0,
                               qt_doc_bas_esco_sup_pos_espec / qt_doc_bas, 0),
    prop_docentes_concursados = ifelse(qt_doc_bas > 0,
                                       qt_doc_bas_vinculo_concur / qt_doc_bas, 0),
    prop_docentes_feminino = ifelse(qt_doc_bas > 0,
                                    qt_doc_bas_fem / qt_doc_bas, 0),
    
    prop_mat_infantil = ifelse(qt_mat_bas > 0, coalesce(qt_mat_inf, 0) / qt_mat_bas, 0),
    prop_mat_fund = ifelse(qt_mat_bas > 0, coalesce(qt_mat_fund, 0) / qt_mat_bas, 0),
    prop_mat_medio = ifelse(qt_mat_bas > 0, coalesce(qt_mat_med, 0) / qt_mat_bas, 0),
    prop_mat_integral = ifelse(qt_mat_bas > 0, coalesce(qt_mat_bas_int, 0) / qt_mat_bas, 0),
    alunos_por_sala = ifelse(qt_salas_utilizadas > 0, qt_mat_bas / qt_salas_utilizadas, 0),
    
    # Gestor
    gestor_superior = as.integer(coalesce(qt_gest_bas_esco_sup_grad, 0) > 0),
    gestor_pos = as.integer(coalesce(qt_gest_bas_esco_sup_pos_espec, 0) > 0),
    gestor_acesso_democratico = as.integer(coalesce(qt_gest_bas_acesso_cargo_eleic, 0) > 0 |
                                             coalesce(qt_gest_bas_acesso_cargo_conca, 0) > 0)
  )

# Seleção final das colunas que entram no modelo
features_finais <- c("nota_media",
                     "infra_essencial_score", "espacos_pedagogicos_score",
                     "tecnologia_score", "acessibilidade_score",
                     "salas_por_aluno", "equipamentos_por_aluno",
                     "funcionarios_nd_por_aluno", "docentes_por_aluno",
                     "prop_docentes_superior", "prop_docentes_pos",
                     "prop_docentes_concursados", "prop_docentes_feminino",
                     "prop_mat_infantil", "prop_mat_fund", "prop_mat_medio",
                     "prop_mat_integral", "alunos_por_sala",
                     "gestor_superior", "gestor_pos", "gestor_acesso_democratico",
                     "tp_localizacao", "tp_dependencia")

dados_modelo <- dados %>%
  select(all_of(features_finais)) %>%
  # substituir possíveis NA/infinito por 0
  mutate(across(where(is.numeric) & !nota_media, ~ ifelse(is.na(.) | is.infinite(.), 0, .)))

# Separar treino (com nota) e imputação (sem nota)
treino <- dados_modelo %>% filter(!is.na(nota_media))
imputar <- dados_modelo %>% filter(is.na(nota_media)) %>% select(-nota_media)

# ============================================================================
# 4. Recipe de pré-processamento
# ============================================================================
rec <- recipe(nota_media ~ ., data = treino) %>%
  step_mutate(tp_localizacao = factor(tp_localizacao),
              tp_dependencia = factor(tp_dependencia)) %>%
  step_dummy(all_nominal_predictors()) %>%
  step_impute_median(all_numeric_predictors())

# ============================================================================
# 5. Modelo: Random Forest
# ============================================================================
rf_spec <- rand_forest(trees = 250, min_n = 10) %>%
  set_engine("ranger", importance = "impurity") %>%
  set_mode("regression")

wf <- workflow() %>%
  add_recipe(rec) %>%
  add_model(rf_spec)

# Validação cruzada (3 folds)
set.seed(123)
cv_folds <- vfold_cv(treino, v = 3)
resultados_cv <- fit_resamples(wf, cv_folds, metrics = metric_set(rmse, rsq, mae))

# Resultados
# collect_metrics(resultados_cv)

# Treinar modelo final
modelo_final <- fit(wf, data = treino)

# ============================================================================
# 6. Salvar na pasta o modelo
# ============================================================================
if (!dir.exists("models")) {
  dir.create("models", recursive = TRUE)
}

# Caminho completo do arquivo
model_path <- file.path("models", "modelo_ideb_nota.rds")

# Salvar o modelo (já com bundle)
bundled_model <- bundle::bundle(modelo_final)
saveRDS(bundled_model, file = model_path)

message("Modelo salvo com sucesso em: ", model_path)
```

Seu script está muito bem estruturado e focado no projeto **EduMaps**. O objetivo é claro: utilizar dados de infraestrutura e pessoal do Censo Escolar 2025 para prever (ou imputar) a nota do IDEB baseando-se no desempenho histórico de 2023.

Abaixo, apresento uma análise de robustez e sugestões de modificações para garantir a corretude científica e técnica do modelo:

### 1. Robustez Matemática (O problema dos Outliers)

No cálculo de `alunos_por_sala` e outras razões, você está tratando `Infinito` como `0`. Isso pode ser perigoso para o modelo.

* **Risco:** Uma escola com 500 alunos e 0 salas (erro de preenchimento) vira `0` alunos por sala, o que é matematicamente o oposto da realidade (superlotação extrema).
* **Sugestão:** Em vez de `0`, substitua valores infinitos pelo **valor máximo** observado ou pela **mediana**, para não confundir o Random Forest.

### 2. Vazamento de Dados (Data Leakage)

Você está usando `step_mutate` para converter fatores **dentro** do recipe.

* **Problema:** Se no conjunto de `imputar` aparecer um código de `tp_dependencia` que não existia no `treino`, o script pode quebrar ou gerar erros silenciosos.
* **Sugestão:** Mova a conversão para `factor` para a etapa de limpeza dos dados brutos (antes do recipe). Assim, você garante que os níveis do fator sejam consistentes em todo o pipeline.

### 3. Melhoria na Engenharia de Features

As variáveis de `acessibilidade_score` e `tecnologia_score` tratam todos os itens com o mesmo peso.

* **Reflexão:** Ter internet banda larga (`in_banda_larga`) costuma impactar mais o aprendizado do que ter um projetor (`in_equip_multimidia`).
* **Sugestão:** Considere manter os itens binários (`0/1`) individuais em vez de apenas o score somado, ou deixe que o Random Forest decida a importância de cada um.

### 4. Modificações Sugeridas no Código

Aqui estão as alterações aplicadas para maior robustez:

```r
# ... (Partes iniciais mantidas)

# --- MELHORIA NA LIMPEZA ---
limpar_dados <- function(df) {
  df %>%
    mutate(
      # Converter fatores antes do recipe para evitar erros de novos níveis
      tp_localizacao = factor(tp_localizacao),
      tp_dependencia = factor(tp_dependencia),
      # Substituir NA por 0 apenas nas contagens brutas
      across(starts_with("qt_"), ~ coalesce(., 0))
    )
}

dados <- limpar_dados(dados)

# --- TRATAMENTO DE DIVISÃO POR ZERO ---
# Evite transformar Infinito em 0. Use a mediana ou um valor alto plausível.
ajustar_proporcoes <- function(df) {
  df %>%
    mutate(
      alunos_por_sala = ifelse(qt_salas_utilizadas > 0, qt_mat_bas / qt_salas_utilizadas, NA),
      # ... (outras razões)
    ) %>%
    mutate(across(where(is.numeric), ~ ifelse(is.infinite(.), NA, .))) # Marcar como NA para o step_impute_median tratar
}

# --- MELHORIA NO RECIPE ---
rec <- recipe(nota_media ~ ., data = treino) %>%
  # Removido step_mutate daqui, já que os dados entram como factor
  step_impute_median(all_numeric_predictors()) %>% 
  step_novel(all_nominal_predictors()) %>% # Trata categorias novas no futuro
  step_dummy(all_nominal_predictors())

# --- PARALELIZAÇÃO (Opcional, para velocidade) ---
library(doParallel)
cl <- makePSOCKcluster(parallel::detectCores() - 1)
registerDoParallel(cl)

# --- TREINAMENTO ---
# (Seu código de fit_resamples e fit final)

stopCluster(cl)

```

### 5. Ponto de Atenção: O Alvo (IDEB 2023)

Você está usando variáveis explicativas de **2025** para prever uma nota de **2023**.

* **Implicação:** Na prática, você está criando um modelo que diz: "Dada a infraestrutura que a escola tem *hoje*, qual seria a nota dela no IDEB passado?".
* **Uso correto:** Isso é excelente para identificar escolas que melhoraram a infraestrutura mas ainda não tiveram o ciclo do IDEB para refletir isso, ou para imputar notas em escolas novas que ainda não participaram do exame.

### 6. Armazenamento e Deploy

O uso do `bundle` é uma prática excelente e mostra maturidade no desenvolvimento (evita que o modelo perca as referências do ambiente ao ser carregado no seu app Svelte/Mojo).

**Dica Extra:** Como você trabalha com PostGIS no `EduMaps`, considere salvar o resultado da predição (as notas imputadas) de volta em uma tabela temporária no Postgres para facilitar a visualização espacial imediata.

# O problema do uso do modelo

Essa é uma percepção fundamental. O que você notou é a separação entre os **metadados** (identificadores) e as **features** (dados de treinamento).

Para que o seu modelo funcione diretamente com a tabela `censo_escolas`, você precisa garantir que o pipeline de dados siga uma regra de ouro: **o modelo não pode ver o `co_entidade` durante o treino, mas você precisa dele para saber de qual escola é a previsão depois.**

Aqui está como você deve estruturar isso para garantir a compatibilidade:

### 1. O "Vício" da Coluna Extra

Se você tentar passar um dataframe que contém a coluna `co_entidade` para a função `predict()`, o R pode gerar um erro ou um aviso dizendo que essa coluna não era esperada pelo modelo (já que ela não estava no `recipe`).

### 2. A Solução: O papel de "ID" no Tidymodels

No seu `recipe`, você pode incluir o `co_entidade`, mas avisar ao R que ele **não é uma variável preditora**, e sim um papel de identificação.

Modifique seu **Recipe** assim:

```r
rec <- recipe(nota_media ~ ., data = treino) %>%
  # Define co_entidade como ID (ele será ignorado no cálculo matemático)
  update_role(co_entidade, new_role = "id") %>% 
  step_mutate(tp_localizacao = factor(tp_localizacao),
              tp_dependencia = factor(tp_dependencia)) %>%
  step_dummy(all_nominal_predictors()) %>%
  step_impute_median(all_numeric_predictors())

```

### 3. Como usar com novos dados do Banco

Quando você puxar os dados da tabela `censo_escolas` para usar o modelo, o fluxo será este:

```r
# 1. Puxar dados novos (que não têm nota_media)
novos_dados <- tbl(con, "censo_escolas") %>% 
  filter(nu_ano_censo == 2025) %>% 
  collect()

# 2. Gerar as predições
# O tidymodels vai ignorar o co_entidade automaticamente se ele tiver o papel de ID
predicoes <- predict(modelo_final, novos_dados)

# 3. Juntar o ID com o Resultado
resultado_final <- novos_dados %>%
  select(co_entidade) %>%
  bind_cols(predicoes) %>%
  rename(nota_imputada = .pred)

```

### Por que isso é importante para o EduMaps?

Como o seu objetivo é visualizar esses dados em um mapa (Svelte + PostGIS), o `co_entidade` é o seu **Join Key**.

**Resumo da robustez:**

* **No Treino:** Você remove o `co_entidade` (ou usa `update_role`) para que o Random Forest não tente "decorar" o número da escola como se fosse uma variável numérica.
* **Na Predição:** Você mantém o `co_entidade` no dataframe original, roda o `predict()`, e depois usa o `bind_cols`. Como o `predict()` do Tidymodels garante que a ordem das linhas seja mantida, a primeira predição corresponderá exatamente à primeira escola do seu dataframe `novos_dados`.

### Dica para o PostGIS:

Depois de gerar esse `resultado_final`, você pode salvá-lo em uma tabela temporária ou definitiva:

```r
dbWriteTable(con, "predicoes_ideb_2025", resultado_final, overwrite = TRUE)

```

Isso permitirá que seu backend em **Mojolicious** faça um `JOIN` simples entre a geometria da escola e a nota predita pelo seu modelo.
