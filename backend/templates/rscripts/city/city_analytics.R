suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(dplyr)
  library(tidyr)
  library(plotly)
  library(jsonlite)
  library(stats)
})

# Suprime warnings globais para evitar poluição do STDOUT
options(warn = -1)


# Força o locale UTF-8 (garantia)
Sys.setlocale("LC_CTYPE", "en_US.UTF-8")

#' Converte a estrutura do Plotly em lista para evitar double-escaping em serializações JSON
plotly_to_list <- function(p) {
  p_build <- plotly_build(p)
  p_build$x[c("data", "layout")]
}

#' Executa a EDA da cidade e persiste resultados e gráficos Plotly em PostgreSQL
compute_and_save_city_summary <- function(con, schema = "clean", codigo_ibge = "3550308", output_schema = "analytics") {
  
  result <- tryCatch({
    # Define client_encoding para UTF-8
    dbExecute(con, "SET client_encoding = 'UTF8'")
    
    # 1. Leitura dos dados agregados do município (usando placeholder $1)
    query <- paste0("
      SELECT 
        e.co_entidade,
        e.no_entidade,
        e.tp_dependencia,
        e.tp_localizacao,
        COALESCE(m.qt_mat_bas, 0)  AS qt_mat_bas,
        COALESCE(m.qt_mat_inf, 0)  AS qt_mat_inf,
        COALESCE(m.qt_mat_fund, 0) AS qt_mat_fund,
        COALESCE(m.qt_mat_med, 0)  AS qt_mat_med,
        COALESCE(d.qt_doc_bas, 0)  AS qt_doc_bas
      FROM ", schema, ".censo_escolas e
      LEFT JOIN ", schema, ".censo_matriculas m 
        ON e.co_entidade = m.co_entidade AND e.nu_ano_censo = m.nu_ano_censo
      LEFT JOIN ", schema, ".censo_docentes d 
        ON e.co_entidade = d.co_entidade AND e.nu_ano_censo = d.nu_ano_censo
      WHERE e.co_municipio = $1
    ")
    
    df_schools <- dbGetQuery(con, query, params = list(codigo_ibge))
    
    if (nrow(df_schools) == 0) {
      stop(paste("Nenhum dado encontrado para o código IBGE:", codigo_ibge))
    }
    
    # Mapeamento de rótulos categóricos
    df_schools <- df_schools %>%
      mutate(
        dependencia = case_when(
          tp_dependencia == 1 ~ "Federal",
          tp_dependencia == 2 ~ "Estadual",
          tp_dependencia == 3 ~ "Municipal",
          tp_dependencia == 4 ~ "Privada",
          TRUE ~ "Outra"
        ),
        localizacao = case_when(
          tp_localizacao == 1 ~ "Urbana",
          tp_localizacao == 2 ~ "Rural",
          TRUE ~ "Desconhecida"
        ),
        ratio_aluno_docente = if_else(qt_doc_bas > 0, round(qt_mat_bas / qt_doc_bas, 2), NA_real_)
      )

    # 2. Computação de Sumários Estatísticos Globais
    summary_stats <- list(
      total_escolas = nrow(df_schools),
      total_matriculas = sum(df_schools$qt_mat_bas, na.rm = TRUE),
      total_docentes = sum(df_schools$qt_doc_bas, na.rm = TRUE),
      media_alunos_por_escola = round(mean(df_schools$qt_mat_bas, na.rm = TRUE), 2),
      mediana_aluno_docente = median(df_schools$ratio_aluno_docente, na.rm = TRUE),
      distribuicao_dependencia = df_schools %>% count(dependencia) %>% tibble::deframe()
    )
    
    # 3. Construção dos Gráficos Interativos (Plotly)
    df_levels <- df_schools %>%
      group_by(dependencia) %>%
      summarise(
        Infantil = sum(qt_mat_inf, na.rm = TRUE),
        Fundamental = sum(qt_mat_fund, na.rm = TRUE),
        Médio = sum(qt_mat_med, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      pivot_longer(cols = c("Infantil", "Fundamental", "Médio"), names_to = "nivel", values_to = "matriculas")
    
    p1 <- plot_ly(df_levels, x = ~dependencia, y = ~matriculas, color = ~nivel, type = "bar") %>%
      layout(
        barmode = "stack",
        title = list(text = "Matrículas por Nível de Ensino e Dependência Administrativa"),
        xaxis = list(title = "Dependência"),
        yaxis = list(title = "Total de Matrículas")
      )
    
    p2 <- plot_ly(df_schools, x = ~dependencia, y = ~ratio_aluno_docente, color = ~dependencia, type = "box") %>%
      layout(
        title = list(text = "Relação Aluno/Docente por Escola"),
        xaxis = list(title = "Dependência"),
        yaxis = list(title = "Alunos por Docente")
      )
    
    json_charts <- list(
      enrollment_by_level = plotly_to_list(p1),
      student_teacher_ratio = plotly_to_list(p2)
    )
    
    # 4. DDL e Persistência no Banco de Dados PostgreSQL (UPSERT)
    dbExecute(con, sprintf("CREATE SCHEMA IF NOT EXISTS %s;", output_schema))
    
    create_table_sql <- sprintf("
      CREATE TABLE IF NOT EXISTS %s.city_school_analytics (
        codigo_ibge VARCHAR(7) NOT NULL,
        analysis VARCHAR(50) NOT NULL,
        summary_data JSONB NOT NULL,
        plotly_charts JSONB NOT NULL,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (codigo_ibge, analysis)
      );
    ", output_schema)
    
    dbExecute(con, create_table_sql)
    
    upsert_sql <- sprintf("
      INSERT INTO %s.city_school_analytics (codigo_ibge, analysis, summary_data, plotly_charts, updated_at)
      VALUES ($1, $2, $3::jsonb, $4::jsonb, NOW())
      ON CONFLICT (codigo_ibge, analysis) DO UPDATE SET
        summary_data = EXCLUDED.summary_data,
        plotly_charts = EXCLUDED.plotly_charts,
        updated_at = NOW();
    ", output_schema)
    
    # Geração do JSON (sem qualquer manipulação de encoding)
    json_summary <- jsonlite::toJSON(summary_stats, auto_unbox = TRUE)
    json_charts  <- jsonlite::toJSON(json_charts, auto_unbox = TRUE)

    # Persistência com params explicitamente nomeados
    dbExecute(
      con,
      upsert_sql,
      params = list(codigo_ibge, "full_summary", json_summary, json_charts)
    )
    
    # Payload de sucesso para o Perl
    list(
      status = "SUCCESS",
      codigo_ibge = codigo_ibge,
      records_processed = nrow(df_schools)
    )
    
  }, error = function(e) {
    list(
      status = "ERROR",
      message = conditionMessage(e),
      codigo_ibge = codigo_ibge
    )
  })
  
  # Saída JSON capturada pelo Perl
  cat(jsonlite::toJSON(result, auto_unbox = TRUE), "\n")
}

#' Stub para distribuição de notas / indicadores
compute_and_save_score_distributions <- function(con, schema, codigo_ibge, output_schema) {
  result <- list(status = "SKIPPED", message = "Função pronta para extensão com SAEB/IDEB", codigo_ibge = codigo_ibge)
  cat(jsonlite::toJSON(result, auto_unbox = TRUE), "\n")
}

#' Stub para agrupamento de escolas por infraestrutura
compute_and_save_school_clusters <- function(con, schema, codigo_ibge, output_schema) {
  result <- list(status = "SKIPPED", message = "Função pronta para extensão com clustering", codigo_ibge = codigo_ibge)
  cat(jsonlite::toJSON(result, auto_unbox = TRUE), "\n")
}
