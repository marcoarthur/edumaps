# Integração com frontend

Sem dúvidas, a **segunda opção** (o Frontend ou o Backend chamando o R Plumber **apenas com o `co_entidade` (ID da escola)**, e o Plumber buscando os dados no banco) é infinitamente superior e mais robusta para o EduMaps.

Para arquiteturas de produção, colocar a carga de buscar as 79 variáveis (features) no Plumber traz vantagens críticas de performance, segurança e manutenção.

---

## Por que a abordagem "Apenas o ID" é a melhor?

### 1. Desempenho e Economia de Rede (Payload Leve)

Se o Frontend ou o Backend tivessem que enviar as 79 colunas via JSON no corpo do POST, você estaria trafegando dados massivos pela rede desnecessariamente. Trafegar apenas `{"co_entidade": 2304802}` consome bytes insignificantes e elimina o overhead de serializar e desserializar um JSON gigante.

### 2. Consistência dos Dados (Garantia de Verdade)

O modelo foi treinado com regras muito específicas (filtros por ano, criação de scores de infraestrutura, etc.). Se o Plumber receber apenas o ID e ele mesmo consultar a tabela `clean.inse` e o Censo no banco (onde ambos os containers já estão conectados), você garante que o dado que entra no modelo é **exatamente** o dado oficial e limpo do banco. Se o Frontend enviasse isso, haveria o risco de enviar dados desatualizados ou formatados incorretamente.

### 3. Facilidade de Manutenção (Desacoplamento)

Se amanhã você decidir adicionar a 80ª variável no modelo (ex: `qt_computadores_por_professor`), você **só mexe no script do R**. O Frontend e o Backend da aplicação nem precisam saber que o modelo mudou, pois a assinatura da API continua sendo apenas o ID da escola.

---

## Como desenhar esse fluxo no R Plumber?

No seu container de Analytics, o script do Plumber deve receber o ID, rodar uma query rápida no banco para puxar a linha daquela escola, passar os dados pela receita (`predict`) e retornar o resultado.

Aqui está um exemplo prático de como estruturar o endpoint no Plumber:

```r
# /opt/edumaps/analytics/R/api.R
library(plumber)
library(DBI)
library(RPostgres)
library(dplyr)
library(workflows)

# Carrega o modelo leve de ~30MB uma única vez na inicialização da API
modelo_prod <- readr::read_rds("models/rf_inse_2025.rds")

#' @filter cors
function(res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
  plumber::forward()
}

#' Predição do IDEB por Escola
#' @post /predict/escola
#' @param co_entidade:int O ID de identificação da escola
function(co_entidade) {
  
  # 1. Conecta ao banco de dados (usando o service do pg_service ou env)
  con <- dbConnect(RPostgres::Postgres(), service = "edumaps")
  on.exit(dbDisconnect(con)) # Garante o fechamento da conexão
  
  # 2. Busca a linha da escola com as features necessárias
  # Nota: Idealmente você aponta para a tabela final/view que já tem as 79 colunas prontas
  dados_escola <- tbl(con, "features_escolas_view") %>% 
    filter(co_entidade == !!as.numeric(co_entidade)) %>% 
    collect()
  
  # Validação caso a escola não exista no banco
  if (nrow(dados_escola) == 0) {
    return(list(error = "Escola não encontrada na base de dados."))
  }
  
  # 3. Executa a predição usando o workflow do tidymodels que extraímos do result_obj
  # O predict() sabe exatamente como aplicar a receita e rodar o ranger internamente
  predicao <- predict(modelo_prod$workflow, new_data = dados_escola)
  
  # 4. Retorna a resposta limpa para o Frontend/Backend
  return(list(
    co_entidade = as.numeric(co_entidade),
    nota_media_predita = round(predicao$.pred, 2),
    data_calculo = Sys.time()
  ))
}

```

---

## O Fluxo da Requisição na Prática

1. **Frontend (Dashboard)** clica em uma escola e dispara uma requisição para o Backend:
`GET /api/escolas/123456/previsao`
2. **Backend (Aplicação)** intercepta, verifica permissões (JWT, etc.) e faz uma chamada interna de container para container (via rede interna do Docker) apontando para o Plumber:
`POST http://analytics-container:8000/predict/escola` com o JSON `{"co_entidade": 123456}`
3. **Plumber (R)** recebe o ID, abre uma conexão rápida no Postgres, puxa a linha daquela escola, joga as 79 colunas no modelo de 30MB, calcula a nota e devolve um JSON simples.
4. **Backend** recebe do Plumber e repassa ao **Frontend** com velocidade de milissegundos.

O Backend intermediar a chamada do Frontend para o Plumber (em vez do Front chamar o Plumber direto) é a melhor prática porque o Backend serve como uma camada de segurança (Firewall/Autenticação), impedindo que a sua API de machine learning fique exposta diretamente para a internet.


# Integrando o banco com o modelo

Para replicar a lógica de preparação dos dados em uma **view** (ou função) no PostgreSQL, você precisa transformar todas as operações do R (joins, filtros, substituição de `NA`, criação de scores e proporções) em SQL puro.

