#' Import data from Secovi-SP.
#'
#' Download and clean real estate information from Sao Paulo (SP) made available
#' by SECOVI-SP.
#'
#' @param category One of `'condo'`, `'rent'`, `'launch'`, `'sale'` or `'all'`
#' (default).
#' @param cached If `TRUE` downloads the cached data from the GitHub repository.
#' This is a faster option but not recommended for daily data.
#'
#' @return A `tibble`
#' @export
#'
#' @examples \dontrun{
#' # Download all available data
#' secovi <- get_secovi_sp()
#'
#' # Download only a specific series
#' sales <- get_secovi_sp("sale")
#'
#' }
get_secovi <- function(category = "all", cached = FALSE) {

  # Check category argument
  stopifnot(
    "Category must be one of 'all', 'condo', 'launch', 'rent', or 'sale'." =
      any(category %in% c("all", "condo", "launch", "rent", "sale"))
  )

  if (cached) {
    # Use new unified architecture for cached data
    tbl_secovi <- get_dataset("secovi", source = "github")
    # Filter category if needed
    if (category != "all") {
      tbl_secovi <- dplyr::filter(tbl_secovi, category == category)
    }
    return(tbl_secovi)
  }

  # Import data from SECOVI
  message("Downloading Secovi data.")
  scrape <- import_secovi(category)

  # Clean data
  clean_tables <- parallel::mclapply(scrape, clean_secovi)
  names(clean_tables) <- names(scrape)
  tbl_secovi <- dplyr::bind_rows(clean_tables, .id = "variable")
  # Filter metadata table if needed
  if (category != "all") {
    secovi <- subset(secovi_metadata, cat == category)
  } else {
    secovi <- secovi_metadata
  }
  # Join table with the metadata (dictionary)
  tbl_secovi <- dplyr::left_join(
    tbl_secovi,
    secovi,
    by = c("variable" = "label")
    )
  # Rearrange column order
  tbl_secovi <- tbl_secovi |>
    dplyr::select(date, category = cat, variable, name, value)

  return(tbl_secovi)

}


secovi_metadata <- dplyr::tribble(
~code,               ~label,      ~cat,
   14, "default_condominio",   "condo",
   78,               "icon",   "condo",
   80,     "acao_locaticia",    "rent",
   18,  "tipos_de_garantia",    "rent",
   13,         "rent_price",    "rent",
   25,      "launches_rmsp",  "launch",
   26,             "supply",  "launch",
   85,           "launches",  "launch",
   86,       "sales_1rooms",    "sale",
   87,       "sales_2rooms",    "sale",
   88,       "sales_3rooms",    "sale",
   89,       "sales_4rooms",    "sale",
   90,              "sales",    "sale",
   118,         "sales_rmsp",    "sale"
)


#' Webscrapes data from Secovi
#'
#' @inheritParams get_secovi
#' @noRd
import_secovi <- function(category) {

  message("Scraping data from http://indiceseconomicos.secovi.com.br/")

  url <- "http://indiceseconomicos.secovi.com.br/indicadormensal.php?idindicador="

  if (category != "all") {
    secovi <- subset(secovi_metadata, cat == category)
  } else {
    secovi <- secovi_metadata
  }

  urls <- paste0(url, secovi[["code"]])
  parsed <- lapply(urls, rvest::read_html)
  tables <- lapply(parsed, \(x) try(rvest::html_table(x), silent = TRUE))
  names(tables) <- secovi[["label"]]

  check_missing <- any(sapply(tables, length) == 0)

  if (check_missing) {
    # Get the names of the missing tables
    missing_tables <- names(tables[sapply(tables, length) == 0])
    # Report a warning
    warn_msg <- glue::glue("Failed to import data for: {paste(missing_tables, collapse = ', ')}")
    warning(warn_msg)
    # Remove elements with less than 0 length
    tables <- tables[sapply(tables, length) > 0]
  }

  return(tables)

}

