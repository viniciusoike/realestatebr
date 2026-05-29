#' Import data from Secovi-SP
#'
#' @details
#' Scrapes real estate data from SECOVI-SP including condominium fees, rental
#' market data, launches, and sales information.
#'
#' @param table Character. One of `'condo'`, `'rent'`, `'launch'`, `'sale'` or `'all'`
#'   (default).
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   web scraping operations. Defaults to 3.
#'
#' @return A `tibble` with SECOVI-SP real estate data. The return includes
#'   metadata attributes:
#'   \describe{
#'     \item{download_info}{List with download statistics}
#'     \item{source}{Data source used}
#'     \item{download_time}{Timestamp of download}
#'   }
#'
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr filter select bind_rows left_join join_by
#' @keywords internal
get_secovi <- function(
  table = "all",
  quiet = FALSE,
  max_retries = 3L
) {
  valid_tables <- c("all", "condo", "launch", "rent", "sale")
  validate_dataset_params(
    table,
    valid_tables,
    quiet,
    max_retries,
    allow_all = TRUE
  )

  cli_user("Downloading SECOVI-SP data from website", quiet = quiet)

  scrape <- rlang::try_fetch(
    download_secovi(table = table, quiet = quiet, max_retries = max_retries),
    error = function(cnd) {
      if (!quiet) {
        cli::cli_warn("Web scraping failed: {cnd$message}")
      }
      NULL
    }
  )

  if (is.null(scrape) || length(scrape) == 0) {
    data <- fallback_to_github_cache("secovi_sp", quiet = quiet)
    if (!is.null(data)) {
      if (table != "all") {
        data <- dplyr::filter(data, category == !!table)
      }
      data <- attach_dataset_metadata(
        data,
        source = "github",
        category = table
      )
      return(data)
    }
    cli::cli_abort(c(
      "Failed to retrieve SECOVI-SP data",
      "x" = "Web scraping returned empty and GitHub release is unavailable",
      "i" = "The SECOVI-SP website may be blocking automated requests"
    ))
  }

  cli_debug("Processing {length(scrape)} data table{?s}...")

  clean_tables <- purrr::map(scrape, clean_secovi)

  secovi_meta <- if (table != "all") {
    dplyr::filter(secovi_metadata, cat == table)
  } else {
    secovi_metadata
  }

  tbl_secovi <- dplyr::bind_rows(clean_tables, .id = "variable")
  tbl_secovi <- dplyr::left_join(
    tbl_secovi,
    secovi_meta,
    by = dplyr::join_by(variable == label)
  )
  tbl_secovi <- dplyr::select(
    tbl_secovi,
    date,
    category = cat,
    variable,
    name,
    value
  )

  tbl_secovi <- attach_dataset_metadata(
    tbl_secovi,
    source = "web",
    category = table,
    extra_info = list(tables_processed = length(scrape))
  )

  if (!quiet) {
    cli::cli_inform("SECOVI-SP data retrieved: {nrow(tbl_secovi)} records")
  }

  return(tbl_secovi)
}


