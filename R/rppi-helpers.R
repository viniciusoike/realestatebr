#' RPPI Helper Functions
#'
#' Internal helper functions to reduce code duplication in RPPI functions.
#' These are not exported and only used internally.
#'
#' @name rppi-helpers
#' @keywords internal
NULL

#' Try Loading Cached RPPI Data
#'
#' Attempts to load RPPI data from GitHub cache with optional source filtering.
#'
#' @param table Table name (e.g., "sale", "rent", "fipezap")
#' @param source_filter Optional source name to filter by (e.g., "IVG-R", "IGMI-R")
#' @return Data if successful, NULL if cache unavailable
#' @keywords internal
#' @noRd
try_rppi_cached <- function(table, source_filter = NULL) {
  tryCatch(
    {
      data <- get_dataset("rppi", table, source = "github")
      if (!is.null(source_filter)) {
        data <- dplyr::filter(data, source == source_filter)
      }
      data
    },
    error = function(e) NULL
  )
}

#' Try Loading RPPI Data from User Cache
#'
#' Silently attempts to load an RPPI dataset from the user's local cache.
#'
#' @param dataset_name Cache key (e.g., "rppi_iqa", "rppi_iqaiw")
#' @param quiet Logical. If TRUE, suppresses messages
#' @return Data if successful, NULL if cache unavailable
#' @keywords internal
#' @noRd
try_rppi_user_cache <- function(dataset_name, quiet = FALSE) {
  tryCatch(
    load_from_user_cache(dataset_name, quiet = quiet),
    error = function(e) NULL
  )
}

# NOTE: download_with_retry() has been moved to R/helpers-download.R
# It is now a shared helper function used across all dataset functions.

#' Calculate RPPI Changes
#'
#' Adds month-on-month (chg) and year-on-year (acum12m) change columns.
#'
#' @param data Data frame with index values
#' @param index_col Name of the index column
#' @param group_col Optional grouping column for panel data
#' @return Data with chg and acum12m columns added
#' @keywords internal
#' @noRd
calculate_rppi_changes <- function(
  data,
  index_col = "index",
  group_col = NULL
) {
  data <- data |>
    dplyr::mutate(
      chg = .data[[index_col]] / dplyr::lag(.data[[index_col]]) - 1,
      acum12m = exp(as.numeric(stats::filter(
        log(1 + chg),
        rep(1, 12),
        sides = 1
      ))) -
        1,
      .by = dplyr::all_of(group_col)
    )

  return(data)
}

#' Download Excel File with Retry
#'
#' Downloads an Excel file to a temporary location with retry logic.
#' This is a thin wrapper around download_excel() from helpers-download.R
#' for backwards compatibility with existing RPPI code.
#'
#' @param url URL of the Excel file
#' @param max_retries Maximum retry attempts
#' @param quiet Suppress warnings
#' @return Path to downloaded temporary file
#' @keywords internal
#' @noRd
download_excel_with_retry <- function(url, max_retries = 3, quiet = FALSE) {
  # Use the generic download_excel() from helpers-download.R
  download_excel(
    url = url,
    expected_sheets = NULL, # No sheet validation for generic RPPI downloads
    min_size = 1000,
    ssl_verify = TRUE,
    max_retries = max_retries,
    quiet = quiet
  )
}
