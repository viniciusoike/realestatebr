#' Title
#'
#' @param category aaa
#' @param cached aaa
#'
#' @return A `tibble`
#' @export
#'
#' @examples
#' # get_bcb_realestate()
get_bcb_realestate <- function(category = "all", cached) {

  if (cached) {
    df <- readr::read_csv("...")
    return(df)
  }

  # Download and import data
  bcb <- import_bcb_realestate()
  # Clean data
  clean_bcb <- clean_bcb_realestate(bcb)
  return(clean_bcb)

}

# TO-DO: a tbl_bcb_credit_... function

import_bcb_realestate <- function() {

  url <- "https://olinda.bcb.gov.br/olinda/servico/MercadoImobiliario/versao/v1/odata/mercadoimobiliario?$format=text/csv&$select=Data,Info,Valor"
  # Create a temporary file name
  temp_file <- tempfile(fileext = ".csv")
  # Download csv file
  download.file(url, destfile = temp_file, mode = "wb", quiet = TRUE)
  # Read the data
  df <- readr::read_csv(temp_file)

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

  # Rearrange columns
  df <- df |>
    dplyr::arrange(series_info) |>
    dplyr::arrange(date)

  return(df)

}

# try to abstract and use purrr::pmap
tbl_bcb_wider <- function(df, category, id_cols, names_from) {

  df |>
    dplyr::filter(category == category) |>
    tidyr::pivot_wider(
      id_cols = id_cols,
      names_from = names_from,
      values_from = "value",
      names_sep = "_"
    ) |>
    dplyr::rename_with(~stringr::str_remove(.x, "_br"))

}

to_wide_bcb_imoveis <- function(df, t) {

  df |>
    dplyr::filter(category == "imoveis") |>
    tidyr::pivot_wider(
      id_cols = c("date", "abbrev_state"),
      names_from = c("type", "v1"),
      values_from = "value",
      names_sep = "_"
    )

}

tbl_bcb_imoveis <- function(df) {

  df |>
    dplyr::filter(category == "imoveis") |>
    tidyr::pivot_wider(
      id_cols = c("date", "abbrev_state"),
      names_from = c("type", "v1"),
      values_from = "value",
      names_sep = "_"
    )

}

tbl_bcb_contabil <- function(df) {

  clean_bcb |>
    dplyr::filter(category == "contabil") |>
    tidyr::pivot_wider(
      id_cols = "date",
      names_from = c("type", "v1"),
      values_from = "value",
      names_sep = "_"
    )

}

tbl_bcb_fontes <- function(df) {

  clean_bcb |>
    dplyr::filter(category == "fontes") |>
    tidyr::pivot_wider(
      id_cols = "date",
      names_from = c("type", "v1"),
      values_from = "value",
      names_sort = TRUE,
    ) |>
    dplyr::rename_with(~stringr::str_remove(.x, "_br"))

}

tbl_bcb_direcionamento <- function(df) {

  clean_bcb |>
    dplyr::filter(category == "direcionamento", !stringr::str_detect(type, "[0-9]")) |>
    tidyr::pivot_wider(
      id_cols = "date",
      names_from = c("type", "v1", "v2"),
      values_from = "value",
      names_sort = TRUE,
    ) |>
    dplyr::rename_with(~stringr::str_remove(.x, "_br"))

}

tbl_bcb_indices <- function(df) {

  clean_bcb |>
    dplyr::filter(category == "indices") |>
    dplyr::mutate(type = stringr::str_c(type, v1)) |>
    tidyr::pivot_wider(
      id_cols = "date",
      names_from = "type",
      values_from = "value",
      names_sort = TRUE,
    ) |>
    dplyr::rename_with(~stringr::str_remove(.x, "br$"))

}
