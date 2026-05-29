#' RPPI Helper Functions
#'
#' Internal helper functions to reduce code duplication in RPPI functions.
#' These are not exported and only used internally.
#'
#' @name rppi_helpers
#' @keywords internal
NULL

#' Calculate RPPI Changes
#'
#' Adds month-on-month (chg) and year-on-year (acum12m) change columns.
#'
#' @param data Data frame with index values
#' @param index_col Name of the index column
#' @param group_col Optional grouping column for panel data
#' @return Data with chg and acum12m columns added
#' @keywords internal
#' @noRd
calculate_rppi_changes <- function(
  data,
  index_col = "index",
  group_col = NULL
) {
  data <- data |>
    dplyr::mutate(
      chg = .data[[index_col]] / dplyr::lag(.data[[index_col]]) - 1,
      acum12m = exp(as.numeric(stats::filter(
        log(1 + chg),
        rep(1, 12),
        sides = 1
      ))) -
        1,
      .by = dplyr::all_of(group_col)
    )

  return(data)
}
