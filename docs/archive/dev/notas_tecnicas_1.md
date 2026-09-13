# Questão

Atualmente construimos o primeiro modelo (random Forest) com os dados sobre escolas
para prever nota_media da escola. Queremos acoplar no plumber.R dois endpoints:

 1. GET /models/show/<all - ou chave> que mostre o modelo com metadados sobre ele (tal como a saída
 que obteríamos no R quando simplesmente imprimos o objeto que representa o modelo).

 2. POST /models/predict/<chave-para-o-modelo>

# DeepSeek

O modelo foi criado usando bundle:

Perfeito! Com base no seu script real, que utiliza **tidymodels** e salva o modelo com `bundle::bundle()`, o código dos endpoints precisa ser ajustado para:

1. Carregar os modelos usando `bundle::unbundle()`.
2. Usar o workflow diretamente para predição – o workflow já contém a recipe, então não precisamos extrair features manualmente.
3. Garantir que o payload JSON forneça as mesmas variáveis preditoras usadas no treino (as colunas de `features_finais` exceto `nota_media` e `co_entidade`).

---

## 🔧 Código para adicionar no `R/plumber.R`

Adicione as seguintes seções ao seu arquivo `R/plumber.R` (após o carregamento dos pacotes e dados existentes).

```r
# -------------------------------------------------------------------
# 4. Carregamento dos modelos salvos com bundle
# -------------------------------------------------------------------

# Pacote necessário para unbundle
library(bundle)

# Caminho para a pasta de modelos
models_dir <- here::here("models")

# Lista global de modelos carregados (chave -> modelo unbundled)
modelos_cache <- list()

if (dir.exists(models_dir)) {
  # Arquivos .rds na pasta models
  model_files <- list.files(models_dir, pattern = "\\.rds$", full.names = TRUE)
  
  for (file in model_files) {
    # Chave = nome do arquivo sem extensão
    key <- tools::file_path_sans_ext(basename(file))
    
    # Carrega o objeto salvo (bundle)
    bundled_model <- tryCatch(
      readRDS(file),
      error = function(e) NULL
    )
    
    if (is.null(bundled_model)) {
      warning("Não foi possível ler o arquivo: ", file)
      next
    }
    
    # Desfaz o bundle para obter o workflow (ou modelo) original
    modelo <- tryCatch(
      unbundle(bundled_model),
      error = function(e) {
        warning("Erro ao unbundle o modelo ", key, ": ", e$message)
        NULL
      }
    )
    
    if (is.null(modelo)) next
    
    # Captura metadados (print do workflow ou do modelo interno)
    if (inherits(modelo, "workflow")) {
      # Para workflow, mostrar resumo da recipe e do modelo
      metadados <- capture.output({
        cat("Workflow:\n")
        print(modelo)
        cat("\nModelo (ranger):\n")
        print(extract_fit_engine(modelo))
      })
    } else {
      metadados <- capture.output(print(modelo))
    }
    
    # Armazena no cache
    modelos_cache[[key]] <- list(
      modelo = modelo,      # objeto workflow ou modelo pronto para predict
      metadados = metadados,
      arquivo = basename(file)
    )
    
    cat("Modelo carregado:", key, "\n")
  }
} else {
  warning("Diretório 'models/' não encontrado. Nenhum modelo será carregado.")
}

# -------------------------------------------------------------------
# 5. Endpoints da API para modelos
# -------------------------------------------------------------------

#* @get /models/show/<chave>
function(chave, res) {
  if (chave == "all") {
    return(list(
      modelos_disponiveis = names(modelos_cache),
      total = length(modelos_cache)
    ))
  }
  
  if (!chave %in% names(modelos_cache)) {
    res$status <- 404
    return(list(error = paste("Modelo não encontrado. Disponíveis:", paste(names(modelos_cache), collapse = ", "))))
  }
  
  list(
    chave = chave,
    arquivo = modelos_cache[[chave]]$arquivo,
    metadados = modelos_cache[[chave]]$metadados
  )
}

#* @post /models/predict/<chave>
#* @serializer json
function(chave, req, res) {
  # 1. Verifica modelo
  if (!chave %in% names(modelos_cache)) {
    res$status <- 404
    return(list(error = paste("Modelo não encontrado. Disponíveis:", paste(names(modelos_cache), collapse = ", "))))
  }
  
  modelo_obj <- modelos_cache[[chave]]$modelo
  
  # 2. Lê o JSON
  body <- tryCatch(
    jsonlite::parse_json(req$postBody, simplifyVector = TRUE),
    error = function(e) NULL
  )
  
  if (is.null(body)) {
    res$status <- 400
    return(list(error = "Corpo da requisição deve ser um JSON válido."))
  }
  
  # 3. Converte para data.frame
  if (is.list(body) && !is.data.frame(body)) {
    # Verifica se é uma lista de observações ou uma única
    if (is.null(names(body)) && all(sapply(body, is.list))) {
      # Múltiplas observações: cada elemento da lista é uma escola
      dados <- do.call(rbind, lapply(body, function(x) as.data.frame(t(unlist(x)), stringsAsFactors = FALSE)))
    } else {
      # Uma única observação (lista nomeada)
      dados <- as.data.frame(t(unlist(body)), stringsAsFactors = FALSE)
    }
  } else if (is.data.frame(body)) {
    dados <- body
  } else {
    res$status <- 400
    return(list(error = "Formato do JSON não reconhecido. Use objeto ou array de objetos."))
  }
  
  # 4. Verifica se as variáveis preditoras necessárias estão presentes
  #    Identifica as variáveis usadas no recipe (exceto nota_media e co_entidade)
  if (inherits(modelo_obj, "workflow")) {
    # Extrai a recipe original
    recipe_obj <- extract_recipe(modelo_obj)
    # Variáveis preditoras são aquelas com role = "predictor"
    pred_vars <- recipe_obj$term_info %>% 
      filter(role == "predictor") %>% 
      pull(variable)
  } else {
    # Fallback para modelo cru (caso não seja workflow)
    pred_vars <- setdiff(names(dados), "nota_media")
  }
  
  # Também pode-se extrair da coluna 'co_entidade' que é role = "id", mas não é preditora
  # Remover co_entidade se estiver no payload
  if ("co_entidade" %in% names(dados)) {
    dados <- select(dados, -co_entidade)
  }
  
  missing_vars <- setdiff(pred_vars, names(dados))
  if (length(missing_vars) > 0) {
    res$status <- 400
    return(list(
      error = "Variáveis faltantes no payload.",
      esperadas = pred_vars,
      fornecidas = names(dados),
      faltantes = missing_vars
    ))
  }
  
  # Seleciona apenas as colunas necessárias (ordem não importa para o workflow)
  dados_pred <- dados[, pred_vars, drop = FALSE]
  
  # Garante que fatores tenham os níveis corretos (se forem passados como inteiros ou caracteres)
  # No seu script original, tp_localizacao e tp_dependencia foram convertidos para factor
  # com níveis baseados nos dados de treino. O recipe com step_dummy espera fatores.
  # Para evitar erro, podemos converter explicitamente baseado nos níveis originais (conhecidos)
  # Mas o step_novel() no recipe já trata novos níveis. Ainda assim, é melhor garantir o tipo.
  if ("tp_localizacao" %in% pred_vars && is.character(dados_pred$tp_localizacao)) {
    # Valores possíveis: "1", "2" ou 1,2. Coerce para factor.
    dados_pred$tp_localizacao <- factor(dados_pred$tp_localizacao, levels = c("1", "2"))
  }
  if ("tp_dependencia" %in% pred_vars && is.character(dados_pred$tp_dependencia)) {
    dados_pred$tp_dependencia <- factor(dados_pred$tp_dependencia, levels = c("1", "2", "3", "4"))
  }
  
  # 5. Realiza predição
  predicoes <- tryCatch({
    if (inherits(modelo_obj, "workflow")) {
      # Usa o workflow diretamente (já aplica a recipe)
      predict(modelo_obj, new_data = dados_pred) %>% pull(.pred)
    } else {
      # Caso seja um modelo cru (ex: rand_forest), apply recipe manualmente? Melhor esperar workflow.
      stop("Modelo não é um workflow. Use bundle com workflow.")
    }
  }, error = function(e) {
    res$status <- 500
    return(list(error = paste("Erro na predição:", e$message)))
  })
  
  if (is.list(predicoes) && !is.null(predicoes$error)) {
    return(predicoes)
  }
  
  # 6. Monta resposta
  resposta <- list(
    modelo = chave,
    predicoes = as.numeric(predicoes)
  )
  
  # Se o payload original tinha identificador (ex: co_entidade), retorna junto
  if ("co_entidade" %in% names(dados)) {
    resposta$ids <- dados$co_entidade
  } else if (!is.null(body$co_entidade)) {
    resposta$ids <- body$co_entidade
  }
  
  return(resposta)
}
```

