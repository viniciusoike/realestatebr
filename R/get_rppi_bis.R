#' Get simplified RPPI data from BIS
#'
#' Download and import a simplified cross-country Residential Property Price
#' Indices (RPPI) panel data from the Bank for International Settlements (BIS).
#'
#' @details
#' This function is a wrapper around `get_bis_rppi_selected`. It simplifies the
#' output by filtering out observations prior to 1980. All index values are
#' centered in 2010. Both nominal and real series are available. Note that
#' Brazilian data becomes available only after 2001.
#'
#' The indexes follow the residential sales market in each country. Index
#' methodologies may not be comparable.
#' @inheritParams get_secovi
#' @return A cross-country `tibble` with RPPIs.
#' @export
#'
#' @examples
#' # Download data from the GitHub Repository
#' bis <- get_rppi_bis(cached = TRUE)
get_rppi_bis <- function(cached = FALSE) {

  # Either download the data from the GitHub repository or fetch from the BIS website
  if (cached) {
    # Use new unified architecture for cached data
    bis <- get_dataset("bis_rppi", source = "github", category = "selected")
  } else {
    bis <- get_bis_rppi_selected()
  }

  # Get only values from 1980 with non-NA values
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

  return(bis)

}
