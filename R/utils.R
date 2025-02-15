#' Finds import range for each table
#'
#' @param path Path to excel file
#' @param sheet Name or number of sheet to be analyzed
#' @param skip_row Additional argument passed to `readxl::read_excel()`
#'
#' @details Based on the date column, finds the range to be imported.
get_range <- function(path = NULL, sheet, skip_row = 4) {

  # Import all data from sheet
  cells <- tidyxl::xlsx_cells(path, sheets = sheet)

  # Change skip if necessary
  skip_row <- skip_row

  # Define range for cell extraction

  # Finds last row that is of type Date
  maxrow <- cells |>
    dplyr::filter(sheet == sheet,
                  row > skip_row,
                  data_type == "date") |>
    dplyr::slice(dplyr::n()) |>
    dplyr::pull(address)

  # Finds last non-NA column
  maxcol <- cells |>
    dplyr::filter(sheet == sheet,
                  row > skip_row,
                  col == max(col)) |>
    dplyr::slice(1) |>
    dplyr::pull(address) |>
    unique()

  maxcol <- cells |>
    dplyr::filter(sheet == sheet,
                  !is.na(numeric)) |>
    dplyr::slice_max(col, n = 1) |>
    dplyr::pull(address) |>
    unique()


  # Paste together range
  # B5:BD162
  r1 <- stringr::str_extract(maxrow, "[A-Z]")
  r2 <- 1 + skip_row
  r3 <- stringr::str_extract(maxcol, "[A-Z]+")
  r4 <- stringr::str_extract(maxrow, "[0-9]+")

  range_excel <- paste0(r1, r2, ":", r3, r4)
  range_excel <- unique(range_excel)
  return(range_excel)
}

#' Get Excel Range for Data Extraction
#'
#' @description
#' Determines the exact range of cells containing data in an Excel sheet.
#' The function finds the boundaries of the data by identifying the last row
#' containing dates and the last column containing non-NA values.
#'
#' @param path Character string. Path to the Excel file.
#' @param sheet Character string. Name of the sheet to analyze.
#' @param skip_row Numeric. Number of rows to skip before the actual data begins.
#'   Defaults to 4.
#'
#' @return Character string representing an Excel range (e.g., "B5:BD162").
#'
#' @details
#' The function works by:
#' 1. Reading the Excel sheet
#' 2. Identifying columns containing dates
#' 3. Finding the last row with valid dates
#' 4. Finding the last column with non-NA values
#' 5. Converting column numbers to Excel-style letters
#' 6. Constructing the range string
#'
#' @examples
#' \dontrun{
#' # Get range from a specific sheet
#' range <- get_range("path/to/file.xlsx", sheet = "Sheet1", skip_row = 4)
#' print(range) # Returns something like "B5:BD162"
#' }
#'
#' @importFrom readxl read_excel excel_sheets
get_range_new <- function(path = NULL, sheet, skip_row = 4) {
  # Input validation
  if (is.null(path)) {
    stop("Path to Excel file must be provided")
  }
  if (!file.exists(path)) {
    stop("Excel file not found at specified path")
  }

  # Read the sheet
  df <- readxl::read_excel(path,
                           sheet = sheet,
                           col_names = TRUE,
                           .name_repair = "minimal")

  # Get dimensions of the data
  dims <- readxl::excel_sheets(path) |>
    purrr::set_names() |>
    purrr::map(~readxl::read_excel(path, sheet = .x, col_names = FALSE)) |>
    purrr::map(dim) |>
    _[[sheet]]

  # Find the last row with dates
  date_cols <- which(sapply(df, inherits, "POSIXct") |
                       sapply(df, inherits, "Date"))

  if (length(date_cols) == 0) {
    stop("No date columns found in the sheet")
  }

  last_date_row <- max(which(!is.na(df[date_cols[1]])))

  # Find the last non-NA column
  last_col <- max(which(colSums(!is.na(df)) > 0))

  # Convert column numbers to Excel column letters
  number_to_letter <- function(n) {
    if (n <= 0) return("")

    letter <- ""
    while (n > 0) {
      n <- n - 1
      letter <- paste0(LETTERS[(n %% 26) + 1], letter)
      n <- n %/% 26
    }
    return(letter)
  }

  # Create range string
  start_col <- number_to_letter(1)  # Usually starts from first column
  start_row <- skip_row + 1
  end_col <- number_to_letter(last_col)
  end_row <- last_date_row

  range_excel <- paste0(start_col, start_row, ":", end_col, end_row)

  return(range_excel)
}



add_geo_dimensions <- function(df, key = c("name_simplified", "abbrev_state")) {

  # Join original table with geographic dimension
  joined <- dplyr::left_join(df, dim_city, by = key)
  return(joined)

}

#' Import cached data from Github
#'
#' A helper function to download the cached data from the GitHub repository. The
#' `csv` files are imported with `vroom::vroom` with pre-defined column types to
#' ensure consistency. The `rds` files are read with `readr::read_rds`.
#'
#' @param table String with the name of the table/file.
#'
#' @return Either a named `list` or a `tibble`
import_cached <- function(table) {

  base_url <- "https://github.com/viniciusoike/realestatebr/raw/main/cached_data/"

  import_params <- list(
    rppi_sale = list(
      ctypes = "cDcddd",
      link = paste0(base_url, "rppi_sale.csv.gz")
    ),
    rppi_rent = list(
      ctypes = "cDcdddd",
      link = paste0(base_url, "rppi_rent.csv.gz")
    ),
    secovi_sp = list(
      ctypes = "Dcccd",
      link = paste0(base_url, "secovi_sp.csv.gz")
    ),
    bcb_series = list(
      ctypes = "DddfccccfDDc",
      link = paste0(base_url, "bcb_series.csv.gz")
    ),
    bcb_realestate = list(
      ctypes = "Dfcccccccdiic",
      link = paste0(base_url, "bcb_realestate.csv.gz")
    ),
    b3_stocks = list(
      ctypes = "cDdddddd",
      link = paste0(base_url, "b3_stocks.csv.gz")
    ),
    bis_selected = list(
      ctypes = "Dcdcfclcccci",
      link = paste0(base_url, "bis_selected.csv.gz")
    ),
    fgv_indicators = list(
      ctypes = "Dcdcdcc",
      link = paste0(base_url, "fgv_indicators.csv.gz")
    ),
    rppi_fipe = list(
      ctypes = "Dcccccd",
      link = paste0(base_url, "rppi_fipe.csv.gz")
    ),
    abrainc = list(link = paste0(base_url, "abrainc.rds")),
    abecip  = list(link = paste0(base_url, "abecip.rds")),
    bis_detailed = list(link = paste0(base_url, "bis_detailed.rds")),
    property_records = list(link = paste0(base_url, "property_records.rds"))
  )
  p <- import_params[[table]]
  if (length(p) == 1) {
    readr::read_rds(p$link)
  } else {
    vroom::vroom(p$link, col_types = p$ctypes)
  }

}
