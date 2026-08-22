#' Download macroeconomic time-series from BCB
#'
#' @details
#' Downloads macroeconomic time series from BCB. Series are organized by
#' relevance to the Brazilian real estate market using a four-level hierarchy.
#' The default ("core") returns the 40 most directly relevant series covering
#' real estate credit concession, interest rates, and delinquency. Use broader
#' levels to include macroeconomic context series.
#'
#' Each series is downloaded in full, from its first published observation to
#' the present. Filter the returned `date` column to restrict the window.
#'
#' @param table Character. Hierarchy level to return:
#'   \describe{
#'     \item{"core"}{Core real estate credit series (default, ~40 series).}
#'     \item{"primary"}{Core plus key macro series such as inflation rate (~59 series).}
#'     \item{"secondary"}{Primary plus broader macro context such as GDP, unemployment (~109 series).}
#'     \item{"tertiary"}{All series including less relevant and discontinued ones (~141 series).}
#'     \item{"full"}{Equivalent to "tertiary". Returns all available series.}
#'   }
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param max_retries Integer. Maximum retry attempts for failed API calls.
#'   Defaults to 3.
#'
#' @source Brazilian Central Bank (BCB) Time Series Management System (SGS)
#' @return A 4-column `tibble` with columns `date`, `code_bcb`,
#'   `name_simplified`, and `value`. Series metadata is available in
#'   \code{\link{bcb_metadata}}.
#'
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr rename select left_join filter pull bind_rows join_by
#' @importFrom purrr map possibly compact map_lgl
#' @importFrom rlang try_fetch
#' @keywords internal
get_bcb_series <- function(
  table = "core",
  quiet = FALSE,
  max_retries = 3L
) {
  hierarchy_levels <- c("core", "primary", "secondary", "tertiary", "full")
  validate_dataset_params(
    table,
    hierarchy_levels,
    quiet,
    max_retries,
    allow_all = TRUE
  )

  codes_bcb <- resolve_bcb_hierarchy(table)

  if (!quiet) {
    cli::cli_inform(
      "Selected {length(codes_bcb)} BCB series (table: {.val {table}})"
    )
  }

  if (!quiet) {
    cli::cli_inform("Downloading BCB series from API...")
  }

  bcb_series <- download_bcb_series(
    codes_bcb = codes_bcb,
    quiet = quiet,
    max_retries = max_retries
  )

  cols_select <- c("date", "code_bcb", "name_simplified", "value")

  bcb_series <- dplyr::left_join(
    bcb_series,
    realestatebr::bcb_metadata,
    by = dplyr::join_by(code_bcb)
  )
  bcb_series <- dplyr::select(bcb_series, dplyr::all_of(cols_select))

  bcb_series <- attach_dataset_metadata(
    bcb_series,
    source = "web",
    category = table,
    extra_info = list(series_count = length(codes_bcb))
  )

  if (!quiet) {
    cli::cli_inform(
      "Successfully downloaded {nrow(bcb_series)} observations"
    )
  }

  return(bcb_series)
}

# Resolve BCB Hierarchy -------------------------------------------------------

#' Resolve BCB Hierarchy Level to Series Codes
#'
#' Maps a hierarchy level name to a vector of BCB series codes. The levels
#' are cumulative: "primary" includes all "core" series, "secondary" includes
#' all "primary" series, and so on.
#'
#' @param table Character. One of "core", "primary", "secondary", "tertiary",
#'   "full", or "all".
#' @return Integer vector of BCB series codes.
#' @keywords internal
resolve_bcb_hierarchy <- function(table) {
  hierarchy_map <- c(
    "core" = 1L,
    "primary" = 2L,
    "secondary" = 3L,
    "tertiary" = 4L,
    "full" = 4L,
    "all" = 4L
  )

  max_level <- hierarchy_map[[table]]

  codes_bcb <- realestatebr::bcb_metadata |>
    dplyr::filter(.data$hierarchy <= max_level) |>
    dplyr::pull(.data$code_bcb)

  return(codes_bcb)
}

# SGS API ---------------------------------------------------------------------

# Fallback start date for series with no recorded first observation.
BCB_SERIES_FLOOR <- as.Date("1980-01-01")

