#' Internal function to fetch FGV real estate indicators
#'
#' Fetches real estate market indicators from Fundação Getulio Vargas (FGV IBRE)
#' including various economic indicators related to real estate markets.
#'
#' @param table Character. Currently supports "all" (default)
#' @param cached Logical. Use cache if available
#' @param quiet Logical. Suppress progress messages
#' @param max_retries Integer. Maximum retry attempts
#' @param ... Additional parameters
#'
#' @return Dataset as tibble
#' @keywords internal
fetch_fgv <- function(table = "all", cached = FALSE, quiet = FALSE,
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
      cli::cli_inform("Loading FGV indicators data from cache...")
    }

    tryCatch({
      data <- import_cached("fgv_indicators")

      if (!quiet) {
        cli::cli_inform("Successfully loaded FGV indicators data from cache")
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
    cli::cli_inform("Downloading FGV indicators data from website...")
  }

  # Call the existing get_fgv_indicators function for now
  # This will be replaced with direct API calls in the final implementation
  result <- tryCatch({
    get_fgv_indicators(
      cached = FALSE,
      quiet = quiet,
      max_retries = max_retries
    )
  }, error = function(e) {
    cli::cli_abort("Failed to download FGV indicators data: {e$message}")
  })

  # Add metadata
  attr(result, "source") <- "web"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    table = table,
    retry_attempts = 0,
    source = "fgv_website"
  )

  return(result)
}