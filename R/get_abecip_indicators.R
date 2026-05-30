#' Get Credit Indicators from Abecip
#'
#' @details
#' Downloads housing credit data from Abecip including SBPE monetary flows, financed
#' units, and home-equity loan data.
#'
#' @param table Character. One of `'sbpe'` (default), `'units'`, or `'cgi'`.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   downloads. Defaults to 3.
#'
#' @return Either a named `list` (when table is `'all'`) or a `tibble`
#'   (for specific tables). The return includes metadata attributes:
#'   \describe{
#'     \item{download_info}{List with download statistics}
#'     \item{source}{Data source used}
#'     \item{download_time}{Timestamp of download}
#'   }
#'
#' @source [https://www.abecip.org.br](https://www.abecip.org.br)
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr filter select mutate rename rename_with bind_rows
#' @importFrom tidyr pivot_longer pivot_wider
#' @importFrom readxl read_excel
#' @importFrom rvest html_elements html_attr
#' @importFrom xml2 read_html
#' @keywords internal
get_abecip_indicators <- function(
  table = "sbpe",
  quiet = FALSE,
  max_retries = 3L
) {
  valid_tables <- c("sbpe", "cgi", "units")
  validate_dataset_params(
    table,
    valid_tables,
    quiet,
    max_retries,
    allow_all = FALSE
  )

  if (!quiet) {
    cli::cli_inform("Downloading data from Abecip...")
  }

  abecip <- NULL

  if (table == "sbpe") {
    temp_path <- download_abecip_sbpe(quiet = quiet, max_retries = max_retries)
    abecip <- clean_abecip_sbpe(temp_path)
  }

  if (table == "units") {
    temp_path <- download_abecip_units(quiet = quiet, max_retries = max_retries)
    abecip <- clean_abecip_units(temp_path)
  }

  if (table == "cgi") {
    if (!quiet) {
      cli::cli_inform(c(
        "i" = "CGI data is a static historical dataset (January 2017-present)",
        "i" = "Loading from bundled package file"
      ))
    }

    cgi_path <- system.file(
      "extdata",
      "abecip_cgi.xlsx",
      package = "realestatebr"
    )
    if (cgi_path == "") {
      cli::cli_abort("CGI data file not found in package installation")
    }

    abecip <- rlang::try_fetch(
      load_abecip_cgi(cgi_path),
      error = function(cnd) {
        rlang::abort("Failed to load CGI data", parent = cnd)
      }
    )
  }

  # Add metadata ----
  if (table == "cgi") {
    abecip <- attach_dataset_metadata(
      abecip,
      source = "bundled",
      category = table,
      extra_info = list(note = "CGI is a static historical dataset")
    )
  } else {
    abecip <- attach_dataset_metadata(abecip, source = "web", category = table)
  }

  if (!quiet) {
    if (table == "cgi") {
      cli::cli_inform("Successfully loaded Abecip CGI data from bundled file")
    } else {
      cli::cli_inform("Successfully downloaded Abecip data")
    }
  }

  return(abecip)
}

#' Download SBPE Excel File from Abecip
#'
#' @param quiet Logical controlling progress messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Path to the downloaded temporary file
#' @keywords internal
download_abecip_sbpe <- function(quiet = FALSE, max_retries = 3L) {
  download_abecip_file(
    url_page = "https://www.abecip.org.br/credito-imobiliario/indicadores/caderneta-de-poupanca",
    xpath = '//*[@id="tab37"]/div/div/div/div/a',
    file_prefix = "abecip_poupanca",
    quiet = quiet,
    max_retries = max_retries
  )
}

