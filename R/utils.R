#' Finds import range for each table
#'
#' @param path Path to excel file
#' @param sheet Name or number of sheet to be analyzed
#' @param skip_row Additional argument passed to `readxl::read_excel()`
#' @details Based on the date column, finds the range to be imported.
#' @noRd
get_range <- function(path = NULL, sheet, skip_row = 4) {
  # readxl::excel_sheets() marks strings as UTF-8 while tidyxl uses "unknown".
  # Stripping the attribute lets tidyxl locate the sheet, but cells$sheet comes
  # back as UTF-8. We re-derive the lookup key from the returned cells so the
  # dplyr::filter comparisons always use matching encoding attributes.
  Encoding(sheet) <- "unknown"
  cells <- tidyxl::xlsx_cells(path, sheets = sheet)
  sheet_key <- unique(cells$sheet)[1L]

  # Finds last row that is of type Date
  maxrow <- cells |>
    dplyr::filter(.data$sheet == sheet_key, row > skip_row, data_type == "date") |>
    dplyr::slice(dplyr::n()) |>
    dplyr::pull(address)

  # Finds last non-NA column
  maxcol <- cells |>
    dplyr::filter(.data$sheet == sheet_key, !is.na(numeric)) |>
    dplyr::slice_max(col, n = 1) |>
    dplyr::pull(address) |>
    unique()

  # Paste together range: e.g. B5:BD162
  r1 <- stringr::str_extract(maxrow, "[A-Z]")
  r2 <- 1 + skip_row
  r3 <- stringr::str_extract(maxcol, "[A-Z]+")
  r4 <- stringr::str_extract(maxrow, "[0-9]+")

  range_excel <- paste0(r1, r2, ":", r3, r4)
  range_excel <- unique(range_excel)
  return(range_excel)
}

#' Check if Debug Mode is Enabled
#'
#' @description
#' Checks whether debug mode is enabled for detailed package messaging.
#' Debug mode can be enabled via environment variable or package option.
#'
#' @return Logical. TRUE if debug mode is enabled, FALSE otherwise.
#'
#' @details
#' Debug mode can be enabled in two ways (checked in order of precedence):
#' 1. Environment variable: `REALESTATEBR_DEBUG=TRUE`
#' 2. Package option: `options(realestatebr.debug = TRUE)`
#'
#' When debug mode is enabled, all detailed processing messages are shown,
#' including file-by-file progress, type detection, and intermediate steps.
#' This is useful for development and troubleshooting.
#'
#' @keywords internal
is_debug_mode <- function() {
  # Check environment variable first (takes precedence)
  debug_env <- Sys.getenv("REALESTATEBR_DEBUG", "")
  if (debug_env %in% c("TRUE", "1", "true")) {
    return(TRUE)
  }

  # Check package option
  debug_opt <- getOption("realestatebr.debug", FALSE)
  return(isTRUE(debug_opt))
}

#' Debug-Level Messaging
#'
#' @description
#' Displays informational messages only when debug mode is enabled.
#' This function is a wrapper around `cli::cli_inform()` that respects
#' the debug mode setting.
#'
#' @param message Character string. The message to display.
#' @param ... Additional arguments passed to `cli::cli_inform()`.
#'
#' @details
#' This function should be used for detailed processing messages that are
#' useful for development and debugging but would be too verbose for
#' end-users. Messages are only shown when debug mode is enabled via
#' `is_debug_mode()`.
#'
#' @seealso [is_debug_mode()]
#' @keywords internal
cli_debug <- function(message, ...) {
  if (is_debug_mode()) {
    cli::cli_inform(message, .envir = parent.frame(), ...)
  }
}

#' User-Level Messaging
#'
#' @description
#' Displays concise informational messages for end-users.
#' This function shows a simplified, clean message unless the user
#' has requested verbose output via the quiet parameter.
#'
#' @param message Character string. The message to display.
#' @param quiet Logical. If TRUE, suppresses the message.
#' @param ... Additional arguments passed to `cli::cli_inform()`.
#'
#' @details
#' This function should be used for essential status messages that
#' provide value to end-users, such as final results or major milestones.
#' The message is shown unless explicitly suppressed by quiet=TRUE.
#'
#' @keywords internal
cli_user <- function(message, quiet = FALSE, ...) {
  if (!quiet) {
    cli::cli_inform(message, .envir = parent.frame(), ...)
  }
}
