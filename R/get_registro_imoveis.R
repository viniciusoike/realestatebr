#' Get Property Records data for major cities
#'
#' Imports and cleans the most up to date property transaction records available
#' from Registro de Imoveis.
#'
#' @param category One of `'capitals'`, `'aggregates'`, or `'all'` (default)
#' @inheritParams get_secovi
#'
#' @return A named `list` with property records data
#' @export
#'
#' @examples \dontrun{
#' # Get property records
#' records <- get_property_records()
#'
#' # Only for capitals and selected cities
#' cities <- get_property_records("capitals")
#'
#' }
get_property_records <- function(category = "all", cached = FALSE) {

  cat_options <- c("all", "aggregates", "capitals")

  stopifnot(
    "Argument `category` must be one of 'all', 'capitals', or 'aggregates'." =
      any(category %in% cat_options)
    )

  # Download cached data from the GitHub repository
  if (cached) {
    prop <- import_cached("property_records")
    if (category == "all") { return(prop) } else { return(prop[[category]]) }
  }

  # Params to download data
  url <- "https://www.registrodeimoveis.org.br/portal-estatistico-registral"
  # Scrape page and get the links
  dlinks <- xml2::read_html(url) |>
    rvest::html_elements(xpath = "//*[@id='section-contact']/div/p[5]/a") |>
    rvest::html_attr("href") |>
    purrr::map(stringr::str_replace, pattern = " ", replacement = "%20")

  if (category == "all") {
    out <- list(
      capitals = get_ri_capitals(cached, url = dlinks[[1]]),
      aggregates = get_ri_aggregates(cached, url = dlinks[[2]])
    )
  }

  if (category == "capitals") {
    out <- get_ri_capitals(cached, url = dlinks[[1]])
  }

  if (category == "aggregates") {
    out <- get_ri_aggregates(cached, url = dlinks[[2]])
  }

  return(out)

}

get_ri_capitals <- function(cached, ...) {

  # Define path
  path_capitals <- tempfile("registro_imoveis_capitals.xlsx")
  # Download file
  download.file(
    destfile = path_capitals,
    mode = "wb",
    quiet = TRUE,
    ...
    )

  # Import and clean sheets
  capitals <- suppressMessages(import_ri_capitals(path_capitals))
  clean_capitals <- suppressWarnings(clean_ri_capitals(capitals))

  return(clean_capitals)

}

get_ri_aggregates <- function(cached, ...) {

  # Define path
  path_spo <- tempfile("registro_imoveis_spo.xlsx")
  # Download file
  download.file(
    destfile = path_spo,
    mode = "wb",
    quiet = TRUE,
    ...
    )

  # Import and clean sheets
  aggregates <- suppressMessages(import_ri_aggregates(path_spo))
  clean_aggregates <- suppressWarnings(clean_ri_aggregates(aggregates))

  return(clean_aggregates)

}

import_ri_capitals <- function(path) {

  # Extract the names of the cities and states from the header

  # Get city names and state (UFs) abbreviations
  # Import city name and clean
  city_name <- readxl::read_excel(path = path, sheet = 2, range = "C2:R2")
  city_name <- janitor::make_clean_names(names(city_name))
  # Import UF abbreviation and clean
  state_abb <- readxl::read_excel(path = path, sheet = 2, range = "C3:R3")
  state_abb <- stringr::str_extract(names(state_abb), "[A-Z]{2}")

  # Build a header for the registro/compra sheet
  header <- c("year", "date", stringr::str_c(city_name, "_", state_abb))
  # Fix an error in the original table: Guarulhos is listed as SC
  header <- ifelse(stringr::str_detect(header, "^gua"), "guarulhos_SP", header)

  # Build a header for the transfers sheet
  header_fid <- readxl::read_excel(path = path, sheet = 4, range = "C1:E1")
  header_fid <- c("year", "date", names(janitor::clean_names(header_fid)))

  # Import sheets
  records   <- readxl::read_excel(path, sheet = 2, skip = 3, col_names = header)
  sales     <- readxl::read_excel(path, sheet = 3, skip = 3, col_names = header)
  transfers <- readxl::read_excel(path, sheet = 4, skip = 3, col_names = header_fid)

  # Return
  out <- list(records = records, sales = sales, transfers = transfers)
  return(out)

}

