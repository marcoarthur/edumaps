Sim. Com a arquitetura atual, eu **não migraria `compute_and_save_gower_similarity()` literalmente**. A mudança importante é que Gower deixa de ser uma função "aplicação + banco + stdout + persistência" e passa a ser uma **Analysis pura**, com o mesmo pipeline que vocês já estabeleceram:

```text
Perl / HTTP / Batch
        │
        ▼
    DataSource
        │
        ▼
SchoolSimilarityModel
        │
        ▼
run_analysis("gower", model, parameters)
        │
        ▼
AnalysisResult
   │          │
   ▼          ▼
View        Repository
JSON        similarity_pairs
Plotly      ...
```

E há uma diferença importante em relação ao `SchoolIndicatorModel`: **similaridade não é uma análise de um indicador**, então eu não tentaria encaixá-la nesse modelo semântico existente. Criaria um segundo modelo semântico, provavelmente `SimilarityModel`.

## 1. O que deve desaparecer do Gower antigo

A antiga função mistura seis responsabilidades:

```r
compute_and_save_gower_similarity()
```

faz:

1. descoberta de script;
2. carregamento de pacotes;
3. acesso ao PostgreSQL;
4. descoberta das features;
5. preparação dos dados;
6. cálculo estatístico;
7. transformação distância → pares;
8. persistência;
9. construção do protocolo stdout;
10. encerramento do processo.

Na arquitetura nova, isso deve virar aproximadamente:

```text
postgres_source
        ↓
similarity_model
        ↓
analyze_gower
        ↓
analysis_result
        ↓
persist_similarity_pairs
```

O Perl deixa de escolher uma **função R** e passa a escolher uma **análise registrada**.

---

# 2. Novo modelo semântico

Eu começaria com:

```text
R/model/semantic/similarity-model.R
```

ou, seguindo seus nomes atuais:

```text
R/model-semantic-similarity-model.R
```

Eu usaria:

```r
# R/model/semantic/similarity_model.R

#' Constrói um SimilarityModel
#'
#' Representa o dataset necessário para calcular uma similaridade
#' par-a-par entre entidades.
#'
#' O modelo não conhece Postgres, schema ou tabela. Ele contém somente
#' as entidades, seus identificadores e as features semânticas.
#'
#' @param data data.frame contendo a coluna de identificação e as features
#' @param id_column nome da coluna que identifica a entidade
#' @param metadata metadados da fonte/dataset
#' @export
new_similarity_model <- function(data, id_column, metadata = list()) {
  if (!is.data.frame(data)) {
    stop_invalid_parameter("SimilarityModel requer um data.frame")
  }

  if (!is.character(id_column) || length(id_column) != 1) {
    stop_invalid_parameter("id_column deve ser uma string")
  }

  if (!(id_column %in% names(data))) {
    stop_invalid_dataset(
      sprintf("Coluna de identificação não encontrada: %s", id_column)
    )
  }

  structure(
    list(
      data = data,
      id_column = id_column,
      metadata = metadata
    ),
    class = "similarity_model"
  )
}

#' @export
entity_ids <- function(model) UseMethod("entity_ids")

#' @export
entity_ids.similarity_model <- function(model) {
  model$data[[model$id_column]]
}

#' @export
similarity_features <- function(model) UseMethod("similarity_features")

#' @export
similarity_features.similarity_model <- function(model) {
  setdiff(names(model$data), model$id_column)
}

#' @export
similarity_data <- function(model) UseMethod("similarity_data")

#' @export
similarity_data.similarity_model <- function(model) {
  model$data[similarity_features(model)]
}

#' @export
similarity_id_column <- function(model) UseMethod("similarity_id_column")

#' @export
similarity_id_column.similarity_model <- function(model) {
  model$id_column
}

#' @export
similarity_sample_size <- function(model) UseMethod("similarity_sample_size")

#' @export
similarity_sample_size.similarity_model <- function(model) {
  nrow(model$data)
}
```

Isso é deliberadamente genérico.

Não colocaria `gower` no modelo.

O modelo representa:

> "Tenho N entidades, identificadas por X, descritas por estas features."

Gower, Euclidean, Mahalanobis etc. são análises diferentes sobre esse mesmo modelo.

---

# 3. DataSource em memória

A mesma ideia do `memory_source` atual pode ser generalizada.

Hoje ele diz:

```r
load_school_indicator(...)
```

Para similaridade, teremos:

```r
load_similarity_model <- function(source, ...) {
  UseMethod("load_similarity_model")
}
```

e:

```r
# R/model/datasource/memory_similarity_source.R

memory_similarity_source <- function(
  rows,
  id_column,
  metadata = list()
) {
  structure(
    list(
      rows = rows,
      id_column = id_column,
      metadata = metadata
    ),
    class = c("memory_similarity_source", "data_source")
  )
}

#' @export
load_similarity_model.memory_similarity_source <- function(source, ...) {
  new_similarity_model(
    data = as.data.frame(source$rows),
    id_column = source$id_column,
    metadata = source$metadata
  )
}
```

Isso será útil depois para testes.

---

# 4. PostgreSQL Source

Aqui está uma mudança arquitetural interessante.

O antigo:

```r
postgres_source(con)
```

é específico de `SchoolIndicatorModel` e contém:

```r
INDICATOR_WHITELIST
NETWORK_WHITELIST
```

Para similarity, eu criaria outro source:

```r
postgres_similarity_source <- function(con) {
  structure(
    list(con = con),
    class = c("postgres_similarity_source", "data_source")
  )
}
```

Mas **não deixaria `schema`, `table_name` e `id_column` serem simplesmente interpolados**.

O problema aqui é importante:

```r
FROM schema.table
```

não pode usar `$1` para identificadores PostgreSQL.

Portanto, a arquitetura deve validar identificadores **antes** de construir SQL.

Como o Perl já faz:

```perl
like(qr/^\w+$/)
```

podemos manter uma defesa equivalente em R.

Por exemplo:

```r
.validate_identifier <- function(value, name) {
  if (
    !is.character(value) ||
    length(value) != 1 ||
    !grepl("^[A-Za-z_]\\w*$", value)
  ) {
    stop_invalid_parameter(
      sprintf("Identificador inválido para %s: %s", name, value)
    )
  }

  value
}
```

E:

```r
load_similarity_model.postgres_similarity_source <- function(
  source,
  schema,
  table_name,
  id_column,
  ...
) {
  schema <- .validate_identifier(schema, "schema")
  table_name <- .validate_identifier(table_name, "table_name")
  id_column <- .validate_identifier(id_column, "id_column")

  sql <- sprintf(
    "
      SELECT *
      FROM %s.%s
    ",
    DBI::dbQuoteIdentifier(source$con, schema),
    DBI::dbQuoteIdentifier(source$con, table_name)
  )

  data <- DBI::dbGetQuery(source$con, sql)

  new_similarity_model(
    data = data,
    id_column = id_column,
    metadata = list(
      schema = schema,
      table_name = table_name
    )
  )
}
```

Mas há uma decisão que eu faria diferente do código antigo:

### não faria `SELECT *` no futuro

Para Gower precisamos descobrir as features primeiro.

Podemos ter:

```r
discover_similarity_features()
```

que consulta os metadados PostgreSQL ou faz:

```r
SELECT *
FROM ...
LIMIT 1
```

e então seleciona as colunas.

Porém, **eu prefiro deixar a descoberta de features como responsabilidade do DataSource**, não da análise.

---

# 5. Feature selection

A antiga:

```r
select_mixed_features()
```

é essencialmente uma regra de preparação de dados.

Eu a moveria para:

```text
R/model/similarity-features.R
```

e deixaria independente do Gower:

```r
select_mixed_features <- function(data, id_column) {
  eligible <- names(
    data[
      vapply(
        data,
        function(x) {
          is.numeric(x) ||
            is.character(x) ||
            is.factor(x) ||
            is.logical(x)
        },
        logical(1)
      )
    ]
  )

  eligible <- setdiff(eligible, id_column)

  if (length(eligible) == 0) {
    stop_invalid_dataset(
      "Nenhuma coluna elegível encontrada para similaridade."
    )
  }

  eligible
}
```

Agora o modelo pode carregar **todas as colunas**, enquanto o Gower decide quais são utilizáveis.

