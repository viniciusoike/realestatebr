# IBGE Aggregates API --------------------------------------------------------

ibge_aggregates_base_url <-
  "https://servicodados.ibge.gov.br/api/v3/agregados"

download_ibge_aggregate <- function(
  aggregate,
  variables = "all",
  periods = NULL,
  localities = "N1[all]",
  classifications = NULL,
  quiet = FALSE,
  max_retries = 3L,
  chunk_size = 120L
) {
  if (is.null(periods)) {
    periods <- download_ibge_periods(
      aggregate,
      quiet = quiet,
      max_retries = max_retries
    )
  }

  period_chunks <- split(
    as.character(periods),
    ceiling(seq_along(periods) / chunk_size)
  )

  chunks <- purrr::map(
    period_chunks,
    function(period_chunk) {
      url <- build_ibge_aggregate_url(
        aggregate = aggregate,
        variables = variables,
        periods = period_chunk,
        localities = localities,
        classifications = classifications
      )
      raw <- download_ibge_json(
        url,
        quiet = quiet,
        max_retries = max_retries,
        description = paste("IBGE aggregate", aggregate)
      )
      parse_ibge_aggregate_chunk(raw, aggregate)
    }
  )
  dat <- dplyr::bind_rows(chunks)

  units <- download_ibge_units(
    aggregate,
    quiet = quiet,
    max_retries = max_retries
  )
  dat <- apply_ibge_units(dat, units)

  return(dat)
}

download_ibge_periods <- function(aggregate, quiet, max_retries) {
  url <- paste0(ibge_aggregates_base_url, "/", aggregate, "/periodos")
  raw <- download_ibge_json(
    url,
    quiet = quiet,
    max_retries = max_retries,
    description = paste("IBGE aggregate", aggregate, "period list")
  )

  return(vapply(raw, `[[`, character(1), "id"))
}

# Data responses leave `unidade` empty when the requested periods include
# months before a variable starts, so units come from the metadata endpoint.
download_ibge_units <- function(aggregate, quiet, max_retries) {
  url <- paste0(ibge_aggregates_base_url, "/", aggregate, "/metadados")
  raw <- download_ibge_json(
    url,
    quiet = quiet,
    max_retries = max_retries,
    description = paste("IBGE aggregate", aggregate, "metadata")
  )

  units <- vapply(
    raw$variaveis,
    function(variable) variable$unidade %||% NA_character_,
    character(1)
  )
  names(units) <- vapply(
    raw$variaveis,
    function(variable) as.character(variable$id),
    character(1)
  )

  return(units)
}

apply_ibge_units <- function(dat, units) {
  if (nrow(dat) == 0) {
    return(dat)
  }

  metadata_unit <- unname(units[dat$variable_id])
  dat$unit <- dplyr::coalesce(metadata_unit, dplyr::na_if(dat$unit, ""))

  return(dat)
}

build_ibge_aggregate_url <- function(
  aggregate,
  variables,
  periods,
  localities,
  classifications = NULL
) {
  period_path <- paste(periods, collapse = "|")
  variable_path <- paste(variables, collapse = "|")
  query <- paste0("localidades=", utils::URLencode(localities, reserved = TRUE))

  if (!is.null(classifications)) {
    query <- paste0(
      query,
      "&classificacao=",
      utils::URLencode(classifications, reserved = TRUE)
    )
  }

  return(paste0(
    ibge_aggregates_base_url,
    "/",
    aggregate,
    "/periodos/",
    period_path,
    "/variaveis/",
    variable_path,
    "?",
    query
  ))
}

download_ibge_json <- function(url, quiet, max_retries, description) {
  return(download_with_retry(
    fn = function() {
      response <- httr::GET(
        url,
        httr::user_agent(
          "realestatebr R package (https://github.com/viniciusoike/realestatebr)"
        ),
        httr::accept_json(),
        httr::timeout(60)
      )
      httr::stop_for_status(response)

      text <- httr::content(response, as = "text", encoding = "UTF-8")
      jsonlite::fromJSON(text, simplifyVector = FALSE)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = description
  ))
}

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

parse_ibge_value <- function(x) {
  x <- as.character(x)
  x[x == "-"] <- "0"
  x[x %in% c("..", "...", "X", "X ")] <- NA_character_

  return(readr::parse_double(x, na = character()))
}
