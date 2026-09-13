Sim. Para a **primeira migração mínima**, eu manteria exatamente o contrato arquitetural que já definimos: o Perl continua orquestrando o job, mas a lógica analítica passa a ser uma implementação do novo MVC analítico.

Para não espalhar a mudança por Gower/Euclidean/etc., começaria migrando **somente Gower** e deixando o restante do dispatch intacto.

A implementação mínima fica em três peças:

```text
EduMaps::Task::Similarity
        │
        ▼
EduMaps::Analysis::R::Pipe
        │
        ▼
R MVC
├── controller/similarity.R
├── model/similarity_gower.R
└── repository/similarity_repository.R
```

A ideia importante é: **o model não conhece Postgres nem stdout**. Isso fica no repository/controller.

### 1. Model: `similarity_gower.R`

```r
# model/similarity_gower.R

compute_gower_similarity <- function(data, id_column, features) {

  if (nrow(data) < 2) {
    stop("Sao necessarias pelo menos 2 entidades.")
  }

  data_for_gower <- data |>
    dplyr::select(dplyr::all_of(features)) |>
    dplyr::mutate(
      dplyr::across(where(is.character), as.factor)
    )

  dist_obj <- cluster::daisy(
    data_for_gower,
    metric = "gower"
  )

  pairs_from_distance(
    ids = data[[id_column]],
    dist_matrix = dist_obj
  )
}
```

Aqui está efetivamente a lógica estatística que existia dentro de:

```r
compute_and_save_gower_similarity()
```

mas sem:

* `DBI`
* `tbl()`
* `collect()`
* `dbWriteTable()`
* `cat()`
* `quit()`
* geração de `run_id`.

Isso é importante para o MVC.

---

# 2. Repository: `similarity_repository.R`

O repository concentra o acesso aos dados.

```r
# repository/similarity_repository.R

load_similarity_data <- function(
  con,
  schema,
  table_name,
  id_column
) {

  db_table <- dplyr::tbl(
    con,
    dbplyr::in_schema(schema, table_name)
  )

  sample_data <- db_table |>
    dplyr::head(1) |>
    dplyr::collect()

  features <- select_mixed_features(
    sample_data,
    id_column
  )

  data <- db_table |>
    dplyr::select(
      dplyr::all_of(c(id_column, features))
    ) |>
    dplyr::collect() |>
    tidyr::drop_na()

  list(
    data = data,
    features = features
  )
}
```

E a persistência:

```r
write_similarity_result <- function(
  con,
  output_schema,
  metric,
  run_id,
  target_table,
  id_column,
  params,
  pairs_df
) {

  write_similarity_pairs(
    con = con,
    schema = output_schema,
    metric = metric,
    run_id = run_id,
    target_table = target_table,
    id_column = id_column,
    params = params,
    pairs_df = pairs_df
  )
}
```

Repare que não estamos reinventando `similarity_utils.R`. Ele continua sendo infraestrutura compartilhada.

---

# 3. Controller: `similarity.R`

Esse é o ponto de entrada que o `R::Pipe` chama.

```r
# controller/similarity.R

run_gower_similarity <- function(
  con,
  schema,
  table_name,
  id_column,
  output_schema
) {

  run_id <- generate_run_id()

  loaded <- load_similarity_data(
    con = con,
    schema = schema,
    table_name = table_name,
    id_column = id_column
  )

  data <- loaded$data
  features <- loaded$features

  pairs_df <- compute_gower_similarity(
    data = data,
    id_column = id_column,
    features = features
  )

  write_similarity_result(
    con = con,
    output_schema = output_schema,
    metric = "gower",
    run_id = run_id,
    target_table = paste0(schema, ".", table_name),
    id_column = id_column,
    params = list(
      features = features
    ),
    pairs_df = pairs_df
  )

  build_similarity_response_payload(
    metric = "gower",
    run_id = run_id,
    schema = schema,
    table_name = table_name,
    id_column = id_column,
    output_schema = output_schema,
    params = list(
      features = features
    ),
    pairs_df = pairs_df
  )
}
```

Esse controller é praticamente o antigo `compute_and_save_gower_similarity()`, mas agora ele **orquestra**:

```text
repository → model → repository → response
```

---

# 4. Estrutura mínima

Eu colocaria inicialmente assim:

```text
share/
└── EduMaps/
    └── Analysis/
        └── R/
            └── similarity/
                ├── controller/
                │   └── similarity.R
                ├── model/
                │   └── similarity_gower.R
                ├── repository/
                │   └── similarity_repository.R
                └── similarity_utils.R
```

