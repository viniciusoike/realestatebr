#' Import data from Secovi-SP (DEPRECATED)
#'
#' @section Deprecation:
#' This function is deprecated since v0.4.0.
#' Use \code{\link{get_dataset}}("secovi") instead:
#'
#' \preformatted{
#'   # Old way:
#'   data <- get_secovi()
#'
#'   # New way:
#'   data <- get_dataset("secovi")
#' }
#'
#' @details
#' Scrapes real estate data from SECOVI-SP including condominium fees, rental
#' market data, launches, and sales information.
#'
#' @param table Character. One of `'condo'`, `'rent'`, `'launch'`, `'sale'` or `'all'`
#'   (default).
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   web scraping operations. Defaults to 3.
#'
#' @return A `tibble` with SECOVI-SP real estate data. The return includes
#'   metadata attributes:
#'   \describe{
#'     \item{download_info}{List with download statistics}
#'     \item{source}{Data source used (web or cache)}
#'     \item{download_time}{Timestamp of download}
#'   }
#'
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr filter select bind_rows left_join
#' @importFrom parallel mclapply
#' @keywords internal
get_secovi <- function(
  table = "all",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
  valid_tables <- c("all", "condo", "launch", "rent", "sale")
  validate_dataset_params(table, valid_tables, cached, quiet, max_retries, allow_all = TRUE)

  # Handle cached data ----
  if (cached) {
    data <- handle_dataset_cache("secovi", table = NULL, quiet = quiet, on_miss = "download")

    if (!is.null(data)) {
      # Filter category if needed
      if (table != "all") {
        data <- dplyr::filter(data, category == !!table)
      }

      data <- attach_dataset_metadata(data, source = "cache", category = table)
      return(data)
    }
  }

  # Download and process data ----
  cli_user("Downloading SECOVI-SP data from website", quiet = quiet)

  # Import data from SECOVI with retry logic
  scrape <- import_secovi_robust(table = table, quiet = quiet, max_retries = max_retries)

  cli_debug("Processing {length(scrape)} data table{?s}...")

  # Clean data with progress reporting for parallel operations
  if (!quiet) {
    # Sequential processing with progress when not quiet
    clean_tables <- list()
    for (i in seq_along(scrape)) {
      table_name <- names(scrape)[i]
      cli_debug("Processing table: {table_name}")
      clean_tables[[i]] <- clean_secovi(scrape[[i]])
    }
    names(clean_tables) <- names(scrape)
  } else {
    # Parallel processing when quiet
    clean_tables <- parallel::mclapply(scrape, clean_secovi)
    names(clean_tables) <- names(scrape)
  }

  tbl_secovi <- dplyr::bind_rows(clean_tables, .id = "variable")
  # Filter metadata table if needed
  if (table != "all") {
    secovi <- subset(secovi_metadata, cat == table)
  } else {
    secovi <- secovi_metadata
  }
  # Join table with the metadata (dictionary)
  tbl_secovi <- dplyr::left_join(
    tbl_secovi,
    secovi,
    by = dplyr::join_by(variable == label)
  )
  # Rearrange column order
  tbl_secovi <- tbl_secovi |>
    dplyr::select(date, category = cat, variable, name, value)

  # Add metadata attributes
  tbl_secovi <- attach_dataset_metadata(
    tbl_secovi,
    source = "web",
    category = table,
    extra_info = list(tables_processed = length(scrape))
  )

  record_count <- nrow(tbl_secovi)
  if (!quiet) {
    cli::cli_inform("\u2713 SECOVI-SP data retrieved: {record_count} records")
  }

  return(tbl_secovi)
}

#' Import SECOVI Data with Robust Error Handling
#'
#' Modern version of import_secovi with retry logic and progress reporting.
#'
#' @param table Data table to import
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return List of scraped data tables
#' @keywords internal
import_secovi_robust <- function(table, quiet, max_retries) {
  # Use download_with_retry() from rppi-helpers.R
  tryCatch(
    {
      download_with_retry(
        fn = function() {
          result <- import_secovi(table)

          # Validate we got some data
          if (length(result) == 0) {
            stop("No data returned from SECOVI website")
          }

          return(result)
        },
        max_retries = max_retries,
        quiet = quiet,
        desc = "Scrape SECOVI data"
      )
    },
    error = function(e) {
      cli::cli_abort(c(
        "Failed to download SECOVI-SP data",
        "x" = "All {max_retries + 1} attempt{?s} failed",
        "i" = "Error: {e$message}",
        "i" = "The SECOVI-SP website may be temporarily unavailable"
      ))
    }
  )
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
import_secovi <- function(table) {

  message("Scraping data from http://indiceseconomicos.secovi.com.br/")

  url <- "http://indiceseconomicos.secovi.com.br/indicadormensal.php?idindicador="

  if (table != "all") {
    secovi <- subset(secovi_metadata, cat == table)
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
