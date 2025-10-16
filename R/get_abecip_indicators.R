#' Get Credit Indicators from Abecip (DEPRECATED)
#'
#' @section Deprecation:
#' This function is deprecated since v0.4.0.
#' Use \code{\link{get_dataset}}("abecip") instead:
#'
#' \preformatted{
#'   # Old way:
#'   data <- get_abecip_indicators()
#'
#'   # New way:
#'   data <- get_dataset("abecip")
#' }
#'
#' @details
#' Downloads housing credit data from Abecip including SBPE monetary flows, financed
#' units, and home-equity loan data.
#'
#' @param table Character. One of `'sbpe'` (default), `'units'`, or `'cgi'`.
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   downloads. Defaults to 3.
#'
#' @return Either a named `list` (when table is `'all'`) or a `tibble`
#'   (for specific tables). The return includes metadata attributes:
#'   \describe{
#'     \item{download_info}{List with download statistics}
#'     \item{source}{Data source used (web or cache)}
#'     \item{download_time}{Timestamp of download}
#'   }
#'
#' @source [https://www.abecip.org.br](https://www.abecip.org.br)
#' @importFrom cli cli_inform cli_warn cli_abort cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom dplyr filter select mutate rename rename_with bind_rows group_by slice
#' @importFrom tidyr pivot_longer pivot_wider
#' @importFrom readxl read_excel
#' @importFrom rvest html_elements html_attr
#' @importFrom xml2 read_html
#' @keywords internal
get_abecip_indicators <- function(
  table = "sbpe",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
  valid_tables <- c("sbpe", "cgi", "units")
  validate_dataset_params(table, valid_tables, cached, quiet, max_retries, allow_all = FALSE)

  # Handle cached data ----
  if (cached) {
    data <- handle_dataset_cache("abecip", table = table, quiet = quiet, on_miss = "download")

    if (!is.null(data)) {
      data <- attach_dataset_metadata(data, source = "cache", category = table)
      return(data)
    }
  }

  # Download fresh data ----
  if (!quiet) {
    cli::cli_inform("Downloading data from Abecip...")
  }

  # Initialize result
  abecip <- NULL
  download_info <- list(
    source = "web",
    category = table,
    attempts = 0,
    errors = character()
  )

  # Download based on category
  if (table == "sbpe") {
    abecip <- download_abecip_sbpe(
      quiet = quiet,
      max_retries = max_retries
    )
  }

  if (table == "units") {
    abecip <- download_abecip_units(
      quiet = quiet,
      max_retries = max_retries
    )
  }

  if (table == "cgi") {
    if (!cached) {
      if (!quiet) {
        cli::cli_inform(c(
          "i" = "CGI data is a static historical dataset (January 2017-present)",
          "i" = "Loading from package cache instead of fresh download"
        ))
      }
    }

    # Load CGI data from user cache
    tryCatch({
      cached_data <- load_from_user_cache("abecip", quiet = quiet)
      if (is.null(cached_data)) {
        cli::cli_abort("CGI data not found in user cache. Try running with cached=FALSE first.")
      }
      if ("cgi" %in% names(cached_data)) {
        abecip <- cached_data[["cgi"]]
      } else {
        cli::cli_abort("CGI data not found in cached dataset")
      }

      if (!quiet) {
        cli::cli_inform("Successfully loaded CGI data from user cache")
      }
    }, error = function(e) {
      cli::cli_abort(c(
        "Failed to load CGI data from cache",
        "x" = "Error: {e$message}",
        "i" = "CGI data should be available in package cache"
      ))
    })
  }

  # Add metadata
  if (table == "cgi") {
    abecip <- attach_dataset_metadata(
      abecip,
      source = "cache",
      category = table,
      extra_info = list(note = "CGI is a static historical dataset")
    )
  } else {
    abecip <- attach_dataset_metadata(abecip, source = "web", category = table, extra_info = download_info)
  }

  if (!quiet) {
    if (table == "cgi") {
      cli::cli_inform("Successfully loaded Abecip CGI data from cache")
    } else {
      cli::cli_inform("Successfully downloaded Abecip data")
    }
  }

  return(abecip)
}