Mas há um detalhe importante no seu `R::Pipe`: precisamos aproveitar o mecanismo atual de `paths`/`source_file`.

Então eu faria o wrapper temporário carregar explicitamente os componentes:

```r
source("similarity_utils.R")
source("repository/similarity_repository.R")
source("model/similarity_gower.R")
source("controller/similarity.R")
```

e depois executar:

```r
run_gower_similarity(
  con = dbConnect(...),
  schema = "...",
  table_name = "...",
  id_column = "...",
  output_schema = "analytics"
)
```

---

# 5. Mudança mínima no Perl

Aqui está a parte boa: **quase nada muda no `EduMaps::Task::Similarity`**.

Trocaríamos:

```perl
use constant METRIC_R_FUNCTION => {
  gower => 'compute_and_save_gower_similarity',
  ...
};
```

por:

```perl
use constant METRIC_R_FUNCTION => {
  gower            => 'run_gower_similarity',
  euclidean_zscore => 'compute_and_save_euclidean_zscore_similarity',
  mahalanobis      => 'compute_and_save_mahalanobis_similarity',
  aitchison        => 'compute_and_save_aitchison_similarity',
  dtw              => 'compute_and_save_dtw_similarity',
};
```

Só isso para a primeira etapa.

O resto do Perl:

```perl
$rpipe->run(
  {
    paths       => $args->{paths} || $job->app->renderer->paths,
    source_file => $args->{source_file} . '.R',
    script      => ...
  }
);
```

continua funcionando.

---

## 6. Porém, eu faria uma pequena correção no `similarity_utils.R`

Há um problema antigo que vale corrigir **agora**, porque estamos mexendo justamente no contrato do model.

Atualmente:

```r
idx <- which(upper.tri(m), arr.ind = TRUE)

tibble::tibble(
  entity_1 = ids[idx[, 1]],
  entity_2 = ids[idx[, 2]],
```

Para uma matriz:

```text
    A B C
A   0 d d
B   d 0 d
C   d d 0
```

`upper.tri()` retorna:

```text
A-B
A-C
B-C
```

Então isso está correto.

Eu apenas adicionaria uma proteção para `n = 2` e para matrizes vazias:

```r
pairs_from_distance <- function(ids, dist_matrix) {

  m <- as.matrix(dist_matrix)

  stopifnot(
    nrow(m) == length(ids),
    ncol(m) == length(ids)
  )

  dimnames(m) <- list(ids, ids)

  idx <- which(upper.tri(m), arr.ind = TRUE)

  if (nrow(idx) == 0) {
    return(tibble::tibble(
      entity_1 = ids[0],
      entity_2 = ids[0],
      distance = numeric(0),
      similarity = numeric(0)
    ))
  }

  tibble::tibble(
    entity_1 = ids[idx[, 1]],
    entity_2 = ids[idx[, 2]],
    distance = m[idx],
    similarity = 1 / (1 + m[idx])
  )
}
```

Não mudaria mais nada nesse momento.

---

# Resultado

Com isso, a análise antiga:

```text
Task::Similarity
       │
       ▼
compute_and_save_gower_similarity()
       │
       ├── DB
       ├── algoritmo
       ├── persistência
       └── stdout
```

passa para:

```text
Task::Similarity
       │
       ▼
run_gower_similarity()       ← Controller
       │
       ├───────────────┐
       ▼               ▼
load_similarity_data   compute_gower_similarity()
Repository             Model
       │               │
       └───────┬───────┘
               ▼
     write_similarity_result()
          Repository
               │
               ▼
 build_similarity_response_payload()
```

E o ponto mais importante: **o comportamento externo permanece o mesmo**.

O Perl continua recebendo:

```json
{
  "status": "success",
  "metric": "gower",
  "run_id": "run_...",
  "n_entities": 123,
  "n_pairs": 7503,
  "avg_similarity": 0.71,
  "sample_top_pairs": [...]
}
```

e o Postgres continua recebendo os pares em:

```text
analytics.similarity_pairs
```

Portanto, essa primeira migração é pequena, testável e não exige ainda refatorar `Task::Similarity`, `R::Pipe` ou as outras métricas. Depois de validar Gower, podemos aplicar exatamente o mesmo esqueleto a `euclidean_zscore`, `mahalanobis`, `aitchison` e `dtw`.


