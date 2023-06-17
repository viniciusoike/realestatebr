#' Get Residential Property Price Indices from BIS
#'
#' Get the Residential Property Price Indices series from the Bank for
#' International Settlements (BIS).
#'
#' @details
#' For the simple selected series select `category = 'selected'`. More information
#' on these series is available at the [BIS website](https://www.bis.org/statistics/pp_selected.htm)
#'
#' For the full detailed dataset select `category = 'detailed'`. More information
#' on these series is available at the [BIS website](https://www.bis.org/statistics/pp_detailed.htm)
#'
#' @param category One of `selected` (default) or `detailed`.
#' @inheritParams get_secovi
#' @source [(https://www.bis.org/statistics/pp_detailed.htm)]((https://www.bis.org/statistics/pp_detailed.htm))
#' @return A `tibble` or a named `list` with all RPPIs from BIS.
#' @export
#'
#' @examples \dontrun{
#' # Download selected RPPI data from BIS
#' bis <- get_bis_rppi()
#'
#' # For faster download time use cached data
#' bis <- get_bis_rppi(category = "detailed", cached = TRUE)
#' }
get_bis_rppi <- function(category = "selected", cached = FALSE) {

  # Check category argument
  stopifnot(
    "Category must be one of 'detailed' or 'selected'." =
      any(category %in% c("detailed", "selected"))
  )
  # Download cached data from the GitHub repo
  if (cached) {
    if (category == "selected") {
      df <- import_cached("bis_selected")
    } else {
      df <- import_cached("bis_detailed")
    }
    return(df)
  }
  # Apply the appropriate function
  if (category == "selected") {
    df <- get_bis_rppi_selected()
  } else if (category == "detailed") {
    df <- get_bis_rppi_detailed()
  }
  return(df)
}


#' Get Residential Property Price Indices from BIS
#'
#' Get the detailed Residential Property Price Indices from the Bank for
#' International Settlements (BIS) available at [their webpage](https://www.bis.org/statistics/pp_selected.htm).
#'
#' @return A named `list` with all Detailed RPPIs from BIS
get_bis_rppi_selected <- function() {

  # Download data

  # Define url and temporary pathfile to download
  url <- "https://www.bis.org/statistics/pp/pp_selected.xlsx"
  temp_path <- tempfile("bis_rppi_selected.xlsx")
  # Download spreadsheet with selected series
  httr::GET(url, httr::write_disk(temp_path, overwrite = TRUE))

  # Import data

  # Import spreasheet into R
  series <- readxl::read_excel(
    temp_path,
    sheet = 3,
    skip = 3
  )
  # Import Dictionary into R and clean column names
  dict <- readxl::read_excel(
    temp_path,
    sheet = 2,
    .name_repair = janitor::make_clean_names
  )
  # Change column names
  dict <- dplyr::rename(dict, is_nominal = value)

  # Clean data

  # Fix date column
  clean_series <- series |>
    # Convert date column to YMD
    dplyr::rename(date = Period) |>
    dplyr::mutate(date = lubridate::ymd(date)) |>
    # Convert data to long (every column is a series)
    tidyr::pivot_longer(cols = -date, names_to = "code")

  # Join with variable dictionary
  clean_series <- clean_series |>
    dplyr::mutate(code = stringr::str_remove(code, "BIS_SPP:")) |>
    dplyr::left_join(dict, by = "code")

  # Insert a numeric code for unit and a TRUE/FALSE for is_nominal
  clean_series <- clean_series |>
    dplyr::mutate(
      unit_code = dplyr::if_else(stringr::str_detect(unit, "Index"), 1L, 2L),
      is_nominal = dplyr::if_else(is_nominal == "Nominal", TRUE, FALSE)
    )

  return(clean_series)
}

#' Get Residential Property Price Indices from BIS
#'
#' Get the detailed Residential Property Price Indices from the Bank for
#' International Settlements (BIS) available at [their webpage](https://www.bis.org/statistics/pp_detailed.htm).
#'
#' @return A named `list` with all Detailed RPPIs from BIS
get_bis_rppi_detailed <- function() {

  # Download data

  # Define url and temporary pathfile to download
  url <- "https://www.bis.org/statistics/pp/pp_detailed.xlsx"
  temp_path <- tempfile("bis_rppi_detailed.xlsx")
  # Download spreadsheet with detailed series
  httr::GET(url, httr::write_disk(temp_path, overwrite = TRUE))

  # Import data

  # Import data from sheets 3 through 6
  sheets <- purrr::map(3:6, \(x) {
    readxl::read_excel(temp_path, skip = 3, sheet = x)
  })
  # Name each element according to sheet names
  names(sheets) <- janitor::make_clean_names(readxl::excel_sheets(temp_path)[3:6])

  # Import Dictionary into R and clean column names
  dict <- readxl::read_excel(
    temp_path,
    sheet = 2,
    .name_repair = janitor::make_clean_names
    )

  # Clean data

  # Define a function to clean the data.frames
  clean_bis_detailed <- function(df) {

    # Inputs are a mix of strings '1901.31.01' and excel numeric dates '366'
    fix_date_column <- function(x) {
      # In most sheets the Period column is read appropriately
      if (lubridate::is.POSIXct(x)) {
        x <- lubridate::ymd(x)
        x <- lubridate::floor_date(x, unit = "month")
      } else {
        # Fix the yearly sheet
        x <- dplyr::if_else(
          nchar(x) < 7,
          janitor::excel_numeric_to_date(as.numeric(x)),
          lubridate::make_date(substr(x, 7, 10))
        )
        x <- lubridate::floor_date(x, unit = "year")
      }

      return(x)
    }

    # Fix date column and convert to long
    clean_df <- df |>
      dplyr::rename(date = Period) |>
      dplyr::mutate(date = suppressWarnings(fix_date_column(date))) |>
      tidyr::pivot_longer(cols = -"date", names_to = "code")

    # Join data with dictionary and create a unit code
    clean_df <- clean_df |>
      dplyr::mutate(code = stringr::str_remove(code, "BIS_SPP:")) |>
      dplyr::left_join(dict, by = "code") |>
      dplyr::mutate(
        unit_code = dplyr::if_else(stringr::str_detect(unit, "Index"), 1L, 2L)
      )

    return(clean_df)

  }
  # Apply function over all sheets
  clean_data <- purrr::map(sheets, clean_bis_detailed)

  return(clean_data)

}