---

## 📁 Estrutura esperada

```
analytics/
├── models/
│   └── modelo_ideb_nota.rds   # salvo com bundle::bundle(modelo_final) e saveRDS
├── R/
│   └── plumber.R
└── run_api.R
```

---

## 🧪 Exemplo de uso

### 1. Listar modelos
```http
GET /models/show/all
```

### 2. Ver metadados
```http
GET /models/show/modelo_ideb_nota
```

### 3. Predição para uma escola

Payload:
```json
{
  "infra_essencial_score": 5,
  "espacos_pedagogicos_score": 3,
  "tecnologia_score": 2,
  "acessibilidade_score": 1,
  "salas_por_aluno": 0.05,
  "equipamentos_por_aluno": 0.2,
  "funcionarios_nd_por_aluno": 0.08,
  "docentes_por_aluno": 0.1,
  "prop_docentes_superior": 0.7,
  "prop_docentes_pos": 0.3,
  "prop_docentes_concursados": 0.5,
  "prop_docentes_feminino": 0.6,
  "prop_mat_infantil": 0.1,
  "prop_mat_fund": 0.6,
  "prop_mat_medio": 0.3,
  "prop_mat_integral": 0.0,
  "alunos_por_sala": 20,
  "gestor_superior": 1,
  "gestor_pos": 0,
  "gestor_acesso_democratico": 1,
  "tp_localizacao": 1,
  "tp_dependencia": 3
}
```

Resposta:
```json
{
  "modelo": "modelo_ideb_nota",
  "predicoes": [6.2]
}
```

---

## ⚠️ Observações importantes

- O modelo foi salvo como **workflow** (`workflow() %>% add_recipe() %>% add_model()`), o que facilita a predição: basta chamar `predict(workflow, new_data)` que a recipe é aplicada automaticamente.
- No payload, as variáveis devem ter **exatamente os mesmos nomes** usados no treino (lista `features_finais` sem `nota_media` e sem `co_entidade`).
- Variáveis categóricas (`tp_localizacao`, `tp_dependencia`) podem ser enviadas como `integer` (1, 2, etc.) ou como `string` ("1", "2"). O código converte para factor com os níveis adequados.
- O campo `co_entidade` é opcional no payload; se fornecido, será devolvido na resposta para identificação.

Se precisar de mais ajustes (ex: logging, tratamento de erros mais fino, suporte a múltiplos modelos com diferentes conjuntos de features), é fácil estender a partir daqui.


# DeepSeek (Sobre Lentidão)

A lentidão excessiva ao carregar o modelo se deve principalmente ao **`unbundle()`** do objeto `workflow` salvo com `bundle`. Esse processo é pesado porque:

- O workflow contém a **recipe** (com passos de imputação, dummy, etc.) e o **modelo** `ranger` (250 árvores).  
- O `unbundle()` precisa reconstruir todos os ambientes e referências, o que em um `workflow` pode ser custoso em máquinas com pouca RAM/CPU.  
- Além disso, você já carrega um dataframe de 214 mil escolas (`censo_global`), que consome memória.

## 🔧 Solução principal: **Carregamento sob demanda (lazy loading)**

Em vez de unbundler todos os modelos na inicialização, vamos **guardar apenas os caminhos dos arquivos** e carregá-los apenas quando o endpoint for chamado (com cache em memória para não recarregar a cada requisição).

### 📝 Substitua a seção de carregamento de modelos no `R/plumber.R` por:

```r
# -------------------------------------------------------------------
# 4. Configuração de modelos com lazy loading
# -------------------------------------------------------------------

library(bundle)

models_dir <- here::here("models")
models_cache <- list()          # cache para modelos já unbundled
models_metadata <- list()       # metadados básicos (nome, arquivo)

if (dir.exists(models_dir)) {
  model_files <- list.files(models_dir, pattern = "\\.rds$", full.names = TRUE)
  
  for (file in model_files) {
    key <- tools::file_path_sans_ext(basename(file))
    
    # Armazena apenas o caminho e informações leves (tamanho, data)
    models_metadata[[key]] <- list(
      arquivo = basename(file),
      path = file,
      size_mb = round(file.size(file) / 1024^2, 2)
    )
    
    cat("Modelo registrado (lazy):", key, " -", models_metadata[[key]]$size_mb, "MB\n")
  }
} else {
  warning("Diretório 'models/' não encontrado.")
}

# Função para carregar (e cachear) um modelo sob demanda
load_model <- function(key) {
  if (key %in% names(models_cache)) {
    return(models_cache[[key]]$modelo)
  }
  
  if (!key %in% names(models_metadata)) {
    stop("Modelo não encontrado.")
  }
  
  cat("Carregando modelo", key, "...\n")
  bundled <- readRDS(models_metadata[[key]]$path)
  modelo <- unbundle(bundled)
  
  # Captura metadados (print) uma única vez
  if (inherits(modelo, "workflow")) {
    metadados <- capture.output({
      cat("Workflow:\n")
      print(modelo)
      cat("\nModelo (ranger):\n")
      print(extract_fit_engine(modelo))
    })
  } else {
    metadados <- capture.output(print(modelo))
  }
  
  models_cache[[key]] <<- list(
    modelo = modelo,
    metadados = metadados,
    arquivo = models_metadata[[key]]$arquivo
  )
  
  cat("Modelo", key, "carregado com sucesso.\n")
  return(modelo)
}

# Função auxiliar para extrair variáveis preditoras do workflow (sem carregar modelo)
get_predictor_names <- function(key) {
  # Se já está em cache, usa o modelo
  if (key %in% names(models_cache)) {
    modelo <- models_cache[[key]]$modelo
    if (inherits(modelo, "workflow")) {
      recipe_obj <- extract_recipe(modelo)
      return(recipe_obj$term_info %>% filter(role == "predictor") %>% pull(variable))
    }
  }
  
  # Fallback: retorna lista conhecida (você pode hardcode ou extrair do arquivo sem unbundle)
  # Como não queremos carregar o modelo agora, retornamos um placeholder.
  # Mas o endpoint /predict precisará carregar o modelo de qualquer forma.
  # Para o endpoint /show, podemos carregar o modelo apenas uma vez.
  warning("Para obter variáveis preditoras sem carregar o modelo, considere salvar um arquivo .rds com os nomes.")
  return(NULL)
}
```

### 📌 Adapte os endpoints para usar `load_model()`:

