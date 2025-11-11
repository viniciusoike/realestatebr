#' Get Residential Property Price Indices from BIS (DEPRECATED)
#'
#' @description
#' Deprecated since v0.4.0. Use \code{\link{get_dataset}}("rppi_bis") instead.
#' Downloads Residential Property Price Indices from BIS with support for selected
#' series and detailed monthly/quarterly/annual/semiannual datasets.
#'
#' @param table Character. Dataset table: "selected", "detailed_monthly",
#'   "detailed_quarterly", "detailed_annual", or "detailed_semiannual".
#' @param cached Logical. If `TRUE`, loads data from cache.
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param max_retries Integer. Maximum retry attempts. Defaults to 3.
#'
#' @return Tibble with BIS RPPI data. Includes metadata attributes:
#'   source, download_time.
#'
#' @source \url{https://data.bis.org/topics/RPP}
#' @keywords internal
get_rppi_bis <- function(
  table = "selected",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
  valid_tables <- c(
    "selected",
    "detailed_monthly",
    "detailed_quarterly",
    "detailed_annual",
    "detailed_semiannual"
  )

  validate_dataset_params(
    table,
    valid_tables,
    cached,
    quiet,
    max_retries,
    allow_all = FALSE
  )

  # Handle cached data ----
  if (cached) {
    data <- handle_dataset_cache(
      "rppi_bis",
      table = table,
      quiet = quiet,
      on_miss = "download"
    )

    if (!is.null(data)) {
      data <- attach_dataset_metadata(data, source = "cache", category = table)
      return(data)
    }
  }

  # Download and process data ----
  cli_user("Downloading BIS RPPI data for table '{table}'", quiet = quiet)

  # Handle selected data
  if (table == "selected") {
    df <- get_rppi_bis_selected_robust(quiet = quiet, max_retries = max_retries)

  } else {
    # Handle detailed data tables
    detailed_data <- get_rppi_bis_detailed_robust(quiet = quiet, max_retries = max_retries)

    # Extract the specific table from detailed data
    # Names are cleaned Excel sheet names (from sheets 3-6)
    df <- switch(table,
      "detailed_monthly" = detailed_data[[1]],  # First detailed sheet (typically monthly)
      "detailed_quarterly" = detailed_data[[2]], # Second detailed sheet (typically quarterly)
      "detailed_annual" = detailed_data[[3]],   # Third detailed sheet (typically annual)
      "detailed_semiannual" = detailed_data[[4]], # Fourth detailed sheet (typically semiannual)
      stop("Unknown detailed table: ", table)
    )

    if (is.null(df)) {
      cli::cli_abort("Failed to extract table '{table}' from detailed data")
    }
  }

  # Add metadata
  df <- attach_dataset_metadata(df, source = "web", category = table)

  cli_user("\u2713 BIS RPPI data retrieved: {nrow(df)} records", quiet = quiet)

  return(df)
}


#' Get RPPI BIS Selected Data with Robust Error Handling
#'
#' Internal function to download BIS RPPI selected data with retry logic.
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Downloaded and processed BIS selected data
#' @keywords internal
get_rppi_bis_selected_robust <- function(quiet, max_retries) {
  cli_debug("Downloading BIS selected RPPI Excel file...")

  temp_path <- download_with_retry(
    fn = function() download_bis_excel(
      url = "https://www.bis.org/statistics/pp/pp_selected.xlsx",
      filename = "bis_rppi_selected.xlsx"
    ),
    max_retries = max_retries,
    quiet = quiet,
    desc = "BIS RPPI selected Excel"
  )

  cli_debug("Processing BIS selected RPPI data...")

  return(process_bis_selected_data(temp_path, quiet))
}

#' Get RPPI BIS Detailed Data with Robust Error Handling
#'
#' Internal function to download BIS RPPI detailed data with retry logic.
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Downloaded and processed BIS detailed data
#' @keywords internal
get_rppi_bis_detailed_robust <- function(quiet, max_retries) {
  cli_debug("Downloading BIS detailed RPPI Excel file...")

  temp_path <- download_with_retry(
    fn = function() download_bis_excel(
      url = "https://www.bis.org/statistics/pp/pp_detailed.xlsx",
      filename = "bis_rppi_detailed.xlsx"
    ),
    max_retries = max_retries,
    quiet = quiet,
    desc = "BIS RPPI detailed Excel"
  )

  cli_debug("Processing BIS detailed RPPI data...")

  return(process_bis_detailed_data(temp_path, quiet))
}

#' Download BIS Excel File
#'
#' Internal function to download BIS Excel file.
#'
#' @param url URL to download from
#' @param filename Filename for temporary file
#'
#' @return Path to downloaded temporary Excel file
#' @keywords internal
download_bis_excel <- function(url, filename) {
  temp_path <- tempfile(filename)
  response <- httr::GET(url, httr::write_disk(temp_path, overwrite = TRUE))

  # Check if download was successful
  httr::stop_for_status(response)

  # Verify file exists and has content
  if (!file.exists(temp_path) || file.size(temp_path) == 0) {
    stop("Downloaded Excel file is empty or missing")
  }

  return(temp_path)
}

#' Process BIS Selected Data
#'
#' Internal function to process BIS selected Excel data.
#'
#' @param temp_path Path to downloaded Excel file
#' @param quiet Logical controlling messages
#'
#' @return Processed BIS selected data
#' @keywords internal
process_bis_selected_data <- function(temp_path, quiet) {
  # Import spreadsheet into R
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

  cli_debug("Cleaning and merging BIS selected data...")

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

#' Process BIS Detailed Data
#'
#' Internal function to process BIS detailed Excel data.
#'
#' @param temp_path Path to downloaded Excel file
#' @param quiet Logical controlling messages
#'
#' @return Processed BIS detailed data as named list
#' @keywords internal
process_bis_detailed_data <- function(temp_path, quiet) {
  # Import data from sheets 3 through 6
  sheets <- purrr::map(3:6, function(x) {
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

  cli_debug("Processing {length(sheets)} detailed data sheets...")

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
