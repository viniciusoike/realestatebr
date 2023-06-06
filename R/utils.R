#' Finds import range for each table
#'
#' @param path Path to excel file
#' @param sheet Name or number of sheet to be analyzed
#'
#' @details Based on the date column, finds the range to be imported.
#' @noRd
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

add_geo_dimensions <- function(
    df,
    key = c("name_simplified", "abbrev_state"),
    update = FALSE) {

  # Join original table with geographic dimension
  joined <- dplyr::left_join(df, dim_geo, by = key)

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
    bis_selected = list(
      ctypes = "Dcdcfclcccci",
      link = paste0(base_url, "bis_selected.csv.gz")
    ),
    fgv_indicators = list(
      cytpes = "Dcdcdcc",
      link = paste0(base_url, "fgv_indicators.csv.gz")
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