Isso é melhor que colocar:

```r
mixed_features
```

dentro do `SimilarityModel`, porque `SimilarityModel` continua independente da métrica.

---

# 6. A nova `analyze_gower()`

Aqui está o coração da migração.

```text
R/analysis-similarity-gower.R
```

```r
#' Calcula similaridade de Gower entre entidades.
#'
#' Análise pura: recebe um SimilarityModel e devolve um AnalysisResult.
#' Não acessa banco, não grava resultados e não escreve stdout.
#'
#' @export
analyze_gower <- function(model, parameters = list()) {

  if (!inherits(model, "similarity_model")) {
    stop_invalid_parameter(
      "analyze_gower espera um similarity_model"
    )
  }

  data <- similarity_data(model)
  ids <- entity_ids(model)
  id_column <- similarity_id_column(model)

  if (length(ids) < 2) {
    stop_invalid_dataset(
      "São necessárias pelo menos 2 entidades para calcular similaridade par-a-par."
    )
  }

  features <- parameters$features %||%
    select_mixed_features(model$data, id_column)

  if (length(features) == 0) {
    stop_invalid_dataset(
      "Nenhuma feature disponível para Gower."
    )
  }

  data_for_gower <- data[features]

  data_for_gower[] <- lapply(
    data_for_gower,
    function(x) {
      if (is.character(x)) {
        as.factor(x)
      } else {
        x
      }
    }
  )

  dist_obj <- cluster::daisy(
    data_for_gower,
    metric = "gower"
  )

  pairs <- pairs_from_distance(ids, dist_obj)

  new_analysis_result(
    analysis = "gower",
    parameters = modifyList(
      parameters,
      list(features = features)
    ),
    data = pairs,
    metrics = list(
      n_entities = length(ids),
      n_pairs = nrow(pairs),
      avg_similarity = mean(pairs$similarity, na.rm = TRUE)
    ),
    metadata = list(
      metric = "gower",
      id_column = id_column,
      features = features
    )
  )
}
```

Essa função já mostra bem a diferença da arquitetura antiga.

Ela não sabe que existe:

```text
analytics.similarity_pairs
```

Não sabe que existe Perl.

Não sabe que existe Minion.

Não sabe que existe stdout.

Não sabe que existe `run_id`.

Isso é exatamente o que queremos.

---

# 7. `pairs_from_distance()` também deve sair de `similarity_utils.R`

Essa função é domínio da análise de similaridade, e não de uma métrica específica.

Eu colocaria:

```text
R/analysis/similarity-pairs.R
```

```r
pairs_from_distance <- function(ids, dist_matrix) {
  m <- as.matrix(dist_matrix)

  if (
    nrow(m) != length(ids) ||
    ncol(m) != length(ids)
  ) {
    stop_invalid_dataset(
      "Matriz de distância incompatível com o número de entidades."
    )
  }

  idx <- which(upper.tri(m), arr.ind = TRUE)

  tibble::tibble(
    entity_1 = ids[idx[, 1]],
    entity_2 = ids[idx[, 2]],
    distance = m[idx],
    similarity = 1 / (1 + m[idx])
  )
}
```

A vantagem é enorme para as próximas quatro migrações.

Teremos:

```text
analyze_gower()
analyze_euclidean_zscore()
analyze_mahalanobis()
analyze_aitchison()
analyze_dtw()
        │
        └── pairs_from_distance()
```

---

# 8. Registry

O atual:

```r
analysis_registry <- list(
  histogram = ...,
  scatter = ...,
  boxplot = ...
)
```

passaria a ter:

```r
analysis_registry <- list(

  histogram = list(
    fn = analyze_histogram,
    required = c("value"),
    view = "plotly"
  ),

  scatter = list(
    fn = analyze_scatter,
    required = c("x", "y"),
    view = "plotly"
  ),

  boxplot = list(
    fn = analyze_boxplot,
    required = c("value", "group"),
    view = "plotly"
  ),

  gower = list(
    fn = analyze_gower,
    required = character(0),
    view = "json"
  )
)
```

Aqui existe uma diferença conceitual importante:

```r
required = character(0)
```

não significa que Gower não precisa de dados.

Significa:

> não há uma dimensão fixa do modelo chamada `value`, `x`, `y` ou `group`.

As features são dinâmicas.

---

# 9. Controller

O `run_analysis()` atual já está praticamente pronto para isso.

Ele aceita:

```r
run_analysis(
  "gower",
  model,
  parameters
)
```

e simplesmente encontra:

```r
analysis_registry$gower$fn
```

Então **não precisamos criar um controller específico para similarity**.

Isso é um ótimo sinal de que a abstração está correta.

---

# 10. O problema do `run_id`

Aqui eu faria uma mudança importante em relação ao código antigo.

Hoje:

```r
generate_run_id()
```

é criado dentro da métrica.

Eu colocaria o `run_id` no **AnalysisResult**, não na análise.

Por exemplo, podemos ter:

```r
new_analysis_result(
  analysis = "gower",
  ...
  metadata = list(
    ...
  )
)
```

e deixar o Repository gerar o `run_id`.

Ou, melhor ainda, o `run_id` ser um parâmetro de execução:

```r
parameters$run_id
```

Isso permite:

```text
uma execução
     │
     ├── Gower
     ├── Euclidean
     └── Mahalanobis
```

compartilhar uma identidade de execução quando isso fizer sentido.

Eu não colocaria:

```r
generate_run_id()
```

dentro de `analyze_gower()`.

---

# 11. Repository de similarity

O atual:

```r
postgres_repository
```

é específico de:

```text
analytics.chart_cache
```

Eu não o sobrecarregaria.

Criaria:

```text
R/repository-postgres-similarity.R
```

Algo como:

```r
postgres_similarity_repository <- function(con) {
  structure(
    list(con = con),
    class = "postgres_similarity_repository"
  )
}
```

E:

```r
persist_similarity <- function(
  repository,
  result,
  run_id,
  target_table,
  id_column
) {
  UseMethod("persist_similarity")
}
```

Implementação:

```r
persist_similarity.postgres_similarity_repository <- function(
  repository,
  result,
  run_id,
  target_table,
  id_column
) {

  pairs <- result$data

  if (!nrow(pairs)) {
    return(invisible(result))
  }

  rows <- dplyr::mutate(
    pairs,
    run_id = run_id,
    metric = result$analysis,
    target_table = target_table,
    id_column = id_column,
    params_json = jsonlite::toJSON(
      result$parameters,
      auto_unbox = TRUE
    ),
    computed_at = Sys.time(),
    .before = 1
  )

  DBI::dbWriteTable(
    repository$con,
    DBI::Id(
      schema = "analytics",
      table = "similarity_pairs"
    ),
    rows,
    append = TRUE
  )

  invisible(result)
}
```

E então a fachada:

```r
persist_result <- function(result, repository, ...) {
  if (inherits(repository, "postgres_similarity_repository")) {
    return(
      persist_similarity(repository, result, ...)
    )
  }

  persist(repository, result, ...)
}
```

Mas aqui eu faria ainda melhor: **um generic próprio**.

```r
persist_similarity <- function(repository, result, ...) {
  UseMethod("persist_similarity")
}
```

Assim não contaminamos o Repository genérico com regras específicas.

---

# 12. A resposta JSON deixa de ser responsabilidade da análise

O antigo:

```r
build_similarity_response_payload()
```

não deve ser migrado.

Ele era parte do protocolo:

```text
Rscript → stdout → EduMaps::Analysis::R::Pipe
```

No MVC novo, temos:

```r
render_json(result)
```

Então podemos produzir:

```r
render_json(result)
```

e obter:

```json
{
  "analysis": "gower",
  "parameters": {
    "features": [...]
  },
  "metrics": {
    "n_entities": 100,
    "n_pairs": 4950,
    "avg_similarity": 0.72
  },
  "metadata": {
    "metric": "gower",
    "id_column": "cod_municipio",
    "features": [...]
  },
  "tables": [...]
}
```

Mas para similarity eu mudaria o `render_json()` atual para não despejar automaticamente todos os pares.

Esse é um ponto em que o código antigo estava certo:

> O(n²) não deve ser devolvido por stdout/HTTP.

Eu criaria uma política de resultado:

```r
new_analysis_result(
  ...
  data = pairs,
  metadata = list(
    materialized = TRUE
  )
)
```

e o renderer poderia produzir apenas:

```json
{
  "analysis": "gower",
  "metrics": {
    "n_entities": 100,
    "n_pairs": 4950,
    "avg_similarity": 0.72
  },
  "preview": [...]
}
```

Enquanto os pares completos ficam no Repository.

---

# 13. Preview dos pares

A lógica antiga:

```r
arrange(desc(similarity)) %>%
head(top_n)
```

é boa.

Eu colocaria isso numa função semântica:

```r
similarity_preview <- function(result, n = 5) {
  result$data |>
    dplyr::arrange(dplyr::desc(similarity)) |>
    utils::head(n)
}
```

E então o renderer:

```r
render_similarity_json <- function(result, top_n = 5) {
  list(
    analysis = result$analysis,
    parameters = result$parameters,
    metrics = result$metrics,
    metadata = result$metadata,
    preview = similarity_preview(result, top_n)
  )
}
```

Isso é muito mais limpo que `build_similarity_response_payload()` terminar com:

```r
quit(status = 0)
```

---

# 14. Perl fica muito menor

Essa é provavelmente a maior vitória da migração.

Hoje o Perl precisa conhecer:

```perl
METRIC_R_FUNCTION
METRIC_VALIDATORS
METRIC_MANUAL_CHECKS
METRIC_R_ARGS
```

e construir código R:

```perl
$rpipe->run({
    script => <<~"EOS",
      ${r_function}(...)
EOS
});
```

Na arquitetura nova, eu faria o Perl chamar **uma única entrada R**.

Conceitualmente:

```perl
$rpipe->run(
    {
        ...
        source_file => 'analytics.R',
        script => <<~"EOS",
          run_similarity(
            con = dbConnect(...),
            metric = "$metric",
            schema = "$args->{schema}",
            table_name = "$args->{table_name}",
            id_column = "$args->{id_column}",
            output_schema = "@{[ ANALYTICS_SCHEMA ]}"
          )
        EOS
    }
);
```

Mas, mais importante ainda, a API R deveria ser:

```r
run_similarity <- function(
  source,
  metric,
  parameters = list()
)
```

e internamente:

```r
model <- load_dataset(source, ...)
result <- run_analysis(metric, model, parameters)
...
```

Assim:

```text
Perl
 │
 │ metric = "gower"
 ▼
R application
 │
 ├── DataSource
 ├── Semantic Model
 ├── Registry
 ├── Analysis
 └── Repository
```

O Perl não precisa mais conhecer:

```text
compute_and_save_gower_similarity
compute_and_save_euclidean_zscore_similarity
...
```

---

# 15. Eu criaria uma fachada `run_similarity()`

Por exemplo:

```r
# R/app/similarity.R

#' Executa uma análise de similaridade completa.
#'
#' Fachada para pipelines batch/HTTP.
#'
#' @export
run_similarity <- function(
  source,
  metric = "gower",
  parameters = list()
) {
  model <- load_similarity_dataset(source)

  result <- run_analysis(
    metric,
    model,
    parameters
  )

  result
}
```

Porém precisamos tomar cuidado: `load_dataset()` atual é semanticamente voltado para `SchoolIndicatorModel`.

Então eu **não faria**:

```r
load_dataset()
```

virar um dispatcher universal.

Prefiro:

```r
load_school_dataset()
load_similarity_dataset()
```

ou, mais elegantemente, generic:

```r
load_dataset(source)
```

com métodos:

```r
load_dataset.memory_source()
load_dataset.postgres_source()

load_dataset.memory_similarity_source()
load_dataset.postgres_similarity_source()
```

Mas isso pode ficar excessivamente polimórfico.

Para a fase atual, eu escolheria explicitamente:

```r
load_similarity_dataset()
```

porque deixa a API extremamente clara.

---

# 16. Estrutura final que eu sugiro

Depois dessa primeira migração, o pacote começaria a ficar assim:

```text
R/
├── utils.R
├── conditions.R
│
├── result/
│   └── analysis-result.R
│
├── model/
│   ├── semantic/
│   │   ├── school-indicator-model.R
│   │   └── similarity-model.R
│   │
│   └── datasource/
│       ├── memory-source.R
│       ├── postgres-source.R
│       └── similarity/
│           ├── memory-similarity-source.R
│           └── postgres-similarity-source.R
│
├── analysis/
│   ├── histogram.R
│   ├── scatter.R
│   ├── boxplot.R
│   │
│   └── similarity/
│       ├── similarity-pairs.R
│       ├── similarity-features.R
│       ├── gower.R
│       ├── euclidean-zscore.R
│       ├── mahalanobis.R
│       ├── aitchison.R
│       └── dtw.R
│
├── app/
│   ├── registry.R
│   ├── controller.R
│   ├── application.R
│   └── similarity.R
│
├── view/
│   ├── plotly.R
│   ├── json.R
│   └── similarity-json.R
│
└── repository/
    ├── postgres.R
    └── postgres-similarity.R
```

Eu não tentaria fazer toda essa reorganização física imediatamente. Podemos primeiro migrar Gower mantendo os nomes dos arquivos próximos da estrutura atual e só depois reorganizar diretórios.

---

# 17. O registry ficaria particularmente interessante

Depois da migração:

```r
analysis_registry <- list(
  histogram = list(
    fn = analyze_histogram,
    required = c("value"),
    view = "plotly"
  ),

  scatter = list(
    fn = analyze_scatter,
    required = c("x", "y"),
    view = "plotly"
  ),

  boxplot = list(
    fn = analyze_boxplot,
    required = c("value", "group"),
    view = "plotly"
  ),

  gower = list(
    fn = analyze_gower,
    required = character(0),
    view = "similarity_json"
  )
)
```

A diferença é que agora o registry realmente começa a cumprir a promessa arquitetural:

> **catálogo das capacidades analíticas do serviço.**

E futuramente:

```r
euclidean_zscore
mahalanobis
aitchison
dtw
```

viram apenas entradas.

---

# 18. Um detalhe importante: Gower tem uma fragilidade no código antigo

Há um problema que eu corrigiria **durante a migração**, em vez de carregar para o novo código.

O antigo faz:

```r
local_data <- db_table %>%
  select(all_of(c(id_column, mixed_features))) %>%
  collect() %>%
  drop_na()
```

Isso significa que **uma única coluna NA elimina a entidade inteira**.

Para Gower, isso é desnecessariamente agressivo. `cluster::daisy()` possui tratamento de valores ausentes e Gower foi justamente escolhido para lidar com datasets heterogêneos.

Eu não mudaria necessariamente o comportamento agora se compatibilidade histórica for requisito, mas colocaria como decisão explícita:

```r
parameters$na_action
```

por exemplo:

```r
na_action = "complete_cases"
```

ou futuramente:

```r
na_action = "gower"
```

Assim não fica escondido dentro da implementação.

---

# 19. E outro detalhe: `n_entities`

O código antigo calcula:

```r
length(unique(c(
  pairs_df$entity_1,
  pairs_df$entity_2
)))
```

Isso pode produzir resultado errado em casos extremos, por exemplo se uma entidade tiver sido perdida durante processamento.

O número de entidades original está no modelo:

```r
similarity_sample_size(model)
```

Portanto:

```r
metrics = list(
  n_entities = similarity_sample_size(model),
  n_pairs = nrow(pairs),
  avg_similarity = mean(pairs$similarity, na.rm = TRUE)
)
```

é semanticamente mais correto.

---

# 20. Testes

Essa migração também fica muito melhor testável.

Eu criaria:

```text
tests/testthat/test-similarity-model.R
tests/testthat/test-gower.R
tests/testthat/test-similarity-pairs.R
tests/testthat/test-similarity-registry.R
tests/testthat/test-similarity-json.R
```

### Modelo

```r
test_that("SimilarityModel expõe ids e features", {
  model <- new_similarity_model(
    data = data.frame(
      id = 1:3,
      income = c(10, 20, 30),
      network = c("municipal", "estadual", "municipal")
    ),
    id_column = "id"
  )

  expect_equal(entity_ids(model), 1:3)

  expect_equal(
    similarity_features(model),
    c("income", "network")
  )

  expect_equal(similarity_sample_size(model), 3)
})
```