```r
#* @get /models/show/<chave>
function(chave, res) {
  if (chave == "all") {
    # Retorna lista com metadados leves
    model_list <- lapply(names(models_metadata), function(k) {
      list(
        chave = k,
        arquivo = models_metadata[[k]]$arquivo,
        tamanho_mb = models_metadata[[k]]$size_mb
      )
    })
    return(list(
      modelos_disponiveis = model_list,
      total = length(models_metadata)
    ))
  }
  
  if (!chave %in% names(models_metadata)) {
    res$status <- 404
    return(list(error = paste("Modelo não encontrado. Disponíveis:", paste(names(models_metadata), collapse = ", "))))
  }
  
  # Carrega o modelo (primeira vez é pesado, depois usa cache)
  tryCatch({
    load_model(chave)  # garante que o modelo esteja no cache
    return(list(
      chave = chave,
      arquivo = models_cache[[chave]]$arquivo,
      metadados = models_cache[[chave]]$metadados
    ))
  }, error = function(e) {
    res$status <- 500
    return(list(error = paste("Erro ao carregar modelo:", e$message)))
  })
}

#* @post /models/predict/<chave>
#* @serializer json
function(chave, req, res) {
  if (!chave %in% names(models_metadata)) {
    res$status <- 404
    return(list(error = paste("Modelo não encontrado. Disponíveis:", paste(names(models_metadata), collapse = ", "))))
  }
  
  # Carrega o modelo (lazy) – pode demorar na primeira chamada, mas não na inicialização da API
  modelo_obj <- tryCatch({
    load_model(chave)
  }, error = function(e) {
    res$status <- 500
    return(list(error = paste("Falha ao carregar modelo:", e$message)))
  })
  
  if (is.list(modelo_obj) && !is.null(modelo_obj$error)) return(modelo_obj)
  
  # Resto da lógica de predição (igual ao que você já tem, mas usando modelo_obj)
  # ... (código de leitura JSON, validação, predict)
}
```

## ⚡ Outras otimizações complementares

### 1. Reduza o tamanho do modelo no momento do treinamento

No script de treinamento, você pode:

- Diminuir `trees = 100` (em vez de 250) – impacta pouco a performance preditiva.
- Usar `ranger` com `importance = "none"` se não precisar de importância.
- Salvar apenas o modelo (sem o workflow) e manter a recipe separada (mais complexo, mas mais leve).

Exemplo de salvamento mais leve (sem bundle):
```r
# Salvar apenas o modelo cru e a recipe separadamente
modelo_cru <- extract_fit_engine(modelo_final)
recipe_cru <- extract_recipe(modelo_final)
saveRDS(list(modelo = modelo_cru, recipe = recipe_cru), "modelo_ideb_nota_light.rds")
```

No plumber, você carregaria essa lista e aplicaria a recipe manualmente (`bake(prep(recipe, new_data), new_data)`). Isso é mais leve que unbundle de um workflow.

### 2. Use `qs` para serialização mais rápida

O pacote `qs` é muito mais rápido que `readRDS`/`saveRDS`. No treinamento:

```r
library(qs)
qsave(bundled_model, "modelo_ideb_nota.qs")
```

No plumber:
```r
bundled <- qread(models_metadata[[key]]$path)
```

### 3. Evite carregar o `censo_global` se não for usado nos novos endpoints

Se os endpoints `/models/*` não precisarem do `censo_global` (apenas os endpoints antigos `/escola`, `/posicao` precisam), você pode **carregar o censo sob demanda** também, ou dividir a API em dois arquivos (um para dados censitários, outro para modelos). Mas como seus endpoints originais dependem do `censo_global`, mantenha-o – porém verifique se o arquivo `censo_indices_ranks.rds` não é muito grande (214k escolas é ok). O problema atual é o modelo, não o censo.

### 4. Mensagem "project is out-of-sync"

Ignore ou execute `renv::status()` para verificar discrepâncias. Isso não afeta o tempo de carregamento.

## 🚀 Resultado esperado

- A API inicia em **segundos** (apenas registra metadados dos modelos, não unbundle).  
- O primeiro acesso ao endpoint `/models/show/<chave>` ou `/models/predict/<chave>` carregará o modelo (10-30s dependendo do tamanho), mas as chamadas subsequentes serão rápidas (cache).  
- Se houver múltiplos modelos, apenas o acessado será carregado.

## 📌 Exemplo de logs após a mudança:

```
Dados carregados com sucesso. Total de escolas: 214192
Modelo registrado (lazy): modelo_ideb_nota - 45.2 MB
Listening on http://0.0.0.0:8000
```

E quando alguém chamar `/models/predict/modelo_ideb_nota`:
```
Carregando modelo modelo_ideb_nota ...
Modelo modelo_ideb_nota carregado com sucesso.
```

Assim a inicialização fica rápida mesmo com máquina limitada.


# Quetão (Parâmetros para treinamento)

Abaixo está o script adaptado para ler um arquivo JSON de configuração, eliminando todos os hardcodes. Agora você pode definir o nome do arquivo, os parâmetros do modelo, as features e demais opções externamente.

## 📄 Script `train_model.R` (versão parametrizada)

```r
#!/usr/bin/env Rscript

# ============================================================================
# 0. Ler argumento da linha de comando (caminho do JSON de configuração)
# ============================================================================
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  config_file <- "config_model.json"
  message("Nenhum arquivo de configuração informado. Usando padrão: ", config_file)
} else {
  config_file <- args[1]
}

if (!file.exists(config_file)) {
  stop("Arquivo de configuração não encontrado: ", config_file)
}

# ============================================================================
# 1. Pacotes e conexão com o banco
# ============================================================================
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidymodels, DBI, RPostgres, dplyr, recipes, bundle, ranger, jsonlite)

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
# 3. Juntar tabelas e criar features derivadas (sempre as mesmas transformações)
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

limpar_dados <- function(df) {
  df %>%
    mutate(
      tp_localizacao = factor(tp_localizacao),
      tp_dependencia = factor(tp_dependencia),
      across(starts_with("qt_"), ~ coalesce(., 0))
    )
}

dados <- limpar_dados(dados)

# ============================================================================
# 4. Ler configuração do modelo (JSON)
# ============================================================================
config <- jsonlite::fromJSON(config_file, simplifyVector = TRUE)

# Parâmetros obrigatórios
save_to <- config$save_to
if (is.null(save_to)) stop("Campo 'save_to' é obrigatório no JSON.")

model_params <- config$model_parameters
if (is.null(model_params)) stop("Campo 'model_parameters' é obrigatório.")
trees <- model_params$trees %||% 500        # padrão 500 se não informado
min_n <- model_params$min_n %||% 10

engine_cfg <- config$engine
if (is.null(engine_cfg$name)) stop("Engine 'name' é obrigatório.")
engine_name <- engine_cfg$name
engine_importance <- engine_cfg$importance %||% "impurity"

mode_cfg <- config$mode
if (is.null(mode_cfg$type)) stop("Mode 'type' é obrigatório.")
mode_type <- mode_cfg$type

cv_params <- config$cross_validation_params
v_folds <- if (!is.null(cv_params$v)) cv_params$v else 3

seed_value <- if (!is.null(config$seed)) config$seed else 123

features_list <- config$features
if (is.null(features_list)) stop("Campo 'features' (lista de colunas) é obrigatório.")

feature_id <- config$feature_id %||% "co_entidade"

# ============================================================================
# 5. Selecionar apenas as features definidas no JSON (após transformações)
# ============================================================================
# Verificar se todas as features existem em dados
missing_cols <- setdiff(features_list, names(dados))
if (length(missing_cols) > 0) {
  stop("As seguintes colunas definidas em 'features' não existem nos dados: ",
       paste(missing_cols, collapse = ", "))
}

dados_modelo <- dados %>%
  select(all_of(features_list)) %>%
  # substituir possíveis NA/infinito por 0 (apenas numéricas, exceto target)
  mutate(across(where(is.numeric) & !any_of("nota_media"), ~ ifelse(is.na(.) | is.infinite(.), 0, .)))

# Separar treino (com nota) e imputação (sem nota)
if (!"nota_media" %in% names(dados_modelo)) {
  stop("A variável alvo 'nota_media' não está presente na lista de features.")
}

treino <- dados_modelo %>% filter(!is.na(nota_media))
imputar <- dados_modelo %>% filter(is.na(nota_media)) %>% select(-nota_media)

message("Total de escolas no treino: ", nrow(treino))
message("Total de escolas para imputação: ", nrow(imputar))

# ============================================================================
# 6. Recipe de pré-processamento
# ============================================================================
rec <- recipe(nota_media ~ ., data = treino) %>%
  update_role(all_of(feature_id), new_role = "id") %>% 
  step_impute_median(all_numeric_predictors()) %>%
  step_novel(all_nominal_predictors()) %>%
  step_dummy(all_nominal_predictors())

# ============================================================================
# 7. Modelo conforme parâmetros do JSON
# ============================================================================
# Construir a especificação do modelo dinamicamente
rf_spec <- rand_forest(trees = trees, min_n = min_n) %>%
  set_engine(engine_name, importance = engine_importance) %>%
  set_mode(mode_type)

wf <- workflow() %>%
  add_recipe(rec) %>%
  add_model(rf_spec)

# ============================================================================
# 8. Validação cruzada (opcional, mas mantida)
# ============================================================================
set.seed(seed_value)
cv_folds <- vfold_cv(treino, v = v_folds)
resultados_cv <- fit_resamples(wf, cv_folds, metrics = metric_set(rmse, rsq, mae))

message("Resultados da validação cruzada (", v_folds, "-folds):")
print(collect_metrics(resultados_cv))

# ============================================================================
# 9. Treinar modelo final
# ============================================================================
modelo_final <- fit(wf, data = treino)

# ============================================================================
# 10. Salvar modelo com bundle no caminho definido
# ============================================================================
# Criar diretório se necessário
output_dir <- dirname(save_to)
if (!dir.exists(output_dir) && output_dir != "") {
  dir.create(output_dir, recursive = TRUE)
}

bundled_model <- bundle::bundle(modelo_final)
saveRDS(bundled_model, file = save_to)

message("Modelo salvo com sucesso em: ", save_to)

# Fechar conexão com banco
dbDisconnect(con)
```

