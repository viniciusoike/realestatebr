#' Get FGV IBRE Confidence Indicators
#'
#' Download and clean construction confidence indicators estimated and released
#' by the Getulio Vargas Foundation (FGV IBRE) with modern error handling and
#' progress reporting capabilities.
#'
#' @details
#' This function provides access to construction confidence indicators from FGV IBRE,
#' including confidence indices, expectation indicators, and INCC price indices.
#' The function supports both cached data access and fallback to package data.
#'
#' \strong{Note:} Fresh data downloads from FGV APIs are not currently supported.
#' The function accesses cached data or internal package data objects.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides progress information
#' about data access operations.
#'
#' @section Error Handling:
#' The function includes robust error handling for data access and
#' provides informative error messages when data is unavailable.
#'
#' @param table Character. Which dataset to return: "indicators" (default) or "all".
#' @param cached Logical. If `TRUE` (default), loads data from package cache
#'   using the unified dataset architecture. If `FALSE`, uses internal
#'   package data objects.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#'
#' @return A `tibble` containing all construction confidence indicator series from FGV IBRE.
#'   The tibble includes metadata attributes:
#'   \describe{
#'     \item{download_info}{List with access statistics}
#'     \item{source}{Data source used (cache or internal)}
#'     \item{download_time}{Timestamp of access}
#'   }
#'
#' @importFrom cli cli_inform cli_warn cli_abort
#'
#' @examples \dontrun{
#' # Get FGV IBRE indicators from cache (with progress)
#' fgv <- get_fgv_ibre(quiet = FALSE)
#'
#' # Use internal package data
#' fgv <- get_fgv_ibre(cached = FALSE)
#'
#' # Check access metadata
#' attr(fgv, "download_info")
#' }
get_fgv_ibre <- function(
  table = "indicators",
  cached = TRUE,
  quiet = FALSE
) {
  # Input validation and backward compatibility ----
  valid_tables <- c("indicators", "all")


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
    cli_debug("Loading FGV IBRE indicators from cache...")

    # Use new unified architecture for cached data
    fgv_data <- get_dataset("fgv_ibre", source = "github")

    cli_debug("Successfully loaded {nrow(fgv_data)} FGV IBRE indicator records from cache")

    # Add metadata
    attr(fgv_data, "source") <- "cache"
    attr(fgv_data, "download_time") <- Sys.time()
    attr(fgv_data, "download_info") <- list(
      table = table,
      dataset = "fgv_ibre",
      source = "cache"
    )

    return(fgv_data)
  }

  # Fresh downloads not supported ----
  cli::cli_abort(c(
    "Fresh downloads not supported for FGV IBRE data",
    "x" = "FGV data is not accessible via API and requires manual updates",
    "i" = "Use {.code cached = TRUE} to access the most recent cached data",
    "i" = "Or use {.code get_dataset('fgv_ibre')} which automatically uses cache"
  ))
}

fgv_dict <- data.frame(
  id_series = 1:15,
  code_series = c(
    1463201, 1463202, 1463203, 1463204, 1463205, 1428409, 1416233, 1416234, 1416232,
    1464783, 1465235, 1464331, 1000379, 1000366, 1000370
  ),
  name_series = c(
    "\u00cdndice de Varia\u00e7\u00e3o de Alugu\u00e9is Residenciais (IVAR) - M\u00e9dia Nacional",
    "\u00cdndice de Varia\u00e7\u00e3o de Alugu\u00e9is Residenciais (IVAR) - S\u00e3o Paulo",
    "\u00cdndice de Varia\u00e7\u00e3o de Alugu\u00e9is Residenciais (IVAR) - Rio de Janeiro",
    "\u00cdndice de Varia\u00e7\u00e3o de Alugu\u00e9is Residenciais (IVAR) - Belo Horizonte",
    "\u00cdndice de Varia\u00e7\u00e3o de Alugu\u00e9is Residenciais (IVAR) - Porto Alegre",
    "Sondagem da Constru\u00e7\u00e3o \u2013 N\u00edvel de Utiliza\u00e7\u00e3o da Capacidade Instalada",
    "IE-CST Com ajuste Sazonal - \u00cdndice de Expectativas da Constru\u00e7\u00e3o",
    "ISA-CST Com ajuste Sazonal - \u00cdndice da Situa\u00e7\u00e3o Atual da Constru\u00e7\u00e3o",
    "ICST Com ajuste Sazonal - \u00cdndice de Confian\u00e7a da Constru\u00e7\u00e3o",
    "INCC - Brasil - DI",
    "INCC - Brasil",
    "INCC - Brasil-10",
    "INCC - 1o Decendio",
    "INCC - 2o Decendio",
    "INCC - Fechamento Mensal"
  ),
  source = c(
    "FGV", "FGV", "FGV", "FGV", "FGV", "FGV", "FGV-SONDA", "FGV-SONDA", "FGV-SONDA",
    "FGV-INCC", "FGV-INCC", "FGV-INCC", "FGV-INCC", "FGV-INCC", "FGV-INCC"
  ),
  unit = c(
    "Indice", "Indice", "Indice", "Indice", "Indice", "Percentual", "Indicador",
    "Indicador", "Indicador", "\u00cdndice", "\u00cdndice", "\u00cdndice", "Percentual",
    "Percentual", "Percentual"
  )
)