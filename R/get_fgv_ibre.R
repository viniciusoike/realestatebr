#' Get FGV IBRE Confidence Indicators (DEPRECATED)
#'
#' @description
#' Deprecated since v0.4.0. Use \code{\link{get_dataset}}("fgv_ibre") instead.
#' Loads construction confidence indicators from FGV IBRE including confidence
#' indices, expectation indicators, and INCC price indices.
#'
#' @param table Character. Which dataset to return: "indicators" (default) or "all".
#' @param cached Logical. If `TRUE` (default), loads data from cache.
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#'
#' @return Tibble with FGV IBRE indicators. Includes metadata attributes:
#'   source, download_time.
#'
#' @keywords internal
get_fgv_ibre <- function(
  table = "indicators",
  cached = TRUE,
  quiet = FALSE
) {
  # Input validation ----
  valid_tables <- c("indicators")

  validate_dataset_params(
    table,
    valid_tables,
    cached,
    quiet,
    max_retries = 3,
    allow_all = TRUE
  )

  # Handle cached data ----
  if (cached) {
    fgv_data <- handle_dataset_cache(
      "fgv_ibre",
      table = NULL,
      quiet = quiet,
      on_miss = "error"
    )

    if (!is.null(fgv_data)) {
      fgv_data <- attach_dataset_metadata(fgv_data, source = "cache", category = table)
      return(fgv_data)
    }
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