#' Download raw SECOVI-SP indicator tables
#'
#' @param table Data table to import
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Named list of scraped data tables
#' @keywords internal
download_secovi <- function(table, quiet, max_retries) {
  url_base <- "https://indiceseconomicos.secovi.com.br/indicadormensal.php?idindicador="

  secovi_meta <- if (table != "all") {
    dplyr::filter(secovi_metadata, cat == table)
  } else {
    secovi_metadata
  }

  download_with_retry(
    fn = function() {
      cli_user(
        "Scraping data from https://indiceseconomicos.secovi.com.br/",
        quiet = quiet
      )

      urls <- paste0(url_base, secovi_meta[["code"]])
      parsed <- purrr::map(urls, rvest::read_html)

      safe_html_table <- purrr::possibly(rvest::html_table, otherwise = list())
      tables <- purrr::map(parsed, safe_html_table)
      names(tables) <- secovi_meta[["label"]]

      missing_mask <- purrr::map_lgl(tables, ~ length(.x) == 0)
      if (any(missing_mask)) {
        missing_tables <- names(tables)[missing_mask]
        cli::cli_warn("Failed to import data for: {.val {missing_tables}}")
        tables <- tables[!missing_mask]
      }

      if (length(tables) == 0) {
        stop("No data returned from SECOVI website")
      }

      return(tables)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "Scrape SECOVI data"
  )
}


secovi_metadata <- dplyr::tribble(
  ~code , ~label               , ~cat     ,
     14 , "default_condominio" , "condo"  ,
     78 , "icon"               , "condo"  ,
     80 , "acao_locaticia"     , "rent"   ,
     18 , "tipos_de_garantia"  , "rent"   ,
     13 , "rent_price"         , "rent"   ,
     25 , "launches_rmsp"      , "launch" ,
     26 , "supply"             , "launch" ,
     85 , "launches"           , "launch" ,
     86 , "sales_1rooms"       , "sale"   ,
     87 , "sales_2rooms"       , "sale"   ,
     88 , "sales_3rooms"       , "sale"   ,
     89 , "sales_4rooms"       , "sale"   ,
     90 , "sales"              , "sale"   ,
    118 , "sales_rmsp"         , "sale"
)


#' Parse PT-BR formatted number strings to numeric
#'
#' Converts strings like "1.203,12" to 1203.12.
#'
#' @param x A `character` that should be a `numeric`
#' @return A `numeric`
#' @noRd
secovi_parse_number <- function(x) {
  x <- stringr::str_remove_all(x, "\\.")
  x <- stringr::str_replace(x, ",", ".")
  x <- suppressWarnings(as.numeric(x))
  return(x)
}


#' Standardise column names, keep first two columns, and parse value
#'
#' @param df A `data.frame` with a date column and one value column
#' @noRd
secovi_basic_clean <- function(df) {
  df <- janitor::clean_names(df)
  df <- df[, 1:2]
  df <- tidyr::pivot_longer(df, cols = -1)
  df$value <- secovi_parse_number(df$value)
  return(df)
}


#' Join with month lookup and build a Date column
#'
#' @param df A `data.frame` with `year`, `mes`, `name`, and `value` columns
#' @return A `tibble` with `date`, `name`, `value`
#' @noRd
secovi_clean_date_label <- function(df) {
  dim_date <- tibble::tibble(
    mes = c(
      "JAN",
      "FEV",
      "MAR",
      "ABR",
      "MAI",
      "JUN",
      "JUL",
      "AGO",
      "SET",
      "OUT",
      "NOV",
      "DEZ"
    ),
    month = 1:12
  )

  df <- dplyr::left_join(df, dim_date, by = "mes")

  df <- df |>
    dplyr::mutate(
      year = as.numeric(year),
      date = lubridate::make_date(year, month),
      value = dplyr::if_else(
        stringr::str_detect(name, "percent"),
        value / 100,
        value
      )
    ) |>
    dplyr::select(date, name, value)

  return(df)
}


#' Decide whether a scraped sub-table should be retained
#'
#' Returns `FALSE` for tables that are fully NA, mostly NA (>= 40 %),
#' single-column, or single-row (header-only artefacts from the scrape).
#'
#' @param df A `data.frame` from the raw scrape
#' @noRd
secovi_keep_table <- function(df) {
  all_na_cols <- purrr::map_lgl(df, \(x) all(is.na(x)))
  check_all_na <- all(all_na_cols)
  check_mostly_na <- mean(all_na_cols) >= 0.4
  check_single_col <- ncol(df) == 1
  check_single_row <- nrow(df) == 1

  !(check_all_na | check_mostly_na | check_single_col | check_single_row)
}


#' Fix the wrong header produced by html_table and return a clean data.frame
#'
#' `rvest::html_table()` sometimes returns the true header as the first data
#' row. This function promotes row 1 to column names and drops it from the data.
#'
#' @param x A raw `data.frame` from `rvest::html_table()`
#' @noRd
secovi_extract_header <- function(x) {
  xm <- as.matrix(x)
  header <- as.character(xm[1, ])

  if (nrow(xm) == 2) {
    df <- data.frame(t(xm[-1, ]))
  } else {
    df <- data.frame(xm[-1, ])
  }

  if (length(header) == ncol(df)) {
    names(df) <- header
  }

  return(df)
}


#' Extract the year values embedded in single-row annotation tables
#'
#' The SECOVI scrape includes 1-row tables of the form "Ano: 2023". This
#' function identifies those rows and returns the years as a numeric vector.
#'
#' @param x Raw list of tables from `rvest::html_table()`
#' @noRd
secovi_get_years <- function(x) {
  single_row <- x[purrr::map_int(x, nrow) == 1]
  year_rows <- dplyr::bind_rows(single_row)
  year_vals <- stats::na.omit(year_rows$X3)
  years <- as.numeric(stringr::str_remove(year_vals, "Ano: "))
  return(years)
}


clean_secovi <- function(x) {
  tables <- purrr::keep(x, secovi_keep_table)
  tables <- purrr::map(tables, secovi_extract_header)
  tables <- purrr::map(tables, secovi_basic_clean)

  years <- secovi_get_years(x)

  year_labels <- rep(years, each = ceiling(length(tables) / length(years)))
  if (length(year_labels) != length(tables)) {
    years <- years[-1]
    year_labels <- rep(years, each = ceiling(length(tables) / length(years)))
  }
  names(tables) <- year_labels

  fact_table <- dplyr::bind_rows(tables, .id = "year")
  fact_table <- secovi_clean_date_label(fact_table)

  return(fact_table)
}