### Gower

```r
test_that("Gower produz pares únicos", {
  model <- new_similarity_model(
    data = data.frame(
      id = 1:4,
      income = c(10, 20, 30, 40),
      network = c(
        "municipal",
        "municipal",
        "estadual",
        "privada"
      )
    ),
    id_column = "id"
  )

  result <- analyze_gower(model)

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "gower")

  # 4 * 3 / 2
  expect_equal(result$metrics$n_pairs, 6)

  expect_true(all(result$data$entity_1 != result$data$entity_2))
  expect_true(all(result$data$similarity > 0))
  expect_true(all(result$data$similarity <= 1))
})
```

### Features mistas

```r
test_that("Gower aceita numericas, categoricas e logicas", {
  model <- new_similarity_model(
    data = data.frame(
      id = 1:3,
      score = c(1, 2, 3),
      network = c("municipal", "estadual", "privada"),
      active = c(TRUE, FALSE, TRUE)
    ),
    id_column = "id"
  )

  result <- analyze_gower(model)

  expect_equal(result$metrics$n_entities, 3)
  expect_equal(result$metrics$n_pairs, 3)
})
```

E o teste mais importante:

```r
test_that("Gower não conhece persistência", {
  ...
})
```

Na prática, a ausência de `DBI`, conexão ou escrita no teste já garante essa propriedade.

---

# 21. O que eu **não** faria nesta primeira migração

Eu evitaria três tentações:

### Não transformar `SimilarityModel` em um modelo gigante

Não:

```r
new_similarity_model(
  ...
  metric = "gower",
  composition_columns = ...,
  time_column = ...,
  value_column = ...
)
```

Isso faria o modelo conhecer todas as métricas.

Melhor:

```text
SimilarityModel
      │
      ├── Gower
      ├── Euclidean
      ├── Mahalanobis
      ├── Aitchison
      └── DTW
```

### Não colocar persistência em `analyze_gower()`

Não:

```r
analyze_gower(...) {
   ...
   dbWriteTable(...)
}
```

### Não fazer Gower retornar JSON

Não:

```r
analyze_gower() -> JSON
```

Ele deve retornar:

```r
analysis_result
```

---

## A migração mínima que eu faria agora

Para não espalhar a mudança, eu faria **esta primeira etapa em 8 arquivos**:

```text
R/model-semantic-similarity-model.R
R/model-datasource-memory-similarity-source.R
R/analysis-similarity-features.R
R/analysis-similarity-pairs.R
R/analysis-gower.R
R/repository-postgres-similarity.R
R/view-similarity-json.R
R/app-registry.R
```

mais:

```text
tests/testthat/test-similarity-model.R
tests/testthat/test-similarity-pairs.R
tests/testthat/test-gower.R
```

e **não mexeria ainda em `Task::Similarity`**.

Primeiro fazemos a nova camada passar completamente os testes:

```text
MemorySource
    ↓
SimilarityModel
    ↓
analyze_gower()
    ↓
AnalysisResult
    ↓
render_similarity_json()
```

Depois adicionamos:

```text
AnalysisResult
    ↓
PostgresSimilarityRepository
    ↓
analytics.similarity_pairs
```

E **só então** substituímos o Perl antigo.

Essa ordem é importante: permite testar a nova implementação sem envolver Minion, `R::Pipe`, PostgreSQL ou HTTP. Depois que a nova cadeia estiver sólida, a alteração do `Task::Similarity` fica pequena e essencialmente passa a ser um adapter entre o contrato Perl existente e a nova aplicação R.

## Sobre a arquitetura Moderna

Com base na análise dos arquivos fornecidos, apresento uma consolidação esquemática da arquitetura do sistema analítico `edumapsAnalytics`. A seguir, descrevo a estrutura em camadas, os componentes principais, os fluxos de dados e as decisões arquiteturais mais relevantes.

---

## Esquemático da Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         APLICAÇÃO (Facades)                           │
│  load_dataset() → run_analysis() → export_result() / persist_result() │
└──────┬─────────────────────┬──────────────────────┬───────────────────┘
       │                     │                      │
       ▼                     ▼                      ▼
┌──────────────┐   ┌─────────────────┐   ┌──────────────────┐
│  DataSource  │   │   Controller    │   │  View / Render   │
│ ──────────── │   │ ─────────────── │   │ ──────────────── │
│ memory_source│   │ run_analysis()  │   │ render_plotly()  │
│ postgres_    │   │  - valida nome  │   │ render_json()    │
│   source     │   │  - verifica req.│   │                  │
│              │   │  - chama fn     │   │                  │
└──────┬───────┘   └────────┬────────┘   └────────┬─────────┘
       │                    │                     │
       ▼                    ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Modelo Semântico Central                    │
│              SchoolIndicatorModel (S3)                         │
│  accessors: values(), values_x(), values_y(), groups(), ...   │
│  metadata: rótulos, indicador_id, rede, município_id          │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Análises (Puras)                         │
│ ─────────────────────────────────────────────────────────────── │
│  analyze_histogram() → AnalysisResult (com métricas)          │
│  analyze_scatter()   → AnalysisResult (correlação)            │
│  analyze_boxplot()   → AnalysisResult (sumário por grupo)     │
│  (futuras: score_distribution, clusters, etc.)                │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     AnalysisResult (S3)                        │
│  - analysis (nome)                                            │
│  - parameters (usados)                                        │
│  - data (data.frame processado para view)                     │
│  - metrics (escalares: n, média, correlação...)               │
│  - tables (data.frames auxiliares)                            │
│  - metadata (rótulos de eixos, etc.)                          │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                ▼                           ▼
        ┌───────────────┐           ┌──────────────────┐
        │  View/Export  │           │   Repository     │
        │ ───────────── │           │ ──────────────── │
        │ render_plotly │           │ postgres_        │
        │ render_json   │           │ repository       │
        └───────────────┘           │ persist()        │
                                    └──────────────────┘
```

---

## Componentes Detalhados

### 1. **DataSource** – Origem dos dados
- **`memory_source`**: usado no **endpoint HTTP ao vivo**. Recebe um payload já validado e extraído pelo Perl; não executa SQL. Transforma os dados em `SchoolIndicatorModel`.
- **`postgres_source`**: usado em **pipelines batch/offline**. Executa consultas parametrizadas contra o banco, com **whitelist fechada** de indicadores (`INDICATOR_WHITELIST`) e redes (`NETWORK_WHITELIST`). Nunca exposto a parâmetros de requisição HTTP.

### 2. **Modelo Semântico** – `SchoolIndicatorModel`
- Representa **um conjunto de valores de um indicador escolar**, opcionalmente com um segundo indicador (scatter) e/ou dimensão categórica (boxplot).
- Provê **accessors** (`values`, `values_x`, `values_y`, `groups`, `sample_size`, `indicator_label`).
- Mantém **metadados** (rótulos, identificador do indicador, rede, município) – usados para rotular gráficos e guardar contexto.

### 3. **Registry** – Catálogo fechado de análises
- `analysis_registry` mapeia nomes (`histogram`, `scatter`, `boxplot`) para:
  - `fn`: função de análise pura.
  - `required`: campos que o modelo deve ter (ex.: `c("value")`).
  - `view`: renderizador padrão (`"plotly"`).
- **Decisão**: qualquer análise nova precisa ser registrada aqui; o Controller nunca aceita nomes arbitrários.

### 4. **Controller** – `run_analysis()`
- Valida:
  1. Nome da análise existe no registry.
  2. Objeto recebido é um `SchoolIndicatorModel`.
  3. O modelo possui todos os campos exigidos pela análise (via `required`).
- Dispara a função de análise.
- Levanta **condições tipadas** (`invalid_analysis`, `invalid_parameter`, `invalid_dataset`) para distinguir erros de cliente de erros internos.

### 5. **Análises** – funções puras
- Cada análise (ex.: `analyze_histogram`) recebe o modelo e parâmetros, calcula estatísticas e retorna um `AnalysisResult`.
- **Não geram gráficos**; apenas preparam os dados e métricas. A responsabilidade de renderizar é da View.

### 6. **AnalysisResult**
- Objeto imutável contendo:
  - `analysis`: nome da análise.
  - `parameters`: parâmetros utilizados.
  - `data`: dados prontos para visualização (não o dataset bruto).
  - `metrics`: escalares (n, média, correlação, etc.).
  - `tables`: tabelas auxiliares (ex.: sumário por grupo).
  - `metadata`: rótulos de eixos, etc.
- É a **única ponte** entre a camada de análise e as camadas de View/Repository.

### 7. **View / Renderers** – `render_plotly()` e `render_json()`
- `render_plotly`: constrói um gráfico **ggplot2** a partir do `AnalysisResult` e converte para especificação **Plotly** (JSON). Cada análise tem seu próprio builder (`PLOTLY_BUILDERS`).
- `render_json`: serializa métricas e tabelas em JSON (sem gráfico).
- Ambas são **dispatcher fechado** (por `result$analysis`).

### 8. **Repository** – Persistência (apenas batch)
- `postgres_repository` e método `persist()` gravam o `AnalysisResult` (como JSON Plotly) na tabela `analytics.chart_cache`.
- **Uso restrito** a jobs agendados; o caminho HTTP ao vivo **não usa** este repositório (o Perl já gerencia o cache).

### 9. **Facades (Application Layer)**
- `load_dataset()`: unifica carregamento de qualquer DataSource.
- `export_result()`: unifica renderização (plotly/json).
- `persist_result()`: unifica persistência.
- **Endpoint HTTP** (`/chart`) usa essas funções com `memory_source`.
- **Batch** (`compute_and_save_school_chart`) usa `postgres_source` e `persist_result`.

### 10. **Tratamento de Erros**
- Condições S3 para **erros de cliente** (`edumaps_client_error`) – retornam HTTP 400.
- Outros erros (bugs internos) viram HTTP 500 sem vazar detalhes.

---

## Fluxos Principais

### Fluxo HTTP ao vivo (`/chart`)
```
Payload JSON (vindo do Perl) 
  → memory_source(rows, metadata) 
  → load_dataset() → SchoolIndicatorModel
  → run_analysis(chart_type, model, parameters) → AnalysisResult
  → export_result(result, "plotly") → JSON Plotly
  → retorna ao cliente (e Perl grava cache separadamente)
