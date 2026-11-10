# Reads fixtures saved from the IBGE Aggregates API v3, which runners cannot
# reach, into the tibble that download_ibge_aggregate() returns.

parse_ibge_aggregate_chunk <- function(raw, aggregate) {
  rows <- list()
  row_index <- 0L

  for (variable in raw) {
    for (result in variable$resultados) {
      classifications <- parse_ibge_classifications(result$classificacoes)

      for (series in result$series) {
        period_ids <- names(series$serie)
        values <- unlist(series$serie, use.names = FALSE)
        locality <- series$localidade

        row_index <- row_index + 1L
        row <- tibble::tibble(
          aggregate_id = as.character(aggregate),
          variable_id = as.character(variable$id),
          variable_name = variable$variavel,
          unit = variable$unidade,
          period = period_ids,
          geography_level = locality$nivel$id,
          geography_level_name = locality$nivel$nome,
          geography_code = as.character(locality$id),
          geography_name = locality$nome,
          value_raw = as.character(values),
          value = parse_ibge_value(values)
        )

        if (length(classifications) > 0) {
          for (column in names(classifications)) {
            row[[column]] <- classifications[[column]]
          }
        }

        rows[[row_index]] <- row
      }
    }
  }

  return(dplyr::bind_rows(rows))
}

parse_ibge_classifications <- function(classifications) {
  columns <- list()

  for (classification in classifications) {
    category <- classification$categoria
    category_id <- names(category)[[1]]
    prefix <- paste0("classification_", classification$id)
    columns[[paste0(prefix, "_code")]] <- category_id
    columns[[paste0(prefix, "_name")]] <- unname(category[[1]])
  }

  return(columns)
}
