#' Get Residential Property Price Indices from BIS
#'
#' Get the selected Residential Property Price Indices from the Bank for
#' International Settlements (BIS) available at [their webpage](https://www.bis.org/statistics/pp_selected.htm).
#'
#' @param cached If `TRUE` downloads the cached data from the GitHub repository.
#' This is a faster option but not recommended for daily data.
#'
#' @return A `tibble` with all selected RPPIs from BIS
#' @export
#'
#' @examples
#' # get_bis_rppi()
get_bis_rppi <- function(cached) {

  if (cached) {
    df <- readr::read_csv("...")
  }

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
#' International Settlements (BIS) available at [their webpage](https://www.bis.org/statistics/pp_selected.htm).
#'
#' @inheritParams get_bis_rppi
#'
#' @return A named `list` with all Detailed RPPIs from BIS
#' @export
#'
#' @examples
#' #get_bis_rppi_detailed()
get_bis_rppi_detailed <- function(cached) {

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
  names(sheets) <- janitor::make_clean_names(readxl::excel_sheets(temp_file)[3:6])

  # Import Dictionary into R and clean column names
  dict <- readxl::read_excel(
    temp_path,
    sheet = 2,
    .name_repair = janitor::make_clean_names
    )

  # Clean data

  # Define a function to clean the data.frames
  clean_bis_detailed <- function(df) {

    # Fix date column and convert to long
    clean_df <- df |>
      dplyr::rename(date = Period) |>
      dplyr::mutate(date = readr::parse_date(date, format = "%d.%m.%Y")) |>
      tidyr::pivot_longer(cols = -"date", names_to = "code")

    # Join data with dictionary and create a unit code
    clean_df <- clean_df |>
      dplyr::mutate(code = stringr::str_remove(code, "BIS_SPP:")) |>
      dplyr::left_join(bis_dict, by = "code") |>
      dplyr::mutate(
        unit_code = dplyr::if_else(stringr::str_detect(unit, "Index"), 1L, 2L)
      )

    return(clean_df)

  }
  # Apply function over all sheets
  clean_data <- purrr::map(sheets, clean_bis_detailed)

  return(clean_data)

}
