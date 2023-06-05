#' Download macroeconomic time-series from BCB.
#'
#' Download a compilation of macroeconomic time series data from the Brazilian
#' Central Bank.
#'
#' @details
#' Using default settings, this function downloads 140 key macroeconomic indicators
#' such as prices indices, interest rates, credit indicators, etc. The full list
#' of variables is gathered in the `bcb_metadata` table.
#'
#' A subset of the variables can be imported using the `category` argument. The
#' available categories are: `'credit'`, `'exchange'`, `'government'`,
#' `'interest-rate'`, `'real-estate'`,`'price'`, and `'production'`.
#'
#' The default value for `date_start` is January 2010. While arbitrary, I advise
#' against setting `date_start` to dates prior to July 1994. To download all
#' available data the user can set a date such as `as.Date("1900-01-01)`.
#'
#' @param category Defaults to `'all'`. See `details` for more options.
#' @param cached Logical indicating
#' @param date_start A `Date` argument indicating the first period to extract
#' from the time series. Defaults to 2010-01-01.
#' @param ... Additional arguments passed to `GetBCBData::gbcbd_get_series`.
#'
#' @return A 12-column `tibble` with all of the selected series from BCB.
#' @export
#'
#' @examples \dontrun{
#' # Get price indicators
#' prices <- get_bcb_series(category = "price")
#' # Get all series
#' bcb_series <- get_bcb_series(date_start = as.Date("2020-01-01"))
#' }
get_bcb_series <- function(
    category = "all",
    cached = FALSE,
    date_start = as.Date("2010-01-01"),
    ...
) {

  check_cats <- c(unique(bcb_metadata$bcb_category), "all")

  if (!any(category %in% check_cats)) {
    stop(
      glue::glue(
        "Category must be one of {paste(check_cats, collapse = ', ')}.")
    )
  }

  if (cached) {
    df <- readr::read_csv("...")
    return(df)
  }

  # Subset metadata based on categories
  if (category != "all") {
    # Subset the metadata to the specific category
    codes_bcb <- subset(bcb_metadata, bcb_category %in% category)$code_bcb
  } else {
    # Use all available categories
    codes_bcb <- bcb_metadata$code_bcb
  }

  # Check if date_start argument is a valid Date
  if (!inherits(date_start, "Date")) {
    # Try to convert to YYYY-MM-DD date
    date_start <- try(lubridate::ymd(date_start))
    if (inherits(date_start, "try-error")) {
      stop("Argument `date_start` must a valid Date or a string interpretable as a YYYY-MM-DD date.")
    }
  }

  # Download series
  message("BCB series: downloading.")
  bcb_series <- GetBCBData::gbcbd_get_series(
    id = codes_bcb,
    first.date = date_start
  )
  message("BCB series: download complete.")

  # Rename column names and join with dictionary (metadata)
  bcb_series <- bcb_series |>
    tibble::as_tibble() |>
    dplyr::rename(date = ref.date, code_bcb = id.num) |>
    dplyr::select(-series.name) |>
    dplyr::left_join(bcb_metadata, by = "code_bcb")

  return(bcb_series)

}
