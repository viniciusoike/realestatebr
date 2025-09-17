#' Get Credit Indicators from Abecip
#'
#' Downloads updated housing credit data from Abecip. Abecip represents the major
#' financial institutions that integrate Brazil's finance housing system (SFH).
#' Provides modern error handling, progress reporting, and robust download capabilities.
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
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including download status and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed downloads and graceful fallback
#' to cached data when downloads fail. Web scraping errors are handled with
#' automatic retries and informative error messages.
#'
#' @param table Character. One of `'sbpe'` (default), `'units'`, `'cgi'` or `'all'`.
#' @param category Character. **Deprecated**. Use `table` parameter instead.
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
#' @export
#' @source [https://www.abecip.org.br](https://www.abecip.org.br)
#' @importFrom cli cli_inform cli_warn cli_abort cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom dplyr filter select mutate rename rename_with bind_rows group_by slice
#' @importFrom tidyr pivot_longer pivot_wider
#' @importFrom readxl read_excel
#' @importFrom rvest html_elements html_attr
#' @importFrom xml2 read_html
#'
#' @examples \dontrun{
#' # Download all available data (with progress)
#' all_data <- get_abecip_indicators(quiet = FALSE)
#'
#' # Get specific table
#' units <- get_abecip_indicators("units")
#'
#' # Use cached data for faster access
#' cached_data <- get_abecip_indicators(cached = TRUE)
#'
#' # Check download metadata
#' attr(units, "download_info")
#' }
get_abecip_indicators <- function(
  table = "sbpe",
  category = NULL,
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation and backward compatibility ----
  valid_tables <- c("sbpe", "cgi", "units", "all")

  # Handle backward compatibility: if category is provided, use it as table
  if (!is.null(category)) {
    cli::cli_warn("The 'category' parameter is deprecated. Use 'table' instead.")
    table <- category
  }

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
    cli::cli_abort("{.arg max_retries} must be a positive number")
  }

  # Handle cached data ----
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading Abecip data from cache...")
    }

    tryCatch(
      {
        # Map table to unified architecture
        if (table == "all") {
          data <- get_dataset("abecip_indicators", source = "github")
        } else {
          data <- get_dataset("abecip_indicators", source = "github", category = table)
        }

        if (!quiet) {
          cli::cli_inform("Successfully loaded data from cache")
        }

        # Add metadata
        attr(data, "source") <- "cache"
        attr(data, "download_time") <- Sys.time()
        attr(data, "download_info") <- list(
          source = "cache",
          category = table
        )

        return(data)
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
    # CGI data is currently static
    abecip <- abecip_cgi
    if (!quiet) {
      cli::cli_inform("Loaded CGI data from package")
    }
  }

  if (table == "all") {
    if (!quiet) {
      cli::cli_progress_bar(
        name = "Downloading all Abecip datasets",
        total = 3,
        format = "{cli::pb_name} [{cli::pb_current}/{cli::pb_total}] {cli::pb_bar}"
      )
    }

    sbpe <- download_abecip_sbpe(
      quiet = TRUE,
      max_retries = max_retries
    )
    if (!quiet) cli::cli_progress_update()

    units <- download_abecip_units(
      quiet = TRUE,
      max_retries = max_retries
    )
    if (!quiet) cli::cli_progress_update()

    cgi <- abecip_cgi
    if (!quiet) {
      cli::cli_progress_update()
      cli::cli_progress_done()
    }

    abecip <- list(sbpe = sbpe, units = units, cgi = cgi)
  }

  # Add metadata
  attr(abecip, "source") <- "web"
  attr(abecip, "download_time") <- Sys.time()
  attr(abecip, "download_info") <- download_info

  if (!quiet) {
    cli::cli_inform("Successfully downloaded Abecip data")
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
    dplyr::rename_with(~stringr::str_replace(.x, "sbpe_", "")) |>
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
  attempts <- 0
  last_error <- NULL

  while (attempts < max_retries) {
    attempts <- attempts + 1

    tryCatch(
      {
        # Find the download URL
        if (!quiet && attempts > 1) {
          cli::cli_inform("Retry attempt {attempts}/{max_retries}...")
        }

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
        download.file(url, destfile = temp_path, mode = "wb", quiet = TRUE)

        # Verify file was downloaded
        if (!file.exists(temp_path) || file.size(temp_path) == 0) {
          stop("Downloaded file is empty or missing")
        }

        return(temp_path)
      },
      error = function(e) {
        last_error <<- e$message

        # Add delay before retry
        if (attempts < max_retries) {
          Sys.sleep(min(attempts * 2, 5)) # Progressive backoff
        }
      }
    )
  }

  # All attempts failed
  cli::cli_abort(c(
    "Failed to download file from Abecip after {max_retries} attempts",
    "x" = "Last error: {last_error}",
    "i" = "Check your internet connection or try again later"
  ))
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
    dplyr::select(dplyr::where(~sum(!is.na(.x)) > 0)) |>
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
  # Check if data is empty
  if (nrow(data) == 0) {
    cli::cli_abort(c(
      "Downloaded {type} data is empty",
      "i" = "The data source may be temporarily unavailable"
    ))
  }

  # Check for required columns
  if (type == "sbpe") {
    required_cols <- "date"
    if (!all(required_cols %in% names(data))) {
      cli::cli_abort(c(
        "Missing required columns in {type} data",
        "x" = "Expected columns: {.val {required_cols}}",
        "i" = "The data format may have changed"
      ))
    }
  }

  if (type == "units") {
    required_cols <- c("date", "units_construction", "units_acquisition")
    if (!all(required_cols %in% names(data))) {
      cli::cli_abort(c(
        "Missing required columns in {type} data",
        "x" = "Expected columns: {.val {required_cols}}",
        "i" = "The data format may have changed"
      ))
    }
  }

  # Check date range is reasonable
  date_range <- range(data$date, na.rm = TRUE)
  if (any(is.na(date_range))) {
    cli::cli_abort("Invalid dates in {type} data")
  }

  # Check dates are not in the future
  if (max(data$date, na.rm = TRUE) > Sys.Date() + 90) {
    cli::cli_warn("Some dates in {type} data are more than 90 days in the future")
  }
}
