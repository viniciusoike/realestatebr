#' Internal function to fetch NRE-IRE real estate index
#'
#' Fetches Real Estate Index tracking average stock prices of Brazilian
#' real estate companies from NRE-Poli-USP.
#'
#' @param table Character. Currently supports "all" (default)
#' @param cached Logical. Use cache if available
#' @param quiet Logical. Suppress progress messages
#' @param max_retries Integer. Maximum retry attempts (not used for static data)
#' @param ... Additional parameters
#'
#' @return Dataset as tibble
#' @keywords internal
fetch_nre <- function(table = "all", cached = FALSE, quiet = FALSE,
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

  # Handle cached data ----
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading NRE-IRE index data from cache...")
    }

    tryCatch({
      data <- import_cached("ire")

      if (!quiet) {
        cli::cli_inform("Successfully loaded NRE-IRE index data from cache")
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
          "i" = "Falling back to package data"
        ))
      }
    })
  }

  # Use package data (cached_only dataset) ----
  if (!quiet) {
    cli::cli_inform("Loading NRE-IRE index data from package...")
  }

  # Call the existing get_nre_ire function for now
  # This dataset is cached_only so it uses internal package data
  result <- tryCatch({
    get_nre_ire(
      cached = TRUE,
      quiet = quiet
    )
  }, error = function(e) {
    cli::cli_abort("Failed to load NRE-IRE index data: {e$message}")
  })

  # Add metadata
  attr(result, "source") <- "package"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    table = table,
    source = "package_data",
    cached_only = TRUE
  )

  return(result)
}