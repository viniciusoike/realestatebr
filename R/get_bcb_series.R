#' Download macroeconomic time-series from BCB (DEPRECATED)
#'
#' @section Deprecation:
#' This function is deprecated since v0.4.0.
#' Use \code{\link{get_dataset}}("bcb_series") instead:
#'
#' \preformatted{
#'   # Old way:
#'   data <- get_bcb_series()
#'
#'   # New way:
#'   data <- get_dataset("bcb_series")
#' }
#'
#' @details
#' Downloads macroeconomic time series from BCB including price indices, interest
#' rates, credit indicators, and production metrics.
#'
#' @param table Character. Which dataset to return: "all" (default), "credit", "exchange",
#'   "government", "interest-rate", "real-estate", "price", or "production".
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param date_start A `Date` argument indicating the first period to extract
#'   from the time series. Defaults to 2010-01-01.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   BCB API calls. Defaults to 3.
#' @param ... Additional arguments passed to `rbcb::get_series`.
#'
#' @source [https://www3.bcb.gov.br/sgspub/localizarseries/localizarSeries.do?method=prepararTelaLocalizarSeries](https://www3.bcb.gov.br/sgspub/localizarseries/localizarSeries.do?method=prepararTelaLocalizarSeries)
#' @return A 12-column `tibble` with all of the selected series from BCB.
#'   The tibble includes metadata attributes:
#'   \describe{
#'     \item{download_info}{List with download statistics}
#'     \item{source}{Data source used (api or cache)}
#'     \item{download_time}{Timestamp of download}
#'   }
#'
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr as_tibble rename select left_join filter
#' @keywords internal
get_bcb_series <- function(
  table = "all",
  cached = FALSE,
  date_start = as.Date("2010-01-01"),
  quiet = FALSE,
  max_retries = 3L,
  ...
) {
  # Input validation and backward compatibility ----

  # Check for required data dependencies
  if (!exists("bcb_metadata")) {
    cli::cli_abort(c(
      "Required data dependency not available",
      "x" = "This function requires the {.pkg bcb_metadata} object",
      "i" = "Please ensure all package data is properly loaded"
    ))
  }

  valid_tables <- c(unique(bcb_metadata$bcb_category), "all")
  validate_dataset_params(table, valid_tables, cached, quiet, max_retries, allow_all = TRUE)

  # Validate and process date_start
  if (!inherits(date_start, "Date")) {
    # Try to convert to YYYY-MM-DD date
    date_start <- tryCatch(
      lubridate::ymd(date_start),
      error = function(e) {
        cli::cli_abort(c(
          "Invalid {.arg date_start} parameter",
          "x" = "{.arg date_start} must be a valid Date or string in YYYY-MM-DD format",
          "i" = "Example: {.val {'2010-01-01'}}"
        ))
      }
    )
  }

  # Get series codes from bcb_metadata ----
  # Filter series by table if not "all"
  if (table != "all") {
    # Get codes for requested table from metadata
    codes_bcb <- bcb_metadata |>
      dplyr::filter(.data$bcb_category == table) |>
      dplyr::pull(code_bcb)

    if (length(codes_bcb) == 0) {
      cli::cli_abort(c(
        "No series found for table '{table}'",
        "i" = "Valid tables: {paste(unique(bcb_metadata$bcb_category), collapse=', ')}"
      ))
    }

    if (!quiet) {
      cli::cli_inform("Selected {length(codes_bcb)} series for table '{table}'")
    }
  } else {
    # Get all series from metadata
    codes_bcb <- bcb_metadata$code_bcb

    if (!quiet) {
      cli::cli_inform("Selected {length(codes_bcb)} BCB series from metadata")
    }
  }

  # Handle cached data ----
  if (cached) {
    data <- handle_dataset_cache("bcb_series", table = NULL, quiet = quiet, on_miss = "download")

    if (!is.null(data)) {
      # Filter by codes and date
      data <- dplyr::filter(
        data,
        .data$code_bcb %in% codes_bcb,
        .data$date >= date_start
      )

      data <- attach_dataset_metadata(
        data,
        source = "cache",
        category = table,
        extra_info = list(series_count = length(codes_bcb), date_start = date_start)
      )
      return(data)
    }
  }

  # Download and process data ----
  if (!quiet) {
    cli::cli_inform("Downloading BCB series from API...")
  }

  # Download series with retry logic
  bcb_series <- import_bcb_series_robust(
    codes_bcb = codes_bcb,
    date_start = date_start,
    quiet = quiet,
    max_retries = max_retries,
    ...
  )

  if (!quiet) {
    cli::cli_inform("Processing BCB series data...")
  }

  # Join with metadata (rbcb already provides clean format)
  bcb_series <- dplyr::left_join(bcb_series, bcb_metadata, by = "code_bcb")

  # Add metadata attributes
  bcb_series <- attach_dataset_metadata(
    bcb_series,
    source = "web",
    category = table,
    extra_info = list(series_count = length(codes_bcb), date_start = date_start)
  )

  if (!quiet) {
    cli::cli_inform(
      "Successfully processed BCB series data with {nrow(bcb_series)} records"
    )
  }

  return(bcb_series)
}

