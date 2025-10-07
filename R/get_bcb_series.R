#' Download macroeconomic time-series from BCB
#'
#' Download a compilation of macroeconomic time series data from the Brazilian
#' Central Bank with modern error handling, progress reporting, and robust API access.
#'
#' @details
#' This function downloads macroeconomic indicators from the BCB based on the
#' series defined in the `bcb_metadata` dataset. The series cover various
#' categories relevant for real estate analysis, including price indices,
#' interest rates, credit indicators, production metrics, and more.
#'
#' The default value for `date_start` is January 2010. While arbitrary, I advise
#' against setting `date_start` to dates prior to July 1994. To download all
#' available data the user can set a date such as `as.Date("1900-01-01)`.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including BCB API access status and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed BCB API calls and robust
#' error handling for metadata processing and data validation.
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
#'
#' @examples \dontrun{
#' # Get price indicators (with progress)
#' prices <- get_bcb_series(table = "price", quiet = FALSE)
#'
#' # Get all series
#' bcb_series <- get_bcb_series(date_start = as.Date("2020-01-01"))
#'
#' # Use cached data for faster access
#' cached_data <- get_bcb_series(cached = TRUE)
#'
#' # Check download metadata
#' attr(prices, "download_info")
#' }
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

  if (!is.character(table) || length(table) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg table} parameter",
      "x" = "{.arg table} must be a single character string",
      "i" = "Valid tables: {.val {valid_tables}}"
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
      dplyr::filter(bcb_category == table) |>
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
    if (!quiet) {
      cli::cli_inform("Loading BCB series data from cache...")
    }

    tryCatch(
      {
        # Use new unified architecture for cached data
        bcb_series <- get_dataset(
          "bcb_series",
          source = "github",
          date_start = date_start
        )
        bcb_series <- dplyr::filter(
          bcb_series,
          code_bcb %in% codes_bcb,
          date >= date_start
        )

        if (!quiet) {
          cli::cli_inform(
            "Successfully loaded {nrow(bcb_series)} BCB records from cache"
          )
        }

        # Add metadata
        attr(bcb_series, "source") <- "cache"
        attr(bcb_series, "download_time") <- Sys.time()
        attr(bcb_series, "download_info") <- list(
          table = table,
          series_count = length(codes_bcb),
          date_start = date_start,
          source = "cache"
        )

        return(bcb_series)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load cached data: {e$message}",
            "i" = "Falling back to fresh download from BCB API"
          ))
        }
      }
    )
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
  attr(bcb_series, "source") <- "api"
  attr(bcb_series, "download_time") <- Sys.time()
  attr(bcb_series, "download_info") <- list(
    table = table,
    series_count = length(codes_bcb),
    date_start = date_start,
    source = "api"
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
