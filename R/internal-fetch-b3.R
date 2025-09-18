#' Internal function to fetch B3 real estate stocks data
#'
#' Fetches stock market data for real estate companies and REITs listed on B3
#' (Brasil Bolsa Balcão).
#'
#' @param table Character. Currently supports "all" (default)
#' @param cached Logical. Use cache if available
#' @param quiet Logical. Suppress progress messages
#' @param max_retries Integer. Maximum retry attempts
#' @param ... Additional parameters
#'
#' @return Dataset as tibble
#' @keywords internal
fetch_b3 <- function(table = "all", cached = FALSE, quiet = FALSE,
                     max_retries = 3L, ...) {

  # Validate inputs ----
  valid_tables <- c("all")

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
    cli::cli_abort("{.arg max_retries} must be a positive number")
  }

  # Handle cached data ----
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading B3 stocks data from cache...")
    }

    tryCatch({
      data <- import_cached("b3_stocks")

      if (!quiet) {
        cli::cli_inform("Successfully loaded B3 stocks data from cache")
      }

      # Add metadata
      attr(data, "source") <- "cache"
      attr(data, "download_time") <- Sys.time()
      attr(data, "download_info") <- list(
        source = "cache",
        table = table
      )

      return(data)
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn(c(
          "Failed to load cached data: {e$message}",
          "i" = "Falling back to fresh download"
        ))
      }
    })
  }

  # Download fresh data ----
  if (!quiet) {
    cli::cli_inform("Downloading B3 stocks data from API...")
  }

  # Call the existing get_b3_stocks function for now
  # This will be replaced with direct API calls in the final implementation
  result <- tryCatch({
    get_b3_stocks(
      cached = FALSE,
      quiet = quiet,
      max_retries = max_retries
    )
  }, error = function(e) {
    cli::cli_abort("Failed to download B3 stocks data: {e$message}")
  })

  # Add metadata
  attr(result, "source") <- "api"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    table = table,
    retry_attempts = 0,
    source = "b3_api"
  )

  return(result)
}