clean_ri_capitals <- function(ls) {

  # Get tables from list
  record <- ls[["records"]]
  sale <- ls[["sales"]]
  transfer <- ls[["transfers"]]

  # Clean data (simplified column names, converts character to numeric)
  clean_record <- clean_ri(record, value_name = "record_total")
  clean_sale <- clean_ri(sale, value_name = "sale_total")
  clean_transfer <- clean_ri(transfer, "transfer_type", "transfer", state = FALSE)

  # Join with city dimension/labels and rearrange column order

  # Creates a name_simplified and abbrev_state columns for left_join
  clean_transfer <- clean_transfer |>
    dplyr::mutate(
      name_simplified = "sao_paulo",
      abbrev_state = "SP"
      )

  # Join both records and sales and proper city names
  tbl1 <- clean_record |>
    dplyr::inner_join(
      dplyr::select(clean_sale, date, name_simplified, sale_total),
      by = c("date", "name_simplified")
      ) |>
    dplyr::left_join(dim_city, by = c("abbrev_state", "name_simplified")) |>
    dplyr::select(
      year, date, name_muni, record_total, sale_total, code_muni, name_state,
      abbrev_state
    )

  # Join transfers with city names
  tbl2 <- clean_transfer |>
    dplyr::left_join(dim_city, by = c("abbrev_state", "name_simplified")) |>
    dplyr::select(
      year, date, name_muni, transfer_type, transfer, code_muni, name_state,
      abbrev_state
    )

  return(list(records = tbl1, transfers = tbl2))

}


import_ri_aggregates <- function(path) {

  # First, get column names

  # Import header line
  header <- readxl::read_excel(path, sheet = 2, range = "C3:V3")
  header <- c("year", "date", names(janitor::clean_names(header)))
  # Import header line
  header_fid <- readxl::read_excel(path = path, sheet = 4, range = "C4:E4")
  header_fid <- c("year", "date", names(janitor::clean_names(header_fid)))
  # Read Excel sheet using column names
  records   <- readxl::read_excel(path, sheet = 2, skip = 4, col_names = header)
  sales     <- readxl::read_excel(path, sheet = 3, skip = 4, col_names = header)
  transfers <- readxl::read_excel(path, sheet = 4, skip = 4, col_names = header_fid)

  # Return sheets as a named list
  out <- list(records = records, sales = sales, transfers = transfers)
  return(out)

}