Como os anos de cada fonte (`censo`, `ideb`, `inse`) podem variar conforme a execução do pipeline, o ideal é criar uma **função paramétrica** que recebe esses anos e retorna a tabela pronta. Assim, do R você chama:

```r
dados <- dbGetQuery(con, "SELECT * FROM analytics.prepare_school_data(2023, 2023, 2023);")
```

Abaixo está o código SQL completo para criar a função no banco (substitua `analytics` pelo seu esquema, se necessário). Você pode adaptar para criar uma **view materializada** fixa se os anos não mudarem.

## 🔧 Função SQL (recomendada)

```sql
CREATE OR REPLACE FUNCTION analytics.prepare_school_data(
  p_censo_year INTEGER,
  p_ideb_year INTEGER,
  p_inse_year INTEGER
)
RETURNS TABLE (
  co_entidade TEXT,
  tp_localizacao INTEGER,
  tp_dependencia INTEGER,
  in_agua_potavel INTEGER,
  in_energia_rede_publica INTEGER,
  in_esgoto_rede_publica INTEGER,
  in_cozinha INTEGER,
  in_banheiro INTEGER,
  in_banheiro_pne INTEGER,
  in_refeitorio INTEGER,
  in_biblioteca INTEGER,
  in_laboratorio_ciencias INTEGER,
  in_laboratorio_informatica INTEGER,
  in_quadra_esportes INTEGER,
  in_patio_coberto INTEGER,
  in_parque_infantil INTEGER,
  in_computador INTEGER,
  in_internet INTEGER,
  in_banda_larga INTEGER,
  in_equip_multimidia INTEGER,
  in_equip_lousa_digital INTEGER,
  in_desktop_aluno INTEGER,
  in_tablet_aluno INTEGER,
  in_acessibilidade_rampas INTEGER,
  in_acessibilidade_corrimao INTEGER,
  in_acessibilidade_elevador INTEGER,
  in_acessibilidade_pisos_tateis INTEGER,
  in_acessibilidade_sinal_sonoro INTEGER,
  qt_salas_utilizadas INTEGER,
  qt_prof_administrativos INTEGER,
  qt_prof_servicos_gerais INTEGER,
  qt_prof_seguranca INTEGER,
  qt_desktop_aluno INTEGER,
  qt_comp_portatil_aluno INTEGER,
  qt_tablet_aluno INTEGER,
  qt_mat_bas INTEGER,
  qt_mat_inf INTEGER,
  qt_mat_fund INTEGER,
  qt_mat_med INTEGER,
  qt_mat_bas_int INTEGER,
  qt_doc_bas INTEGER,
  qt_doc_bas_fem INTEGER,
  qt_doc_bas_esco_sup_grad INTEGER,
  qt_doc_bas_esco_sup_pos_espec INTEGER,
  qt_doc_bas_vinculo_concur INTEGER,
  qt_gest_bas_esco_sup_grad INTEGER,
  qt_gest_bas_esco_sup_pos_espec INTEGER,
  qt_gest_bas_acesso_cargo_eleic INTEGER,
  qt_gest_bas_acesso_cargo_conca INTEGER,
  nota_media NUMERIC,
  media_inse NUMERIC,
  pc_nivel_1 NUMERIC,
  pc_nivel_2 NUMERIC,
  pc_nivel_3 NUMERIC,
  pc_nivel_4 NUMERIC,
  pc_nivel_5 NUMERIC,
  pc_nivel_6 NUMERIC,
  pc_nivel_7 NUMERIC,
  pc_nivel_8 NUMERIC,
  infra_essencial_score BIGINT,
  espacos_pedagogicos_score BIGINT,
  tecnologia_score BIGINT,
  acessibilidade_score BIGINT,
  salas_por_aluno NUMERIC,
  equipamentos_por_aluno NUMERIC,
  funcionarios_nd_por_aluno NUMERIC,
  docentes_por_aluno NUMERIC,
  prop_docentes_superior NUMERIC,
  prop_docentes_pos NUMERIC,
  prop_docentes_concursados NUMERIC,
  prop_docentes_feminino NUMERIC,
  prop_mat_infantil NUMERIC,
  prop_mat_fund NUMERIC,
  prop_mat_medio NUMERIC,
  prop_mat_integral NUMERIC,
  alunos_por_sala NUMERIC,
  gestor_superior INTEGER,
  gestor_pos INTEGER,
  gestor_acesso_democratico INTEGER
)
LANGUAGE sql
STABLE
AS $$
  WITH
    -- Filtrar e selecionar as colunas necessárias de cada tabela
    escolas AS (
      SELECT
        co_entidade,
        tp_localizacao,
        tp_dependencia,
        in_agua_potavel,
        in_energia_rede_publica,
        in_esgoto_rede_publica,
        in_cozinha,
        in_banheiro,
        in_banheiro_pne,
        in_refeitorio,
        in_biblioteca,
        in_laboratorio_ciencias,
        in_laboratorio_informatica,
        in_quadra_esportes,
        in_patio_coberto,
        in_parque_infantil,
        in_computador,
        in_internet,
        in_banda_larga,
        in_equip_multimidia,
        in_equip_lousa_digital,
        in_desktop_aluno,
        in_tablet_aluno,
        in_acessibilidade_rampas,
        in_acessibilidade_corrimao,
        in_acessibilidade_elevador,
        in_acessibilidade_pisos_tateis,
        in_acessibilidade_sinal_sonoro,
        qt_salas_utilizadas,
        qt_prof_administrativos,
        qt_prof_servicos_gerais,
        qt_prof_seguranca,
        qt_desktop_aluno,
        qt_comp_portatil_aluno,
        qt_tablet_aluno
      FROM analytics.escolas
      WHERE nu_ano_censo = p_censo_year
    ),
    matriculas AS (
      SELECT
        co_entidade,
        qt_mat_bas,
        qt_mat_inf,
        qt_mat_fund,
        qt_mat_med,
        qt_mat_bas_int
      FROM analytics.matriculas
      WHERE nu_ano_censo = p_censo_year
    ),
    docentes AS (
      SELECT
        co_entidade,
        qt_doc_bas,
        qt_doc_bas_fem,
        qt_doc_bas_esco_sup_grad,
        qt_doc_bas_esco_sup_pos_espec,
        qt_doc_bas_vinculo_concur
      FROM analytics.docentes
      WHERE nu_ano_censo = p_censo_year
    ),
    gestor AS (
      SELECT
        co_entidade,
        qt_gest_bas_esco_sup_grad,
        qt_gest_bas_esco_sup_pos_espec,
        qt_gest_bas_acesso_cargo_eleic,
        qt_gest_bas_acesso_cargo_conca
      FROM analytics.gestor
      WHERE nu_ano_censo = p_censo_year
    ),
    ideb AS (
      SELECT DISTINCT
        id_escola AS co_entidade,
        nota_media
      FROM analytics.ideb
      WHERE ano = p_ideb_year
    ),
    inse AS (
      SELECT
        id_escola AS co_entidade,
        media_inse,
        pc_nivel_1,
        pc_nivel_2,
        pc_nivel_3,
        pc_nivel_4,
        pc_nivel_5,
        pc_nivel_6,
        pc_nivel_7,
        pc_nivel_8
      FROM analytics.inse
      WHERE nu_ano_saeb = p_inse_year
    ),
    joined AS (
      SELECT
        e.*,
        m.qt_mat_bas,
        m.qt_mat_inf,
        m.qt_mat_fund,
        m.qt_mat_med,
        m.qt_mat_bas_int,
        d.qt_doc_bas,
        d.qt_doc_bas_fem,
        d.qt_doc_bas_esco_sup_grad,
        d.qt_doc_bas_esco_sup_pos_espec,
        d.qt_doc_bas_vinculo_concur,
        g.qt_gest_bas_esco_sup_grad,
        g.qt_gest_bas_esco_sup_pos_espec,
        g.qt_gest_bas_acesso_cargo_eleic,
        g.qt_gest_bas_acesso_cargo_conca,
        i.nota_media,
        s.media_inse,
        s.pc_nivel_1,
        s.pc_nivel_2,
        s.pc_nivel_3,
        s.pc_nivel_4,
        s.pc_nivel_5,
        s.pc_nivel_6,
        s.pc_nivel_7,
        s.pc_nivel_8
      FROM escolas e
      LEFT JOIN matriculas m ON e.co_entidade = m.co_entidade
      LEFT JOIN docentes d ON e.co_entidade = d.co_entidade
      LEFT JOIN gestor g ON e.co_entidade = g.co_entidade
      LEFT JOIN ideb i ON e.co_entidade = i.co_entidade
      LEFT JOIN inse s ON e.co_entidade = s.co_entidade
      WHERE i.nota_media IS NOT NULL   -- remove escolas sem IDEB
    )
  SELECT
    co_entidade,
    tp_localizacao,
    tp_dependencia,
    in_agua_potavel,
    in_energia_rede_publica,
    in_esgoto_rede_publica,
    in_cozinha,
    in_banheiro,
    in_banheiro_pne,
    in_refeitorio,
    in_biblioteca,
    in_laboratorio_ciencias,
    in_laboratorio_informatica,
    in_quadra_esportes,
    in_patio_coberto,
    in_parque_infantil,
    in_computador,
    in_internet,
    in_banda_larga,
    in_equip_multimidia,
    in_equip_lousa_digital,
    in_desktop_aluno,
    in_tablet_aluno,
    in_acessibilidade_rampas,
    in_acessibilidade_corrimao,
    in_acessibilidade_elevador,
    in_acessibilidade_pisos_tateis,
    in_acessibilidade_sinal_sonoro,
    COALESCE(qt_salas_utilizadas, 0) AS qt_salas_utilizadas,
    COALESCE(qt_prof_administrativos, 0) AS qt_prof_administrativos,
    COALESCE(qt_prof_servicos_gerais, 0) AS qt_prof_servicos_gerais,
    COALESCE(qt_prof_seguranca, 0) AS qt_prof_seguranca,
    COALESCE(qt_desktop_aluno, 0) AS qt_desktop_aluno,
    COALESCE(qt_comp_portatil_aluno, 0) AS qt_comp_portatil_aluno,
    COALESCE(qt_tablet_aluno, 0) AS qt_tablet_aluno,
    COALESCE(qt_mat_bas, 0) AS qt_mat_bas,
    COALESCE(qt_mat_inf, 0) AS qt_mat_inf,
    COALESCE(qt_mat_fund, 0) AS qt_mat_fund,
    COALESCE(qt_mat_med, 0) AS qt_mat_med,
    COALESCE(qt_mat_bas_int, 0) AS qt_mat_bas_int,
    COALESCE(qt_doc_bas, 0) AS qt_doc_bas,
    COALESCE(qt_doc_bas_fem, 0) AS qt_doc_bas_fem,
    COALESCE(qt_doc_bas_esco_sup_grad, 0) AS qt_doc_bas_esco_sup_grad,
    COALESCE(qt_doc_bas_esco_sup_pos_espec, 0) AS qt_doc_bas_esco_sup_pos_espec,
    COALESCE(qt_doc_bas_vinculo_concur, 0) AS qt_doc_bas_vinculo_concur,
    COALESCE(qt_gest_bas_esco_sup_grad, 0) AS qt_gest_bas_esco_sup_grad,
    COALESCE(qt_gest_bas_esco_sup_pos_espec, 0) AS qt_gest_bas_esco_sup_pos_espec,
    COALESCE(qt_gest_bas_acesso_cargo_eleic, 0) AS qt_gest_bas_acesso_cargo_eleic,
    COALESCE(qt_gest_bas_acesso_cargo_conca, 0) AS qt_gest_bas_acesso_cargo_conca,
    nota_media,
    media_inse,
    pc_nivel_1,
    pc_nivel_2,
    pc_nivel_3,
    pc_nivel_4,
    pc_nivel_5,
    pc_nivel_6,
    pc_nivel_7,
    pc_nivel_8,
    -- Scores
    (COALESCE(in_agua_potavel,0) + COALESCE(in_energia_rede_publica,0) +
     COALESCE(in_esgoto_rede_publica,0) + COALESCE(in_cozinha,0) +
     COALESCE(in_banheiro,0) + COALESCE(in_banheiro_pne,0) +
     COALESCE(in_refeitorio,0)) AS infra_essencial_score,
    (COALESCE(in_biblioteca,0) + COALESCE(in_laboratorio_ciencias,0) +
     COALESCE(in_laboratorio_informatica,0) + COALESCE(in_quadra_esportes,0) +
     COALESCE(in_patio_coberto,0) + COALESCE(in_parque_infantil,0)) AS espacos_pedagogicos_score,
    (COALESCE(in_computador,0) + COALESCE(in_internet,0) +
     COALESCE(in_banda_larga,0) + COALESCE(in_equip_multimidia,0) +
     COALESCE(in_equip_lousa_digital,0) + COALESCE(in_desktop_aluno,0) +
     COALESCE(in_tablet_aluno,0)) AS tecnologia_score,
    (COALESCE(in_acessibilidade_rampas,0) + COALESCE(in_acessibilidade_corrimao,0) +
     COALESCE(in_acessibilidade_elevador,0) + COALESCE(in_acessibilidade_pisos_tateis,0) +
     COALESCE(in_acessibilidade_sinal_sonoro,0)) AS acessibilidade_score,
    -- Razões
    CASE WHEN COALESCE(qt_mat_bas,0) > 0
         THEN COALESCE(qt_salas_utilizadas,0)::NUMERIC / qt_mat_bas
         ELSE 0 END AS salas_por_aluno,
    CASE WHEN COALESCE(qt_mat_bas,0) > 0
         THEN (COALESCE(qt_desktop_aluno,0) + COALESCE(qt_comp_portatil_aluno,0) + COALESCE(qt_tablet_aluno,0))::NUMERIC / qt_mat_bas
         ELSE 0 END AS equipamentos_por_aluno,
    CASE WHEN COALESCE(qt_mat_bas,0) > 0
         THEN (COALESCE(qt_prof_administrativos,0) + COALESCE(qt_prof_servicos_gerais,0) + COALESCE(qt_prof_seguranca,0))::NUMERIC / qt_mat_bas
         ELSE 0 END AS funcionarios_nd_por_aluno,
    CASE WHEN COALESCE(qt_mat_bas,0) > 0
         THEN COALESCE(qt_doc_bas,0)::NUMERIC / qt_mat_bas
         ELSE 0 END AS docentes_por_aluno,
    CASE WHEN COALESCE(qt_doc_bas,0) > 0
         THEN COALESCE(qt_doc_bas_esco_sup_grad,0)::NUMERIC / qt_doc_bas
         ELSE 0 END AS prop_docentes_superior,
    CASE WHEN COALESCE(qt_doc_bas,0) > 0
         THEN COALESCE(qt_doc_bas_esco_sup_pos_espec,0)::NUMERIC / qt_doc_bas
         ELSE 0 END AS prop_docentes_pos,
    CASE WHEN COALESCE(qt_doc_bas,0) > 0
         THEN COALESCE(qt_doc_bas_vinculo_concur,0)::NUMERIC / qt_doc_bas
         ELSE 0 END AS prop_docentes_concursados,
    CASE WHEN COALESCE(qt_doc_bas,0) > 0
         THEN COALESCE(qt_doc_bas_fem,0)::NUMERIC / qt_doc_bas
         ELSE 0 END AS prop_docentes_feminino,
    CASE WHEN COALESCE(qt_mat_bas,0) > 0
         THEN COALESCE(qt_mat_inf,0)::NUMERIC / qt_mat_bas
         ELSE 0 END AS prop_mat_infantil,
    CASE WHEN COALESCE(qt_mat_bas,0) > 0
         THEN COALESCE(qt_mat_fund,0)::NUMERIC / qt_mat_bas
         ELSE 0 END AS prop_mat_fund,
    CASE WHEN COALESCE(qt_mat_bas,0) > 0
         THEN COALESCE(qt_mat_med,0)::NUMERIC / qt_mat_bas
         ELSE 0 END AS prop_mat_medio,
    CASE WHEN COALESCE(qt_mat_bas,0) > 0
         THEN COALESCE(qt_mat_bas_int,0)::NUMERIC / qt_mat_bas
         ELSE 0 END AS prop_mat_integral,
    CASE WHEN COALESCE(qt_salas_utilizadas,0) > 0
         THEN COALESCE(qt_mat_bas,0)::NUMERIC / qt_salas_utilizadas
         ELSE 0 END AS alunos_por_sala,
    -- Gestor flags
    CASE WHEN COALESCE(qt_gest_bas_esco_sup_grad,0) > 0 THEN 1 ELSE 0 END AS gestor_superior,
    CASE WHEN COALESCE(qt_gest_bas_esco_sup_pos_espec,0) > 0 THEN 1 ELSE 0 END AS gestor_pos,
    CASE WHEN (COALESCE(qt_gest_bas_acesso_cargo_eleic,0) > 0 OR
               COALESCE(qt_gest_bas_acesso_cargo_conca,0) > 0) THEN 1 ELSE 0 END AS gestor_acesso_democratico
  FROM joined;
$$;
```

