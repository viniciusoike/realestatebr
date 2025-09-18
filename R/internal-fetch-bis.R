#' Internal function to fetch BIS residential property price indices
#'
#' Fetches international residential property price indices from Bank for International Settlements
#' including both selected series for major countries and detailed dataset.
#'
#' @param table Character. Specific table to fetch:
#'   - "selected": Core RPPI series for major countries
#'   - "detailed": Full RPPI dataset with all available series
#'   - "all": Both datasets as a list (default)
#' @param cached Logical. Use cache if available
#' @param quiet Logical. Suppress progress messages
#' @param max_retries Integer. Maximum retry attempts
#' @param ... Additional parameters
#'
#' @return Dataset as tibble (single table) or list (table = "all")
#' @keywords internal
fetch_bis <- function(table = "selected", cached = FALSE, quiet = FALSE,
                      max_retries = 3L, ...) {

  # Validate inputs ----
  valid_tables <- c("selected", "detailed", "all")

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
      cli::cli_inform("Loading BIS RPPI data from cache...")
    }

    tryCatch({
      if (table == "all") {
        data <- list(
          selected = import_cached("bis_selected"),
          detailed = import_cached("bis_detailed")
        )
      } else if (table == "selected") {
        data <- import_cached("bis_selected")
      } else if (table == "detailed") {
        data <- import_cached("bis_detailed")
      }

      if (!quiet) {
        cli::cli_inform("Successfully loaded BIS RPPI data from cache")
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
    cli::cli_inform("Downloading BIS RPPI data from API...")
  }

  # Call the existing get_bis_rppi function for now
  # This will be replaced with direct API calls in the final implementation
  result <- tryCatch({
    get_bis_rppi(
      table = table,
      cached = FALSE,
      quiet = quiet,
      max_retries = max_retries
    )
  }, error = function(e) {
    cli::cli_abort("Failed to download BIS RPPI data: {e$message}")
  })

  # Add metadata
  attr(result, "source") <- "api"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    table = table,
    retry_attempts = 0,
    source = "bis_api"
  )

  return(result)
}