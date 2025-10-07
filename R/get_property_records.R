#' Get Property Records Table
#'
#' Imports and cleans specific tables from the most up to date property transaction
#' records available from Registro de Imoveis with modern error handling, progress
#' reporting, and robust download capabilities.
#'
#' @details
#' This function scrapes download links from the Registro de Imoveis website
#' and processes Excel files containing property transaction data. The function
#' handles multiple data categories and includes comprehensive data cleaning.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including web scraping status, download progress, and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed downloads and robust error
#' handling for web scraping and Excel processing operations.
#'
#' @param table Character. One of:
#'   \describe{
#'     \item{"capitals"}{Records data for capital cities (default)}
#'     \item{"capitals_transfers"}{Transfer data for capital cities}
#'     \item{"cities"}{Records data for all cities}
#'     \item{"aggregates"}{Records data for SP regional aggregates}
#'     \item{"aggregates_transfers"}{Transfer data for SP aggregates}
#'   }
#' @param cached Logical. If `TRUE`, attempts to load data from package cache.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   downloads. Defaults to 3.
#'
#' @return A `tibble` with the requested property records table.
#'
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr filter select mutate inner_join left_join
#' @importFrom xml2 read_html
#' @importFrom rvest html_elements html_attr
#'
#' @keywords internal
get_property_records <- function(
  table = "capitals",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
  valid_tables <- c(
    "capitals",
    "capitals_transfers",
    "cities",
    "aggregates",
    "aggregates_transfers"
  )

  if (!is.character(table) || length(table) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg table} parameter",
      "x" = "{.arg table} must be a single character string"
    ))
  }

  if (!table %in% valid_tables) {
    cli::cli_abort(c(
      "Invalid table: {.val {table}}",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  if (!is.logical(cached) || length(cached) != 1) {
    cli::cli_abort("{.arg cached} must be a logical value")
  }

  if (!is.logical(quiet) || length(quiet) != 1) {
    cli::cli_abort("{.arg quiet} must be a logical value")
  }

  if (!is.numeric(max_retries) || length(max_retries) != 1 || max_retries < 1) {
    cli::cli_abort("{.arg max_retries} must be a positive integer")
  }

  # Handle cached data ----
  if (cached) {
    cli_debug("Loading property records from cache...")

    tryCatch(
      {
        prop <- import_cached("property_records")

        cli_debug("Successfully loaded property records from cache")

        # Extract the specific table from cached data
        result <- extract_property_table(prop, table)

        return(result)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load cached data: {e$message}",
            "i" = "Falling back to fresh download"
          ))
        }
      }
    )
  }

  # Scrape download links ----
  cli_user("Downloading property records data for '{table}'", quiet = quiet)

  download_links <- scrape_registro_imoveis_links(
    quiet = quiet,
    max_retries = max_retries
  )

  if (is.null(download_links) || length(download_links) < 2) {
    cli::cli_abort(c(
      "Failed to find download links",
      "x" = "Could not locate Excel files on the website",
      "i" = "The website structure may have changed"
    ))
  }

  # Process data based on table parameter ----
  if (table %in% c("capitals", "capitals_transfers")) {
    cli_debug("Processing capitals data...")

    capitals_data <- get_ri_capitals_robust(
      url = download_links[[1]],
      quiet = quiet,
      max_retries = max_retries
    )

    out <- if (table == "capitals") {
      capitals_data$records
    } else {
      capitals_data$transfers
    }
  } else if (table %in% c("cities", "aggregates", "aggregates_transfers")) {
    cli_debug("Processing aggregates data...")

    aggregates_data <- get_ri_aggregates_robust(
      url = download_links[[2]],
      quiet = quiet,
      max_retries = max_retries
    )

    out <- switch(
      table,
      "cities" = aggregates_data$record_cities,
      "aggregates" = aggregates_data$record_aggregates,
      "aggregates_transfers" = aggregates_data$transfers
    )
  }

  cli_user(
    "\u2713 Property records data retrieved: {nrow(out)} records",
    quiet = quiet
  )

  return(out)
}