#' Clean SBPE Data from Abecip Excel File
#'
#' @param temp_path Path to the downloaded Excel file
#'
#' @return A tibble with processed SBPE data
#' @keywords internal
clean_abecip_sbpe <- function(temp_path) {
  cnames <- c(
    "date",
    "sbpe_inflow",
    "sbpe_outflow",
    "sbpe_netflow",
    "sbpe_netflow_pct",
    "sbpe_yield",
    "sbpe_stock",
    "drop",
    "dim_currency",
    "dim_currecy_label",
    "dim_unit"
  )
  cols_select <- cnames[1:7]

  # Import spreadsheet ----
  raw <- rlang::try_fetch(
    {
      range_sbpe <- get_range(temp_path, sheet = "SBPE_Mensal", skip_row = 19)
      range_sbpe <- stringr::str_replace(range_sbpe, ":R", ":K")

      range_rural <- get_range(temp_path, sheet = "Rural_Mensal")
      range_rural <- stringr::str_replace(range_rural, "A5", "A268")

      sbpe <- readxl::read_excel(
        path = temp_path,
        sheet = "SBPE_Mensal",
        col_names = cnames,
        range = range_sbpe
      )

      rural <- readxl::read_excel(
        path = temp_path,
        sheet = "Rural_Mensal",
        col_names = cols_select,
        range = range_rural
      )

      list(sbpe = sbpe, rural = rural)
    },
    error = function(cnd) {
      rlang::abort(
        c(
          "Failed to read Excel file from Abecip",
          "i" = "The Excel file structure may have changed"
        ),
        parent = cnd
      )
    }
  )

  # Clean individual tables ----
  clean_sbpe <- abecip_clean_sbpe_table(raw$sbpe)
  clean_rural <- abecip_clean_sbpe_table(raw$rural)

  # Stack SBPE and rural data with category label ----
  stacked <- dplyr::bind_rows(
    list(
      sbpe = dplyr::select(clean_sbpe, dplyr::all_of(cols_select)),
      rural = dplyr::select(clean_rural, dplyr::all_of(cols_select))
    ),
    .id = "category"
  )

  # Reshape to wide format with totals ----
  sbpe_total <- stacked |>
    dplyr::rename_with(~ stringr::str_replace(.x, "sbpe_", "")) |>
    tidyr::pivot_longer(
      cols = inflow:stock,
      names_to = "series_name"
    ) |>
    tidyr::pivot_wider(
      id_cols = "date",
      names_from = c("category", "series_name"),
      values_from = "value",
      names_sep = "_"
    ) |>
    dplyr::mutate(
      total_stock = sbpe_stock + rural_stock,
      total_netflow = sbpe_netflow + rural_netflow
    )

  validate_abecip_data(sbpe_total, "sbpe")

  return(sbpe_total)
}

#' Download Units Excel File from Abecip
#'
#' @param quiet Logical controlling progress messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Path to the downloaded temporary file
#' @keywords internal
download_abecip_units <- function(quiet = FALSE, max_retries = 3L) {
  download_abecip_file(
    url_page = "https://www.abecip.org.br/credito-imobiliario/indicadores/financiamento",
    xpath = '/html/body/section/div/div/div[3]/div/div/a',
    file_prefix = "abecip_financiamento",
    quiet = quiet,
    max_retries = max_retries
  )
}

#' Clean Units Data from Abecip Excel File
#'
#' @param temp_path Path to the downloaded Excel file
#'
#' @return A tibble with processed units data
#' @keywords internal
clean_abecip_units <- function(temp_path) {
  cnames <- c(
    "date",
    "units_construction",
    "units_acquisition",
    "units_total",
    "currency_construction",
    "currency_acquisition",
    "currency_total"
  )

  raw <- rlang::try_fetch(
    readxl::read_excel(
      temp_path,
      skip = 5,
      sheet = "BD_Unidades",
      col_names = cnames
    ),
    error = function(cnd) {
      rlang::abort(
        c(
          "Failed to read Excel file from Abecip",
          "i" = "The Excel file structure may have changed"
        ),
        parent = cnd
      )
    }
  )

  clean_units <- raw |>
    dplyr::mutate(
      date = suppressWarnings(
        janitor::excel_numeric_to_date(as.numeric(date))
      )
    ) |>
    stats::na.omit()

  validate_abecip_data(clean_units, "units")

  return(clean_units)
}

