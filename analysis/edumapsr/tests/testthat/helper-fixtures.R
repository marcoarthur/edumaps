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