Agora sim — com esse contexto, a migração é outra coisa. **Não devemos criar outro `SchoolDataset` nem mexer no `school_indicator_model`**.

A similaridade é uma análise de outra natureza: ela recebe um conjunto de entidades com várias características, calcula a distância/similaridade entre pares e persiste o resultado. Portanto, a menor extensão correta do MVC atual é:

```text
DataSource
    ↓
SchoolSimilarityModel
    ↓
analyze_gower_similarity()
    ↓
AnalysisResult
    ↓
PostgresRepository
```

E **não** passa pelo `analysis_registry` dos gráficos, porque `required = value/x/y/group` é específico do `SchoolIndicatorModel`.

A implementação mínima que eu faria é esta.

---

## 1. Novo modelo semântico

`R/model-semantic-school-similarity-model.R`

```r
# R/model/semantic/school_similarity_model.R
#
# Modelo semântico para análise de similaridade entre escolas.
#
# Diferentemente de school_indicator_model, aqui uma observação representa
# uma entidade e as colunas restantes são as características usadas para
# calcular a similaridade.
#
# A análise não conhece Postgres, nomes de tabelas ou SQL.

new_school_similarity_model <- function(
  data,
  entity_id = "school_id",
  features = NULL,
  metadata = list()
) {
  if (!is.data.frame(data)) {
    stop("data deve ser um data.frame")
  }

  if (!(entity_id %in% names(data))) {
    stop(sprintf("Coluna de entidade não encontrada: %s", entity_id))
  }

  if (is.null(features)) {
    features <- setdiff(names(data), entity_id)
  }

  missing <- setdiff(features, names(data))

  if (length(missing) > 0) {
    stop(sprintf(
      "Features não encontradas: %s",
      paste(missing, collapse = ", ")
    ))
  }

  structure(
    list(
      data = data,
      entity_id = entity_id,
      features = features,
      metadata = metadata
    ),
    class = "school_similarity_model"
  )
}

similarity_data <- function(model) {
  UseMethod("similarity_data")
}

similarity_data.school_similarity_model <- function(model) {
  model$data
}

similarity_entity_ids <- function(model) {
  UseMethod("similarity_entity_ids")
}

similarity_entity_ids.school_similarity_model <- function(model) {
  model$data[[model$entity_id]]
}

similarity_features <- function(model) {
  UseMethod("similarity_features")
}

similarity_features.school_similarity_model <- function(model) {
  model$features
}

similarity_sample_size <- function(model) {
  UseMethod("similarity_sample_size")
}

similarity_sample_size.school_similarity_model <- function(model) {
  nrow(model$data)
}
```

Isso é importante porque agora o contrato da análise fica explícito:

```r
model <- new_school_similarity_model(
  data = schools,
  entity_id = "school_id",
  features = c("x1", "x2", "x3")
)
```

---

# 2. DataSource em memória

O `memory_source` atual não deve ser alterado para tentar representar dois domínios diferentes.

Adicionamos um segundo DataSource:

`R/model-datasource-memory-similarity-source.R`

```r
# R/model/datasource/memory_similarity_source.R

load_school_similarity <- function(source, ...) {
  UseMethod("load_school_similarity")
}

memory_similarity_source <- function(
  rows,
  entity_id = "school_id",
  features = NULL,
  metadata = list()
) {
  structure(
    list(
      rows = rows,
      entity_id = entity_id,
      features = features,
      metadata = metadata
    ),
    class = c("memory_similarity_source", "data_source")
  )
}

load_school_similarity.memory_similarity_source <- function(
  source,
  ...
) {
  new_school_similarity_model(
    data = as.data.frame(source$rows),
    entity_id = source$entity_id,
    features = source$features,
    metadata = source$metadata
  )
}
```

Assim o R continua sem SQL no caminho HTTP.

---

# 3. A análise Gower

Aqui está a migração efetiva da lógica antiga.

`R/analysis-similarity.R`