#' Download Abecip Excel File
#'
#' Scrapes the given page to find the download link, then downloads the Excel
#' file using the shared `download_excel()` helper.
#'
#' @param url_page URL of the Abecip page containing the download link
#' @param xpath XPath to locate the download link
#' @param file_prefix Prefix used in retry-attempt messages
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Path to the downloaded temporary file
#' @keywords internal
download_abecip_file <- function(
  url_page,
  xpath,
  file_prefix,
  quiet = FALSE,
  max_retries = 3L
) {
  # Scrape page to find download URL ----
  url <- download_with_retry(
    fn = function() {
      page <- xml2::read_html(url_page)
      href <- rvest::html_elements(page, xpath = xpath) |>
        rvest::html_attr("href")

      if (length(href) == 0) {
        stop("Could not find download link on page")
      }

      href <- href[1]

      if (!stringr::str_detect(href, "^http")) {
        href <- paste0("https://www.abecip.org.br", href)
      }

      return(href)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = paste("Scrape", file_prefix, "page")
  )

  # Download the Excel file ----
  download_excel(url, max_retries = max_retries, quiet = quiet)
}

#' Clean a Single SBPE-Format Table
#'
#' @param df Raw data frame from Excel import
#'
#' @return Cleaned tibble
#' @keywords internal
abecip_clean_sbpe_table <- function(df) {
  clean <- df |>
    dplyr::select(dplyr::where(~ sum(!is.na(.x)) > 0)) |>
    dplyr::filter(!stringr::str_detect(date, "Total")) |>
    dplyr::mutate(
      date = janitor::excel_numeric_to_date(as.numeric(date)),
      sbpe_netflow_pct = sbpe_netflow_pct / 100
    )

  return(clean)
}

#' Validate Abecip Data
#'
#' @param data Data frame to validate
#' @param type Type of data ("sbpe" or "units")
#'
#' @return NULL (validates or errors)
#' @keywords internal
validate_abecip_data <- function(data, type) {
  if (type == "sbpe") {
    validate_dataset(
      data,
      dataset_name = paste0("abecip_", type),
      required_cols = "date",
      check_dates = TRUE,
      max_future_days = 90
    )
  } else if (type == "units") {
    validate_dataset(
      data,
      dataset_name = paste0("abecip_", type),
      required_cols = c("date", "units_construction", "units_acquisition"),
      check_dates = TRUE,
      max_future_days = 90
    )
  } else {
    validate_dataset(data, dataset_name = paste0("abecip_", type))
  }
}

#' Load and Process CGI Data from Bundled Excel File
#'
#' @param path Path to abecip_cgi.xlsx
#' @return A tibble with processed CGI data
#' @keywords internal
load_abecip_cgi <- function(path) {
  raw <- readxl::read_excel(path, col_types = "text")
  raw <- janitor::clean_names(raw)

  cols_rename <- c(
    year = "ano",
    month_label = "mes",
    loan = "valor_emprestimo",
    new_contracts = "no_contratos",
    average_term = "prazo_medio",
    default_rate = "inadimplencia",
    stock_contracts = "quantidade_contratos",
    outstanding_balance = "saldo_remanescente"
  )
  cols_select <- c(
    "year",
    "date",
    "new_contracts",
    "stock_contracts",
    "loan",
    "outstanding_balance",
    "average_term",
    "default_rate"
  )

  cgi <- raw |>
    dplyr::rename(dplyr::any_of(cols_rename)) |>
    dplyr::mutate(
      date = readr::parse_date(
        paste(year, month_label),
        format = "%Y %B",
        locale = readr::locale("pt")
      ),
      year = as.numeric(year),
      loan = parse_cgi_number(loan, decimal = TRUE),
      average_term = as.numeric(stringr::str_replace(average_term, " ", ".")),
      default_rate = as.numeric(stringr::str_remove(default_rate, "%")),
      new_contracts = parse_cgi_contract(new_contracts),
      stock_contracts = parse_cgi_stock(stock_contracts),
      outstanding_balance = parse_cgi_balance(outstanding_balance)
    ) |>
    dplyr::select(dplyr::all_of(cols_select))

  return(cgi)
}

parse_cgi_number <- function(x, decimal = TRUE) {
  y <- stringr::str_extract_all(x, "\\d+")
  if (decimal) {
    y <- sapply(y, \(z) paste0(paste(z[1:3], collapse = ""), ".", z[4]))
  } else {
    y <- sapply(y, paste, collapse = "")
  }
  as.numeric(y)
}

parse_cgi_contract <- function(x, width = 4) {
  y <- stringr::str_remove(x, "\\.")
  y <- stringr::str_sub(y, 1, 4)
  y <- ifelse(
    stringr::str_detect(y, "(^1)|(^2)|(^3)") & stringr::str_length(y) == 3,
    stringr::str_pad(y, width = 4, side = "right", pad = "0"),
    y
  )
  as.numeric(y)
}

parse_cgi_balance <- function(x) {
  y <- stringr::str_extract_all(x, "\\d+")
  y <- sapply(y, paste, collapse = "")
  y <- ifelse(
    stringr::str_detect(y, "^9"),
    stringr::str_sub(y, 1, 10),
    stringr::str_sub(y, 1, 11)
  )
  y <- ifelse(
    stringr::str_detect(y, "^1") & stringr::str_length(y) == 10,
    stringr::str_pad(y, width = 11, side = "right", pad = "0"),
    y
  )
  as.numeric(y)
}

parse_cgi_stock <- function(x) {
  y <- stringr::str_remove(x, "\\.")
  y <- dplyr::case_when(
    stringr::str_detect(y, "^1") ~ stringr::str_pad(
      stringr::str_sub(y, 1, 6),
      width = 6,
      side = "right",
      pad = "0"
    ),
    stringr::str_detect(y, "^9") ~ stringr::str_pad(
      stringr::str_sub(y, 1, 5),
      width = 5,
      side = "right",
      pad = "0"
    )
  )
  as.numeric(y)
}