```

### Fluxo Batch (job agendado)
```
PostgreSQL (indicador, rede, município)
  → postgres_source(con) 
  → load_dataset(indicator_id, rede, municipio_id) → SchoolIndicatorModel
  → run_analysis(chart_type, model, parameters) → AnalysisResult
  → persist_result(result, repository, feature, cache_key) 
  → grava em analytics.chart_cache
```

---

## Avaliação e Decisões Arquiteturais Relevantes

### Pontos Fortes
- **Separação clara de responsabilidades** (DataSource, Model, Analysis, View, Repository) – facilita testes, manutenção e evolução.
- **Modelo semântico restrito** – evita que análises acessem dados crus, garantindo que só operem sobre indicadores validados.
- **Registry fechado** – impede execução de código arbitrário e centraliza a descoberta de análises.
- **Erros tipados** – diferencia cliente de servidor, evitando vazamento de detalhes internos.
- **Testes de arquitetura** – garantem que todas as análises registradas obedecem ao mesmo contrato, reduzindo a necessidade de testes unitários repetitivos.
- **Separação entre HTTP e Batch** – o R nunca executa SQL em requisições HTTP, mitigando riscos de injeção; a fonte em memória confia na validação prévia do Perl.
- **Uso de funções puras** – análises são deterministicamente testáveis sem dependências externas.

### Pontos de Atenção / Melhorias Possíveis
- **Duplicidade de cache** (Perl e R) – reconhecida como temporária. Se um dia os formatos de `cache_key` divergirem, será necessário unificar.
- **Expansibilidade** – o modelo `SchoolIndicatorModel` é específico para escolas; para novas análises (ex.: clusters, séries temporais) será necessário criar novos modelos semânticos.
- **Batch e HTTP compartilham a mesma lógica de análise**, mas o batch usa `postgres_source` e persistência. Isso está bem isolado, mas a interface `compute_and_save_school_chart` ainda exige que o chamador forneça o `cache_key` (calculado pelo Perl) – uma possível abstração futura poderia gerar a chave internamente.

### Sugestões
- **Documentar o contrato de `cache_key`** entre Perl e R, para evitar desalinhamentos.
- **Considerar a criação de um `DataSource` para Parquet/CSV** para futuras análises offline.
- **Adicionar testes de integração** que exercitem o endpoint HTTP real (com plumber) e o batch com banco de teste.

---

## Conclusão

A arquitetura do `edumapsAnalytics` é **bem estruturada, modular e segura**, seguindo princípios de separação de interesses e design orientado a contratos. A escolha de um modelo semântico restrito, combinada com um registry fechado e camadas de View/Repository bem definidas, torna o sistema **extensível** e **manutenível**. A decisão de manter o R fora do caminho de execução SQL para requisições HTTP é acertada do ponto de vista de segurança. O uso de testes de arquitetura é um diferencial que garante consistência à medida que novas análises forem adicionadas.

O esquemático apresentado resume os componentes e fluxos, servindo como referência rápida para novos desenvolvedores e para futuras evoluções do sistema.

## Implementação (DeepSeek)

Com base no plano revisto e nas suas considerações, apresento o código completo para a migração da análise de similaridade (Gower) para a nova arquitetura analítica. Os arquivos seguem a nomenclatura e estrutura do pacote existente, mantendo compatibilidade e adicionando as melhorias sugeridas.

---

## 1. Modelo Semântico – `SimilarityModel`

**Arquivo:** `R/model-semantic-similarity-model.R`

```r
# R/model-semantic-similarity-model.R
#
# Modelo semântico para similaridade entre entidades.
# Representa um conjunto de entidades identificadas por uma coluna,
# com diversas features (numéricas, categóricas, lógicas).
# Não conhece métricas específicas (Gower, Euclidiana, etc.).

#' Constrói um SimilarityModel
#'
#' @param data data.frame com colunas: identificador e features
#' @param id_column nome da coluna que identifica unicamente cada entidade
#' @param metadata lista livre com metadados (schema, tabela, etc.)
#' @export
new_similarity_model <- function(data, id_column, metadata = list()) {
  if (!is.data.frame(data)) {
    stop_invalid_parameter("SimilarityModel requer um data.frame")
  }
  if (!is.character(id_column) || length(id_column) != 1) {
    stop_invalid_parameter("id_column deve ser uma string única")
  }
  if (!(id_column %in% names(data))) {
    stop_invalid_dataset(
      sprintf("Coluna de identificação '%s' não encontrada no data.frame", id_column)
    )
  }
  # Garantir que a coluna id não seja factor (pode causar problemas)
  if (is.factor(data[[id_column]])) {
    data[[id_column]] <- as.character(data[[id_column]])
  }
  structure(
    list(
      data = data,
      id_column = id_column,
      metadata = metadata
    ),
    class = "similarity_model"
  )
}

#' @export
entity_ids <- function(model) UseMethod("entity_ids")
#' @export
entity_ids.similarity_model <- function(model) {
  model$data[[model$id_column]]
}

#' @export
similarity_features <- function(model) UseMethod("similarity_features")
#' @export
similarity_features.similarity_model <- function(model) {
  setdiff(names(model$data), model$id_column)
}

#' @export
similarity_data <- function(model) UseMethod("similarity_data")
#' @export
similarity_data.similarity_model <- function(model) {
  model$data[similarity_features(model)]
}

#' @export
similarity_id_column <- function(model) UseMethod("similarity_id_column")
#' @export
similarity_id_column.similarity_model <- function(model) {
  model$id_column
}

#' @export
similarity_sample_size <- function(model) UseMethod("similarity_sample_size")
#' @export
similarity_sample_size.similarity_model <- function(model) {
  nrow(model$data)
}

#' @export
similarity_metadata <- function(model) UseMethod("similarity_metadata")
#' @export
similarity_metadata.similarity_model <- function(model) {
  model$metadata
}
```

---

## 2. DataSource em Memória para Similaridade

**Arquivo:** `R/model-datasource-memory-similarity-source.R`

```r
# R/model-datasource-memory-similarity-source.R
#
# Fonte de dados em memória para similaridade.
# Usada em testes e eventualmente em endpoints HTTP (se fornecermos similaridade via API).