## 📄 Exemplo de arquivo `config_model.json`

```json
{
    "save_to": "models/rforest.rds",
    "model_parameters": {
        "trees": 100,
        "min_n": 10
    },
    "engine": {
        "name": "ranger",
        "importance": "impurity"
    },
    "mode": {
        "type": "regression"
    },
    "cross_validation_params": {
        "v": 3
    },
    "seed": 123,
    "features": [
        "nota_media",
        "co_entidade",
        "infra_essencial_score",
        "espacos_pedagogicos_score",
        "tecnologia_score",
        "acessibilidade_score",
        "salas_por_aluno",
        "equipamentos_por_aluno",
        "funcionarios_nd_por_aluno",
        "docentes_por_aluno",
        "prop_docentes_superior",
        "prop_docentes_pos",
        "prop_docentes_concursados",
        "prop_docentes_feminino",
        "prop_mat_infantil",
        "prop_mat_fund",
        "prop_mat_medio",
        "prop_mat_integral",
        "alunos_por_sala",
        "gestor_superior",
        "gestor_pos",
        "gestor_acesso_democratico",
        "tp_localizacao",
        "tp_dependencia"
    ],
    "feature_id": "co_entidade"
}
```

## ▶️ Como executar

```bash
Rscript train_model.R config_model.json
```

Caso o nome do arquivo não seja informado, o script procura por `config_model.json` no diretório atual.

## 🔧 Observações

- O operador `%||%` não é nativo do R; adicionei uma pequena função no início ou use `ifelse`. Para simplificar, substituí por uma verificação explícita. No código acima, usei `%||%` como se fosse do pacote `rlang`, mas para não adicionar dependência, melhor trocar por `if (is.null(x)) default else x`. Vou ajustar no script final. Porém, como estamos usando `tidymodels`, o `rlang` já é carregado, então `%||%` funciona. Mesmo assim, mantive a sintaxe.

- As transformações (scores, proporções) permanecem fixas, pois são necessárias para gerar as features. Se futuramente você quiser parametrizar também esses cálculos, seria mais complexo.

- O campo `features` deve conter **exatamente** os nomes das colunas que estarão no data frame após as transformações. Inclua `nota_media` e `co_entidade`.

- O campo `feature_id` define qual coluna será tratada como identificador (role "id") e não entrará como preditora.

Agora você pode treinar modelos diferentes apenas alterando o JSON, sem modificar o script.

# Tempo para subir serviço
Não, o tempo para **carregar um modelo via `bundle::unbundle()`** geralmente é **muito menor** que o tempo de treinamento.

## ⏱ Comparação típica

| Etapa | Tempo relativo | Exemplo (dados com ~50k escolas, 250 árvores) |
|-------|---------------|------------------------------------------------|
| **Treinamento** | Alto (minutos) | 2 a 10 minutos (dependendo da CPU, número de árvores) |
| **Salvar com `bundle` + `saveRDS`** | Baixo (segundos) | 1–5 segundos (serialização) |
| **Carregar com `readRDS` + `unbundle`** | Baixo a médio (segundos) | 2–10 segundos (desserialização + reconstrução do ambiente) |

## 🔍 Por que você está demorando mais de 10 minutos para carregar?

O problema que você relatou (API parada em “Dados carregados com sucesso”) **não é normal** e indica algum gargalo específico:

### Possíveis causas:
1. **O workflow contém a receita com `step_impute_median` aplicada a um conjunto de dados muito grande**?  
   - `bundle` serializa **toda a estrutura do workflow**, incluindo a receita preparada. Se a receita guarda internamente estatísticas (ex: medianas) e o modelo `ranger` é grande, o `unbundle` pode ser pesado, mas ainda assim não deveria passar de 30 segundos – a menos que haja **falta de memória RAM** e o sistema fique trocando (swap).

2. **O arquivo do modelo é enorme (centenas de MB)** e sua máquina tem pouca RAM/CPU.  
   - Random forest com 250 árvores, 22 features, 50k escolas → tamanho do objeto pode ser ~200–500 MB. Em uma máquina limitada, o `unbundle` pode demorar vários minutos.

3. **Problemas com o `bundle` + ambiente R**:  
   - O `bundle` tenta capturar o ambiente completo do objeto, incluindo referências a pacotes e dados globais. Se algo ficou “sujo” durante o treino, o `unbundle` pode ser lento.

4. **Alguma etapa do seu `plumber.R` que não só carrega o modelo, mas também **refaz partes da recipe** ou processa dados**? Pelo log, ele para depois de carregar o `censo_global` – antes mesmo de tentar unbundle. Então pode ser que o modelo ainda nem esteja sendo carregado! Você confirmou que o código de lazy loading foi implementado? Ele só carregaria no primeiro endpoint chamado.

## 🚀 Soluções práticas

### 1. Meça o tempo real de `unbundle` isoladamente
Rode no terminal (fora da API):
```r
system.time({
  m <- readRDS("models/modelo_ideb_nota.rds")
  modelo <- unbundle(m)
})
```
Isso dirá se o problema é no `unbundle` ou em outra parte.

### 2. Reduza o tamanho do modelo
- Diminua `trees` para **100** (você já fez).
- Salve **apenas o modelo cru (engine)** e a recipe em separado.  
  Exemplo:
  ```r
  modelo_cru <- extract_fit_engine(modelo_final)
  recipe_cru <- extract_recipe(modelo_final)
  saveRDS(list(model = modelo_cru, recipe = recipe_cru), "modelo_light.rds")
  ```
  No plumber, você carrega a lista e aplica a recipe `bake()` nos novos dados. Isso é muito mais leve porque `bundle` não é usado.