#' Fetch a Single Series from the BCB SGS API
#'
#' Wraps `GetBCBData::gbcbd_get_series()`, which splits long spans into
#' windows the API accepts. SGS rejects requests covering more than ten years
#' of a daily series, so the split is what makes full history reachable.
#'
#' A window that returns no data yields a row with no reference date, which
#' happens for discontinued series whose last window falls after the final
#' observation. Those rows are dropped.
#'
#' @param code Numeric. BCB series code.
#' @param first_date Date. First period to request.
#'
#' @return A tibble with columns `date`, `value`, and `code_bcb`.
#' @keywords internal
fetch_sgs_series <- function(code, first_date) {
  # An empty window warns from the connection layer. Discontinued series warn
  # on every run, so the empty result below is the signal we act on.
  raw <- suppressWarnings(
    GetBCBData::gbcbd_get_series(
      id = code,
      first.date = first_date,
      last.date = Sys.Date(),
      be.quiet = TRUE,
      use.memoise = FALSE
    )
  )

  cols_rename <- c("date" = "ref.date", "code_bcb" = "id.num")
  cols_select <- c("date", "value", "code_bcb")

  series <- raw |>
    dplyr::rename(dplyr::any_of(cols_rename)) |>
    dplyr::select(dplyr::all_of(cols_select)) |>
    dplyr::filter(!is.na(.data$date))

  if (nrow(series) == 0) {
    cli::cli_abort("BCB series {code} returned no observations.")
  }

  return(series)
}

#' Look Up the First Observation Date of a Series
#'
#' Reads `first_value` from \code{\link{bcb_metadata}} so each series is
#' requested from its own start rather than a shared floor.
#'
#' @param code Numeric. BCB series code.
#'
#' @return A `Date`.
#' @keywords internal
bcb_series_first_date <- function(code) {
  metadata <- realestatebr::bcb_metadata
  first_date <- metadata$first_value[metadata$code_bcb == code]

  if (length(first_date) != 1 || is.na(first_date)) {
    return(BCB_SERIES_FLOOR)
  }

  return(first_date)
}

# Download BCB Series ---------------------------------------------------------

#' Download BCB Series Data
#'
#' Downloads BCB series data with per-series retry logic. Uses
#' `purrr::possibly()` to collect failures without aborting, then reports
#' any failed series after the full map completes.
#'
#' @param codes_bcb Vector of BCB series codes.
#' @param quiet Logical controlling messages.
#' @param max_retries Maximum number of retry attempts per series.
#'
#' @return A long-format tibble with columns `date`, `value`, and `code_bcb`.
#' @keywords internal
download_bcb_series <- function(
  codes_bcb,
  quiet,
  max_retries
) {
  safe_get <- purrr::possibly(
    function(code) {
      download_with_retry(
        fn = function() {
          result <- suppressMessages(
            fetch_sgs_series(code, bcb_series_first_date(code))
          )
          if (!is.data.frame(result)) {
            stop("result is not a data frame")
          }
          result
        },
        max_retries = max_retries,
        quiet = TRUE,
        desc = paste0("BCB series ", code)
      )
    },
    otherwise = NULL
  )

  results <- purrr::map(codes_bcb, function(code) {
    cli_debug("Downloading series {code}...")
    safe_get(code)
  })

  failed_codes <- codes_bcb[purrr::map_lgl(results, is.null)]

  if (length(failed_codes) > 0) {
    cli::cli_warn(c(
      "Failed to download {length(failed_codes)} series after {max_retries + 1} attempts",
      "x" = "Failed series codes: {paste(failed_codes, collapse = ', ')}",
      "i" = "Returning {length(codes_bcb) - length(failed_codes)}/{length(codes_bcb)} successful series"
    ))
  }

  successful <- purrr::compact(results)

  if (length(successful) == 0) {
    cli::cli_abort(c(
      "Failed to download ANY BCB series data",
      "x" = "All {length(codes_bcb)} series failed",
      "i" = "Check your internet connection and BCB API status"
    ))
  }

  combined <- dplyr::bind_rows(successful)

  if (!quiet) {
    cli::cli_inform(
      "Successfully downloaded {length(successful)}/{length(codes_bcb)} series"
    )
  }

  return(combined)
}