#' Converts numbers saved as strings into nubmers
#' 1.203,12 -> 1203.12
#'
#' @param x A `character` that should be a `numeric`
#'
#' @return A `numeric`
#' @noRd
as_numeric_character <- function(x) {
  x <- stringr::str_remove_all(x, "\\.")
  x <- stringr::str_replace(x, ",", ".")
  x <- suppressWarnings(as.numeric(x))
  return(x)
}

#' Renames columns, selects only the first two and converts second table to num
#' Assumes first column is date and second column is a value column
#' @param df A `data.frame`
#' @noRd
clean_basic <- function(df) {
  # Simplify names
  df <- janitor::clean_names(df)
  # dplyr::selects first two columns
  df <- df[, 1:2]
  # Convert to long (name, value)
  df <- tidyr::pivot_longer(df, cols = -1)
  # Cleans numeric variable
  df$value <- as_numeric_character(df$value)
  return(df)
}

#' Joins with dim_date and creates a Date variable
#'
#' @param df A `data.frame`
#'
#' @return A `tibble`
#' @noRd
clean_date_label <- function(df) {

  dim_date <- tidyr::tibble(
    month_label = lubridate::month(1:12, label = TRUE, locale = "pt_BR"),
    month = 1:12
  )

  # Fix date column: Creates a key column and joins with dim_date
  df <- df |>
    dplyr::mutate(month_label = stringr::str_to_title(mes)) |>
    dplyr::left_join(dim_date, by = "month_label") |>
    dplyr::mutate(
      year = as.numeric(year),
      date = lubridate::make_date(year, month)
      )
  # Convert value to percent if needed
  df <- df |>
    dplyr::mutate(
      value = dplyr::if_else(
        stringr::str_detect(name, "percent"), value / 100, value
        )
    )
  # Select columns
  df <- df |>
    dplyr::select(date, name, value)

  return(df)
}

clean_secovi <- function(x) {

  # html_table comes with wrong header. this function solves that
  extract <- function(x) {
    # Convert to matrix
    xm <- as.matrix(x)
    # Remove first row and define as header row
    if (nrow(xm) == 2) {
      # Undesired behavior of data.frame when input is a atomic vector
      df <- data.frame(t(xm[-1, ]))
      try(names(df) <- as.character(xm[1, ]))
    } else {
      df <- data.frame(xm[-1, ])
      try(names(df) <- as.character(xm[1, ]))
    }
    return(df)
  }

  # Drop problematic tables from scrape
  remove_tables <- function(df) {

    # Check if all columns are NA
    check1 <- all(sapply(df, \(x) all(is.na(x))))
    # Check if most columns are NA
    check2 <- sum(sapply(df, \(x) all(is.na(x)))) / ncol(df)
    # Check if there is only a single column
    check3 <- ncol(df) == 1
    # Check if there is only a single row
    check4 <- nrow(df) == 1

    # If any of the four conditions above is TRUE return a FALSE to drop this
    # table
    if (check1 | check2 >= 0.4 | check3 | check4) {
      return(FALSE)
    } else {
      return(TRUE)
    }
  }

  tables <- x[sapply(x, remove_tables)]
  tables <- purrr::map(tables, extract)
  tables <- purrr::map(tables, clean_basic)

  get_years <- function(x) {
    years <- x[sapply(x, nrow) == 1]
    years <- dplyr::bind_rows(years)
    years <- stats::na.omit(years$X3)
    years <- as.numeric(stringr::str_remove(years, "Ano: "))
  }

  years <- get_years(x)
  nvars <- length(unique(dplyr::bind_rows(tables)$name))

  t <- try(
    names(tables) <- rep(years, each = ceiling(length(tables) / length(years))),
    silent = TRUE
  )

  if (inherits(t, "try-error")) {
    #tt <- length(tables)
    #yy <- length(rep(years, each = ceiling(length(tables) / length(years))))
    years <- years[-1]
  }

  names(tables) <- rep(years, each = ceiling(length(tables) / length(years)))

  fact_table <- dplyr::bind_rows(tables, .id = "year")
  fact_table <- clean_date_label(fact_table)

  return(fact_table)

}
