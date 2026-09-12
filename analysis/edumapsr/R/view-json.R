# R/view/json.R

#' Converte um valor escalar R em um escalar JSON
#'
#' jsonlite, por padrão, representa valores dentro de listas como arrays.
#' unbox() marca explicitamente valores escalares que devem ser emitidos
#' como valores JSON simples.
#'
#' @keywords internal
as_json_scalar <- function(value) {
  if (is.factor(value)) {
    value <- as.character(value)
  }

  if (length(value) != 1) {
    return(value)
  }

  jsonlite::unbox(value)
}

#' Converte um data.frame em uma lista de objetos JSON, uma linha por objeto
#'
#' @param data data.frame a ser convertido.
#'
#' @return Lista de objetos representando as linhas do data.frame.
#'
#' @keywords internal
as_json_rows <- function(data) {
  data <- as.data.frame(data)

  if (nrow(data) == 0) {
    return(list())
  }

  lapply(
    seq_len(nrow(data)),
    function(i) {
      row <- data[i, , drop = FALSE]

      result <- lapply(
        row,
        function(column) {
          as_json_scalar(column[[1]])
        }
      )

      names(result) <- names(row)
      result
    }
  )
}

#' @export
render_json <- function(result) {
  list(
    analysis = as_json_scalar(result$analysis),

    parameters = lapply(
      result$parameters,
      function(value) {
        if (length(value) == 1) {
          as_json_scalar(value)
        } else {
          value
        }
      }
    ),

    data = as_json_rows(result$data),

    metrics = lapply(
      result$metrics,
      as_json_scalar
    ),

    metadata = lapply(
      result$metadata,
      function(value) {
        if (length(value) == 1) {
          as_json_scalar(value)
        } else {
          value
        }
      }
    ),

    tables = lapply(
      result$tables,
      as_json_rows
    )
  )
}
