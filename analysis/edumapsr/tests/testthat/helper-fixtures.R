# tests/testthat/helper-fixtures.R
#
# A propriedade mais valiosa da separação DataSource/Semantic Model:
# qualquer teste constrói um school_indicator_model direto, sem banco,
# sem payload HTTP, sem mock de conexão.

fixture_histogram_model <- function(values = c(5, 6, 7, 7, 8, 9, 9, 9, 10)) {
  new_school_indicator_model(
    data = data.frame(value = values),
    metadata = list(value_label = "Infraestrutura")
  )
}

fixture_scatter_model <- function(n = 20) {
  set.seed(42)
  x <- rnorm(n, mean = 7, sd = 1)
  y <- x + rnorm(n, sd = 0.5)
  new_school_indicator_model(
    data = data.frame(x_value = x, y_value = y),
    metadata = list(x_label = "Infraestrutura", y_label = "IDEB")
  )
}

fixture_boxplot_model <- function() {
  new_school_indicator_model(
    data = data.frame(
      value = c(5, 6, 7, 6, 7, 8, 8, 9, 9),
      group = c(
        "municipal", "municipal", "municipal",
        "estadual", "estadual", "estadual",
        "privada", "privada", "privada"
      )
    ),
    metadata = list(value_label = "IDEB", group_label = "Rede")
  )
}

# Fixture do perfil da escola (issue #105). Monta um school_profile_model
# completo (9 indicadores, com dois no quartil inferior do cluster para
# exercitar os sinais de atenção) sem banco, sem payload HTTP.
fixture_school_profile_model <- function() {
  inds <- c(
    "prop_licenciatura", "prop_mestrado", "prop_doutorado", "prop_efetivos",
    "prop_sem_especializacao", "ratio_aluno_docente", "ideb_observado",
    "nota_media", "inse"
  )

  data <- data.frame(
    indicador = inds,
    escola = c(0.87, 0.10, 0.02, 0.20, 0.30, 32.1, 4.7, 5.1, 4.2),
    municipio = c(0.72, 0.08, 0.01, 0.40, 0.35, 24.5, 5.2, 5.4, 4.5),
    rede = c(0.68, 0.06, 0.01, 0.52, 0.40, 22.0, 5.3, 5.6, 4.7),
    brasil = c(0.79, 0.03, 0.005, 0.40, 0.54, 15.0, 5.2, 5.5, 4.8),
    cluster = c(0.81, 0.05, 0.01, 0.42, 0.35, 25.1, 5.0, 5.2, 4.6),
    cluster_p25 = c(0.70, 0.03, 0.005, 0.35, 0.30, 22.0, 4.5, 4.8, 4.1),
    cluster_p50 = c(0.81, 0.05, 0.01, 0.42, 0.35, 25.1, 5.0, 5.2, 4.6),
    cluster_p75 = c(0.90, 0.09, 0.02, 0.55, 0.45, 29.0, 5.6, 5.8, 5.2),
    cluster_media = c(0.80, 0.055, 0.012, 0.43, 0.36, 25.5, 5.0, 5.2, 4.6),
    cluster_n = 42L,
    stringsAsFactors = FALSE
  )

  peers <- data.frame(
    co_entidade = c("35003111", "35003112"),
    no_entidade = c("EMEF Vizinha", "EMEF Central"),
    similarity = c(0.94, 0.90),
    ideb_observado = c(6.1, 5.8),
    stringsAsFactors = FALSE
  )

  flags_meta <- data.frame(
    indicador = inds,
    codigo = paste0(inds, "_flag"),
    severidade = "media",
    mensagem = paste0("Sinal em ", inds),
    stringsAsFactors = FALSE
  )

  metadata <- list(
    co_entidade = "23165669",
    no_entidade = "EMEF Exemplo",
    co_municipio = 2307304,
    no_municipio = "Juazeiro do Norte",
    sg_uf = "CE",
    nu_ano_censo = 2025L,
    cluster_id = 3L,
    cluster_label = "Alta perfil escolar",
    cluster_source = "persisted",
    cluster_scope = "tabela_school_indicators",
    cluster_size = 42L,
    peers_source = "similarity_pairs",
    n_municipio = 10L,
    n_rede = 20L,
    n_brasil = 100L,
    similarity_threshold = 0.3
  )

  new_school_profile_model(
    data = data,
    peers = peers,
    flags_meta = flags_meta,
    metadata = metadata
  )
}
