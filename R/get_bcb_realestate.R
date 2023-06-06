#' Import Real Estate data from the Brazilian Central Bank
#'
#' Imports and cleans real estate data published monthly by the Brazilian Central
#' Bank. Includes credit sources, credit applications, credit operations, financed
#' units, real estate indices.
#'
#' @details
#' If `category = 'all'` a tidy long `tibble` will be returned with all available
#' data. This table can be hard to navigate since it contains several different
#' tables within it. Each series is uniquely identified by the `series_info` column.
#' The `series_info` column is also split along the `v1` to `v8` columns.
#' A complete metadata of each series is available [here](https://www.bcb.gov.br/estatisticas/mercadoimobiliario) (only in Portuguese).
#'
#' Other choices of `category` return a wide `tibble` with informative column
#' names. Available options are: `'accounting'`, `'application'`, `'indices'`,
#' `'sources'`, `'units'`, or `'all'`.
#'
#' @param category One of `'accounting'`, `'application'`, `'indices'`,
#' `'sources'`, `'units'`, or `'all'` (default).
#' @inheritParams get_secovi
#'
#' @return A `tibble`
#' @export
#'
#' @examples \dontrun{
#' # Download all data in long format
#' bcb <- get_bcb_realestate()
#'
#' # Get only data on financed units
#' units <- get_bcb_realestate("units")
#'
#' }
get_bcb_realestate <- function(category = "all", cached = FALSE) {

  check_cats <- c("all", "accounting", "application", "indices", "sources", "units")

  if (!any(category %in% check_cats)) {
    stop(
      glue::glue("Category must be one of {paste(check_cats, collapse = ', ')}.")
    )
  }

  if (cached) {
    # Download cached data
    clean_bcb <- import_cached("bcb_realestate")
  } else {
    # Download and import most recent data available
    bcb <- import_bcb_realestate()
    # Clean data
    clean_bcb <- clean_bcb_realestate(bcb)
  }

  # Return full cleaned table
  if (category == "all") {
    return(clean_bcb)
  }

  # Auxiliary function to pivot_wider thematic tables
  tbl_bcb_wider <- function(cat, id_cols, names_from) {

    clean_bcb |>
      dplyr::filter(category == cat, !stringr::str_detect(type, "[0-9]")) |>
      tidyr::pivot_wider(
        id_cols = id_cols,
        names_from = names_from,
        values_from = "value",
        names_sep = "_",
        names_repair = "universal"
      ) |>
      dplyr::rename_with(~stringr::str_remove(.x, "(_br)|(br$)"))

  }

  # Tibble with parameters to feed the tbl_bcb_wider function
  params <- tibble::tibble(
    category_label = c("units", "accounting", "indices", "sources", "application"),
    cat = c("imoveis", "contabil", "indices", "fontes", "direcionamento"),
    id_cols = c(list(c("date", "abbrev_state")), "date", "date", "date", "date"),
    names_from = list(c("type", "v1"), c("type", "v1"), c("type", "v1"), c("type", "v1"), c("type", "v1", "v2")
    )
  )
  # Use purrr::pmap to apply function
  params <- params |>
    dplyr::mutate(
      tab = purrr::pmap(list(cat, id_cols, names_from), tbl_bcb_wider)
    )
  # Subset for specific category
  tbl_bcb <- params |>
    dplyr::filter(category_label == category) |>
    tidyr::unnest(cols = tab) |>
    dplyr::select(-cat, -id_cols, -names_from)

  return(tbl_bcb)

}

import_bcb_realestate <- function() {

  url <- "https://olinda.bcb.gov.br/olinda/servico/MercadoImobiliario/versao/v1/odata/mercadoimobiliario?$format=text/csv&$select=Data,Info,Valor"
  # Create a temporary file name
  temp_file <- tempfile(fileext = ".csv")
  message("Downloading real estate data from the Brazilian Central Bank.")
  # Download csv file
  download.file(url, destfile = temp_file, mode = "wb", quiet = TRUE)
  # Read the data
  df <- vroom::vroom(temp_file, col_types = "Dcc")

}

clean_bcb_realestate <- function(df) {

  # Named vector to help split series_info into smaller categories v1-v8 (for filtering)
  new_names <- c(
    "home_equity" = "home-equity",
    "risco_operacao" = "risco-operacao",
    "d_mais" = "d-mais",
    "ivg_r" = "ivg-r",
    "mvg_r" = "mvg-r")

  # Basic clean: renames columns and convert types
  df <- df |>
    dplyr::rename(date = Data, series_info = Info, value = Valor) |>
    dplyr::mutate(
      # Convert to numeric
      value = stringr::str_replace(value, ",", "."),
      value = suppressWarnings(as.numeric(value)),
      # Swap some elements to help split the series_info column
      series_info = stringr::str_replace_all(series_info, new_names),
      # Define year and month columns
      year = lubridate::year(date),
      month = lubridate::month(date),
    )

  # Split the info column into several columns
  df <- df |>
    tidyr::separate_wider_delim(
      series_info,
      delim = "_",
      names = c("category", "type", "v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8"),
      too_few = "align_start",
      cols_remove = FALSE
    )

  # Finds region
  uf_abb <- "br|ro|ac|am|rr|pa|ap|to|ma|pi|ce|rn|pb|pe|al|se|ba|mg|es|rj|sp|pr|sc|rs|ms|mt|go|df"
  # Creates the abbrev_state column
  df <- df |>
    dplyr::mutate(
      # State abbreviation (if exists) is always in the last two elements of the string
      abbrev_state = stringr::str_extract(stringr::str_sub(series_info, -2, -1), uf_abb),
      # Convert to upper case
      abbrev_state = stringr::str_to_upper(abbrev_state),
      # If no element was found, default to BR (Brazil)
      abbrev_state = ifelse(is.na(abbrev_state), "BR", abbrev_state)
    )

  # Remove columns that are full NA
  df <- dplyr::select(df, dplyr::where(~!all(is.na(.x))))

  # Rearrange columns
  df <- df |>
    dplyr::arrange(series_info) |>
    dplyr::arrange(date)

  return(df)

}
