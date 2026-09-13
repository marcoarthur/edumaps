Aqui está uma proposta completa e modular para o pacote **`edumapsr`**. Esta estrutura organiza a camada analítica do EduMaps seguindo as melhores práticas do ecossistema R (CRAN package structure + R6 para a camada de persistência/domínio + controllers funcionais para cálculos estatísticos).

---

### 1. Árvore de Arquivos do Pacote `edumapsr`

```text
edumapsr/
├── DESCRIPTION
├── NAMESPACE
├── R/
│   ├── 00_connection.R        # Gerenciamento de conexão com o PostGIS
│   ├── model_escola.R        # Repositório R6 para entidade Escola / Geometrias
│   ├── model_indicadores.R   # Repositório R6 para dados do Censo/INEP/SIOPE
│   ├── controller_spatial.R  # Análises espaciais (KDE, agregação espacial)
│   ├── controller_stats.R    # Análises estatísticas (ANOVA, distribuições)
│   └── views_serializers.R   # Exportadores para Plotly JSON e GeoJSON
├── tests/
│   ├── testthat.R
│   └── testthat/
│       ├── test_escola_repo.R
│       └── test_spatial.R
└── inst/
    └── sql/                  # Queries SQL complexas reutilizáveis
        └── fetch_infra_geo.sql

```

---

### 2. Especificação dos Arquivos Principais

#### `DESCRIPTION`

Define o pacote, dependências e metadados.

```dcf
Package: edumapsr
Title: Domain Model and Spatial Analytics for EduMaps
Version: 0.1.0
Authors@R: person("Marco", "Arthur", role = c("aut", "cre"), email = "marco@edumaps.local")
Description: Pacote de domínio e análises estatísticas e espaciais para o projeto EduMaps.
License: MIT
Encoding: UTF-8
RoxygenNote: 7.3.0
Imports:
    R6 (>= 2.5.0),
    DBI (>= 1.1.0),
    RPostgres (>= 1.4.0),
    sf (>= 1.0.0),
    spatstat.geom (>= 3.0.0),
    spatstat.explore (>= 3.0.0),
    dplyr (>= 1.1.0),
    jsonlite (>= 1.8.0),
    plotly (>= 4.10.0)
Suggests:
    testthat (>= 3.0.0)

```

---

#### `R/00_connection.R`

Garante um manuseio centralizado e seguro da conexão com o PostgreSQL/PostGIS.

```r
#' Pool de Conexão PostGIS
#' @import DBI RPostgres
#' @export
DatabaseContext <- R6::R6Class("DatabaseContext",
  public = list(
    conn = NULL,
    
    initialize = function(dbname = Sys.getenv("POSTGRES_DB", "edumaps"),
                            host = Sys.getenv("POSTGRES_HOST", "localhost"),
                            port = Sys.getenv("POSTGRES_PORT", 5432),
                            user = Sys.getenv("POSTGRES_USER", "postgres"),
                            password = Sys.getenv("POSTGRES_PASSWORD", "postgres")) {
      self$conn <- DBI::dbConnect(
        RPostgres::Postgres(),
        dbname   = dbname,
        host     = host,
        port     = as.numeric(port),
        user     = user,
        password = password
      )
    },
    
    disconnect = function() {
      if (!is.null(self$conn) && DBI::dbIsValid(self$conn)) {
        DBI::dbDisconnect(self$conn)
      }
    },
    
    finalize = function() {
      self$disconnect()
    }
  )
)

```

---

#### `R/model_escola.R`

Representa o **Model (M)**. Abstrai acessos ao banco usando `sf` para trazer os dados em formato nativo espacial e vetorial.

```r
#' Repositório de Dados de Escolas
#' @import R6 sf DBI
#' @export
EscolaRepository <- R6::R6Class("EscolaRepository",
  public = list(
    ctx = NULL,
    
    initialize = function(db_context) {
      if (!inherits(db_context, "DatabaseContext")) {
        stop("db_context deve ser uma instância de DatabaseContext")
      }
      self$ctx <- db_context
    },
    
    #' Busca escolas de um município retornando objeto Simple Features (sf)
    #' @param codigo_ibge Código IBGE do município (7 dígitos)
    get_by_municipio = function(codigo_ibge) {
      query <- "
        SELECT 
          co_entidade, 
          no_entidade, 
          tp_dependencia,
          co_municipio,
          geom 
        FROM clean.censo_escolas 
        WHERE co_municipio = $1 AND geom IS NOT NULL
      "
      res <- sf::st_read(
        self$ctx$conn, 
        query = query, 
        params = list(as.character(codigo_ibge)),
        geometry_column = "geom"
      )
      return(res)
    },
    
    #' Salva os resultados analíticos na tabela de cache do PostgreSQL
    save_analytics = function(codigo_ibge, analysis_type, summary_json, plotly_json) {
      query <- "
        INSERT INTO analytics.city_school_analytics 
          (codigo_ibge, analysis, summary_data, plotly_charts, updated_at)
        VALUES ($1, $2, $3::jsonb, $4::jsonb, CURRENT_TIMESTAMP)
        ON CONFLICT (codigo_ibge, analysis) 
        DO UPDATE SET 
          summary_data = EXCLUDED.summary_data,
          plotly_charts = EXCLUDED.plotly_charts,
          updated_at = CURRENT_TIMESTAMP
      "
      DBI::dbExecute(
        self$ctx$conn, 
        query, 
        params = list(
          as.character(codigo_ibge), 
          analysis_type, 
          summary_json, 
          plotly_json
        )
      )
    }
  )
)

```

