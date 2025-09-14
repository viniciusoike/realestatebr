#' Download macroeconomic time-series from BCB using rbcb.
#'
#' Alternative version of get_bcb_series that uses the rbcb package instead 
#' of GetBCBData. This version may be more reliable for some series.
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
#' @param cached Logical indicating whether to use cached data
#' @param date_start A `Date` argument indicating the first period to extract
#' from the time series. Defaults to 2010-01-01.
#' @param date_end A `Date` argument indicating the last period to extract.
#' If NULL, downloads until the most recent data.
#' @param ... Additional arguments (currently unused)
#'
#' @source [https://www3.bcb.gov.br/sgspub/localizarseries/localizarSeries.do?method=prepararTelaLocalizarSeries](https://www3.bcb.gov.br/sgspub/localizarseries/localizarSeries.do?method=prepararTelaLocalizarSeries)
#' @return A 12-column `tibble` with all of the selected series from BCB.
#' @export
#'
#' @examples \dontrun{
#' # Get price indicators
#' prices <- get_bcb_series_rbcb(category = "price")
#' # Get all series
#' bcb_series <- get_bcb_series_rbcb(date_start = as.Date("2020-01-01"))
#' }
get_bcb_series_rbcb <- function(
  category = "all",
  cached = FALSE,
  date_start = as.Date("2010-01-01"),
  date_end = NULL,
  ...
) {
  
  # Load required packages
  if (!requireNamespace("rbcb", quietly = TRUE)) {
    stop("Package 'rbcb' is required for this function. Please install it with: install.packages('rbcb')")
  }
  
  check_cats <- c(unique(bcb_metadata$bcb_category), "all")

  if (!any(category %in% check_cats)) {
    stop(glue::glue(
      "Category must be one of {paste(check_cats, collapse = ', ')}."
    ))
  }

  # Subset metadata based on categories
  if (category != "all") {
    codes_bcb <- subset(bcb_metadata, bcb_category %in% category)$code_bcb
  } else {
    codes_bcb <- bcb_metadata$code_bcb
  }

  # Check if date_start argument is a valid Date
  if (!inherits(date_start, "Date")) {
    date_start <- try(lubridate::ymd(date_start))
    if (inherits(date_start, "try-error")) {
      stop(
        "Argument `date_start` must a valid Date or a string interpretable as a YYYY-MM-DD date."
      )
    }
  }

  # Check if date_end argument is a valid Date
  if (!is.null(date_end) && !inherits(date_end, "Date")) {
    date_end <- try(lubridate::ymd(date_end))
    if (inherits(date_end, "try-error")) {
      stop(
        "Argument `date_end` must a valid Date or a string interpretable as a YYYY-MM-DD date."
      )
    }
  }

  if (cached) {
    bcb_series <- import_cached("bcb_series")
    bcb_series <- dplyr::filter(
      bcb_series,
      code_bcb %in% codes_bcb,
      date >= date_start
    )
    if (!is.null(date_end)) {
      bcb_series <- dplyr::filter(bcb_series, date <= date_end)
    }
    return(bcb_series)
  }

  # Download series using rbcb
  message("BCB series: downloading using rbcb package.")
  
  bcb_series_list <- list()
  failed_series <- character()
  
  for (i in seq_along(codes_bcb)) {
    series_id <- codes_bcb[i]
    message(glue::glue("Downloading series {series_id} ({i}/{length(codes_bcb)})"))
    
    # First attempt
    series_data <- try({
      rbcb::get_series(
        code = series_id,
        start_date = date_start,
        end_date = date_end,
        as = "tibble"
      )
    }, silent = TRUE)
    
    # Retry if first attempt failed
    if (inherits(series_data, "try-error")) {
      message(glue::glue("  First attempt failed, retrying series {series_id}..."))
      Sys.sleep(0.5)  # Brief pause before retry
      series_data <- try({
        rbcb::get_series(
          code = series_id,
          start_date = date_start,
          end_date = date_end,
          as = "tibble"
        )
      }, silent = TRUE)
    }
    
    # Check if download was successful and has valid data
    if (inherits(series_data, "try-error")) {
      message(glue::glue("  Failed to download series {series_id} after 2 attempts, skipping."))
      failed_series <- c(failed_series, series_id)
    } else if (nrow(series_data) == 0) {
      message(glue::glue("  Series {series_id} returned no data, skipping."))
      failed_series <- c(failed_series, series_id)
    } else if (all(is.na(series_data$value))) {
      message(glue::glue("  Series {series_id} contains only NA values, skipping."))
      failed_series <- c(failed_series, series_id)
    } else {
      # Add series code to the data and store
      series_data$code_bcb <- series_id
      bcb_series_list[[as.character(series_id)]] <- series_data
      message(glue::glue("  Success: {series_id} ({nrow(series_data)} observations)"))
    }
    
    # Small delay to avoid overwhelming the API
    if (i < length(codes_bcb)) {
      Sys.sleep(0.1)
    }
  }
  
  # Combine all successful downloads
  if (length(bcb_series_list) > 0) {
    bcb_series <- dplyr::bind_rows(bcb_series_list)
  } else {
    stop("No series were successfully downloaded.")
  }
  
  if (length(failed_series) > 0) {
    message(glue::glue("Warning: {length(failed_series)} series failed to download: {paste(failed_series, collapse = ', ')}"))
  }
  
  message(glue::glue("BCB series: download complete. Successfully downloaded {length(bcb_series_list)} out of {length(codes_bcb)} series."))

  # Rename columns to match the original function's output format
  bcb_series <- bcb_series |>
    dplyr::as_tibble() |>
    dplyr::left_join(bcb_metadata, by = "code_bcb") |>
    dplyr::select(date, value, code_bcb, dplyr::everything())

  return(bcb_series)
}