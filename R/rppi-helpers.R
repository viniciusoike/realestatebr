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

#' Download with Retry Logic
#'
#' Executes a download function with automatic retry on failure.
#'
#' @param fn Function to execute (should return data on success)
#' @param max_retries Maximum number of retry attempts
#' @param quiet If TRUE, suppresses retry warnings
#' @param desc Description of what's being downloaded (for error messages)
#' @return Result from fn() if successful
#' @keywords internal
#' @noRd
download_with_retry <- function(
  fn,
  max_retries = 3,
  quiet = FALSE,
  desc = "Download"
) {
  for (i in seq_len(max_retries + 1)) {
    result <- tryCatch(fn(), error = function(e) {
      if (i <= max_retries && !quiet) {
        cli::cli_warn(
          "{desc} attempt {i}/{max_retries + 1} failed: {e$message}"
        )
      }
      NULL
    })
    if (!is.null(result)) {
      return(result)
    }
    if (i <= max_retries) Sys.sleep(min(i * 0.5, 3))
  }
  cli::cli_abort("{desc} failed after {max_retries + 1} attempts")
}

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
      acum12m = zoo::rollapplyr(1 + chg, width = 12, FUN = prod, fill = NA) - 1,
      # Default is NULL (i.e. ungrouped), so this does nothing if group_col is NULL
      .by = group_col
    )

  # if (!is.null(group_col)) {
  #   data <- data |>
  #     dplyr::group_by(dplyr::across(dplyr::all_of(group_col)))
  # }

  # data <- data |>
  #   dplyr::mutate(
  #     chg = .data[[index_col]] / dplyr::lag(.data[[index_col]]) - 1,
  #     acum12m = zoo::rollapplyr(1 + chg, width = 12, FUN = prod, fill = NA) - 1
  #   )

  # if (!is.null(group_col)) {
  #   data <- data |> dplyr::ungroup()
  # }

  data
}

#' Download Excel File with Retry
#'
#' Downloads an Excel file to a temporary location with retry logic.
#'
#' @param url URL of the Excel file
#' @param max_retries Maximum retry attempts
#' @param quiet Suppress warnings
#' @return Path to downloaded temporary file
#' @keywords internal
#' @noRd
download_excel_with_retry <- function(url, max_retries = 3, quiet = FALSE) {
  download_with_retry(
    function() {
      temp_path <- tempfile(fileext = ".xlsx")
      response <- httr::GET(url, httr::write_disk(temp_path, overwrite = TRUE))
      httr::stop_for_status(response)

      if (!file.exists(temp_path) || file.size(temp_path) == 0) {
        stop("Downloaded file is empty or missing")
      }

      temp_path
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "Excel file download"
  )
}
