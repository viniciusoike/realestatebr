#' Get Credit Indicators from Abecip
#'
#' Downloads updated housing credit data from Abecip. Abecip represents the major
#' financial institutions that integrate Brazil's finance housing system (SFH).
#'
#' @details
#' This function returns three tables:
#' 1. The `sbpe` table summarizes the monetary flows from SBPE. Values are nominal
#' and currency changes over the years. Data is available since January 1982. Original
#' data from Abecip is split into rural (`rural_` and non-rural (`sbpe_`). The total
#' columns sum rural and non-rural financing.
#' 2. The `units` table summarizes the number of units financed by SBPE. Data
#' is available since January 2002. The original data discriminates loans that
#' are used to finance new units (`_construction`) and to finance acquisitions in
#' the secondary market (`_acquisition`). The `units_` columns are in absolute units.
#' The `currency_` columns are in millions of nominal BRL (R$ million).
#' 3. The `cgi` table returns summary data on home-equity loans. Data is available
#' since January 2017. All columns are in absolute/nominal units except `default_rate` which
#' is in percentage and `average_term` which is in months.
#'
#' @param category One of `'sbpe'`, `'units'`, `'cgi'` or `'all'` (default)
#' @inheritParams get_secovi
#'
#' @return Either a named `list` or a `tibble`.
#' @export
#'
#' @examples \dontrun{
#' # SBPE financed units
#' units <- get_abecip_indicators("units")
#'
#' # Download all available data
#' sbpe <- get_abecip_indicators()
#'
#' }
get_abecip_indicators <- function(category = "all", cached = FALSE) {

  message(glue::glue("Downloading data from Abecip."))

  if (category == "sbpe") {
    suppressMessages( abecip <- get_abecip_sbpe(cached) )
  }

  if (category == "units") {
    suppressMessages( abecip <- get_abecip_units(cached) )
  }

  if (category == "cgi") {
    abecip <- abecip_cgi
  }

  if (category == "all") {
    suppressMessages( sbpe <- get_abecip_sbpe(cached) )
    suppressMessages( units <- get_abecip_units(cached) )
    cgi <- abecip_cgi

    abecip <- list(sbpe = sbpe, units = units, cgi = cgi)
  }

  return(abecip)

}

#' Get the SBPE tables
#'
#' @inheritParams get_abecip_indicators
#'
#' @noRd
get_abecip_sbpe <- function(cached) {

  if (cached) {
    df <- readr::read_csv("...")
    return(df)
  }

  # Download the Excel spreadsheet from Abecip's site

  # url
  url_page <- "https://www.abecip.org.br/credito-imobiliario/indicadores/caderneta-de-poupanca"
  # Find the updated link to the download url
  url <- xml2::read_html(url_page) |>
    rvest::html_elements(xpath = '//*[@id="tab37"]/div/div/div/div/a') |>
    rvest::html_attr(name = "href")

  # Define a temporary path to store the sheet and download
  temp_path <- tempfile("abecip_poupanca.xlsx")
  try(download.file(url, destfile = temp_path, mode = "wb", quiet = TRUE))

  # Import the spreadsheet into R

  # Get excel range to import
  range_sbpe <- get_range(temp_path, sheet = "SBPE_Mensal", skip_row = 19)
  range_sbpe <- stringr::str_replace(range_sbpe, ":R", ":K")
  # Define column names
  cnames <- c(
    "date", "sbpe_inflow", "sbpe_outflow", "sbpe_netflow", "sbpe_netflow_pct",
    "sbpe_yield", "sbpe_stock", "drop", "dim_currency", "dim_currecy_label",
    "dim_unit")

  # Get excel range to import
  range_rural <- get_range(temp_path, sheet = "Rural_Mensal")
  range_rural <- stringr::str_replace(range_rural, "A5", "A268")

  # Import
  sbpe <- readxl::read_excel(
    path = temp_path,
    sheet = "SBPE_Mensal",
    col_names = cnames,
    range = range_sbpe
  )

  rural <- readxl::read_excel(
    path = temp_path,
    sheet = "Rural_Mensal",
    col_names = cnames[1:7],
    range = range_rural
  )

  # Clean the data

  clean_abecip_sbpe <- function(df) {
    df |>
      # Select only columns that are not full NA
      dplyr::select(dplyr::where(~sum(!is.na(.x)) > 0)) |>
      # Remove all "Total" rows
      dplyr::filter(!stringr::str_detect(date, "Total")) |>
      dplyr::mutate(
        # Convert date column
        date = janitor::excel_numeric_to_date(as.numeric(date)),
        sbpe_netflow_pct = sbpe_netflow_pct / 100
      )
  }

  clean_sbpe <- clean_abecip_sbpe(sbpe)
  clean_rural <- clean_abecip_sbpe(rural)

  # Join both tables
  sbpe_total <- dplyr::bind_rows(
    list(sbpe = dplyr::select(clean_sbpe, date, sbpe_stock, sbpe_netflow),
         rural = dplyr::select(clean_rural, date, sbpe_stock, sbpe_netflow)),
    .id = "category")

  sbpe_total <- dplyr::bind_rows(
    list(
      sbpe = dplyr::select(clean_sbpe, dplyr::all_of(cnames[1:7])),
      rural = dplyr::select(clean_rural, dplyr::all_of(cnames[1:7]))
      ),
    .id = "category")

  # Sum values and convert to wide
  sbpe_total <- sbpe_total |>
    #dplyr::rename(stock = sbpe_stock, netflow = sbpe_netflow) |>
    dplyr::rename_with(~stringr::str_replace(.x, "sbpe_", "")) |>
    #tidyr::pivot_longer(cols = stock:netflow, names_to = "series_name") |>
    tidyr::pivot_longer(cols = inflow:stock, names_to = "series_name") |>
    dplyr::group_by(category, series_name) |>
    tidyr::pivot_wider(
      id_cols = "date",
      names_from = c("category", "series_name"),
      values_from = "value"
    ) |>
    dplyr::mutate(
      total_stock = sbpe_stock + rural_stock,
      total_netflow = sbpe_netflow + rural_netflow
    )

  return(sbpe_total)

}

#' Get the financed units table
#'
#' @inheritParams get_abecip_indicators
#'
#' @noRd
get_abecip_units <- function(cached) {

  if (cached) {
    df <- readr::read_csv("...")
    return(df)
  }

  # Download the Excel spreadsheet from Abecip's site

  # Url to abecip page
  url_page <- "https://www.abecip.org.br/credito-imobiliario/indicadores/financiamento"
  # Find the up to date link to the download url
  url <- xml2::read_html(url_page) |>
    rvest::html_elements(xpath = '/html/body/section/div/div/div[3]/div/div/a') |>
    rvest::html_attr(name = "href")

  # Define a temporary path to store the sheet and download
  temp_path <- tempfile("abecip_financiamento.xlsx")
  try(download.file(url, destfile = temp_path, mode = "wb", quiet = TRUE))

  # Import the spreadsheet into R

  # Define column names
  cnames <- c(
    "date", "units_construction", "units_acquisition", "units_total",
    "currency_construction", "currency_acquisition", "currency_total"
  )
  # Import excel sheet
  units <- readxl::read_excel(
    temp_path,
    skip = 5,
    sheet = "BD_Unidades",
    col_names = cnames
  )

  # Clean the data
  clean_units <- units |>
    dplyr::mutate(
      date = suppressWarnings(
        janitor::excel_numeric_to_date(as.numeric(date))
        )
      ) |>
    stats::na.omit()

  return(clean_units)

}