clean_ri_aggregates <- function(ls) {

  # Separate objects from named list
  record <- ls[["records"]]
  sale <- ls[["sales"]]
  transfer <- ls[["transfers"]]

  # Clean data (simplifies columns names, converts char to num, and reshapes to long)
  clean_record <- clean_ri(
    record,
    var_name = "name_simplified",
    value_name = "record_total",
    state = FALSE
  )

  clean_sale <- clean_ri(
    sale,
    var_name = "name_simplified",
    value_name = "sale_total",
    state = FALSE
  )

  clean_transfer <- clean_ri(
    transfer,
    var_name = "transfer_type",
    value_name = "transfer",
    state = FALSE
  )

  # Join tables with city dimension/labels and rearrange column order

  # Joins with city dimensions and filters only cities
  record_cities <- clean_ri_cities(clean_record)
  sale_cities <- clean_ri_cities(clean_sale)
  # Joins with city dimensions and filters only aggregate regions (RMSP, UF, etc.)
  record_aggs <- clean_ri_spo(clean_record)
  sale_aggs <- clean_ri_spo(clean_sale)
  # Creates a name_simplified column for left_join
  clean_transfer <- dplyr::mutate(clean_transfer, name_simplified = "sao_paulo")

  # Join tables and rearrange column order

  # Join city sales and records data
  tbl1 <- dplyr::inner_join(
    record_cities,
    sale_cities,
    by = c("year", "date", "abbrev_state", "name_simplified", "name_muni")
    )

  # Join aggregate-regions sales and records data
  tbl2 <- dplyr::inner_join(
    record_aggs,
    # Select fewer columns to avoid overlapping columns
    dplyr::select(sale_aggs, date, name_sp_region, sale_total),
    by = c("date", "name_sp_region")
    )
  # Rearrange column order
  tbl2 <- tbl2 |>
    dplyr::select(
      year, date, name_sp_region, name_sp_label, record_total, sale_total
      )

  # Join transfer data with city dimensions and rearrange column order
  tbl3 <- clean_transfer |>
    dplyr::left_join(dim_city, by = "name_simplified") |>
    dplyr::select(year, date, name_state, transfer_type, transfer, abbrev_state)

  return(list(record_cities = tbl1, record_aggregates = tbl2, transfers = tbl3))

}

clean_ri_spo <- function(df) {

  df_aux <- tibble::tribble(
    ~name_sp_region,                          ~name_sp_label,
    "estado_de_sao_paulo_total",              "Estado de São Paulo",
    "metropolitana_de_sao_paulo_total",       "Metropolitana de São Paulo",
    "regiao_metropolitana_de_sao_paulo_rmsp", "Região Metro. de São Paulo",
    "municipio_de_sao_paulo",                 "São Paulo (capital)",
    "demais_municipios_da_rmsp",              "Demais municípios da RMSP",
    "demais_municipios_da_msp",               "Demais municípios da MSP",
    "vale_do_paraiba_paulista",               "Vale do Paraíba Paulista",
    "macro_metropolitana_paulista",           "Macrorregião Metropolitana Paulista",
    "litoral_sul_paulista",                   "Litoral Sul Paulista"
  )

  df |>
    dplyr::left_join(dim_city, by = "name_simplified") |>
    dplyr::filter(is.na(name_muni)) |>
    dplyr::distinct() |>
    dplyr::rename(name_sp_region = name_simplified) |>
    dplyr::left_join(df_aux, by = "name_sp_region") |>
    dplyr::select(
      -code_muni, -name_muni, -abbrev_state, -name_state, -code_state,
      -code_region, -name_region
      )

}

clean_ri <- function(df, var_name = "name", value_name = "value", state = TRUE) {

  # Fix date column, convert to long and remove missing values
  clean <- df |>
    dplyr::mutate(date = janitor::excel_numeric_to_date(as.numeric(date))) |>
    tidyr::pivot_longer(
      cols = -c(date, year),
      names_to = var_name,
      values_to = value_name,
      values_transform = as.numeric
    ) |>
    dplyr::filter(!is.na(!!rlang::sym(value_name)))

  if (isTRUE(state)) {
    clean <- clean |>
      dplyr::mutate(
        abbrev_state = stringr::str_extract(name, "[A-Z]{2}$"),
        name_simplified = stringr::str_remove(name, "_[A-Z]{2}$")
      ) |>
      dplyr::select(
        year, date, abbrev_state, name_simplified, dplyr::all_of(value_name)
      )

  }

  return(clean)

}

clean_ri_cities <- function(df) {
  df |>
    dplyr::mutate(
      name_simplified = stringr::str_replace(
        name_simplified,
        "municipio_de_sao_paulo",
        "sao_paulo")
    ) |>
    dplyr::left_join(dim_city, by = "name_simplified") |>
    dplyr::filter(!is.na(name_muni)) |>
    dplyr::select(
      year,
      date,
      abbrev_state,
      name_simplified,
      name_muni,
      dplyr::any_of(c("record_total", "sale_total"))
      )
}