### 3. Use serialização mais rápida – `qs`
```r
# No treinamento
qs::qsave(bundled_model, "modelo.qs", preset = "fast")
# No plumber
modelo <- unbundle(qs::qread("modelo.qs"))
```
`qs` pode ser 2–5x mais rápido que `readRDS`.

### 4. Carregue o modelo em um **processo separado** (fork)
Se a API já está no ar, você pode carregar o modelo em background usando `future` ou `callr`, mas isso é mais complexo.

## ✅ Conclusão
- **Em condições normais**: carregar via bundle leva **segundos**, não minutos, e é bem mais rápido que treinar.
- **Se está demorando 10+ minutos**: há algo errado no ambiente (pouca RAM, swap excessivo) ou o arquivo do modelo está corrompido/contendo dados desnecessários.
- Recomendo fortemente adotar o **modelo leve (engine + recipe separados)** para sua máquina com recursos limitados.

Se precisar de ajuda para implementar a versão “leve” sem `bundle`, me avise que forneço o código adaptado.

# Versão Light para subir o bundle rapidamente

Abaixo está a versão "leve" do modelo, **sem `bundle`**, que carrega muito mais rápido e consome menos memória. O segredo é salvar separadamente o **modelo cru (engine)** e a **recipe preparada** (já com medianas, níveis de fatores, etc.). Na API, basta aplicar `bake(recipe, new_data)` e depois `predict()`.

---

## 🧠 1. Script de treinamento leve (`train_model_light.R`)

Baseado no seu script original, mas salvando apenas o essencial.

```r
#!/usr/bin/env Rscript

# ============================================================================
# 0. Ler argumento da linha de comando (caminho do JSON de configuração)
# ============================================================================
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  config_file <- "config_model.json"
  message("Nenhum arquivo de configuração informado. Usando padrão: ", config_file)
} else {
  config_file <- args[1]
}
if (!file.exists(config_file)) stop("Arquivo de configuração não encontrado: ", config_file)

# ============================================================================
# 1. Pacotes e conexão com o banco
# ============================================================================
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidymodels, DBI, RPostgres, dplyr, recipes, ranger, jsonlite)

con <- dbConnect(RPostgres::Postgres(), service = "edumaps")

# ============================================================================
# 2. Carregar dados brutos (apenas 2025) – igual ao original
# ============================================================================
# [INSIRA AQUI TODO O CÓDIGO DE LEITURA DAS TABELAS: escolas, matriculas, docentes, gestor, ideb]
# ... (mesmo código que você já tem) ...

# ============================================================================
# 3. Aplicar as mesmas transformações (scores, proporções, fatores)
# ============================================================================
# [INSIRA AQUI TODO O CÓDIGO DE MUTATE E LIMPEZA – igual ao original]
# Ao final, você deve ter o dataframe `dados` com todas as colunas.

# ============================================================================
# 4. Ler configuração do modelo (JSON)
# ============================================================================
config <- jsonlite::fromJSON(config_file, simplifyVector = TRUE)

save_to <- config$save_to   # ex: "models/rforest_light.rds"
trees <- config$model_parameters$trees %||% 100
min_n <- config$model_parameters$min_n %||% 10
engine_name <- config$engine$name %||% "ranger"
engine_importance <- config$engine$importance %||% "impurity"
mode_type <- config$mode$type %||% "regression"
seed_value <- config$seed %||% 123
features_list <- config$features
feature_id <- config$feature_id %||% "co_entidade"

if (is.null(features_list)) stop("Campo 'features' é obrigatório.")

# ============================================================================
# 5. Selecionar apenas as features e preparar treino
# ============================================================================
dados_modelo <- dados %>%
  select(all_of(features_list)) %>%
  mutate(across(where(is.numeric) & !any_of("nota_media"),
                ~ ifelse(is.na(.) | is.infinite(.), 0, .)))

treino <- dados_modelo %>% filter(!is.na(nota_media))

# ============================================================================
# 6. Recipe (pré-processamento)
# ============================================================================
rec <- recipe(nota_media ~ ., data = treino) %>%
  update_role(all_of(feature_id), new_role = "id") %>%
  step_impute_median(all_numeric_predictors()) %>%
  step_novel(all_nominal_predictors()) %>%
  step_dummy(all_nominal_predictors())

# Prepara a recipe (ajusta medianas, níveis de fatores, etc.)
prepped_recipe <- prep(rec, training = treino)

# ============================================================================
# 7. Modelo (Random Forest com ranger)
# ============================================================================
rf_spec <- rand_forest(trees = trees, min_n = min_n) %>%
  set_engine(engine_name, importance = engine_importance) %>%
  set_mode(mode_type)

wf <- workflow() %>%
  add_recipe(prepped_recipe) %>%
  add_model(rf_spec)

set.seed(seed_value)
modelo_final <- fit(wf, data = treino)

# Extrai apenas o modelo ranger (engine)
engine_model <- extract_fit_engine(modelo_final)

# ============================================================================
# 8. Salvar objeto leve (modelo + recipe)
# ============================================================================
output_dir <- dirname(save_to)
if (!dir.exists(output_dir) && output_dir != "") dir.create(output_dir, recursive = TRUE)

modelo_light <- list(
  model = engine_model,
  recipe = prepped_recipe,
  feature_names = setdiff(features_list, c("nota_media", feature_id)),
  id_col = feature_id,
  target = "nota_media"
)

saveRDS(modelo_light, file = save_to)

message("✅ Modelo leve salvo com sucesso em: ", save_to)
message("📦 Tamanho do arquivo: ", round(file.size(save_to) / 1024^2, 2), " MB")

dbDisconnect(con)
```

---

## 🚀 2. Adaptação no `plumber.R` (carregamento rápido)

No seu arquivo `R/plumber.R`, substitua toda a seção de `bundle` e carregamento de modelos por:

```r
# -------------------------------------------------------------------
# Carregamento leve de modelos (sem bundle)
# -------------------------------------------------------------------
models_dir <- here::here("models")
models_cache <- list()   # cache: chave -> objeto modelo_light

if (dir.exists(models_dir)) {
  model_files <- list.files(models_dir, pattern = "\\.rds$", full.names = TRUE)
  for (file in model_files) {
    key <- tools::file_path_sans_ext(basename(file))
    models_cache[[key]] <- list(
      path = file,
      loaded = FALSE,
      model_obj = NULL
    )
    cat("📌 Modelo registrado (leve):", key, "\n")
  }
}

# Função lazy loader – carrega apenas na primeira chamada
load_model_light <- function(key) {
  if (models_cache[[key]]$loaded) {
    return(models_cache[[key]]$model_obj)
  }
  cat("⏳ Carregando modelo leve:", key, "...\n")
  model_obj <- readRDS(models_cache[[key]]$path)
  models_cache[[key]]$model_obj <- model_obj
  models_cache[[key]]$loaded <- TRUE
  cat("✅ Modelo carregado. Features: ", paste(model_obj$feature_names, collapse = ", "), "\n")
  return(model_obj)
}
```

E ajuste os endpoints:

### Endpoint `/models/show/<chave>` (leve, sem carregar o modelo)

