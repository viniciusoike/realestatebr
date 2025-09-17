#' Get simplified RPPI data from BIS
#'
#' Download and import a simplified cross-country Residential Property Price
#' Indices (RPPI) panel data from the Bank for International Settlements (BIS).
#'
#' @details
#' \strong{Deprecation Notice:} This function is deprecated in favor of
#' `get_bis_rppi(category = "selected")` which provides the same functionality
#' with modern error handling and progress reporting. This wrapper is maintained
#' for backward compatibility but will be removed in a future version.
#'
#' This function is a wrapper around `get_bis_rppi()`. It simplifies the
#' output by filtering out observations prior to 1980. All index values are
#' centered in 2010. Both nominal and real series are available. Note that
#' Brazilian data becomes available only after 2001.
#'
#' The indexes follow the residential sales market in each country. Index
#' methodologies may not be comparable.
#'
#' @param cached Logical. If `TRUE`, attempts to load data from package cache.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#' @param max_retries Integer. Maximum number of retry attempts.
#'
#' @return A cross-country `tibble` with RPPIs.
#' @export
#'
#' @examples \dontrun{
#' # Download data from the GitHub Repository
#' bis <- get_rppi_bis(cached = TRUE)
#'
#' # Recommended: Use the modern function instead
#' bis <- get_bis_rppi(category = "selected", cached = TRUE)
#' }
get_rppi_bis <- function(
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Deprecation warning
  if (!quiet) {
    cli::cli_warn(c(
      "{.fn get_rppi_bis} is deprecated",
      "i" = "Use {.fn get_bis_rppi}(category = \"selected\") instead",
      "i" = "This function will be removed in a future version"
    ))
  }

  # Use the modernized get_bis_rppi function
  bis <- get_bis_rppi(
    table = "selected",
    cached = cached,
    quiet = quiet,
    max_retries = max_retries
  )

  # Apply the legacy filtering and transformations
  bis <- bis |>
    dplyr::filter(
      unit == "Index, 2010 = 100",
      date >= as.Date("1980-01-01"),
      !is.na(value)
    ) |>
    dplyr::select(
      date, code, country = reference_area, is_nominal, index = value
    )

  # Compute MoM and YoY percent changes by group
  bis <- bis |>
    dplyr::group_by(code) |>
    dplyr::mutate(
      chg = index / dplyr::lag(index) - 1,
      acum12m = zoo::rollapplyr(1 + chg, width = 12, FUN = prod, fill = NA) - 1
    ) |>
    dplyr::ungroup()

  # Preserve metadata from the underlying function
  attr(bis, "deprecated") <- TRUE
  attr(bis, "replacement") <- "get_bis_rppi(category = 'selected')"

  return(bis)
}