## 📌 Como usar no R

Após criar a função no banco, substitua a etapa `capture` por:

```r
run <- function(data, args) {
  con <- dbConnect(RPostgres::Postgres(), service = args$db_service)
  on.exit(dbDisconnect(con))
  
  anos <- args$anos
  dados <- dbGetQuery(con, "
    SELECT * FROM analytics.prepare_school_data($1, $2, $3);
  ", params = list(anos$censo, anos$ideb, anos$inse))
  
  # Os fatores tp_localizacao e tp_dependencia são inteiros no banco,
  # mas você pode convertê-los para factor no R se desejar:
  dados <- dados %>%
    mutate(
      tp_localizacao = factor(tp_localizacao),
      tp_dependencia = factor(tp_dependencia)
    )
  
  return(list(data = dados, metadata = list(...)))
}
```

## 🧩 Alternativa: view fixa (se os anos não mudarem)

Caso os anos sejam sempre os mesmos, substitua os parâmetros pelos valores concretos e crie uma **materialized view** para performance:

```sql
CREATE MATERIALIZED VIEW analytics.school_data_2023 AS
SELECT * FROM analytics.prepare_school_data(2023, 2023, 2023);
```

Depois, no R, basta `dbGetQuery(con, "SELECT * FROM analytics.school_data_2023")`.

