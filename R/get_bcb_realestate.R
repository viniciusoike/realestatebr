#' Import Real Estate data from the Brazilian Central Bank
#'
#' @description
#' Imports real estate data from BCB including credit sources, applications,
#' financed units, and real estate indices.
#'
#' @param table Character. One of `'accounting'`, `'application'`, `'indices'`,
#'   `'sources'`, `'units'`, or `'all'` (default).
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param max_retries Integer. Maximum retry attempts. Defaults to 3.
#'
#' @return Tibble with BCB real estate data. Includes metadata attributes:
#'   source, download_time.
#'
#' @source Brazilian Central Bank (BCB) Open Data Portal
#' @keywords internal
get_bcb_realestate <- function(
  table = "all",
  quiet = FALSE,
  max_retries = 3L
) {
  valid_tables <- c("accounting", "application", "indices", "sources", "units")

  validate_dataset_params(
    table,
    valid_tables,
    quiet,
    max_retries,
    allow_all = TRUE
  )

  cli_user("Downloading real estate data from BCB API", quiet = quiet)

  bcb <- download_bcb_realestate(quiet = quiet, max_retries = max_retries)
  clean_bcb <- clean_bcb_realestate(bcb, quiet = quiet)
  clean_bcb <- attach_dataset_metadata(clean_bcb, source = "web")
  selected <- apply_table_filtering(clean_bcb, "bcb_realestate", table)
  n_records <- nrow(selected)
  cli_user(
    "BCB real estate data retrieved: {n_records} records",
    quiet = quiet
  )

  return(selected)
}

#' Download raw BCB real estate data from the API
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#' @return Raw tibble from BCB API endpoint
#' @keywords internal
download_bcb_realestate <- function(quiet = FALSE, max_retries = 3L) {
  url <- "https://olinda.bcb.gov.br/olinda/servico/MercadoImobiliario/versao/v1/odata/mercadoimobiliario?$format=text/csv&$select=Data,Info,Valor"

  temp_path <- download_csv(url, max_retries = max_retries, quiet = quiet)
  raw <- readr::read_csv(temp_path, col_types = "Dcc")

  return(raw)
}

clean_bcb_realestate <- function(df, quiet = FALSE) {
  # Named vector to swap hyphenated tokens before splitting on underscore
  new_names <- c(
    "home_equity" = "home-equity",
    "risco_operacao" = "risco-operacao",
    "d_mais" = "d-mais",
    "ivg_r" = "ivg-r",
    "mvg_r" = "mvg-r"
  )

  df <- df |>
    dplyr::rename(date = Data, series_info = Info, value = Valor) |>
    dplyr::mutate(
      value_raw = stringr::str_replace(value, ",", "."),
      value = suppressWarnings(as.numeric(.data$value_raw)),
      series_info = stringr::str_replace_all(series_info, new_names),
      year = lubridate::year(date),
      month = lubridate::month(date),
    )

  # Report values that silently failed numeric coercion
  coercion_failures <- sum(is.na(df$value) & !is.na(df$value_raw))
  if (coercion_failures > 0 && !quiet) {
    cli::cli_warn(
      "{coercion_failures} BCB value{?s} could not be parsed as numeric and {?was/were} set to {.val {NA}}"
    )
  }

  df <- dplyr::select(df, -dplyr::all_of("value_raw"))

  df <- tidyr::separate_wider_delim(
    df,
    series_info,
    delim = "_",
    names = c(
      "category",
      "type",
      "v1",
      "v2",
      "v3",
      "v4",
      "v5",
      "v6",
      "v7",
      "v8"
    ),
    too_few = "align_start",
    cols_remove = FALSE
  )

  uf_abb <- "br|ro|ac|am|rr|pa|ap|to|ma|pi|ce|rn|pb|pe|al|se|ba|mg|es|rj|sp|pr|sc|rs|ms|mt|go|df"

  df <- df |>
    dplyr::mutate(
      abbrev_state = stringr::str_extract(
        stringr::str_sub(series_info, -2, -1),
        uf_abb
      ),
      abbrev_state = stringr::str_to_upper(abbrev_state),
      abbrev_state = ifelse(is.na(abbrev_state), "BR", abbrev_state)
    )

  df <- dplyr::select(df, dplyr::where(~ !all(is.na(.x))))
  df <- dplyr::arrange(df, date)

  return(df)
}
