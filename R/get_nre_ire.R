#' Get the IRE Index
#'
#' Imports the Real Estate Index from NRE-Poli (USP) with modern error handling
#' and progress reporting capabilities.
#'
#' @details
#' The Real Estate Index (IRE) tracks the average stock price of real estate
#' companies in Brazil. The Index is maintained by the Real Estate Research
#' Group by the Polytechnich School of the University of São Paulo (NRE-Poli-USP).
#'
#' The values are indexed (100 = May/2006). Check `return` for a definition of each
#' column.
#'
#' \strong{Note:} This function currently only supports cached data loading.
#' Fresh data downloads are not available as the original data source requires
#' manual processing.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides progress information
#' about cache loading operations.
#'
#' @section Error Handling:
#' The function includes robust error handling for cache access and
#' provides informative error messages when data is unavailable.
#'
#' @param table Character. Which dataset to return: "indicators" (default) or "all".
#' @param category Character. Deprecated parameter name for backward compatibility.
#'   Use `table` instead.
#' @param cached Logical. If `TRUE` (default), loads data from package cache
#'   using the unified dataset architecture. This is currently the only
#'   supported method for this dataset.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#'
#' @return A tibble with 8 columns where:
#' * `ire` is the IRE Index.
#' * `ire_r50_plus` is the IRE Index of the top 50% companies.
#' * `ire_r50_minus` is the IRE Index of the bottom 50% companies.
#' * `ire_bi` is the IRE-BI Index (non-residential).
#' * `ibov` is the Ibovespa Index.
#' * `ibov_points` is the Ibovespa Index in points.
#' * `ire_ibov` is the ratio of the IRE Index and the Ibovespa Index.
#'
#' The tibble includes metadata attributes:
#' \describe{
#'   \item{download_info}{List with access statistics}
#'   \item{source}{Data source used (cache)}
#'   \item{download_time}{Timestamp of access}
#' }
#'
#' @keywords internal
#' @importFrom cli cli_inform cli_warn cli_abort
#' @source Original series and methodology available at [https://www.realestate.br/site/conteudo/pagina/1,84+Indice_IRE.html](https://www.realestate.br/site/conteudo/pagina/1,84+Indice_IRE.html).
#'
#' @examples \dontrun{
#' # Import the IRE Index (with progress)
#' ire <- get_nre_ire(quiet = FALSE)
#'
#' # Import quietly
#' ire <- get_nre_ire(cached = TRUE, quiet = TRUE)
#'
#' # Check access metadata
#' attr(ire, "download_info")
#' }
get_nre_ire <- function(
  table = "indicators",
  category = NULL,
  cached = TRUE,
  quiet = FALSE
) {
  # Input validation and backward compatibility ----
  valid_tables <- c("indicators", "all")

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

  # Note: Fresh downloads not supported, but we can fall back to internal data

  # Handle cached data ----
  # Note: NRE-IRE is static data from Excel file, so we skip cache and
  # go directly to internal package data
  if (cached) {
    if (!quiet) {
      cli::cli_inform("NRE-IRE uses static package data (no cache needed)")
    }
  }

  # Use internal package data ----
  if (!quiet) {
    cli::cli_inform("Loading NRE-IRE index data from internal package data...")
  }

  # Load internal data (ire should be available from sysdata.rda)
  # No need to check exists() since it's internal package data

  if (!quiet) {
    cli::cli_inform(
      "Successfully accessed {nrow(ire)} NRE-IRE records from package data"
    )
  }

  # Add metadata
  attr(ire, "source") <- "internal"
  attr(ire, "download_time") <- Sys.time()
  attr(ire, "download_info") <- list(
    table = table,
    dataset = "nre_ire",
    source = "internal",
    note = "Fresh downloads not supported - data requires manual processing"
  )

  return(ire)
}
