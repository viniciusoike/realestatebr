#' Get the IRE Index (DEPRECATED)
#'
#' @description
#' Deprecated since v0.4.0. Use \code{\link{get_dataset}}("nre_ire") instead.
#' Loads the Real Estate Index (IRE) from NRE-Poli (USP) tracking average stock
#' prices of real estate companies in Brazil.
#'
#' @param table Character. Which dataset to return: "indicators" (default) or "all".
#' @param cached Logical. If `TRUE` (default), loads data from cache.
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#'
#' @return Tibble with NRE-IRE index data. Includes metadata attributes:
#'   source, download_time.
#'
#' @source \url{https://www.realestate.br/site/conteudo/pagina/1,84+Indice_IRE.html}
#' @keywords internal
get_nre_ire <- function(
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
    ire_data <- handle_dataset_cache(
      "nre_ire",
      table = NULL,
      quiet = quiet,
      on_miss = "error"
    )

    if (!is.null(ire_data)) {
      ire_data <- attach_dataset_metadata(ire_data, source = "cache", category = table)
      return(ire_data)
    }
  }

  # Fresh downloads not supported ----
  cli::cli_abort(c(
    "Fresh downloads not supported for NRE-IRE data",
    "x" = "NRE-IRE data requires manual processing from the source website",
    "i" = "Use {.code cached = TRUE} to access the most recent cached data",
    "i" = "Or use {.code get_dataset('nre_ire')} which automatically uses cache"
  ))
}
