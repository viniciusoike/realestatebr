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
