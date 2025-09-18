#' Internal function to fetch BCB real estate market data
#'
#' Fetches comprehensive real estate credit and market data from Brazilian Central Bank
#' including credit sources, applications, operations, financed units, and indices.
#'
#' @param table Character. Specific table to fetch:
#'   - "accounting": Credit accounting and balance sheet data
#'   - "application": Credit application statistics and approvals
#'   - "indices": Various real estate market indices
#'   - "sources": Breakdown of credit sources and funding
#'   - "units": Number and value of financed units
#'   - "all": All tables as combined dataset (default)
#' @param cached Logical. Use cache if available
#' @param quiet Logical. Suppress progress messages
#' @param max_retries Integer. Maximum retry attempts
#' @param ... Additional parameters
#'
#' @return Dataset as tibble
#' @keywords internal
fetch_bcb_realestate <- function(table = "all", cached = FALSE, quiet = FALSE,
                                 max_retries = 3L, ...) {

  # Validate inputs ----
  valid_tables <- c("accounting", "application", "indices", "sources", "units", "all")

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
      cli::cli_inform("Loading BCB real estate data from cache...")
    }

    tryCatch({
      data <- import_cached("bcb_realestate")

      if (!quiet) {
        cli::cli_inform("Successfully loaded BCB real estate data from cache")
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
    cli::cli_inform("Downloading BCB real estate data from API...")
  }

  # Call the existing get_bcb_realestate function for now
  # This will be replaced with direct API calls in the final implementation
  result <- tryCatch({
    get_bcb_realestate(
      category = table,
      cached = FALSE,
      quiet = quiet,
      max_retries = max_retries
    )
  }, error = function(e) {
    cli::cli_abort("Failed to download BCB real estate data: {e$message}")
  })

  # Add metadata
  attr(result, "source") <- "api"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    table = table,
    retry_attempts = 0,
    source = "bcb_api"
  )

  return(result)
}

#' Internal function to fetch BCB economic series data
#'
#' Fetches general economic and real estate related time series from Brazilian Central Bank
#' including price indices, credit indicators, and economic activity measures.
#'
#' @param table Character. Specific table to fetch:
#'   - "price": Price indices and inflation measures
#'   - "credit": Credit market indicators
#'   - "activity": Economic activity indicators
#'   - "all": All series as combined dataset (default)
#' @param cached Logical. Use cache if available
#' @param quiet Logical. Suppress progress messages
#' @param max_retries Integer. Maximum retry attempts
#' @param date_start Date. Start date for series download
#' @param ... Additional parameters
#'
#' @return Dataset as tibble
#' @keywords internal
fetch_bcb_series <- function(table = "all", cached = FALSE, quiet = FALSE,
                             max_retries = 3L, date_start = as.Date("2010-01-01"), ...) {

  # Validate inputs ----
  valid_tables <- c("price", "credit", "activity", "all")

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

  if (!inherits(date_start, "Date")) {
    cli::cli_abort("{.arg date_start} must be a Date object")
  }

  # Handle cached data ----
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading BCB series data from cache...")
    }

    tryCatch({
      data <- import_cached("bcb_series")

      if (!quiet) {
        cli::cli_inform("Successfully loaded BCB series data from cache")
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
    cli::cli_inform("Downloading BCB series data from API...")
  }

  # Call the existing get_bcb_series function for now
  # This will be replaced with direct API calls in the final implementation
  result <- tryCatch({
    get_bcb_series(
      table = table,
      cached = FALSE,
      quiet = quiet,
      max_retries = max_retries,
      date_start = date_start,
      ...
    )
  }, error = function(e) {
    cli::cli_abort("Failed to download BCB series data: {e$message}")
  })

  # Add metadata
  attr(result, "source") <- "api"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    table = table,
    retry_attempts = 0,
    source = "bcb_api",
    date_start = date_start
  )

  return(result)
}