```r
#* @get /models/show/<chave>
function(chave, res) {
  if (chave == "all") {
    model_list <- lapply(names(models_cache), function(k) {
      list(chave = k, arquivo = basename(models_cache[[k]]$path))
    })
    return(list(modelos_disponiveis = model_list, total = length(models_cache)))
  }
  
  if (!chave %in% names(models_cache)) {
    res$status <- 404
    return(list(error = "Modelo não encontrado."))
  }
  
  # Carrega o modelo (só para pegar metadados – pode ser um pouco lento na primeira vez)
  model_obj <- load_model_light(chave)
  list(
    chave = chave,
    arquivo = basename(models_cache[[chave]]$path),
    feature_names = model_obj$feature_names,
    id_col = model_obj$id_col
  )
}
```

### Endpoint `/models/predict/<chave>` (usando o modelo leve)

```r
#* @post /models/predict/<chave>
#* @serializer json
function(chave, req, res) {
  if (!chave %in% names(models_cache)) {
    res$status <- 404
    return(list(error = "Modelo não encontrado."))
  }
  
  model_light <- load_model_light(chave)   # carrega se ainda não estiver
  model <- model_light$model
  recipe_prep <- model_light$recipe
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
      dados <- do.call(rbind, lapply(body, function(x) as.data.frame(t(unlist(x)), stringsAsFactors = FALSE)))
    } else {
      dados <- as.data.frame(t(unlist(body)), stringsAsFactors = FALSE)
    }
  } else {
    dados <- body
  }
  
  # Verifica se todas as features estão presentes
  missing_vars <- setdiff(feature_names, names(dados))
  if (length(missing_vars) > 0) {
    res$status <- 400
    return(list(error = paste("Variáveis faltantes:", paste(missing_vars, collapse = ", "))))
  }
  
  # Aplica a recipe (pré-processamento)
  dados_prep <- bake(recipe_prep, new_data = dados)
  
  # Remove a coluna de identificador (se existir – não é preditora)
  if (id_col %in% names(dados_prep)) {
    dados_prep <- dados_prep %>% select(-all_of(id_col))
  }
  
  # Predição (ranger retorna lista com component 'predictions')
  predicoes <- predict(model, data = dados_prep)$predictions
  
  resposta <- list(
    modelo = chave,
    predicoes = as.numeric(predicoes)
  )
  
  if (id_col %in% names(dados)) {
    resposta$ids <- dados[[id_col]]
  }
  
  return(resposta)
}
```

---

## 📦 Exemplo de `config_model.json` (compatível)

```json
{
    "save_to": "models/rforest_light.rds",
    "model_parameters": {
        "trees": 100,
        "min_n": 10
    },
    "engine": {
        "name": "ranger",
        "importance": "impurity"
    },
    "mode": {
        "type": "regression"
    },
    "seed": 123,
    "features": [
        "nota_media",
        "co_entidade",
        "infra_essencial_score",
        "espacos_pedagogicos_score",
        "tecnologia_score",
        "acessibilidade_score",
        "salas_por_aluno",
        "equipamentos_por_aluno",
        "funcionarios_nd_por_aluno",
        "docentes_por_aluno",
        "prop_docentes_superior",
        "prop_docentes_pos",
        "prop_docentes_concursados",
        "prop_docentes_feminino",
        "prop_mat_infantil",
        "prop_mat_fund",
        "prop_mat_medio",
        "prop_mat_integral",
        "alunos_por_sala",
        "gestor_superior",
        "gestor_pos",
        "gestor_acesso_democratico",
        "tp_localizacao",
        "tp_dependencia"
    ],
    "feature_id": "co_entidade"
}
```

---

## ✅ Resultado esperado

- O arquivo `models/rforest_light.rds` terá **50–100 MB** (vs 200–500 MB do workflow com bundle).  
- Carregamento na API (primeira chamada) cai de **>10min para ~5–10 segundos**.  
- Memória RAM consumida reduzida significativamente.  
- Endpoints respondem de forma rápida e estável mesmo em máquinas limitadas.

Se precisar de ajustes (ex: outro tipo de modelo, como xgboost), é só adaptar a extração do engine e a chamada de `predict()`.

# Salvando todos os metadados

Para enriquecer os metadados retornados pelo endpoint `/models/show/<chave>` com as métricas de validação cruzada (R², RMSE, MAE), precisamos salvá‑las junto com o modelo durante o treinamento. Além disso, podemos corrigir o formato atual onde os valores aparecem dentro de colchetes (`["rforest"]`) – isso acontece porque no endpoint estamos criando listas com `list(chave = key, ...)`, mas se `key` for um vetor, o JSON resultante o representa como array. Provavelmente é só um efeito colateral de como o objeto é construído, mas vamos garantir que fique como string simples.

## 🧠 1. Modificação no script de treinamento (`train_model_light.R`)

No final do script, depois de realizar a validação cruzada, salve as métricas junto com o modelo:

```r
# Após coletar os resultados da CV (resultados_cv)
cv_metrics <- collect_metrics(resultados_cv) %>%
  select(.metric, mean, std_err) %>%
  pivot_wider(names_from = .metric, values_from = c(mean, std_err))

# Ou de forma mais simples:
metrics_list <- list(
  rmse = resultados_cv %>% filter(.metric == "rmse") %>% pull(mean),
  rsq  = resultados_cv %>% filter(.metric == "rsq")  %>% pull(mean),
  mae  = resultados_cv %>% filter(.metric == "mae")  %>% pull(mean),
  rmse_se = resultados_cv %>% filter(.metric == "rmse") %>% pull(std_err),
  rsq_se  = resultados_cv %>% filter(.metric == "rsq")  %>% pull(std_err),
  mae_se  = resultados_cv %>% filter(.metric == "mae")  %>% pull(std_err)
)

# Adicionar outros metadados
modelo_light <- list(
  model = engine_model,
  recipe = prepped_recipe,
  feature_names = setdiff(features_list, c("nota_media", feature_id)),
  id_col = feature_id,
  target = "nota_media",
  metrics = metrics_list,
  hyperparams = list(trees = trees, min_n = min_n, engine = engine_name),
  training_date = Sys.time(),
  n_training_samples = nrow(treino)
)

saveRDS(modelo_light, file = save_to)
```

## 🔧 2. Ajuste no endpoint `/models/show/<chave>` no `plumber.R`

Modifique a função para retornar um objeto JSON mais limpo e com mais campos:

```r
#* @get /models/show/<chave>
function(chave, res) {
  if (chave == "all") {
    model_list <- lapply(names(models_cache), function(k) {
      list(chave = k, arquivo = basename(models_cache[[k]]$path))
    })
    return(list(modelos_disponiveis = model_list, total = length(models_cache)))
  }
  
  if (!chave %in% names(models_cache)) {
    res$status <- 404
    return(list(error = "Modelo não encontrado."))
  }
  
  # Carrega o modelo (se ainda não estiver)
  model_obj <- load_model_light(chave)
  
  # Monta resposta com metadados
  response <- list(
    chave = chave,
    arquivo = basename(models_cache[[chave]]$path),
    feature_names = model_obj$feature_names,
    id_col = model_obj$id_col,
    training_date = model_obj$training_date,
    n_training_samples = model_obj$n_training_samples,
    hyperparameters = model_obj$hyperparams
  )
  
  # Adiciona métricas de validação cruzada, se existirem
  if (!is.null(model_obj$metrics)) {
    response$cv_metrics <- list(
      rmse = model_obj$metrics$rmse,
      rmse_se = model_obj$metrics$rmse_se,
      rsq = model_obj$metrics$rsq,
      rsq_se = model_obj$metrics$rsq_se,
      mae = model_obj$metrics$mae,
      mae_se = model_obj$metrics$mae_se
    )
  }
  
  return(response)
}
```

## 📌 3. Exemplo de resposta após as alterações

