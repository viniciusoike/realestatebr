#' Get FGV Confidence Indicators
#'
#' Download and clean construction confidence indicators estimated and released
#' by the Getúlio Vargas Foundation (FGV) with modern error handling and
#' progress reporting capabilities.
#'
#' @details
#' This function provides access to construction confidence indicators from FGV,
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
#' @param category Character. Deprecated parameter name for backward compatibility.
#'   Use `table` instead.
#' @param cached Logical. If `TRUE` (default), loads data from package cache
#'   using the unified dataset architecture. If `FALSE`, uses internal
#'   package data objects.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#'
#' @return A `tibble` containing all construction confidence indicator series from FGV.
#'   The tibble includes metadata attributes:
#'   \describe{
#'     \item{download_info}{List with access statistics}
#'     \item{source}{Data source used (cache or internal)}
#'     \item{download_time}{Timestamp of access}
#'   }
#'
#' @keywords internal
#' @importFrom cli cli_inform cli_warn cli_abort
#'
#' @examples \dontrun{
#' # Get FGV indicators from cache (with progress)
#' fgv <- get_fgv_indicators(quiet = FALSE)
#'
#' # Use internal package data
#' fgv <- get_fgv_indicators(cached = FALSE)
#'
#' # Check access metadata
#' attr(fgv, "download_info")
#' }
get_fgv_indicators <- function(
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

  # Handle cached data ----
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading FGV indicators from cache...")
    }

    tryCatch(
      {
        # Use new unified architecture for cached data
        fgv_data <- get_dataset("fgv_indicators", source = "github")

        if (!quiet) {
          cli::cli_inform(
            "Successfully loaded {nrow(fgv_data)} FGV indicator records from cache"
          )
        }

        # Add metadata
        attr(fgv_data, "source") <- "cache"
        attr(fgv_data, "download_time") <- Sys.time()
        attr(fgv_data, "download_info") <- list(
          table = table,
          dataset = "fgv_indicators",
          source = "cache"
        )

        return(fgv_data)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load FGV data from cache: {e$message}",
            "i" = "Falling back to internal package data"
          ))
        }
      }
    )
  }

  # Use internal package data ----
  if (!quiet) {
    cli::cli_inform("Loading FGV indicators from internal package data...")
  }

  # Check for required data dependencies
  if (!exists("fgv_data")) {
    cli::cli_abort(c(
      "Required data dependency not available",
      "x" = "This function requires the {.pkg fgv_data} object",
      "i" = "Please ensure all package data is properly loaded",
      "i" = "Try using {.code cached = TRUE} to access cached data instead"
    ))
  }

  if (!quiet) {
    cli::cli_inform(
      "Successfully accessed {nrow(fgv_data)} FGV indicator records from package data"
    )
  }

  # Add metadata
  attr(fgv_data, "source") <- "internal"
  attr(fgv_data, "download_time") <- Sys.time()
  attr(fgv_data, "download_info") <- list(
    table = table,
    dataset = "fgv_indicators",
    source = "internal",
    note = "Fresh downloads not supported - using package data"
  )

  return(fgv_data)
}

fgv_dict <- data.frame(
  id_series = 1:15,
  code_series = c(
    1463201, 1463202, 1463203, 1463204, 1463205, 1428409, 1416233, 1416234, 1416232,
    1464783, 1465235, 1464331, 1000379, 1000366, 1000370
  ),
  name_series = c(
    "Índice de Variação de Aluguéis Residenciais (IVAR) - Média Nacional",
    "Índice de Variação de Aluguéis Residenciais (IVAR) - São Paulo",
    "Índice de Variação de Aluguéis Residenciais (IVAR) - Rio de Janeiro",
    "Índice de Variação de Aluguéis Residenciais (IVAR) - Belo Horizonte",
    "Índice de Variação de Aluguéis Residenciais (IVAR) - Porto Alegre",
    "Sondagem da Construção – Nível de Utilização da Capacidade Instalada",
    "IE-CST Com ajuste Sazonal - Índice de Expectativas da Construção",
    "ISA-CST Com ajuste Sazonal - Índice da Situação Atual da Construção",
    "ICST Com ajuste Sazonal - Índice de Confiança da Construção",
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
    "Indicador", "Indicador", "Índice", "Índice", "Índice", "Percentual",
    "Percentual", "Percentual"
  )
)
