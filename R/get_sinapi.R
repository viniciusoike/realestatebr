# SINAPI constants -----------------------------------------------------------

sinapi_api_base <- "https://servicodados.ibge.gov.br/api/v3/agregados/2296"
sinapi_chunk_size <- 120L

sinapi_variable_names <- c(
  "48" = "cost",
  "2119" = "materials_cost",
  "2120" = "labor_cost",
  "49" = "cost_index",
  "1193" = "materials_index",
  "1232" = "labor_index",
  "1196" = "monthly_change",
  "1197" = "year_to_date_change",
  "1198" = "twelve_month_change"
)

sinapi_geography_names <- c(
  "N1" = "brazil",
  "N2" = "region",
  "N3" = "state"
)

# Get SINAPI data ------------------------------------------------------------

#' Get SINAPI Construction Costs and Indices
#'
#' Downloads the monthly SINAPI series from IBGE SIDRA table 2296 for Brazil,
#' the five geographic regions, and all states.
#'
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param max_retries Integer. Maximum retry attempts. Defaults to 3.
#'
#' @return A tibble with monthly construction costs, indices, and percentage
#'   changes by geography.
#'
#' @source IBGE Sistema Nacional de Pesquisa de Custos e Índices da Construção
#'   Civil (SINAPI), SIDRA table 2296
#' @keywords internal
get_sinapi <- function(quiet = FALSE, max_retries = 3L) {
  if (!rlang::is_bool(quiet)) {
    cli::cli_abort("{.arg quiet} must be `TRUE` or `FALSE`.")
  }
  if (
    !is.numeric(max_retries) ||
      length(max_retries) != 1 ||
      is.na(max_retries) ||
      max_retries < 1
  ) {
    cli::cli_abort("{.arg max_retries} must be a positive integer.")
  }

  cli_user("Downloading SINAPI data from IBGE", quiet = quiet)

  raw <- download_sinapi(quiet = quiet, max_retries = max_retries)
  data <- clean_sinapi(raw)

  validate_dataset(
    data,
    dataset_name = "sinapi",
    required_cols = c(
      "date",
      "geography_type",
      "geography_code",
      "geography_name",
      "variable",
      "unit",
      "value"
    ),
    min_rows = 1000
  )

  duplicated_keys <- duplicated(
    data[c("date", "geography_type", "geography_code", "variable")]
  )
  if (any(duplicated_keys)) {
    cli::cli_abort("SINAPI data contains duplicate observation keys.")
  }

  data <- attach_dataset_metadata(
    data,
    source = "web",
    extra_info = list(sidra_table = 2296L)
  )

  cli_user("SINAPI data retrieved: {nrow(data)} records", quiet = quiet)

  return(data)
}

# Download SINAPI ------------------------------------------------------------

download_sinapi <- function(quiet, max_retries) {
  periods_url <- paste0(sinapi_api_base, "/periodos")
  periods <- download_sinapi_json(
    periods_url,
    quiet = quiet,
    max_retries = max_retries,
    desc = "SINAPI period list"
  )

  period_ids <- vapply(periods, `[[`, character(1), "id")
  chunks <- split(
    period_ids,
    ceiling(seq_along(period_ids) / sinapi_chunk_size)
  )

  raw <- purrr::map(
    chunks,
    function(period_chunk) {
      url <- build_sinapi_url(period_chunk)
      download_sinapi_json(
        url,
        quiet = quiet,
        max_retries = max_retries,
        desc = "SINAPI data"
      )
    }
  )

  return(raw)
}

build_sinapi_url <- function(periods) {
  period_path <- paste(periods, collapse = "|")
  geography_query <- "N1%5Ball%5D%7CN2%5Ball%5D%7CN3%5Ball%5D"

  paste0(
    sinapi_api_base,
    "/periodos/",
    period_path,
    "/variaveis/all?localidades=",
    geography_query
  )
}

download_sinapi_json <- function(url, quiet, max_retries, desc) {
  download_with_retry(
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
    desc = desc
  )
}

# Clean SINAPI ---------------------------------------------------------------

clean_sinapi <- function(raw) {
  rows <- lapply(raw, clean_sinapi_chunk)
  data <- dplyr::bind_rows(rows)

  data <- data |>
    dplyr::filter(!is.na(.data$value)) |>
    dplyr::arrange(
      .data$date,
      .data$geography_type,
      .data$geography_code,
      .data$variable
    )

  return(data)
}

clean_sinapi_chunk <- function(chunk) {
  rows <- list()
  row_index <- 0L

  for (variable in chunk) {
    variable_id <- variable$id
    variable_name <- unname(sinapi_variable_names[variable_id])
    variable_label <- variable$variavel
    variable_unit <- variable$unidade

    if (length(variable_name) == 0 || is.na(variable_name)) {
      cli::cli_abort(
        "Unknown SINAPI variable ID {.val {variable_id}} returned by IBGE."
      )
    }

    for (result in variable$resultados) {
      for (series in result$series) {
        period_ids <- names(series$serie)
        geography_level <- series$localidade$nivel$id
        geography_type <- unname(sinapi_geography_names[geography_level])

        if (length(geography_type) == 0 || is.na(geography_type)) {
          cli::cli_abort(
            "Unknown SINAPI geography level {.val {geography_level}} returned by IBGE."
          )
        }

        row_index <- row_index + 1L
        rows[[row_index]] <- tibble::tibble(
          date = as.Date(paste0(period_ids, "01"), format = "%Y%m%d"),
          geography_type = geography_type,
          geography_code = as.character(series$localidade$id),
          geography_name = series$localidade$nome,
          variable = variable_name,
          variable_label = variable_label,
          unit = variable_unit,
          value = readr::parse_double(
            unlist(series$serie, use.names = FALSE),
            na = c("-", "..", "...", "X")
          )
        )
      }
    }
  }

  dplyr::bind_rows(rows)
}
