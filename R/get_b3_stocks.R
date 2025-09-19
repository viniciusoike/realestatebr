#' Get Stock Prices
#'
#' Imports stock prices of Brazilian real estate players with modern error handling,
#' progress reporting, and robust download capabilities. Additionally, imports
#' some relevant financial indices.
#'
#' @details
#' Downloads and imports the stock values of the most relevant
#' real estate players in Brazil via `rb3` package which provides native
#' access to B3 (Brazilian stock exchange) data. A list of companies
#' can be found at `b3_real_estate`.
#'
#' This function now uses the `rb3` package for better reliability and 
#' to handle delisted companies gracefully, replacing the previous 
#' `quantmod`-based approach.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' about financial data downloads and processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed downloads and robust error
#' handling for financial data access operations.
#'
#' @param table Character. Which dataset to return: "stocks" (default) or "all".
#' @param category Character. Deprecated parameter name for backward compatibility.
#'   Use `table` instead.
#' @param cached Logical. If TRUE, loads data from package cache using the unified dataset architecture.
#' @param symbol Optional character string with the stock tickers symbols. If
#'   none is provided uses all symbols in `b3_real_estate`.
#' @param src Character string. Deprecated parameter for backward compatibility.
#'   Previously specified data source; now uses rb3 exclusively.
#' @param quiet Logical. If TRUE, suppresses progress messages and warnings.
#'   If FALSE (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   download operations. Defaults to 3.
#' @param ... Additional arguments (currently unused, kept for backward compatibility).
#'
#' @seealso [rb3::fetch_marketdata()], [rb3::cotahist_get()]
#'
#' @return A `tibble` containing stock prices for all companies.
#'   The tibble includes metadata attributes:
#'   \describe{
#'     \item{download_info}{List with download statistics}
#'     \item{source}{Data source used (web or cache)}
#'     \item{download_time}{Timestamp of download}
#'   }
#'
#' @export
#' @importFrom rb3 fetch_marketdata cotahist_get indexes_historical_data_get
#' @importFrom bizdays bizseq
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom stringr str_remove
#' @importFrom lubridate as_date year
#' @examples \dontrun{
#' # Get all available companies (with progress)
#' stocks <- get_b3_stocks(quiet = FALSE)
#'
#' # Get a specific company
#' cyrela <- get_b3_stocks(symbol = "CYRE3.SA", quiet = FALSE)
#'
#' # Use cached data for faster access
#' stocks <- get_b3_stocks(cached = TRUE)
#'
#' # Check download metadata
#' attr(stocks, "download_info")
#' }
get_b3_stocks <- function(
  table = "stocks",
  category = NULL,
  cached = FALSE,
  symbol = NULL,
  src = NULL,
  quiet = FALSE,
  max_retries = 3L,
  ...
) {
  # Input validation and backward compatibility ----
  valid_tables <- c("stocks", "all")

  # Handle backward compatibility: if category is provided, use it as table
  if (!is.null(category)) {
    cli::cli_warn(c(
      "Parameter {.arg category} is deprecated",
      "i" = "Use {.arg table} parameter instead",
      ">" = "This will be removed in a future version"
    ))
    table <- category
  }

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
  
  # Handle deprecated src parameter
  if (!is.null(src)) {
    cli::cli_warn(c(
      "Parameter {.arg src} is deprecated",
      "i" = "This function now uses rb3 exclusively for better reliability",
      ">" = "This parameter will be removed in a future version"
    ))
  }

  # Handle cached data ----
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading B3 stock data from cache...")
    }

    tryCatch({
      # Use new unified architecture for cached data
      stack <- get_dataset("b3_stocks", source = "github")

      if (!quiet) {
        cli::cli_inform(
          "Successfully loaded {nrow(stack)} B3 stock records from cache"
        )
      }

      # Add metadata
      attr(stack, "source") <- "cache"
      attr(stack, "download_time") <- Sys.time()
      attr(stack, "download_info") <- list(
        table = table,
        source = "cache"
      )

      return(stack)
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn(c(
          "Failed to load B3 data from cache: {e$message}",
          "i" = "Falling back to fresh download"
        ))
      }
    })
  }

  # Validate and prepare symbols ----
  if (is.null(symbol)) {
    # Get real estate companies symbols
    symbol <- b3_real_estate$symbol
    # Add relevant financial indices
    symbol <- c(symbol, "^BVSP", "^IBX50", "EWZ", "EEM", "DBC", "IFIX")
  } else {
    if (!is.character(symbol)) {
      cli::cli_abort("{.arg symbol} must be a character vector")
    }
    # Validate symbols against available options
    available_symbols <- c(b3_real_estate$symbol, "^BVSP", "^IBX50", "EWZ", "EEM", "DBC", "IFIX")
    if (!any(symbol %in% available_symbols)) {
      cli::cli_abort(c(
        "No valid symbols provided",
        "x" = "None of the provided symbols are available",
        "i" = "Available symbols in {.val b3_real_estate$symbol} and indices"
      ))
    }
  }

  # Download financial data using rb3 ----
  if (!quiet) {
    cli::cli_inform("Downloading {length(symbol)} financial series using rb3...")
  }

  attempts <- 0
  stack <- NULL

  while (attempts <= max_retries && is.null(stack)) {
    attempts <- attempts + 1

    tryCatch({
      # Setup rb3 environment
      cache_dir <- file.path(tempdir(), "realestatebr_rb3_cache")
      setup_rb3_environment(cache_dir = cache_dir, quiet = quiet)
      
      # Use rb3 to fetch data with appropriate date range
      end_date <- Sys.Date()
      start_date <- end_date - 365  # Default to 1 year of data
      
      stack <- fetch_b3_stocks_rb3(
        symbols = symbol,
        start_date = start_date,
        end_date = end_date,
        quiet = quiet,
        cache_dir = cache_dir
      )
      
    }, error = function(e) {
      if (attempts > max_retries) {
        cli::cli_abort(c(
          "Failed to download financial data after {max_retries} attempts",
          "x" = "Error: {e$message}",
          "i" = "Check your internet connection or try again later",
          "i" = "rb3 requires connection to B3 servers for data download"
        ))
      }

      if (!quiet) {
        cli::cli_warn("Download attempt {attempts} failed, retrying...")
      }

      # Exponential backoff
      Sys.sleep(min(attempts * 1, 5))
    })
  }

  if (is.null(stack)) {
    cli::cli_abort("Failed to download any data after all retry attempts")
  }

  if (!quiet) {
    cli::cli_inform("Financial data download complete using rb3")
  }

  # Add metadata attributes ----
  attr(stack, "source") <- "web"
  attr(stack, "download_time") <- Sys.time()
  attr(stack, "download_info") <- list(
    table = table,
    total_records = nrow(stack),
    symbols_downloaded = length(symbol),
    retry_attempts = attempts,
    source = "rb3",
    data_provider = "B3 (Brasil Bolsa Balcão)"
  )

  if (!quiet) {
    cli::cli_inform("Successfully processed {nrow(stack)} stock price records")
  }

  return(stack)
}
