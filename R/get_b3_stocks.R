#' Import Stock Prices for Brazilian Real Estate Players
#'
#' Download and imports the stock values of the most relevant
#' real-estate players in Brazil via `tidyquant::tq_get()`. A list of companies
#' can be found at `b3_real_estate`.
#'
#' Additionally returns some relevant financial indices.
#'
#' @inheritParams get_secovi
#' @param date_start Date value passed on to `tidyquant::tq_get`. Defaults
#' to `2022-12-01`.
#' @param ... Additional arguments passed on to `tidyquant::tq_get`.
#'
#' @return A `tibble` containing stock prices for all companies.
#' @export
#'
#' @examples
#' # Default input download stock prices for all companies
#' # get_b3_stocks(as.Date("2022-10-01"))
#' # Can use a string as date input as long as it's in a YYYY-MM-DD format
#' # get_b3_stocks("2022-10-01")
get_b3_stocks <- function(
    date_start = as.Date("2022-12-01"),
    cached = FALSE,
    ...) {

  if (!inherits(date_start, "Date")) {

    date_start <- try(lubridate::ymd(date_start))

    if (inherits(date_start, "try-error")) {
      error("Date start must be a valid Date or a string interpretable as a Date.")
    }

  }

  # Download series using tidyquant::tq_get

  # Stock Symbols
  syms <- c("ALSO3", "BRML3", "BRPR3", "CYRE3", "DIRR3", "EVEN3", "EZTC3",
            "GFSA3", "HBOR3", "IGTI11", "JHSF3", "LOGG3", "LPSB3", "MRVE3",
            "MULT3", "TCSA3", "TEND3", "TRIS3", "RSID3", "RDNI3", "CURY3",
            "MTRE3", "VIVR3", "BBRK3", "LAVV3", "MDNE3", "MELK3", "PLPL3",
            "AVLL3", "CALI3", "CRDE3", "INTT3", "JFEN3", "KLAS3", "PDGR3",
            "TEGA3")
  syms <- paste0(syms, ".SA")
  # Indexes
  syms <- c(syms, "^BVSP", "^IBX50", "EWZ", "EEM", "DBC", "IFIX")

  message("Financial series: downloading.")
  # Uses purrr::map and stacks rows

  imob <- suppressWarnings(
    tidyquant::tq_get(x = syms, get = "stock.prices", from = date_start)
    )
  message("Financial series: download complete.")

  return(imob)

}