```r
# R/analysis/similarity.R
#
# Calcula similaridade de Gower entre entidades.
#
# A função é pura:
#
#   SchoolSimilarityModel -> AnalysisResult
#
# Não conhece banco, HTTP ou formato de persistência.

analyze_gower_similarity <- function(
  model,
  parameters = list()
) {
  if (!inherits(model, "school_similarity_model")) {
    stop("analyze_gower_similarity requer um school_similarity_model")
  }

  data <- similarity_data(model)
  entity_ids <- similarity_entity_ids(model)
  features <- similarity_features(model)

  if (length(features) == 0) {
    stop("similaridade requer pelo menos uma feature")
  }

  if (length(unique(entity_ids)) != length(entity_ids)) {
    stop("IDs das entidades devem ser únicos")
  }

  x <- data[, features, drop = FALSE]

  if (nrow(x) < 2) {
    stop("similaridade requer pelo menos duas entidades")
  }

  # cluster::daisy calcula a distância de Gower.
  distance <- cluster::daisy(
    x,
    metric = "gower"
  )

  distance_matrix <- as.matrix(distance)

  # A matriz de distância é simétrica e a diagonal é zero.
  # Geramos apenas cada par uma vez.
  pair_index <- which(
    upper.tri(distance_matrix),
    arr.ind = TRUE
  )

  pairs <- data.frame(
    entity_id_a = entity_ids[pair_index[, "row"]],
    entity_id_b = entity_ids[pair_index[, "col"]],
    distance = distance_matrix[pair_index],
    similarity = 1 - distance_matrix[pair_index],
    stringsAsFactors = FALSE
  )

  pairs <- pairs[
    order(pairs$similarity, decreasing = TRUE),
    ,
    drop = FALSE
  ]

  new_analysis_result(
    analysis = "gower_similarity",
    parameters = parameters,
    data = pairs,
    metrics = list(
      n_entities = nrow(data),
      n_features = length(features),
      n_pairs = nrow(pairs),
      mean_similarity = if (nrow(pairs) > 0) {
        mean(pairs$similarity, na.rm = TRUE)
      } else {
        NA_real_
      }
    ),
    metadata = list(
      entity_id = model$entity_id,
      features = features
    )
  )
}
```

A parte essencial da migração é exatamente esta:

```r
distance <- cluster::daisy(
  x,
  metric = "gower"
)

similarity <- 1 - distance
```

Ou seja, preservamos a semântica da análise antiga: **Gower distance → Gower similarity**.

E o resultado já é um `AnalysisResult`, portanto a análise não salva nada.

---

# 4. Repository específico da similaridade

Aqui temos uma diferença importante em relação ao `postgres_repository` existente.

O repository atual está acoplado a:

```text
analytics.chart_cache
```

e não devemos transformar esse repository em um "repository universal".

Criamos:

`R/repository-postgres-similarity.R`

```r
# R/repository/postgres_similarity.R

postgres_similarity_repository <- function(con) {
  structure(
    list(con = con),
    class = "postgres_similarity_repository"
  )
}

persist_similarity <- function(
  repository,
  result,
  ...
) {
  UseMethod("persist_similarity")
}

persist_similarity.postgres_similarity_repository <- function(
  repository,
  result,
  table = DBI::Id(
    schema = "analytics",
    table = "school_similarity"
  ),
  ...
) {
  if (!inherits(result, "analysis_result")) {
    stop("result deve ser um analysis_result")
  }

  if (!identical(result$analysis, "gower_similarity")) {
    stop("repository espera um resultado gower_similarity")
  }

  data <- result$data

  DBI::dbWriteTable(
    repository$con,
    table,
    data,
    append = TRUE,
    row.names = FALSE
  )

  invisible(result)
}
```

### Porém há um ponto que não quero inventar

O nome acima:

```text
analytics.school_similarity
```

é apenas o lugar natural para a nova implementação.

**Se a tabela usada pelo `Analitico` antigo tiver outro nome ou uma estrutura específica, devemos preservar exatamente aquela tabela/colunas.**

Isso é especialmente importante porque a migração deve ser substituível pelo legado sem mudar o consumidor.

---

# 5. Fachada da aplicação

Adicionamos ao `app-application.R`:

```r
#' Carrega o modelo semântico de similaridade
#' @export
load_similarity_dataset <- function(source, ...) {
  load_school_similarity(source, ...)
}

#' Executa a análise de similaridade Gower
#' @export
run_similarity <- function(
  model,
  parameters = list()
) {
  analyze_gower_similarity(model, parameters)
}

#' Persiste resultado de similaridade
#' @export
persist_similarity_result <- function(
  result,
  repository,
  ...
) {
  persist_similarity(repository, result, ...)
}
```

O fluxo batch fica então:

```r
source <- memory_similarity_source(
  rows = data,
  entity_id = "school_id",
  features = features
)

model <- load_similarity_dataset(source)

result <- run_similarity(
  model,
  parameters = parameters
)

repository <- postgres_similarity_repository(con)

persist_similarity_result(
  result,
  repository
)
```

---