Essa abordagem elimina toda a lógica de transformação do R, agilizando o pipeline e centralizando as regras de negócio no banco de dados.

# Problemas com o model e o recipe na predicao

O problema é que o modelo salvo **não contém mais o objeto `recipe` separado** (foi removido para economizar espaço). No entanto, o **workflow** treinado já encapsula tanto a recipe pré-preparada quanto o modelo. Portanto, você deve usar o workflow diretamente para predizer, sem precisar chamar `bake()` manualmente.

## 🔧 Código corrigido para o endpoint do Plumber

```r
#* @post /models/predict/<chave>
#* @serializer json
function(chave, req, res) {
  require(recipes)   # ainda necessário para o workflow (bake é chamado internamente)
  
  if (!chave %in% names(models_cache)) {
    res$status <- 404
    return(list(error = "Modelo não encontrado."))
  }
  
  # Carrega o objeto leve (workflow + metadados)
  model_light <- load_model_light(chave)
  
  # O objeto salvo deve conter o workflow treinado (já com recipe e modelo)
  workflow <- model_light$workflow
  if (is.null(workflow)) {
    res$status <- 500
    return(list(error = "Objeto de modelo inválido (workflow não encontrado)."))
  }
  
  feature_names <- model_light$feature_names
  id_col <- model_light$id_col
  
  # Lê o JSON do corpo da requisição
  body <- tryCatch(
    jsonlite::parse_json(req$postBody, simplifyVector = TRUE),
    error = function(e) NULL
  )
  if (is.null(body)) {
    res$status <- 400
    return(list(error = "JSON inválido."))
  }
  
  # Converte para data.frame (suporta uma ou várias escolas)
  if (is.list(body) && !is.data.frame(body)) {
    if (is.null(names(body)) && all(sapply(body, is.list))) {
      # Lista de objetos (várias escolas)
      dados <- do.call(rbind, lapply(body, function(x) as.data.frame(t(unlist(x)), stringsAsFactors = FALSE)))
    } else {
      # Um único objeto
      dados <- as.data.frame(t(unlist(body)), stringsAsFactors = FALSE)
    }
  } else {
    dados <- body
  }
  
  # Converte colunas numéricas (se vierem como character)
  dados <- type.convert(dados, as.is = TRUE)
  
  # Verifica se todas as features (colunas esperadas) estão presentes
  missing_vars <- setdiff(feature_names, names(dados))
  if (length(missing_vars) > 0) {
    res$status <- 400
    return(list(error = paste("Variáveis faltantes:", paste(missing_vars, collapse = ", "))))
  }
  
  # Usa o workflow diretamente para predizer (ele aplica a recipe e o modelo)
  predicoes <- predict(workflow, new_data = dados)
  
  # Resposta
  resposta <- list(
    modelo = chave,
    predicoes = as.numeric(predicoes$.pred)   # tidy predictions
  )
  
  if (!is.null(id_col) && id_col %in% names(dados)) {
    resposta$ids <- dados[[id_col]]
  }
  
  return(resposta)
}
```