#' Scrape Download Links from Registro de Imoveis Website
#'
#' Internal function to scrape Excel file download links with retry logic.
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Character vector of download links or NULL if failed
#' @keywords internal
scrape_registro_imoveis_links <- function(quiet, max_retries) {
  attempts <- 0
  last_error <- NULL

  while (attempts <= max_retries) {
    attempts <- attempts + 1

    result <- tryCatch(
      {
        url <- "https://www.registrodeimoveis.org.br/portal-estatistico-registral"
        con <- url(url, "rb")
        on.exit(try(close(con), silent = TRUE), add = TRUE)

        # Scrape and process links in one pipe
        dlinks <- xml2::read_html(con) |>
          rvest::html_elements(xpath = "//*[@id='section-contact']/div/p[5]/a") |>
          rvest::html_attr("href") |>
          stringr::str_replace_all(" ", "%20") |>
          stringr::str_remove("\\t") |>
          stringr::str_extract("https.+\\.xlsx$")

        # Validate
        if (length(dlinks) >= 2 && !any(is.na(dlinks))) {
          return(as.list(dlinks))
        }
        NULL
      },
      error = function(e) {
        last_error <<- e$message
        if (attempts <= max_retries) Sys.sleep(min(attempts * 0.5, 3))
        NULL
      }
    )

    if (!is.null(result)) return(result)
  }

  # All attempts failed
  if (!quiet) {
    cli::cli_warn(c(
      "Failed to scrape download links after {max_retries} attempt{?s}",
      "x" = "Last error: {last_error}"
    ))
  }
  return(NULL)
}

#' Download Excel File with Retry Logic for Registro de Imoveis
#'
#' Internal helper function to download Excel files with retry attempts.
#'
#' @param url Download URL
#' @param filename Base filename for temp file
#' @param quiet Logical controlling messages
#' @param max_retries Maximum retry attempts
#'
#' @return List with path (character or NULL) and attempt count
#' @keywords internal
download_ri_excel <- function(url, filename, quiet, max_retries) {
  temp_path <- tempfile(filename)
  attempts <- 0
  last_error <- NULL

  while (attempts <= max_retries) {
    attempts <- attempts + 1

    tryCatch(
      {
        # Attempt download
        utils::download.file(
          url = url,
          destfile = temp_path,
          mode = "wb",
          quiet = TRUE
        )

        # Validate file was downloaded successfully
        if (file.exists(temp_path) && file.size(temp_path) > 1000) {
          return(list(
            path = temp_path,
            attempts = attempts,
            error = NULL
          ))
        } else {
          last_error <<- "Downloaded file is empty or too small"
        }
      },
      error = function(e) {
        last_error <<- e$message

        # Add small delay before retry
        if (attempts <= max_retries) {
          Sys.sleep(min(attempts * 0.5, 3))
        }
      }
    )
  }

  # All attempts failed
  return(list(
    path = NULL,
    attempts = attempts,
    error = last_error
  ))
}

#' Get Capitals Data with Robust Error Handling
#'
#' Modern version of get_ri_capitals with retry logic and progress reporting.
#'
#' @param url Download URL for the Excel file
#' @param quiet Logical controlling messages
#' @param max_retries Maximum retry attempts
#'
#' @return Processed capitals data
#' @keywords internal
get_ri_capitals_robust <- function(url, quiet, max_retries) {
  cli_debug("Downloading capitals data...")

  # Download with retry logic
  download_result <- download_ri_excel(
    url = url,
    filename = "registro_imoveis_capitals.xlsx",
    quiet = quiet,
    max_retries = max_retries
  )

  if (is.null(download_result$path)) {
    cli::cli_abort(c(
      "Failed to download capitals data",
      "x" = "All {max_retries} download attempt{?s} failed",
      "i" = "Error: {download_result$error}"
    ))
  }

  # Import and clean sheets
  cli_debug("Processing capitals Excel file...")

  capitals <- suppressMessages(import_ri_capitals(download_result$path))
  clean_capitals <- suppressWarnings(clean_ri_capitals(capitals))

  return(clean_capitals)
}