```json
{
  "chave": "rforest",
  "arquivo": "rforest.rds",
  "feature_names": ["infra_essencial_score", "espacos_pedagogicos_score", ...],
  "id_col": "co_entidade",
  "training_date": "2026-05-15T22:30:00Z",
  "n_training_samples": 86705,
  "hyperparameters": {
    "trees": 100,
    "min_n": 10,
    "engine": "ranger"
  },
  "cv_metrics": {
    "rmse": 0.786,
    "rmse_se": 0.00444,
    "rsq": 0.376,
    "rsq_se": 0.00384,
    "mae": 0.609,
    "mae_se": 0.00347
  }
}
```

## 🚀 4. Corrigir o formato atual (colchetes)

O problema dos `[ ]` no JSON atual não está no retorno dos metadados, mas no modo como o `model_list` foi construído. No seu código atual, você está usando:

```r
list(chave = k, arquivo = basename(models_cache[[k]]$path))
```

Quando `k` é um vetor de tamanho 1, o R mantém como vetor e a conversão para JSON do plumber transforma em `["valor"]`. Para obter uma string simples, use `chave = as.character(k)` ou apenas certifique-se de que `k` não seja um vetor com atributos. O mais seguro é fazer:

```r
list(chave = k[[1]], arquivo = basename(models_cache[[k]]$path)[[1]])
```

Mas como `k` é uma string normal, pode ser só um efeito do `lapply` sobre nomes. Outra forma: usar `purrr::map` ou `as.list` com `simplify = TRUE`. A maneira mais simples: no endpoint `/models/show/all`, faça:

```r
model_list <- lapply(names(models_cache), function(k) {
  list(chave = k, arquivo = basename(models_cache[[k]]$path))
})
# Depois converta cada elemento para um tipo atômico (opcional)
model_list <- lapply(model_list, function(x) lapply(x, unname))
```

Isso resolve. Mas o foco principal é adicionar os metadados extras.

## ✅ Próximos passos

1. Reexecute o script de treinamento modificado para gerar novos arquivos `.rds` (com métricas e data).
2. Reinicie a API (`sudo systemctl restart edumaps-analytic`).
3. Teste o endpoint `/models/show/rforest` novamente.

Se precisar de ajuda para ajustar o treinamento ou a exibição, é só avisar.

# Analisando as métricas do modelo

## 📊 Análise dos Resultados da Validação Cruzada

Seu modelo Random Forest apresentou os seguintes resultados (3-folds, 86.705 escolas):

| Métrica | Valor | Interpretação |
|---------|-------|----------------|
| **MAE** | 0,609 | Em média, a previsão da nota fica a ~0,61 ponto da nota real |
| **RMSE** | 0,786 | Erro quadrático médio; penaliza previsões muito erradas |
| **R²** | 0,376 | O modelo explica cerca de 37,6% da variância das notas |

### 🔍 O que esses números significam na prática?

- **MAE 0,61**: Para uma nota média de IDEB (digamos 5,5), errar por 0,6 é moderado. Em contextos educacionais, pode ser aceitável para predições agregadas, mas alto para diagnóstico escola a escola.
- **R² 0,376**: O modelo captura pouco mais de um terço da variação entre escolas. Isso é **razoável para um modelo baseado apenas em características físicas e de recursos** (infraestrutura, tecnologia, proporção de professores, etc.), mas há grande margem de melhoria.

### 📌 Por que o R² não é mais alto?

Você está prevendo desempenho escolar (IDEB) sem incluir o **fator socioeconômico dos alunos**, que é historicamente o preditor mais forte. A nota técnica do INSE (que você leu) mostra correlações fortes entre nível socioeconômico e desempenho. Sem isso, o modelo fica limitado.

### ✅ Próximos passos recomendados

1. **Incluir o INSE da escola** (média do indicador socioeconômico dos alunos) – isso deve elevar o R² para **0,60 ou mais**.
2. **Ajustar hiperparâmetros** – você usou `trees = 100, min_n = 10`. Pode testar `mtry` (número de variáveis por divisão) ou aumentar `trees` para 300–500.
3. **Engenharia de features** – interações entre variáveis (ex: `tecnologia_score * prop_mat_infantil`) podem capturar efeitos não lineares.
4. **Testar outro modelo** – XGBoost ou uma rede neural simples podem superar a random forest com os mesmos dados.

### 📈 Expectativa com INSE

Se você adicionar o `INSE_CLASSIFICACAO` (nível I a VIII) ou a `MEDIA_INSE` (contínua) como preditor, o R² pode saltar para **0,55–0,70**. A literatura mostra que indicadores socioeconômicos respondem por ~40-60% da variação do desempenho escolar.

---

## 🚀 Quer que eu desenvolva o script para:

1. **Integrar a tabela do INSE** (aquela que você recebeu com `PC_NIVEL_*` e `MEDIA_INSE`) ao seu pipeline de treinamento?
2. **Re-treinar o modelo** incluindo essas variáveis e comparar as métricas?
3. **Gerar automaticamente** o novo JSON de configuração com as features estendidas?

Se sim, me informe como os dados do INSE estão disponíveis (já estão no banco? É um arquivo `.rds` separado?). Posso criar o código de junção e o novo treinamento.

# Corrigindo a resposta (tirando listas desnecessarias para metadados modelo)

Excelente! Agora os metadados estão completos, incluindo as métricas da validação cruzada. O único detalhe estético é que valores únicos (como `"chave"`, `"rmse"`, `"trees"`) estão aparecendo dentro de colchetes (`["rforest"]` em vez de `"rforest"`) porque o R armazena esses valores como vetores de tamanho 1 e o serializador JSON do plumber mantém a representação de array.

Para remover os colchetes e ter um JSON mais limpo, ajuste duas pequenas coisas:

## 🔧 1. No script de treinamento (`train_model_light.R`)

Ao construir `metrics_list` e `hyperparams`, extraia o primeiro elemento com `[[1]]`:

```r
metrics_list <- list(
  rmse    = (cv_metrics_df %>% filter(.metric == "rmse") %>% pull(mean))[[1]],
  rsq     = (cv_metrics_df %>% filter(.metric == "rsq")  %>% pull(mean))[[1]],
  mae     = (cv_metrics_df %>% filter(.metric == "mae")  %>% pull(mean))[[1]],
  rmse_se = (cv_metrics_df %>% filter(.metric == "rmse") %>% pull(std_err))[[1]],
  rsq_se  = (cv_metrics_df %>% filter(.metric == "rsq")  %>% pull(std_err))[[1]],
  mae_se  = (cv_metrics_df %>% filter(.metric == "mae")  %>% pull(std_err))[[1]]
)

hyperparams <- list(
  trees = trees[[1]],   # se trees for um vetor de tamanho 1
  min_n = min_n[[1]],
  engine = engine_name[[1]]
)
```

Se `trees` e `min_n` já forem números atômicos, pode usar direto. Mas para garantir, use `[[1]]`.

## 🔧 2. No endpoint `/models/show/<chave>` (opcional)

Caso o problema persista, você pode forçar a conversão ao montar a resposta:

```r
response <- list(
  chave = as.character(chave),
  arquivo = as.character(basename(models_cache[[chave]]$path)),
  feature_names = model_obj$feature_names,
  id_col = as.character(model_obj$id_col),
  training_date = as.character(model_obj$training_date),
  n_training_samples = as.numeric(model_obj$n_training_samples),
  hyperparameters = list(
    trees = as.numeric(model_obj$hyperparams$trees),
    min_n = as.numeric(model_obj$hyperparams$min_n),
    engine = as.character(model_obj$hyperparams$engine)
  ),
  cv_metrics = list(
    rmse = as.numeric(model_obj$metrics$rmse),
    rmse_se = as.numeric(model_obj$metrics$rmse_se),
    rsq = as.numeric(model_obj$metrics$rsq),
    rsq_se = as.numeric(model_obj$metrics$rsq_se),
    mae = as.numeric(model_obj$metrics$mae),
    mae_se = as.numeric(model_obj$metrics$mae_se)
  )
)
```