## 📌 Adaptações necessárias no salvamento

Certifique-se de que o arquivo RDS salvo (`rf_inse_2025.rds`) contenha **pelo menos**:
- `workflow`: o objeto workflow treinado (que já inclui a recipe e o modelo)
- `feature_names`: vetor com os nomes das colunas esperadas (útil para validação)
- `id_col`: nome da coluna de identificação (opcional)

O seu código `save_model.R` atualmente remove `recipe` e `model`, mas mantém `workflow` e `feature_names` (não os remove). Verifique se `feature_names` está sendo salvo. Caso não esteja, você pode recuperá-lo do próprio workflow:

```r
# Exemplo de como obter feature_names do workflow (se não estiver salvo)
feature_names <- workflow$pre$actions$recipe$recipe$var_info %>%
  filter(role == "predictor") %>%
  pull(variable)
```

Mas é mais simples salvar explicitamente no momento do treino.

## 🧪 Teste após a correção

Reinicie o servidor Plumber e execute o mesmo `curl` com o JSON completo (todas as features). O erro `could not find function "bake"` não ocorrerá mais, pois o próprio `predict.workflow` chama `bake` internamente (e o pacote `recipes` já estará carregado).


# Endpoint no plumber para predicao apenas com o id da escola e sua etapa

Para atender à solicitação, o endpoint GET deve aceitar um parâmetro opcional `etapa`, permitindo filtrar a predição por uma etapa específica (ex.: `fundamental_i` ou `fundamental_ii`). Se o parâmetro não for informado, a API retornará predições para todas as etapas disponíveis na view.