---

#### `R/controller_spatial.R`

Contém as regras de negócio e os **Controllers (C)** para análise de ponto e densidade (KDE).

```r
#' Controller Espacial do EduMaps
#' @import spatstat.geom spatstat.explore sf dplyr
#' @export
SpatialAnalyticsController <- R6::R6Class("SpatialAnalyticsController",
  public = list(
    
    #' Executa o Kernel Density Estimation (KDE) para uma camada sf
    compute_school_kde = function(sf_escolas, sigma = NULL) {
      if (nrow(sf_escolas) < 3) {
        stop("Mínimo de 3 pontos geométricos necessários para cálculo de KDE")
      }
      
      # Garante projeção métrica (ex: SIRGAS 2000 / UTM zone correspondente)
      sf_proj <- sf::st_transform(sf_escolas, 31983) # UTM 23S como padrão
      
      # Converte sf para objeto ppp do spatstat
      coords <- sf::st_coordinates(sf_proj)
      bbox   <- sf::st_bbox(sf_proj)
      
      win <- spatstat.geom::owin(
        xrange = c(bbox["xmin"], bbox["xmax"]), 
        yrange = c(bbox["ymin"], bbox["ymax"])
      )
      
      ppp_escolas <- spatstat.geom::ppp(
        x = coords[,1], 
        y = coords[,2], 
        window = win
      )
      
      # Calcula a largura de banda se não informada
      bw <- if (is.null(sigma)) spatstat.explore::bw.diggle(ppp_escolas) else sigma
      
      # Computa a densidade
      kde_result <- spatstat.explore::density.ppp(ppp_escolas, sigma = bw)
      
      return(list(
        density = kde_result,
        bandwidth = as.numeric(bw),
        n_points = nrow(sf_escolas)
      ))
    }
  )
)

```

---

#### `R/views_serializers.R`

Atua como a **View (V)** no contexto de uma API/Engine Headless: transforma os resultados dos modelos/controllers em artefatos serializáveis (JSON/Plotly) consumíveis pelo Mojolicious e Svelte.

```r
#' Serializadores de Saída do EduMaps
#' @import plotly jsonlite
#' @export
AnalyticsSerializer <- R6::R6Class("AnalyticsSerializer",
  public = list(
    
    #' Converte resultado da análise em estrutura Plotly JSON
    build_enrollment_plotly = function(df_summary) {
      p <- plotly::plot_ly(
        data = df_summary,
        x = ~tp_dependencia,
        y = ~total_matriculas,
        color = ~tp_nivel,
        type = "bar"
      ) %>% plotly::layout(
        barmode = "stack",
        title = "Matrículas por Nível de Ensino e Dependência",
        xaxis = list(title = "Dependência"),
        yaxis = list(title = "Total de Matrículas")
      )
      
      # Exporta a estrutura pura do plotly para inserção direta no PostGIS/JSONB
      plotly_build_list <- plotly::plotly_build(p)$x[c("data", "layout")]
      return(jsonlite::toJSON(plotly_build_list, auto_unbox = TRUE))
    }
  )
)

```

---

### 3. Exemplo de Execução do Pipeline (Entrypoint)

Veja como fica limpo e legível o script executável que roda a task no Worker/Minion:

```r
# exec/run_city_analytics.R
library(edumapsr)

args <- commandArgs(trailingOnly = TRUE)
cod_ibge <- args[1] %||% "3549904" # São José dos Campos exemplo

# 1. Inicializa contexto e repositórios (Models)
ctx   <- DatabaseContext$new()
repo  <- EscolaRepository$new(ctx)

# 2. Inicializa os Controllers e Serializers
spatial_ctrl <- SpatialAnalyticsController$new()
serializer   <- AnalyticsSerializer$new()

# 3. Fluxo de execução
sf_escolas <- repo$get_by_municipio(cod_ibge)

if (nrow(sf_escolas) > 0) {
  # Lógica de Análise
  kde_output <- spatial_ctrl$compute_school_kde(sf_escolas)
  
  # Montagem das Views
  summary_data <- jsonlite::toJSON(list(
    total_escolas = kde_output$n_points,
    bandwidth_opt = kde_output$bandwidth
  ), auto_unbox = TRUE)
  
  plotly_json <- serializer$build_enrollment_plotly(sf_escolas)
  
  # Persistência
  repo$save_analytics(cod_ibge, "full_summary", summary_data, plotly_json)
  cat("Análise concluída com sucesso para o município:", cod_ibge, "\n")
}

ctx$disconnect()

```

---

### Vantagens do Padrão Escolhido:

1. **Desacoplamento:** O controller espacial não sabe onde o dado está salvo (se é PostGIS, arquivo Shapefile ou DuckDB); ele opera sobre o objeto estandardizado `sf`.
2. **Facilidade em Testes:** É possível instanciar um `DatabaseContext` apontando para um banco de dados de teste (ou *mock*) no `testthat`.
3. **Escalabilidade:** Novas rotinas estatísticas (ANOVA, clusters) entram como novos métodos nos Controllers sem alterar a estrutura da aplicação.