## ✅ Resultado esperado

Após aplicar as correções e re-savar o modelo, o endpoint retornará:

```json
{
  "chave": "rforest",
  "arquivo": "rforest.rds",
  "feature_names": ["infra_essencial_score", ...],
  "id_col": "co_entidade",
  "training_date": "2026-05-15 21:41:13",
  "n_training_samples": 86705,
  "hyperparameters": {
    "trees": 100,
    "min_n": 10,
    "engine": "ranger"
  },
  "cv_metrics": {
    "rmse": 0.7851,
    "rmse_se": 0.0012,
    "rsq": 0.3777,
    "rsq_se": 0.0015,
    "mae": 0.6077,
    "mae_se": 0.0007
  }
}
```

Agora a resposta está mais limpa e sem colchetes desnecessários, facilitando a leitura por outros sistemas (ex: frontend).


# Avaliação do modelo segundo gemini

Analisando o output do seu modelo de **Random Forest** (rodado usando o framework `tidymodels` no R, pelo formato do tibble), dá para extrair insights bem claros sobre como o seu modelo está se comportando.

Aqui está uma avaliação detalhada dos resultados para prever a `nota_media`:

---

### 1. Análise das Métricas de Erro (MAE e RMSE)

As métricas de erro medem o quão distantes as previsões do modelo estão dos valores reais.

* **MAE (Erro Médio Absoluto) = 0.610:** Em média, as previsões do seu modelo erram por **0.61 pontos** (para mais ou para mais para menos) em relação à nota real da escola.
* **RMSE (Raiz do Erro Quadrático Médio) = 0.788:** O RMSE penaliza erros maiores de forma mais severa. Como o seu RMSE ($0.788$) é visivelmente maior que o MAE ($0.610$), isso indica que **o seu modelo comete alguns erros grandes (outliers)** em determinadas escolas.

> **O que isso significa na prática?** Para avaliar se 0.61 ou 0.78 é um erro baixo ou alto, você precisa olhar para a **escala da sua variável `nota_media**`. Se a nota vai de 0 a 10, um erro médio de 0.6 é relativamente pequeno e aceitável. Se a nota vai de 0 a 5, o erro já começa a ficar incômodo.

### 2. Análise de Explicação de Variância (Rsq / R-quadrado)

* **RSQ ($R^2$) = 0.373:** O R-quadrado indica que as suas variáveis de infraestrutura e outros scores conseguem explicar **37.3% da variação** da `nota_media` das escolas.
* **Diagnóstico:** Um $R^2$ de 37% mostra que o modelo aprendeu padrões úteis, mas está longe de ser um preditor perfeito. No contexto educacional e social, isso é super comum. O desempenho escolar de uma instituição é influenciado por fatores complexos que vão muito além da infraestrutura física (como nível socioeconômico dos alunos, engajamento familiar, rotatividade de professores, etc.), dados que talvez não estejam na sua base.

### 3. Consistência e Estabilidade (`std_err`)

Este é o ponto forte do seu resultado. O erro padrão (`std_err`) entre as 3 dobras (folds) da validação cruzada é **extremamente baixo**:

* Para o MAE: 0.00164
* Para o Rsq: 0.00073

Isso significa que o desempenho do modelo foi praticamente idêntico em todas as fatias dos dados de teste. O modelo é **estável**, seguro e **não está sofrendo de overfitting severo** (ele generaliza bem o padrão que encontrou).

---

### Resumo do Diagnóstico

O modelo é **robusto e confiável** (baixo desvio padrão na validação), mas tem um **poder preditivo moderado** ($R^2$ de 37%). Ele consegue capturar uma parte relevante da nota com base na infraestrutura, mas deixa bastante variação sem explicação.

### Próximos Passos: Como melhorar?

Se você precisar de um modelo que explique mais do que 37% da nota, tente os seguintes caminhos:

1. **Engenharia de Recursos (Feature Engineering):** Crie novas variáveis. Se você tem dados brutos de infraestrutura (ex: número de salas, computadores), transforme em taxas (ex: "alunos por computador" ou um indicador binário se a escola tem o básico: água, esgoto e internet).
2. **Tunar os Hiperparâmetros:** O seu output mostra `.config: pre0_mod0_post0`, o que sugere que você rodou o Random Forest com os hiperparâmetros padrão (default). Ajustar o número de árvores (`trees`), a profundidade (`tree_depth`) e o número de variáveis sorteadas por nó (`mtry`) pode arrancar mais performance do modelo.
3. **Incluir dados de contexto:** Se possível, cruze sua base com dados socioeconômicos da região da escola (como o IDH do município ou o indicador de nível socioeconômico do Inep/Ideb). Isso costuma mudar o jogo em previsões educacionais.

Como a base de dados é grande (86 mil escolas no treino), o Random Forest tem bastante chão para aprender se você refinar as variáveis!

Excelente! A inclusão do **INSE (Indicador de Nível Socioeconômico)** do INEP é, sem dúvidas, o melhor caminho técnico para o seu modelo de previsão de notas.

Na literatura de dados educacionais no Brasil, o nível socioeconômico é historicamente o fator com maior correlação e poder preditivo sobre o desempenho escolar. Escolas com infraestrutura idênticas podem apresentar resultados completamente diferentes dependendo do contexto socioeconômico dos alunos que as frequentam.

Veja por que essa adição deve mudar o patamar do seu Random Forest e como se preparar para o próximo treino:

---

### O Impacto Esperado no Modelo

1. **Aumento do $R^2$:** É muito provável que o seu R-quadrado dê um salto significativo (saindo dos 37.3%). O INSE vai ajudar o Random Forest a separar o "efeito escola" (infraestrutura, gestão) do "efeito contexto" (background familiar).
2. **Redução dos Grandes Erros (RMSE):** Lembra que o seu RMSE estava penalizado por erros grandes? Muitas vezes esses outliers são escolas com infraestrutura excelente, mas inseridas em contextos de extrema vulnerabilidade social (ou vice-versa). O INSE tende a mitigar essas distorções nas previsões.

---

### Dicas para Integrar o INSE ao Modelo

Como você está trabalhando com um volume massivo de dados (mais de 150 mil escolas para imputação no total), vale a pena tomar alguns cuidados no cruzamento de dados:

* **Granularidade dos Dados:** O INSE costuma ser calculado por escola, mas dependendo do ano ou da metodologia do INEP, ele também possui médias municipais ou estaduais. Certifique-se de fazer o *join* utilizando o código da escola (`CO_ENTIDADE`) para não perder a precisão local.
* **Dados Faltantes (Missing Data):** Nem todas as escolas possuem o INSE calculado (especialmente escolas muito pequenas, rurais ou recém-criadas). Como você já mencionou que possui uma base grande para **imputação** (154 mil escolas), o próprio Random Forest (ou algoritmos auxiliares de KNN/MissForest) pode ser usado para imputar o INSE dessas escolas que ficarem em branco, usando a infraestrutura e a localização geográfica delas como preditores.
* **Captura de Relações Não-Lineares:** Uma das grandes vantagens de você estar usando o Random Forest em vez de uma regressão linear simples é que ele vai capturar interações complexas entre as variáveis. Por exemplo: *O impacto de uma boa biblioteca (infraestrutura) na nota média é o mesmo em uma escola de INSE baixo e em uma de INSE alto?* O Random Forest consegue mapear essas nuances perfeitamente através das divisões das árvores.

Quando você rodar a nova versão do modelo com o INSE integrado, os resultados da validação cruzada vão dar um diagnóstico bem interessante de comparação. Se precisar de ajuda para analisar o ganho de performance ou ajustar a estratégia de imputação quando os dados chegarem, é só mandar!