Abaixo, o código atualizado da função Plumber:

```r
#* @get /models/predict/school/<chave>/<co_entidade>
#* @param etapa string Opcional: fundamental_i, fundamental_ii, etc.
#* @serializer json
function(chave, co_entidade, etapa = NULL, req, res) {
  require(recipes)
  require(RPostgres)
  require(dplyr)
  require(dbplyr)
  
  # 1. Verifica se o modelo existe no cache
  if (!chave %in% names(models_cache)) {
    res$status <- 404
    return(list(error = "Modelo não encontrado."))
  }
  
  # 2. Carrega o workflow e metadados
  model_light <- load_model_light(chave)
  workflow <- model_light$workflow
  if (is.null(workflow)) {
    res$status <- 500
    return(list(error = "Workflow inválido."))
  }
  feature_names <- model_light$feature_names
  id_col <- model_light$id_col  # "co_entidade"
  
  # 3. Conecta ao banco de dados (ajuste conforme sua configuração)
  con <- tryCatch(
    dbConnect(RPostgres::Postgres(), service = Sys.getenv("DB_SERVICE", "educacao")),
    error = function(e) {
      dbConnect(RPostgres::Postgres(),
        host = Sys.getenv("DB_HOST", "localhost"),
        port = Sys.getenv("DB_PORT", 5432),
        dbname = Sys.getenv("DB_NAME", "geoinova"),
        user = Sys.getenv("DB_USER", "postgres"),
        password = Sys.getenv("DB_PASSWORD")
      )
    }
  )
  on.exit(dbDisconnect(con), add = TRUE)
  
  # 4. Constrói a consulta à materialized view (filtra por escola e opcionalmente por etapa)
  query_tbl <- tbl(con, dbplyr::in_schema("analytics", "school_data_2023")) %>%
    filter(!!sym(id_col) == co_entidade)
  
  if (!is.null(etapa) && etapa != "") {
    query_tbl <- query_tbl %>% filter(etapa == etapa)
  }
  
  dados_escola <- query_tbl %>% collect()
  
  if (nrow(dados_escola) == 0) {
    res$status <- 404
    return(list(error = paste("Escola", co_entidade, 
                              ifelse(!is.null(etapa), paste("com etapa", etapa), ""),
                              "não encontrada na view.")))
  }
  
  # 5. Para cada linha (cada etapa), faz a predição
  predicoes_list <- list()
  for (i in 1:nrow(dados_escola)) {
    registro <- dados_escola[i, , drop = FALSE]
    
    # Seleciona apenas as colunas esperadas pelo modelo
    registro <- registro %>% select(any_of(feature_names))
    
    missing <- setdiff(feature_names, names(registro))
    if (length(missing) > 0) {
      next  # pula se faltar feature (não deve acontecer)
    }
    
    registro <- type.convert(registro, as.is = TRUE)
    pred <- predict(workflow, new_data = registro)
    pred_val <- as.numeric(pred$.pred)
    
    etapa_val <- if ("etapa" %in% names(registro)) registro$etapa else NA
    predicoes_list[[length(predicoes_list) + 1]] <- list(
      etapa = etapa_val,
      predicao = pred_val
    )
  }
  
  if (length(predicoes_list) == 0) {
    res$status <- 500
    return(list(error = "Não foi possível gerar predições para esta escola."))
  }
  
  # 6. Resposta final
  return(list(
    modelo = chave,
    escola = co_entidade,
    predicoes = predicoes_list
  ))
}
```