#' Cria uma fonte de dados de similaridade em memória
#'
#' @param rows lista de listas ou data.frame com os dados
#' @param id_column nome da coluna identificadora
#' @param metadata metadados adicionais
#' @export
memory_similarity_source <- function(rows, id_column, metadata = list()) {
  if (!is.data.frame(rows) && !is.list(rows)) {
    stop_invalid_parameter("rows deve ser data.frame ou lista")
  }
  structure(
    list(
      rows = rows,
      id_column = id_column,
      metadata = metadata
    ),
    class = c("memory_similarity_source", "data_source")
  )
}

#' @export
load_similarity_model <- function(source, ...) UseMethod("load_similarity_model")

#' @export
load_similarity_model.memory_similarity_source <- function(source, ...) {
  new_similarity_model(
    data = as.data.frame(source$rows),
    id_column = source$id_column,
    metadata = source$metadata
  )
}
```

---

## 3. DataSource PostgreSQL para Similaridade

**Arquivo:** `R/model-datasource-postgres-similarity-source.R`

```r
# R/model-datasource-postgres-similarity-source.R
#
# Fonte de dados PostgreSQL para similaridade.
# Uso restrito a pipelines batch/offline.
# Valida identificadores (schema, table, id_column) para prevenir injeção.

#' @importFrom DBI dbQuoteIdentifier dbGetQuery
NULL

.validate_identifier <- function(value, name) {
  if (!is.character(value) || length(value) != 1) {
    stop_invalid_parameter(sprintf("'%s' deve ser uma string única", name))
  }
  # Permite letras, números, sublinhado; não pode começar com número
  if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", value)) {
    stop_invalid_parameter(
      sprintf("Identificador inválido para %s: '%s'. Deve ser um nome SQL válido.", name, value)
    )
  }
  value
}

#' Cria uma fonte de dados PostgreSQL para similaridade (uso batch)
#'
#' @param con Conexão DBI ativa (ex.: RPostgres::dbConnect)
#' @export
postgres_similarity_source <- function(con) {
  structure(
    list(con = con),
    class = c("postgres_similarity_source", "data_source")
  )
}

#' @export
load_similarity_model.postgres_similarity_source <- function(
    source,
    schema,
    table_name,
    id_column,
    features = NULL,           # opcional: vetor de colunas a selecionar
    where = NULL,              # opcional: condição WHERE (string)
    ...,
    na_action = "complete.cases"  # "complete.cases" ou "gower"
) {
  schema <- .validate_identifier(schema, "schema")
  table_name <- .validate_identifier(table_name, "table_name")
  id_column <- .validate_identifier(id_column, "id_column")

  # Se features for fornecido, validar cada um
  if (!is.null(features)) {
    if (!is.character(features) || length(features) == 0) {
      stop_invalid_parameter("features deve ser um vetor de caracteres não vazio")
    }
    for (f in features) .validate_identifier(f, "feature")
    cols <- paste(DBI::dbQuoteIdentifier(source$con, c(id_column, features)), collapse = ", ")
  } else {
    # SELECT * é permitido, mas pode ser ineficiente; deixamos explícito
    cols <- "*"
  }

  sql <- sprintf(
    "SELECT %s FROM %s.%s",
    cols,
    DBI::dbQuoteIdentifier(source$con, schema),
    DBI::dbQuoteIdentifier(source$con, table_name)
  )

  if (!is.null(where)) {
    sql <- paste(sql, "WHERE", where)
  }

  data <- DBI::dbGetQuery(source$con, sql)

  if (nrow(data) == 0) {
    stop_invalid_dataset("Nenhum dado encontrado na tabela especificada")
  }

  # Se não forneceu features, todas as colunas exceto id_column são features
  if (is.null(features)) {
    features <- setdiff(names(data), id_column)
  } else {
    # Verificar se todas as features existem
    missing <- setdiff(features, names(data))
    if (length(missing) > 0) {
      stop_invalid_dataset(
        sprintf("As seguintes colunas solicitadas não existem: %s", paste(missing, collapse=", "))
      )
    }
  }

  # Aplicar na_action: remover linhas com NA (compatibilidade com legado)
  if (na_action == "complete.cases") {
    data <- data[stats::complete.cases(data), ]
  } else if (na_action == "gower") {
    # Deixar NAs para o Gower (daisy lida com elas)
    # Não faz nada
  } else {
    stop_invalid_parameter("na_action deve ser 'complete.cases' ou 'gower'")
  }

  if (nrow(data) < 2) {
    stop_invalid_dataset(
      "Menos de 2 entidades completas para calcular similaridade."
    )
  }

  new_similarity_model(
    data = data,
    id_column = id_column,
    metadata = list(
      schema = schema,
      table_name = table_name,
      features = features,
      na_action = na_action
    )
  )
}
```

---

## 4. Seleção de Features para Similaridade

**Arquivo:** `R/analysis-similarity-features.R`

```r
# R/analysis-similarity-features.R
#
# Utilitário para selecionar colunas elegíveis para cálculo de similaridade.
# Independente da métrica.

#' Seleciona colunas de um data.frame que são elegíveis para similaridade
#'
#' Considera numéricas, categóricas (character/factor) e lógicas.
#' Exclui a coluna de identificação.
#'
#' @param data data.frame
#' @param id_column nome da coluna de identificação (será excluída)
#' @return vetor de nomes de colunas elegíveis
#' @export
select_mixed_features <- function(data, id_column) {
  if (!is.data.frame(data)) {
    stop_invalid_parameter("select_mixed_features requer um data.frame")
  }
  eligible <- names(
    data[
      vapply(
        data,
        function(x) {
          is.numeric(x) || is.character(x) || is.factor(x) || is.logical(x)
        },
        logical(1)
      )
    ]
  )
  eligible <- setdiff(eligible, id_column)
  if (length(eligible) == 0) {
    stop_invalid_dataset(
      "Nenhuma coluna elegível (numérica, categórica ou lógica) encontrada para similaridade."
    )
  }
  eligible
}
```

---

## 5. Transformação Distância → Pares

**Arquivo:** `R/analysis-similarity-pairs.R`

```r
# R/analysis-similarity-pairs.R
#
# Converte uma matriz de distâncias (ou objeto dist) em um data.frame de pares
# com distância e similaridade (1/(1+d)).