#' Get Aggregates Data with Robust Error Handling
#'
#' Modern version of get_ri_aggregates with retry logic and progress reporting.
#'
#' @param url Download URL for the Excel file
#' @param quiet Logical controlling messages
#' @param max_retries Maximum retry attempts
#'
#' @return Processed aggregates data
#' @keywords internal
get_ri_aggregates_robust <- function(url, quiet, max_retries) {
  cli_debug("Downloading aggregates data...")

  # Download with retry logic
  download_result <- download_ri_excel(
    url = url,
    filename = "registro_imoveis_aggregates.xlsx",
    quiet = quiet,
    max_retries = max_retries
  )

  if (is.null(download_result$path)) {
    cli::cli_abort(c(
      "Failed to download aggregates data",
      "x" = "All {max_retries} download attempt{?s} failed",
      "i" = "Error: {download_result$error}"
    ))
  }

  # Import and clean sheets
  cli_debug("Processing aggregates Excel file...")

  aggregates <- suppressMessages(import_ri_aggregates(download_result$path))
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
  records <- readxl::read_excel(path, sheet = 2, skip = 3, col_names = header)
  sales <- readxl::read_excel(path, sheet = 3, skip = 3, col_names = header)
  transfers <- readxl::read_excel(
    path,
    sheet = 4,
    skip = 3,
    col_names = header_fid
  )

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
  clean_transfer <- clean_ri(
    transfer,
    "transfer_type",
    "transfer",
    state = FALSE
  )

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
      year,
      date,
      name_muni,
      record_total,
      sale_total,
      code_muni,
      name_state,
      abbrev_state
    )

  # Join transfers with city names
  tbl2 <- clean_transfer |>
    dplyr::left_join(dim_city, by = c("abbrev_state", "name_simplified")) |>
    dplyr::select(
      year,
      date,
      name_muni,
      transfer_type,
      transfer,
      code_muni,
      name_state,
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
  records <- readxl::read_excel(path, sheet = 2, skip = 4, col_names = header)
  sales <- readxl::read_excel(path, sheet = 3, skip = 4, col_names = header)
  transfers <- readxl::read_excel(
    path,
    sheet = 4,
    skip = 4,
    col_names = header_fid
  )

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
      year,
      date,
      name_sp_region,
      name_sp_label,
      record_total,
      sale_total
    )

  # Join transfer data with city dimensions and rearrange column order
  tbl3 <- clean_transfer |>
    dplyr::left_join(dim_city, by = "name_simplified") |>
    dplyr::select(year, date, name_state, transfer_type, transfer, abbrev_state)

  return(list(record_cities = tbl1, record_aggregates = tbl2, transfers = tbl3))
}

clean_ri_spo <- function(df) {
  df_aux <- dplyr::tribble(
    ~name_sp_region,
    ~name_sp_label,
    "estado_de_sao_paulo_total",
    "Estado de S\u00e3o Paulo",
    "metropolitana_de_sao_paulo_total",
    "Metropolitana de S\u00e3o Paulo",
    "regiao_metropolitana_de_sao_paulo_rmsp",
    "Regi\u00e3o Metro. de S\u00e3o Paulo",
    "municipio_de_sao_paulo",
    "S\u00e3o Paulo (capital)",
    "demais_municipios_da_rmsp",
    "Demais munic\u00edpios da RMSP",
    "demais_municipios_da_msp",
    "Demais munic\u00edpios da MSP",
    "vale_do_paraiba_paulista",
    "Vale do Para\u00edba Paulista",
    "macro_metropolitana_paulista",
    "Macrorregi\u00e3o Metropolitana Paulista",
    "litoral_sul_paulista",
    "Litoral Sul Paulista"
  )

  df |>
    dplyr::left_join(dim_city, by = dplyr::join_by(name_simplified)) |>
    dplyr::filter(is.na(name_muni)) |>
    dplyr::distinct() |>
    dplyr::rename(name_sp_region = name_simplified) |>
    dplyr::left_join(df_aux, by = dplyr::join_by(name_sp_region)) |>
    dplyr::select(
      -code_muni,
      -name_muni,
      -abbrev_state,
      -name_state,
      -code_state,
      -code_region,
      -name_region
    )
}

clean_ri <- function(
  df,
  var_name = "name",
  value_name = "value",
  state = TRUE
) {
  # Fix date column, convert to long and remove missing values
  clean <- df |>
    # dplyr::mutate(date = janitor::excel_numeric_to_date(as.numeric(date))) |>
    dplyr::mutate(date = lubridate::ymd(date)) |>
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
        year,
        date,
        abbrev_state,
        name_simplified,
        dplyr::all_of(value_name)
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
        "sao_paulo"
      )
    ) |>
    dplyr::left_join(dim_city, by = dplyr::join_by(name_simplified)) |>
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

#' Extract Specific Table from Property Records Data
#'
#' Internal helper function to extract a specific table from cached property data
#'
#' @param prop_data Property records data structure (cached format)
#' @param table Table name to extract
#' @return Single tibble for the requested table
#' @keywords internal
extract_property_table <- function(prop_data, table) {
  # Handle different cached data structures
  if (is.list(prop_data) && "capitals" %in% names(prop_data)) {
    # Standard cached structure: list(capitals = list(...), aggregates = list(...))
    switch(
      table,
      "capitals" = prop_data$capitals$records,
      "capitals_transfers" = prop_data$capitals$transfers,
      "cities" = prop_data$aggregates$record_cities,
      "aggregates" = prop_data$aggregates$record_aggregates,
      "aggregates_transfers" = prop_data$aggregates$transfers,
      stop("Unknown table: ", table)
    )
  } else {
    # Fallback for different cache formats
    cli::cli_abort("Unsupported cached data format for property records")
  }
}