#' Import BCB Series Data with Robust Error Handling
#'
#' Internal function to download BCB series data with retry logic.
#'
#' @param codes_bcb Vector of BCB series codes
#' @param date_start Start date for series
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#' @param ... Additional arguments passed to rbcb::get_series
#'
#' @return Downloaded BCB API data
#' @keywords internal
import_bcb_series_robust <- function(
  codes_bcb,
  date_start,
  quiet,
  max_retries,
  ...
) {
  # Use purrr::possibly for safe downloading (following get_cbic.R pattern)
  get_series_safe <- purrr::possibly(
    .f = function(code) {
      suppressMessages(
        rbcb::get_series(code = code, start_date = date_start, ...)
      )
    },
    otherwise = NULL,
    quiet = TRUE
  )

  # Download each series individually to handle partial failures gracefully
  results <- list()
  failed_series <- c()

  for (i in seq_along(codes_bcb)) {
    code <- codes_bcb[i]

    cli_debug("Downloading series {code} ({i}/{length(codes_bcb)})...")

    # Try download with retries for this specific series
    result <- NULL
    last_error <- NULL

    for (attempt in 1:(max_retries + 1)) {
      result <- tryCatch(
        {
          suppressMessages(
            rbcb::get_series(code = code, start_date = date_start, ...)
          )
        },
        error = function(e) {
          last_error <<- e$message
          NULL
        }
      )

      if (!is.null(result)) {
        break # Success!
      }

      # Retry with backoff
      if (attempt <= max_retries) {
        cli_debug("Series {code} failed (attempt {attempt}), retrying...")
        Sys.sleep(min(attempt * 0.5, 3))
      }
    }

    if (!is.null(result)) {
      # Success - process and collect
      # rbcb returns a single tibble for single series
      if (is.data.frame(result)) {
        # Rename value column (second column is always the value)
        result <- dplyr::rename(result, value = 2)
        result$code_bcb <- code
        results[[length(results) + 1]] <- result
      }
    } else {
      # Failed after all retries
      failed_series <- c(failed_series, code)
      cli_debug("Series {code} failed after {max_retries + 1} attempts")
    }
  }

  # Report results
  if (length(failed_series) > 0) {
    cli::cli_warn(c(
      "Failed to download {length(failed_series)} series after {max_retries + 1} attempts",
      "x" = "Failed series codes: {paste(failed_series, collapse=', ')}",
      "i" = "Returning {length(results)}/{length(codes_bcb)} successful series"
    ))
  }

  # Abort only if ALL series failed
  if (length(results) == 0) {
    cli::cli_abort(c(
      "Failed to download ANY BCB series data",
      "x" = "All {length(codes_bcb)} series failed",
      "i" = "Check your internet connection and BCB API status"
    ))
  }

  # Combine successful results
  combined <- dplyr::bind_rows(results)

  if (!quiet) {
    cli::cli_inform(
      "Successfully downloaded {length(results)}/{length(codes_bcb)} series"
    )
  }

  return(combined)
}
