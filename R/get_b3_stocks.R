#' Get Stock Prices
#'
#' Imports stock prices of Brazilian real estate players. Additionally, imports
#' some relevant financial indices.
#'
#' @details
#' Downloads and imports the stock values of the most relevant
#' real estate players in Brazil via `quantmod::getSymbols`. A list of companies
#' can be found at `b3_real_estate`.
#'
#' By default uses `src = 'yahoo'`.
#'
#' @inheritParams get_secovi
#' @param symbol Optional character string with the stock tickers symbols. If
#' none is provided uses all symbols in `b3_real_estate`.
#' @param src Character string specifying sourcing method (defaults to `'yahoo'`).
#' @param quiet Logical indicating if warnings should be printed to the console.
#' @param ... Additional arguments passed on to `quantmod::getSymbols`.
#'
#' @seealso [quantmod::getSymbols()]
#'
#' @return A `tibble` containing stock prices for all companies.
#' @export
#' @importFrom quantmod getSymbols
#' @examples \dontrun{
#' # Get a specific company
#' cyrela <- get_b3_stocks(symbol = "CYRE3.SA")
#'
#' # Get all available companies
#' stocks <- get_b3_stocks()
#'
#' }
get_b3_stocks <- function(cached = FALSE, src = "yahoo", symbol = NULL, quiet = TRUE, ...) {

  # Download cached data
  if (cached) {
    # Use new unified architecture for cached data
    stack <- get_dataset("b3_stocks", source = "github")
  }

  # Download series using quantmod::getSymbols

  # Stock Symbols

  if (is.null(symbol)) {
    # Get real estate companies symbols
    symbol <- b3_real_estate$symbol
    # Indexes
    symbol <- c(symbol, "^BVSP", "^IBX50", "EWZ", "EEM", "DBC", "IFIX")
  } else {
    stopifnot(is.character(symbol))
    stopifnot(any(symbol %in% b3_real_estate$symbol))
  }

  # Download series
  message("Financial series: downloading.")

  if (quiet) {
    imob <- try(suppressWarnings(quantmod::getSymbols(symbol, src = src, ...)))
  } else {
    imob <- try(quantmod::getSymbols(symbol, src = src, ...))
  }

  if (inherits(imob, "try-error")) {
    stop("Error: failed to download series. Check internet connection or change provider.")
  }

  message("Financial series: download complete.")

  # Stack series
  series <- mget(imob)

  # Convert from xts to tibble
  # Helper function
  xts_to_tibble <- function(x) {
    # Convert xts to data.frame and then to tibble
    df <- data.frame(date = zoo::index(x), zoo::coredata(x))
    tbl <- tidyr::as_tibble(df)
    # Adjust column names
    col_names <- names(tbl)
    # Removes symbols from column names, removes a trailing dot
    col_names <- stringr::str_remove_all(col_names, paste(symbol, collapse = "|"))
    col_names <- stringr::str_remove(col_names, "^\\.")
    col_names <- stringr::str_to_lower(col_names)

    # Standardize column names for consistency
    col_names <- stringr::str_replace_all(
      col_names,
      c(
        "^open$" = "price_open",
        "^high$" = "price_high",
        "^low$" = "price_low",
        "^close$" = "price_close",
        "^volume$" = "volume",
        "^adjusted$" = "adjusted"
      )
    )
    names(tbl) <- col_names

    return(tbl)

  }
  # Convert all series to tibble and stack
  series <- lapply(series, xts_to_tibble)
  stack <- dplyr::bind_rows(series, .id = "symbol")

  return(stack)

}