## Como usar

- **Obter todas as etapas** (sem filtro):
  ```bash
  curl "http://ubatexu.lan:5173/analytic-api/models/predict/school/rf_inse_2025/35047824"
  ```

- **Obter apenas uma etapa específica**:
  ```bash
  curl "http://ubatexu.lan:5173/analytic-api/models/predict/school/rf_inse_2025/35047824?etapa=fundamental_ii"
  ```

A resposta incluirá um array `predicoes` contendo objeto(s) com os campos `etapa` e `predicao`. Se o parâmetro `etapa` for fornecido, o array terá no máximo um elemento (a menos que a view contenha duplicatas, o que não é esperado).

# etapa obrigatoria

Você tem razão. A função deve exigir a etapa como parâmetro **obrigatório** e retornar apenas a predição para aquela etapa específica (uma única escola, uma única etapa). Corrigi o código:

```r
#* @get /models/predict/school/<chave>/<co_entidade>/<etapa>
#* @serializer json
function(chave, co_entidade, etapa, req, res) {
  require(recipes)
  require(RPostgres)
  require(dplyr)
  require(dbplyr)
  
  # 1. Verifica se o modelo existe no cache
  if (!chave %in% names(models_cache)) {
    res$status <- 404
    return(list(error = "Modelo não encontrado."))
  }
  
  # 2. Carrega o workflow e metadados
  model_light <- load_model_light(chave)
  workflow <- model_light$workflow
  if (is.null(workflow)) {
    res$status <- 500
    return(list(error = "Workflow inválido."))
  }
  feature_names <- model_light$feature_names
  id_col <- model_light$id_col  # "co_entidade"
  
  # 3. Conecta ao banco de dados
  con <- tryCatch(
    dbConnect(RPostgres::Postgres(), service = Sys.getenv("DB_SERVICE", "educacao")),
    error = function(e) {
      dbConnect(RPostgres::Postgres(),
        host = Sys.getenv("DB_HOST", "localhost"),
        port = Sys.getenv("DB_PORT", 5432),
        dbname = Sys.getenv("DB_NAME", "geoinova"),
        user = Sys.getenv("DB_USER", "postgres"),
        password = Sys.getenv("DB_PASSWORD")
      )
    }
  )
  on.exit(dbDisconnect(con), add = TRUE)
  
  # 4. Busca os dados da escola e etapa na materialized view
  dados_escola <- tbl(con, dbplyr::in_schema("analytics", "school_data_2023")) %>%
    filter(!!sym(id_col) == co_entidade, etapa == etapa) %>%
    collect()
  
  if (nrow(dados_escola) == 0) {
    res$status <- 404
    return(list(error = paste("Escola", co_entidade, "com etapa", etapa, "não encontrada.")))
  }
  if (nrow(dados_escola) > 1) {
    # Em caso de duplicidade inesperada, use o primeiro
    dados_escola <- dados_escola[1, , drop = FALSE]
  }
  
  # 5. Seleciona apenas as colunas esperadas pelo modelo
  dados_escola <- dados_escola %>% select(any_of(feature_names))
  missing_vars <- setdiff(feature_names, names(dados_escola))
  if (length(missing_vars) > 0) {
    res$status <- 500
    return(list(error = paste("View não possui todas as features:", paste(missing_vars, collapse = ", "))))
  }
  
  # 6. Converte tipos e prediz
  dados_escola <- type.convert(dados_escola, as.is = TRUE)
  pred <- predict(workflow, new_data = dados_escola)
  pred_val <- as.numeric(pred$.pred)
  
  # 7. Resposta
  return(list(
    modelo = chave,
    escola = co_entidade,
    etapa = etapa,
    predicao = pred_val
  ))
}
```

