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
  rlang::try_fetch(
    {
      data <- get_dataset("rppi", table, source = "github")
      if (!is.null(source_filter)) {
        data <- dplyr::filter(data, source == source_filter)
      }
      data
    },
    error = function(cnd) NULL
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
  rlang::try_fetch(
    load_from_user_cache(dataset_name, quiet = quiet),
    error = function(cnd) NULL
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