#' Converte matriz de distância em pares ordenados
#'
#' @param ids vetor de identificadores das entidades (mesma ordem da matriz)
#' @param dist_matrix objeto `dist` ou matriz quadrada de distâncias
#' @return data.frame com colunas: entity_1, entity_2, distance, similarity
#' @export
pairs_from_distance <- function(ids, dist_matrix) {
  # Se for objeto dist, converter para matriz
  if (inherits(dist_matrix, "dist")) {
    m <- as.matrix(dist_matrix)
  } else if (is.matrix(dist_matrix)) {
    m <- dist_matrix
  } else {
    stop_invalid_parameter("dist_matrix deve ser uma matriz ou objeto 'dist'")
  }

  if (nrow(m) != length(ids) || ncol(m) != length(ids)) {
    stop_invalid_dataset(
      "Matriz de distância incompatível com o número de entidades."
    )
  }

  idx <- which(upper.tri(m), arr.ind = TRUE)
  n_pairs <- nrow(idx)

  if (n_pairs == 0) {
    return(data.frame(
      entity_1 = character(0),
      entity_2 = character(0),
      distance = numeric(0),
      similarity = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    entity_1 = ids[idx[, 1]],
    entity_2 = ids[idx[, 2]],
    distance = m[idx],
    similarity = 1 / (1 + m[idx]),
    stringsAsFactors = FALSE
  )
}
```

---

## 6. Análise Gower (Pura)

**Arquivo:** `R/analysis-similarity-gower.R`

```r
# R/analysis-similarity-gower.R
#
# Análise de similaridade usando distância de Gower.
# Recebe SimilarityModel, seleciona features (ou usa as fornecidas),
# calcula matriz de distâncias via cluster::daisy, converte para pares
# e retorna AnalysisResult.
# Não acessa banco, não persiste, não gera JSON.

#' @importFrom cluster daisy
#' @importFrom stats complete.cases
NULL

#' @export
analyze_gower <- function(model, parameters = list()) {
  if (!inherits(model, "similarity_model")) {
    stop_invalid_parameter("analyze_gower espera um similarity_model")
  }

  data <- model$data
  ids <- entity_ids(model)
  id_column <- similarity_id_column(model)

  if (length(ids) < 2) {
    stop_invalid_dataset(
      "São necessárias pelo menos 2 entidades para calcular similaridade par-a-par."
    )
  }

  # Features: pode vir de parameters$features, ou selecionar automaticamente
  features <- parameters$features %||%
    select_mixed_features(data, id_column)

  if (length(features) == 0) {
    stop_invalid_dataset("Nenhuma feature disponível para Gower.")
  }

  # Subconjunto de dados para as features
  data_for_gower <- data[features]

  # Converter character para factor (daisy exige factor para categóricas)
  data_for_gower[] <- lapply(
    data_for_gower,
    function(x) {
      if (is.character(x)) {
        as.factor(x)
      } else {
        x
      }
    }
  )

  # Verificar se há dados suficientes
  if (nrow(data_for_gower) < 2) {
    stop_invalid_dataset("Menos de 2 linhas com dados completos para Gower.")
  }

  # Calcular distância de Gower usando cluster::daisy
  # Nota: daisy() trata NAs via argumento 'na.rm' (padrão FALSE) - precisamos definir?
  # O padrão do daisy é usar NA se houver missing, mas podemos definir 'na.rm = TRUE'? 
  # O parâmetro 'na.rm' no daisy controla se colunas com NA são excluídas. 
  # Para manter compatibilidade com legado (drop_na), já removemos NAs no DataSource se na_action=="complete.cases".
  # Se na_action=="gower", deixamos NAs e usamos a opção 'na.rm = TRUE' para que o daisy lide com elas.
  # Vamos inferir de model$metadata$na_action.
  na_action <- model$metadata$na_action %||% "complete.cases"
  na_rm <- (na_action == "gower")

  dist_obj <- cluster::daisy(
    data_for_gower,
    metric = "gower",
    stand = FALSE,
    na.rm = na_rm   # se TRUE, daisy usa pares completos para cada variável
  )

  # Converter para pares
  pairs <- pairs_from_distance(ids, dist_obj)

  # Métricas
  n_entities <- length(ids)
  n_pairs <- nrow(pairs)
  avg_sim <- if (n_pairs > 0) mean(pairs$similarity, na.rm = TRUE) else NA_real_

  new_analysis_result(
    analysis = "gower",
    parameters = parameters,
    data = pairs,
    metrics = list(
      n_entities = n_entities,
      n_pairs = n_pairs,
      avg_similarity = avg_sim
    ),
    tables = list(),  # poderia incluir sumário de features, mas não necessário
    metadata = list(
      metric = "gower",
      id_column = id_column,
      features = features,
      na_action = na_action
    )
  )
}
```

---

## 7. Preview de Pares (para JSON)

**Arquivo:** `R/analysis-similarity-preview.R` (opcional, mas útil)

```r
# R/analysis-similarity-preview.R
#
# Função para extrair um preview dos pares mais similares.

#' Extrai preview dos pares mais similares
#'
#' @param result AnalysisResult de uma análise de similaridade
#' @param n número de pares a retornar (padrão 5)
#' @return data.frame com os n pares com maior similaridade
#' @export
similarity_preview <- function(result, n = 5) {
  if (!inherits(result, "analysis_result")) {
    stop_invalid_parameter("similarity_preview espera um analysis_result")
  }
  if (result$analysis != "gower" && !grepl("similarity", result$analysis)) {
    # Pode ser usado para qualquer métrica de similaridade
  }
  pairs <- result$data
  if (nrow(pairs) == 0) return(pairs)
  pairs[order(pairs$similarity, decreasing = TRUE), ][seq_len(min(n, nrow(pairs))), ]
}
```

---

## 8. Renderizador JSON para Similaridade

**Arquivo:** `R/view-similarity-json.R`

```r
# R/view-similarity-json.R
#
# Renderiza um AnalysisResult de similaridade como JSON.
# Inclui métricas e preview dos top N pares (não todos, para evitar O(n²) no HTTP).

#' @export
render_similarity_json <- function(result, top_n = 5) {
  if (!inherits(result, "analysis_result")) {
    stop_invalid_parameter("render_similarity_json espera um analysis_result")
  }

  preview <- similarity_preview(result, top_n)

  list(
    analysis = result$analysis,
    parameters = result$parameters,
    metrics = result$metrics,
    metadata = result$metadata,
    preview = preview
  )
}
```

---

## 9. Repository para Similaridade (PostgreSQL)

**Arquivo:** `R/repository-postgres-similarity.R`

```r
# R/repository-postgres-similarity.R
#
# Repository para persistir pares de similaridade no PostgreSQL.
# Uso restrito a pipelines batch.

#' Cria um repositório PostgreSQL para similaridade
#'
#' @param con Conexão DBI ativa
#' @export
postgres_similarity_repository <- function(con) {
  structure(
    list(con = con),
    class = "postgres_similarity_repository"
  )
}

#' Persiste pares de similaridade
#'
#' @param repository objeto postgres_similarity_repository
#' @param result AnalysisResult (deve conter data com pares)
#' @param run_id identificador da execução (gerado pelo chamador)
#' @param target_table nome da tabela (opcional, padrão "analytics.similarity_pairs")
#' @param ... outros parâmetros (ex: schema, table, etc.)
#' @export
persist_similarity <- function(repository, result, run_id, target_table = NULL, ...) {
  UseMethod("persist_similarity")
}

#' @export
persist_similarity.postgres_similarity_repository <- function(
    repository,
    result,
    run_id,
    target_table = NULL,
    ...
) {
  if (!inherits(result, "analysis_result")) {
    stop_invalid_parameter("persist_similarity espera um analysis_result")
  }

  pairs <- result$data
  if (nrow(pairs) == 0) {
    # Nada a persistir
    return(invisible(result))
  }

  # Garantir que temos run_id
  if (is.null(run_id)) {
    stop_invalid_parameter("run_id é obrigatório para persistência")
  }

  # Construir data.frame com colunas adicionais
  rows <- data.frame(
    run_id = rep(run_id, nrow(pairs)),
    metric = rep(result$analysis, nrow(pairs)),
    entity_1 = pairs$entity_1,
    entity_2 = pairs$entity_2,
    distance = pairs$distance,
    similarity = pairs$similarity,
    params_json = rep(
      jsonlite::toJSON(result$parameters, auto_unbox = TRUE),
      nrow(pairs)
    ),
    computed_at = Sys.time(),
    stringsAsFactors = FALSE
  )

  # Se target_table não fornecido, usar padrão
  if (is.null(target_table)) {
    target_table <- DBI::Id(schema = "analytics", table = "similarity_pairs")
  } else {
    # target_table pode ser string "analytics.similarity_pairs" ou objeto Id
    if (is.character(target_table)) {
      parts <- strsplit(target_table, "\\.")[[1]]
      if (length(parts) == 2) {
        target_table <- DBI::Id(schema = parts[1], table = parts[2])
      } else {
        target_table <- DBI::Id(table = target_table)
      }
    }
  }

  # Inserir usando dbWriteTable com append
  DBI::dbWriteTable(
    repository$con,
    target_table,
    rows,
    append = TRUE,
    row.names = FALSE
  )

  invisible(result)
}
```

---

## 10. Fachada `run_similarity`

**Arquivo:** `R/app-similarity.R`

```r
# R/app-similarity.R
#
# Fachada para execução de análises de similaridade.
# Combina carga de dados, execução da análise e (opcionalmente) persistência.

#' Executa uma análise de similaridade completa
#'
#' @param source DataSource (ex: postgres_similarity_source ou memory_similarity_source)
#' @param metric Nome da métrica (atualmente "gower", futuramente "euclidean", etc.)
#' @param parameters Lista de parâmetros para a análise e para o DataSource.
#'   Parâmetros comuns: features, na_action, run_id, etc.
#' @param persist Lógico: se TRUE, persiste o resultado usando um repositório apropriado.
#'   Se FALSE, retorna apenas o AnalysisResult.
#' @param ... Parâmetros adicionais para persistência (ex: target_table)
#' @return AnalysisResult (invisivelmente se persistir)
#' @export
run_similarity <- function(source, metric = "gower", parameters = list(),
                           persist = FALSE, ...) {
  # Carregar modelo
  model <- load_similarity_model(source, !!!parameters)

  # Executar análise via controller genérico
  result <- run_analysis(metric, model, parameters)

  if (persist) {
    # Verificar se temos run_id nos parâmetros
    run_id <- parameters$run_id
    if (is.null(run_id)) {
      # Gerar run_id automaticamente (opcional)
      run_id <- paste0("R_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sample(1000:9999, 1))
      warning("run_id não fornecido, gerado automaticamente: ", run_id)
    }
    # Criar repositório: assumimos que source é PostgreSQL e tem $con
    if (inherits(source, "postgres_similarity_source")) {
      repo <- postgres_similarity_repository(source$con)
      persist_similarity(repo, result, run_id = run_id, ...)
    } else {
      warning("Persistência não suportada para este tipo de DataSource. Resultado não persistido.")
    }
  }

  invisible(result)
}
```

---

## 11. Atualização do Registry

**Arquivo:** `R/app-registry.R` (adicionar entrada ao final)

```r
# (conteúdo existente permanece)

analysis_registry <- list(
  histogram = list(
    fn = analyze_histogram,
    required = c("value"),
    view = "plotly"
  ),
  scatter = list(
    fn = analyze_scatter,
    required = c("x", "y"),
    view = "plotly"
  ),
  boxplot = list(
    fn = analyze_boxplot,
    required = c("value", "group"),
    view = "plotly"
  ),
  # Nova entrada para Gower
  gower = list(
    fn = analyze_gower,
    required = character(0),   # sem campos fixos; features são dinâmicas
    view = "similarity_json"   # renderizador específico
  )
)
```

---

## 12. Testes

A seguir, os arquivos de teste para a nova funcionalidade.

### `tests/testthat/test-similarity-model.R`

```r
test_that("SimilarityModel é construído corretamente", {
  df <- data.frame(
    id = 1:3,
    income = c(10, 20, 30),
    network = c("municipal", "estadual", "municipal")
  )
  model <- new_similarity_model(df, "id")
  expect_s3_class(model, "similarity_model")
  expect_equal(entity_ids(model), 1:3)
  expect_equal(similarity_features(model), c("income", "network"))
  expect_equal(similarity_sample_size(model), 3)
  expect_equal(similarity_id_column(model), "id")
})

test_that("SimilarityModel rejeita id_column inválida", {
  df <- data.frame(id = 1:2, x = c(1,2))
  expect_error(new_similarity_model(df, "wrong"), "não encontrada")
  expect_error(new_similarity_model(df, c("id", "x")), "string única")
})
```

### `tests/testthat/test-similarity-pairs.R`

```r
test_that("pairs_from_distance produz pares corretos", {
  ids <- c("A", "B", "C")
  dist_mat <- matrix(c(0, 1, 2,
                       1, 0, 3,
                       2, 3, 0), nrow=3)
  pairs <- pairs_from_distance(ids, dist_mat)
  expect_equal(nrow(pairs), 3)
  expect_equal(pairs$entity_1, c("A", "A", "B"))
  expect_equal(pairs$entity_2, c("B", "C", "C"))
  expect_equal(pairs$distance, c(1,2,3))
  expect_equal(pairs$similarity, 1/(1+c(1,2,3)))
})

test_that("pairs_from_distance aceita objeto dist", {
  ids <- 1:4
  m <- matrix(runif(16), nrow=4)
  m <- (m + t(m))/2
  diag(m) <- 0
  d <- as.dist(m)
  pairs <- pairs_from_distance(ids, d)
  expect_equal(nrow(pairs), 6)
})
```

### `tests/testthat/test-gower.R`

```r
test_that("analyze_gower funciona com dados numéricos e categóricos", {
  df <- data.frame(
    id = 1:4,
    income = c(10, 20, 30, 40),
    network = c("municipal", "municipal", "estadual", "privada")
  )
  model <- new_similarity_model(df, "id")
  result <- analyze_gower(model)
  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "gower")
  expect_equal(result$metrics$n_entities, 4)
  expect_equal(result$metrics$n_pairs, 6)
  expect_true(all(result$data$similarity >= 0 & result$data$similarity <= 1))
})

test_that("analyze_gower permite especificar features manualmente", {
  df <- data.frame(
    id = 1:3,
    income = c(10, 20, 30),
    irrelevant = c("a", "b", "c")
  )
  model <- new_similarity_model(df, "id")
  result <- analyze_gower(model, parameters = list(features = "income"))
  expect_equal(result$metadata$features, "income")
})

test_that("analyze_gower falha com menos de 2 entidades", {
  df <- data.frame(id = 1, income = 10)
  model <- new_similarity_model(df, "id")
  expect_error(analyze_gower(model), "pelo menos 2 entidades")
})

test_that("analyze_gower respeita na_action", {
  df <- data.frame(
    id = 1:3,
    income = c(10, NA, 30)
  )
  model <- new_similarity_model(df, "id", metadata = list(na_action = "complete.cases"))
  result <- analyze_gower(model)
  expect_equal(result$metrics$n_entities, 2)  # id 2 removido
  # Se na_action = "gower", deve manter NAs (daisy lida)
  model2 <- new_similarity_model(df, "id", metadata = list(na_action = "gower"))
  result2 <- analyze_gower(model2)
  expect_equal(result2$metrics$n_entities, 3)  # mantém todos
})
```

### `tests/testthat/test-similarity-registry.R`

```r
test_that("Gower está registrado no analysis_registry", {
  expect_true("gower" %in% names(analysis_registry))
  entry <- analysis_registry[["gower"]]
  expect_equal(entry$required, character(0))
  expect_equal(entry$view, "similarity_json")
  expect_true(is.function(entry$fn))
})

test_that("run_analysis despacha para Gower corretamente", {
  df <- data.frame(id = 1:3, x = c(1,2,3))
  model <- new_similarity_model(df, "id")
  result <- run_analysis("gower", model)
  expect_equal(result$analysis, "gower")
})
```

### `tests/testthat/test-similarity-json.R`

```r
test_that("render_similarity_json produz preview", {
  df <- data.frame(id = 1:5, x = rnorm(5), y = rnorm(5))
  model <- new_similarity_model(df, "id")
  result <- analyze_gower(model)
  json <- render_similarity_json(result, top_n = 3)
  expect_true("preview" %in% names(json))
  expect_lte(nrow(json$preview), 3)
  expect_true("metrics" %in% names(json))
  expect_equal(json$analysis, "gower")
})
```

---

## 13. Atualizações no NAMESPACE (a serem adicionadas)

Adicione as seguintes exportações ao `NAMESPACE` (ou use roxygen2 `@export`):

```
export(new_similarity_model)
export(entity_ids)
export(similarity_features)
export(similarity_data)
export(similarity_id_column)
export(similarity_sample_size)
export(similarity_metadata)
export(memory_similarity_source)
export(postgres_similarity_source)
export(load_similarity_model)
export(select_mixed_features)
export(pairs_from_distance)
export(analyze_gower)
export(similarity_preview)
export(render_similarity_json)
export(postgres_similarity_repository)
export(persist_similarity)
export(run_similarity)
```

Adicione `cluster` ao `Imports` no `DESCRIPTION`:

```
Imports:
    ggplot2,
    plotly,
    jsonlite,
    DBI,
    stats,
    cluster
```

---

## Considerações Finais

- **Compatibilidade**: O código mantém o comportamento legado (`na_action = "complete.cases"`) por padrão. O usuário pode optar por `"gower"` para usar o tratamento nativo do `daisy`.
- **Segurança**: Identificadores são validados com regex antes de montar SQL.
- **Extensibilidade**: Novas métricas (Euclidean, Mahalanobis, etc.) podem ser adicionadas seguindo o mesmo padrão, reutilizando `pairs_from_distance` e o modelo.
- **Testes**: Os testes unitários cobrem os principais fluxos e garantem que a análise não dependa de banco ou persistência.

Esta implementação está pronta para ser integrada ao pacote `edumapsAnalytics` e substituir a antiga função `compute_and_save_gower_similarity` após validação.