# 6. Registry

**Eu não colocaria `gower_similarity` no registry atual.**

O registry atual tem este contrato:

```r
school_indicator_model
        ↓
value / x / y / group
        ↓
histogram / scatter / boxplot
        ↓
plotly
```

A similaridade tem outro contrato:

```text
school_similarity_model
        ↓
entity_id + features
        ↓
gower_similarity
        ↓
pair table
```

Forçar isso no registry atual seria justamente o tipo de abstração que queremos evitar.

Se quisermos um catálogo geral posteriormente, podemos evoluir o registry para algo como:

```r
analysis_registry <- list(
  histogram = ...,
  scatter = ...,
  boxplot = ...,
  gower_similarity = ...
)
```

mas **não é necessário para a migração mínima**.

---

# 7. Teste da análise

`tests/testthat/test-similarity.R`

```r
fixture_similarity_model <- function() {
  new_school_similarity_model(
    data = data.frame(
      school_id = c(1, 2, 3),
      infrastructure = c(10, 10, 0),
      capacity = c(10, 8, 0),
      diversity = c(10, 9, 0)
    ),
    entity_id = "school_id",
    features = c(
      "infrastructure",
      "capacity",
      "diversity"
    )
  )
}


test_that("Gower similarity produz pares", {
  model <- fixture_similarity_model()

  result <- analyze_gower_similarity(model)

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "gower_similarity")

  expect_equal(result$metrics$n_entities, 3)
  expect_equal(result$metrics$n_features, 3)
  expect_equal(result$metrics$n_pairs, 3)

  expect_true(
    all(result$data$similarity >= 0) &&
      all(result$data$similarity <= 1)
  )
})


test_that("Gower similarity é simétrica e gera cada par uma vez", {
  model <- fixture_similarity_model()

  result <- analyze_gower_similarity(model)

  pairs <- result$data

  expect_equal(
    nrow(pairs),
    choose(3, 2)
  )

  expect_false(
    any(pairs$entity_id_a == pairs$entity_id_b)
  )
})


test_that("similaridade de entidade idêntica é 1", {
  model <- new_school_similarity_model(
    data = data.frame(
      school_id = c(1, 2),
      infrastructure = c(10, 10),
      capacity = c(5, 5),
      diversity = c(8, 8)
    ),
    entity_id = "school_id",
    features = c(
      "infrastructure",
      "capacity",
      "diversity"
    )
  )

  result <- analyze_gower_similarity(model)

  expect_equal(
    result$data$similarity,
    1
  )

  expect_equal(
    result$data$distance,
    0
  )
})


test_that("análise exige pelo menos duas entidades", {
  model <- new_school_similarity_model(
    data = data.frame(
      school_id = 1,
      infrastructure = 10
    ),
    entity_id = "school_id",
    features = "infrastructure"
  )

  expect_error(
    analyze_gower_similarity(model),
    "pelo menos duas"
  )
})
```

---

# 8. Dependência

Como estamos usando:

```r
cluster::daisy()
```

basta adicionar `cluster` ao `DESCRIPTION`:

```text
Imports:
    ggplot2,
    plotly,
    jsonlite,
    DBI,
    stats,
    cluster
```

E no `NAMESPACE`, como usamos `cluster::daisy`, **não precisamos importar `daisy`**.

---

## O que efetivamente adicionamos

A árvore fica conceitualmente:

```text
R/
├── model/
│   ├── semantic/
│   │   ├── school_indicator_model.R
│   │   └── school_similarity_model.R       ← NOVO
│   └── datasource/
│       ├── memory_source.R
│       ├── postgres_source.R
│       └── memory_similarity_source.R      ← NOVO
│
├── analysis/
│   ├── histogram.R
│   ├── scatter.R
│   ├── boxplot.R
│   └── similarity.R                         ← NOVO
│
├── result/
│   └── analysis_result.R
│
├── repository/
│   ├── postgres.R
│   └── postgres_similarity.R                ← NOVO
│
└── app/
    └── application.R                       ← pequenas adições
```

Isso mantém **intacta a arquitetura que já implementamos**.

O ponto que falta para eu fechar a migração **1:1 com o `Analitico` antigo** é o contrato concreto do antigo script: principalmente **a query/dataset que ele recebia e o `INSERT`/tabela onde salvava os pares**. O algoritmo Gower acima está no lugar correto arquiteturalmente, mas não vou inventar o schema de persistência se a intenção é substituir o script antigo sem alterar seu comportamento.
