#' Get Residential Property Price Indices from BIS (DEPRECATED)
#'
#' @section Deprecation:
#' This function is deprecated since v0.4.0.
#' Use \code{\link{get_dataset}}("rppi_bis") instead:
#'
#' \preformatted{
#'   # Old way:
#'   data <- get_rppi_bis()
#'
#'   # New way:
#'   data <- get_dataset("rppi_bis")
#' }
#'
#' @details
#' Downloads Residential Property Price Indices from BIS with support for selected
#' series and detailed monthly/quarterly/annual/semiannual datasets.
#'
#' @param table Character. Which dataset table to return:
#'   \describe{
#'     \item{"selected"}{Selected RPPI series for major countries (default)}
#'     \item{"detailed_monthly"}{Monthly detailed RPPI data}
#'     \item{"detailed_quarterly"}{Quarterly detailed RPPI data}
#'     \item{"detailed_annual"}{Annual detailed RPPI data}
#'     \item{"detailed_semiannual"}{Semiannual detailed RPPI data}
#'   }
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   Excel download operations. Defaults to 3.
#'
#' @source [https://data.bis.org/topics/RPP](https://data.bis.org/topics/RPP)
#' @return A `tibble` with the requested RPPI data.
#'   The return includes metadata attributes:
#'   \describe{
#'     \item{download_info}{List with download statistics}
#'     \item{source}{Data source used (web or cache)}
#'     \item{download_time}{Timestamp of download}
#'   }
#'
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr rename mutate left_join select filter if_else
#' @importFrom tidyr pivot_longer
#' @keywords internal
#' @export
get_rppi_bis <- function(
  table = "selected",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
  valid_tables <- c("selected", "detailed_monthly", "detailed_quarterly",
                    "detailed_annual", "detailed_semiannual")


  if (!is.character(table) || length(table) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg table} parameter",
      "x" = "{.arg table} must be a single character string",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  if (!table %in% valid_tables) {
    cli::cli_abort(c(
      "Invalid table: {.val {table}}",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  if (!is.logical(cached) || length(cached) != 1) {
    cli::cli_abort("{.arg cached} must be a logical value")
  }

  if (!is.logical(quiet) || length(quiet) != 1) {
    cli::cli_abort("{.arg quiet} must be a logical value")
  }

  if (!is.numeric(max_retries) || length(max_retries) != 1 || max_retries < 1) {
    cli::cli_abort("{.arg max_retries} must be a positive integer")
  }

  # Handle cached data ----
  if (cached) {
    cli_debug("Loading BIS RPPI data from cache...")

    tryCatch(
      {
        # Use new unified architecture for cached data
        data <- get_dataset("rppi_bis", table, source = "github")

        total_records <- if (is.list(data)) sum(sapply(data, nrow)) else nrow(data)
        cli_debug("Successfully loaded {total_records} BIS RPPI records from cache")

        # Add metadata
        attr(data, "source") <- "cache"
        attr(data, "download_time") <- Sys.time()
        attr(data, "download_info") <- list(
          table = table,
          source = "cache"
        )

        return(data)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load cached data: {e$message}",
            "i" = "Falling back to fresh download from BIS"
          ))
        }
      }
    )
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

  # Add metadata attributes
  attr(df, "source") <- "web"
  attr(df, "download_time") <- Sys.time()
  attr(df, "download_info") <- list(
    table = table,
    source = "web"
  )

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

  temp_path <- download_bis_excel_robust(
    url = "https://www.bis.org/statistics/pp/pp_selected.xlsx",
    filename = "bis_rppi_selected.xlsx",
    quiet = quiet,
    max_retries = max_retries
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

  temp_path <- download_bis_excel_robust(
    url = "https://www.bis.org/statistics/pp/pp_detailed.xlsx",
    filename = "bis_rppi_detailed.xlsx",
    quiet = quiet,
    max_retries = max_retries
  )

  cli_debug("Processing BIS detailed RPPI data...")

  return(process_bis_detailed_data(temp_path, quiet))
}

#' Download BIS Excel File with Robust Error Handling
#'
#' Internal function to download BIS Excel files with retry logic.
#'
#' @param url URL to download from
#' @param filename Filename for temporary file
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Path to downloaded temporary Excel file
#' @keywords internal
download_bis_excel_robust <- function(url, filename, quiet, max_retries) {
  attempts <- 0
  last_error <- NULL

  while (attempts <= max_retries) {
    attempts <- attempts + 1

    tryCatch(
      {
        # Download the Excel file
        temp_path <- tempfile(filename)
        response <- httr::GET(url, httr::write_disk(temp_path, overwrite = TRUE))

        # Check if download was successful
        httr::stop_for_status(response)

        # Verify file exists and has content
        if (!file.exists(temp_path) || file.size(temp_path) == 0) {
          stop("Downloaded Excel file is empty or missing")
        }

        return(temp_path)
      },
      error = function(e) {
        last_error <<- e$message

        if (!quiet && attempts <= max_retries) {
          cli::cli_warn(c(
            "BIS Excel download failed (attempt {attempts}/{max_retries + 1})",
            "x" = "Error: {e$message}",
            "i" = "Retrying in {min(attempts * 0.5, 3)} second{?s}..."
          ))
        }

        # Add delay before retry
        if (attempts <= max_retries) {
          Sys.sleep(min(attempts * 0.5, 3))
        }
      }
    )
  }

  # All attempts failed
  cli::cli_abort(c(
    "Failed to download BIS Excel file",
    "x" = "All {max_retries + 1} attempt{?s} failed",
    "i" = "Last error: {last_error}",
    "i" = "Check your internet connection and BIS website status"
  ))
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