## Como usar

```bash
curl "http://ubatexu.lan:5173/analytic-api/models/predict/school/rf_inse_2025/35047824/fundamental_ii"
```

Resposta:
```json
{
  "modelo": "rf_inse_2025",
  "escola": "35047824",
  "etapa": "fundamental_ii",
  "predicao": 4.87
}
```

Agora a etapa é obrigatória e integra a URL. Se o parâmetro for omitido, o roteamento do Plumber retornará 404 automaticamente.

# Bug sutil no plumber

A análise combinada do seu código, do teste com o `curl` e dos logs do sistema revelou **dois erros sutis e fatais** operando em conjunto. Eles explicam perfeitamente por que a API sempre retorna o código de escola **`11000201`** no log e o mesmo valor de predição **`6.1158`** no terminal.

---

### O Erro Fatais Revelados pelo Log

#### 1. Escopo e Colisão de Nomes no SQL (`etapa == etapa`)

Como suspeitado, quando o `dbplyr` traduz a linha `filter(..., etapa == etapa)` para SQL, ele gera a cláusula `WHERE etapa = etapa`. Para o banco de dados, isso é uma tautologia (sempre verdadeiro).

* **O Impacto:** O banco simplesmente ignorou o seu parâmetro `"fundamental_i"` e trouxe todas as escolas e todas as etapas que existiam na tabela para a memória.

#### 2. Incompatibilidade de Tipos no `filter` do `dplyr`

Os parâmetros capturados pelas rotas do Plumber chegam como strings (`character`). O seu `co_entidade` na URL veio como `"29231620"`. Ao tentar comparar um texto (`character`) com uma coluna numérica no banco de dados (`bigint` ou `integer`), o `dbplyr` pode falhar silenciosamente ou invalidar o filtro de igualdade dependendo do driver.

#### O Resultado Desastroso:

Como ambos os filtros falharam na tradução para o banco, o `collect()` trouxe a materialized view **inteira** (ou as primeiras linhas dela) para o R. Logo em seguida, o seu código executou isso:

```r
if (nrow(dados_escola) > 1) {
  dados_escola <- dados_escola[1, , drop = FALSE]
}

```

Como o filtro falhou e o banco retornou milhares de linhas, o seu código pacientemente **jogou tudo fora e pegou a primeira linha da tabela**, que por coincidência é a escola **`11000201`**. Por isso, não importa qual ID você envie no `curl`, o modelo sempre calcula a nota da escola `11000201`.

---

### Como Corrigir o Código

Para resolver isso de vez, precisamos forçar a conversão de tipo das variáveis do Plumber para numérico e usar o operador de injeção (`!!`) para deixar claro ao `dbplyr` o que é coluna do banco e o que é variável local do R.

Substitua a **Etapa 4** do seu código por esta estrutura corrigida:

```r
  # ============================================================================
  # 4. Busca os dados da escola e etapa na materialized view (CORRIGIDO)
  # ============================================================================
  
  # Garante que os parâmetros vindos do Plumber possuem os tipos corretos
  co_entidade_num <- as.numeric(co_entidade)
  etapa_val <- as.character(etapa)
  
  dados_escola <- tbl(con, dbplyr::in_schema("analytics", "escola_features")) %>%
    filter(
      !!sym(id_col) == !!co_entidade_num, 
      etapa == !!etapa_val
    ) %>%
    collect()
  
  if (nrow(dados_escola) == 0) {
    res$status <- 404
    return(list(error = paste("Escola", co_entidade, "com etapa", etapa, "não encontrada.")))
  }
  
  if (nrow(dados_escola) > 1) {
    # Se ainda houver duplicidade real no banco para a MESMA etapa, pega a primeira
    dados_escola <- dados_escola[1, , drop = FALSE]
  }

```

### O que mudou?

1. **`!!co_entidade_num`**: Converte a string da URL em número antes de enviar ao Postgres.
2. **`etapa == !!etapa_val`**: O operador `!!` (unquote) força o R a avaliar o valor da variável local (`"fundamental_i"`) *antes* de enviar a query, gerando no banco um filtro correto do tipo `WHERE etapa = 'fundamental_i'`.

Ao aplicar essa mudança e reiniciar o Plumber, você verá nos logs que o ID impresso no tibble mudará a cada chamada do `curl` e as predições começarão a oscilar corretamente para cada escola!