#' Download SBPE Data from Abecip
#'
#' Internal function to download and process SBPE (savings) data from Abecip
#' with robust error handling and retry logic.
#'
#' @param quiet Logical controlling progress messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return A tibble with processed SBPE data
#' @keywords internal
download_abecip_sbpe <- function(quiet = FALSE, max_retries = 3L) {
  # Download Excel file with retry logic ----
  temp_path <- download_abecip_file(
    url_page = "https://www.abecip.org.br/credito-imobiliario/indicadores/caderneta-de-poupanca",
    xpath = '//*[@id="tab37"]/div/div/div/div/a',
    file_prefix = "abecip_poupanca",
    quiet = quiet,
    max_retries = max_retries
  )

  # Import the spreadsheet into R ----
  tryCatch(
    {
      # Get excel range to import
      range_sbpe <- get_range(temp_path, sheet = "SBPE_Mensal", skip_row = 19)
      range_sbpe <- stringr::str_replace(range_sbpe, ":R", ":K")
      # Define column names
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
    },
    error = function(e) {
      cli::cli_abort(c(
        "Failed to read Excel file from Abecip",
        "x" = "Error: {e$message}",
        "i" = "The Excel file structure may have changed"
      ))
    }
  )

  # Clean the data ----
  clean_sbpe <- process_sbpe_data(sbpe)
  clean_rural <- process_sbpe_data(rural)

  # Combine SBPE and rural data
  sbpe_total <- dplyr::bind_rows(
    list(
      sbpe = dplyr::select(clean_sbpe, dplyr::all_of(cnames[1:7])),
      rural = dplyr::select(clean_rural, dplyr::all_of(cnames[1:7]))
    ),
    .id = "category"
  )

  # Reshape to wide format with totals
  sbpe_total <- sbpe_total |>
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

  # Validate data
  validate_abecip_data(sbpe_total, "sbpe")

  return(sbpe_total)
}

#' Download Units Data from Abecip
#'
#' Internal function to download and process financed units data from Abecip
#' with robust error handling and retry logic.
#'
#' @param quiet Logical controlling progress messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return A tibble with processed units data
#' @keywords internal
download_abecip_units <- function(quiet = FALSE, max_retries = 3L) {
  # Download Excel file with retry logic ----
  temp_path <- download_abecip_file(
    url_page = "https://www.abecip.org.br/credito-imobiliario/indicadores/financiamento",
    xpath = '/html/body/section/div/div/div[3]/div/div/a',
    file_prefix = "abecip_financiamento",
    quiet = quiet,
    max_retries = max_retries
  )

  # Import the spreadsheet into R ----
  tryCatch(
    {
      # Define column names
      cnames <- c(
        "date",
        "units_construction",
        "units_acquisition",
        "units_total",
        "currency_construction",
        "currency_acquisition",
        "currency_total"
      )

      # Import excel sheet
      units <- readxl::read_excel(
        temp_path,
        skip = 5,
        sheet = "BD_Unidades",
        col_names = cnames
      )
    },
    error = function(e) {
      cli::cli_abort(c(
        "Failed to read Excel file from Abecip",
        "x" = "Error: {e$message}",
        "i" = "The Excel file structure may have changed"
      ))
    }
  )

  # Clean the data ----
  clean_units <- units |>
    dplyr::mutate(
      date = suppressWarnings(
        janitor::excel_numeric_to_date(as.numeric(date))
      )
    ) |>
    stats::na.omit()

  # Validate data
  validate_abecip_data(clean_units, "units")

  return(clean_units)
}

#' Download Abecip Excel File with Retry Logic
#'
#' Internal helper function to download Excel files from Abecip website
#' with automatic retry on failure.
#'
#' @param url_page URL of the Abecip page containing the download link
#' @param xpath XPath to locate the download link
#' @param file_prefix Prefix for the temporary file name
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
  # Use existing download_with_retry() from rppi-helpers.R
  download_with_retry(
    fn = function() {
      # Parse the page to find download link
      page <- xml2::read_html(url_page)
      url <- rvest::html_elements(page, xpath = xpath) |>
        rvest::html_attr("href")

      if (length(url) == 0) {
        stop("Could not find download link on page")
      }

      # Take first URL if multiple found
      url <- url[1]

      # Ensure URL is absolute
      if (!stringr::str_detect(url, "^http")) {
        url <- paste0("https://www.abecip.org.br", url)
      }

      # Download the file
      temp_path <- tempfile(paste0(file_prefix, ".xlsx"))
      utils::download.file(url, destfile = temp_path, mode = "wb", quiet = TRUE)

      # Verify file was downloaded
      if (!file.exists(temp_path) || file.size(temp_path) == 0) {
        stop("Downloaded file is empty or missing")
      }

      return(temp_path)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = paste("Download", file_prefix)
  )
}

#' Process SBPE Data
#'
#' Internal helper function to clean and process SBPE data tables.
#'
#' @param df Raw data frame from Excel import
#'
#' @return Cleaned tibble
#' @keywords internal
process_sbpe_data <- function(df) {
  df |>
    # Select only columns that are not full NA
    dplyr::select(dplyr::where(~ sum(!is.na(.x)) > 0)) |>
    # Remove all "Total" rows
    dplyr::filter(!stringr::str_detect(date, "Total")) |>
    dplyr::mutate(
      # Convert date column
      date = janitor::excel_numeric_to_date(as.numeric(date)),
      # Convert percentage to proportion
      sbpe_netflow_pct = sbpe_netflow_pct / 100
    )
}

#' Validate Abecip Data
#'
#' Internal helper function to validate downloaded Abecip data.
#'
#' @param data Data frame to validate
#' @param type Type of data ("sbpe" or "units")
#'
#' @return NULL (validates or errors)
#' @keywords internal
validate_abecip_data <- function(data, type) {
  # Use generic validate_dataset() helper
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
    # Generic validation for other types
    validate_dataset(data, dataset_name = paste0("abecip_", type))
  }
}
