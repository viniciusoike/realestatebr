# Generic Helper Functions for Dataset Operations
# Created: 2025-10-15 (v0.6.0 Phase 3)
# Purpose: Consolidate repetitive logic across dataset functions

# ==============================================================================
# HELPER 1: PARAMETER VALIDATION
# ==============================================================================

#' Generic Parameter Validation for Dataset Functions
#'
#' Validates common parameters used across all dataset functions. This
#' consolidates repetitive validation logic into a single reusable function.
#'
#' @param table Character. The table parameter to validate.
#' @param valid_tables Character vector. Valid table names for the dataset.
#' @param cached Logical. Whether to use cached data.
#' @param quiet Logical. Whether to suppress messages.
#' @param max_retries Numeric. Maximum number of retry attempts.
#' @param allow_all Logical. Whether "all" is a valid table value. Default TRUE.
#'
#' @return Invisible TRUE if all validations pass. Errors otherwise.
#'
#' @details
#' This function performs standard validation for:
#' - table: Must be character, length 1, in valid_tables (or "all" if allowed)
#' - cached: Must be logical, length 1
#' - quiet: Must be logical, length 1
#' - max_retries: Must be numeric, length 1, positive
#'
#' @keywords internal
validate_dataset_params <- function(
  table,
  valid_tables,
  cached,
  quiet,
  max_retries,
  allow_all = TRUE
) {
  # Validate table parameter
  if (!is.character(table) || length(table) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg table} parameter",
      "x" = "{.arg table} must be a single character string"
    ))
  }

  # Check if table is in valid tables (or "all" if allowed)
  valid_values <- if (allow_all) c(valid_tables, "all") else valid_tables

  if (!table %in% valid_values) {
    cli::cli_abort(c(
      "Invalid table: {.val {table}}",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  # Validate cached parameter
  if (!is.logical(cached) || length(cached) != 1) {
    cli::cli_abort("{.arg cached} must be a logical value")
  }

  # Validate quiet parameter
  if (!is.logical(quiet) || length(quiet) != 1) {
    cli::cli_abort("{.arg quiet} must be a logical value")
  }

  # Validate max_retries parameter
  if (!is.numeric(max_retries) || length(max_retries) != 1 || max_retries < 1) {
    cli::cli_abort("{.arg max_retries} must be a positive integer")
  }

  invisible(TRUE)
}

# ==============================================================================
# HELPER 2: CACHE HANDLING
# ==============================================================================

#' Generic Cache Handler with Fallback
#'
#' Attempts to load data from user cache with configurable fallback behavior.
#' Consolidates cache loading logic used across all dataset functions.
#'
#' @param dataset_name Character. Name of the dataset (e.g., "abecip").
#' @param table Character or NULL. Specific table to extract from cached data.
#'   If NULL, returns entire cached dataset.
#' @param quiet Logical. Whether to suppress informational messages.
#' @param on_miss Character. What to do on cache miss:
#'   - "return_null": Return NULL silently
#'   - "error": Throw an error
#'   - "download": Return NULL to trigger download (default)
#'
#' @return The cached data (tibble or list), or NULL on cache miss.
#'
#' @details
#' The function attempts to load data from the user cache directory
#' (`~/.local/share/realestatebr/` or equivalent). If a table parameter is
#' provided, it extracts that specific table from the cached dataset.
#'
#' On cache miss, behavior is controlled by `on_miss`:
#' - "return_null": Quietly returns NULL (caller handles fallback)
#' - "error": Throws error (use when cache is required)
#' - "download": Returns NULL with warning (triggers download in caller)
#'
#' @keywords internal
handle_dataset_cache <- function(
  dataset_name,
  table = NULL,
  quiet = FALSE,
  on_miss = c("download", "return_null", "error")
) {
  on_miss <- match.arg(on_miss)

  if (!quiet) {
    cli::cli_inform("Loading {dataset_name} data from cache...")
  }

  tryCatch(
    {
      # Attempt to load from user cache
      cached_data <- load_from_user_cache(dataset_name, quiet = quiet)

      # Handle cache miss
      if (is.null(cached_data)) {
        if (!quiet) {
          if (on_miss == "download") {
            cli::cli_warn("Data not found in user cache, falling back to fresh download")
          } else if (on_miss == "return_null") {
            cli::cli_inform("Data not found in user cache")
          }
        }

        if (on_miss == "error") {
          cli::cli_abort("Cache miss for {dataset_name}")
        }

        # Return NULL for "download" and "return_null"
        return(NULL)
      }

      # Extract specific table if requested
      if (!is.null(table) && table != "all") {
        if (table %in% names(cached_data)) {
          data <- cached_data[[table]]
        } else {
          available <- paste(names(cached_data), collapse = ", ")
          cli::cli_abort(
            "Table '{table}' not found in cached data. Available: {available}"
          )
        }
      } else {
        # Return full cached dataset
        data <- cached_data
      }

      if (!quiet) {
        cli::cli_inform("Successfully loaded data from cache")
      }

      return(data)
    },
    error = function(e) {
      if (!quiet) {
        cli::cli_warn(c(
          "Failed to load cached data: {e$message}",
          "i" = "Falling back to fresh download"
        ))
      }

      if (on_miss == "error") {
        stop(e)
      }

      return(NULL)
    }
  )
}

# ==============================================================================
# HELPER 3: DOWNLOAD WITH RETRY
# ==============================================================================

# NOTE: download_with_retry() already exists in R/rppi-helpers.R
# We reuse that existing implementation rather than creating a duplicate.
# The existing function signature is:
#   download_with_retry(fn, max_retries = 3, quiet = FALSE, desc = "Download")
#
# This consolidates retry logic across all dataset functions.

# ==============================================================================
# HELPER 4: METADATA ATTACHMENT
# ==============================================================================

#' Attach Standard Metadata to Dataset
#'
#' Attaches standardized metadata attributes to a dataset. Consolidates
#' metadata attachment logic used across all dataset functions.
#'
#' @param data Data frame or tibble. The dataset to attach metadata to.
#' @param source Character. Data source: "web", "cache", or "github".
#' @param category Character or NULL. Dataset category/table name.
#' @param extra_info List. Additional metadata to include in download_info.
#'
#' @return The data with metadata attributes attached.
#'
#' @details
#' Attaches three standard attributes:
#' - `source`: Where the data came from ("web", "cache", "github")
#' - `download_time`: Timestamp when data was retrieved
#' - `download_info`: List with source, category, and any extra_info
#'
#' The metadata is preserved when subsetting but may be lost during some
#' transformations. Use `attributes()` to inspect metadata.
#'
#' @examples
#' \dontrun{
#' data <- attach_dataset_metadata(
#'   data,
#'   source = "web",
#'   category = "sbpe",
#'   extra_info = list(attempts = 1, url = "https://...")
#' )
#'
#' # Inspect metadata
#' attributes(data)$source # "web"
#' attributes(data)$download_time # POSIXct timestamp
#' attributes(data)$download_info # List with details
#' }
#'
#' @keywords internal
attach_dataset_metadata <- function(
  data,
  source = c("web", "cache", "github"),
  category = NULL,
  extra_info = list()
) {
  source <- match.arg(source)

  # Attach standard attributes
  attr(data, "source") <- source
  attr(data, "download_time") <- Sys.time()

  # Build download_info list
  download_info <- list(
    source = source
  )

  # Add category if provided
  if (!is.null(category)) {
    download_info$category <- category
  }

  # Merge in extra_info
  if (length(extra_info) > 0) {
    download_info <- c(download_info, extra_info)
  }

  attr(data, "download_info") <- download_info

  return(data)
}

# ==============================================================================
# HELPER 5: DATA VALIDATION
# ==============================================================================

#' Generic Data Validation
#'
#' Validates basic dataset requirements. Consolidates validation logic
#' used across all dataset functions.
#'
#' @param data Data frame or tibble. The dataset to validate.
#' @param dataset_name Character. Name of dataset for error messages.
#' @param required_cols Character vector. Required column names.
#'   Default is "date".
#' @param min_rows Integer. Minimum expected number of rows. Default 1.
#' @param check_dates Logical. Whether to validate date column. Default TRUE.
#' @param max_future_days Integer. Maximum days in future allowed for dates.
#'   Default 90.
#'
#' @return Invisible TRUE if all validations pass. Errors or warns otherwise.
#'
#' @details
#' Performs the following checks:
#' 1. Data is not empty (nrow > 0)
#' 2. Minimum row count met
#' 3. Required columns present
#' 4. Date column valid (if check_dates = TRUE)
#' 5. Dates not too far in future (if check_dates = TRUE)
#'
#' Throws errors for critical issues (empty data, missing columns, invalid dates).
#' Issues warnings for suspicious values (low row count, future dates).
#'
#' @examples
#' \dontrun{
#' # Basic validation (just check for date column)
#' validate_dataset(data, "abecip")
#'
#' # Validate specific columns
#' validate_dataset(
#'   data,
#'   "abecip_units",
#'   required_cols = c("date", "units_construction", "units_acquisition")
#' )
#'
#' # Skip date validation
#' validate_dataset(data, "cbic", check_dates = FALSE)
#' }
#'
#' @keywords internal
validate_dataset <- function(
  data,
  dataset_name,
  required_cols = "date",
  min_rows = 1,
  check_dates = TRUE,
  max_future_days = 90
) {
  # Check if data is empty
  if (nrow(data) == 0) {
    cli::cli_abort(c(
      "Downloaded {dataset_name} data is empty",
      "i" = "The data source may be temporarily unavailable"
    ))
  }

  # Check minimum rows
  if (nrow(data) < min_rows) {
    cli::cli_warn(
      "{dataset_name} data has only {nrow(data)} row{?s} (expected >= {min_rows})"
    )
  }

  # Check for required columns
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "Missing required columns in {dataset_name}",
      "x" = "Missing: {.val {missing_cols}}",
      "i" = "The data format may have changed"
    ))
  }

  # Check dates if requested and date column exists
  if (check_dates && "date" %in% names(data)) {
    # Check if there are any NA dates
    na_count <- sum(is.na(data$date))
    if (na_count > 0) {
      cli::cli_abort(c(
        "Invalid dates in {dataset_name} data",
        "x" = "{na_count} NA date{?s} found",
        "i" = "Date column may contain non-date values"
      ))
    }

    # Get date range (only if no NAs)
    date_range <- tryCatch(
      range(data$date, na.rm = FALSE),
      error = function(e) c(NA, NA)
    )

    # Check for invalid dates (shouldn't happen after NA check, but defensive)
    if (any(is.na(date_range))) {
      cli::cli_abort(c(
        "Invalid dates in {dataset_name} data",
        "i" = "Date column contains non-date values"
      ))
    }

    # Check for dates too far in future
    max_date <- date_range[2]
    max_allowed <- Sys.Date() + max_future_days

    if (!is.na(max_date) && max_date > max_allowed) {
      cli::cli_warn(c(
        "Some dates in {dataset_name} are more than {max_future_days} days in future",
        "i" = "Latest date: {as.character(max_date)}",
        "i" = "This may indicate a data quality issue"
      ))
    }
  }

  invisible(TRUE)
}

# ==============================================================================
# BONUS HELPER: EXCEL FILE VALIDATION
# ==============================================================================

#' Validate Excel File Download
#'
#' Validates that a downloaded Excel file is valid and contains expected sheets.
#' Useful for datasets downloaded from Excel sources (e.g., Abrainc, Abecip).
#'
#' @param path Character. Path to the Excel file.
#' @param expected_sheets Character vector. Sheet names that must be present.
#' @param min_size Numeric. Minimum file size in bytes. Default 1000.
#'
#' @return Invisible TRUE if all validations pass. Errors otherwise.
#'
#' @details
#' Performs the following checks:
#' 1. File exists and is readable
#' 2. File size meets minimum threshold
#' 3. File is a valid Excel file (can read sheets)
#' 4. All expected sheets are present
#'
#' This is particularly useful after download operations to ensure the
#' download completed successfully and the file structure is as expected.
#'
#' @examples
#' \dontrun{
#' validate_excel_file(
#'   temp_path,
#'   expected_sheets = c("Indicadores Abrainc-Fipe", "Radar Abrainc-Fipe")
#' )
#' }
#'
#' @keywords internal
validate_excel_file <- function(
  path,
  expected_sheets,
  min_size = 1000
) {
  # Check file exists and has content
  if (!file.exists(path)) {
    cli::cli_abort("Excel file not found at {.path {path}}")
  }

  file_size <- file.size(path)
  if (is.na(file_size) || file_size < min_size) {
    cli::cli_abort(c(
      "Downloaded Excel file is too small or empty",
      "i" = "File size: {file_size} bytes (minimum: {min_size})"
    ))
  }

  # Try to read Excel sheets
  sheets <- tryCatch(
    readxl::excel_sheets(path),
    error = function(e) {
      cli::cli_abort(c(
        "Downloaded file is not a valid Excel file",
        "x" = "Error: {e$message}"
      ))
    }
  )

  # Check for expected sheets
  missing_sheets <- setdiff(expected_sheets, sheets)
  if (length(missing_sheets) > 0) {
    cli::cli_abort(c(
      "Downloaded Excel file is missing expected sheets",
      "x" = "Missing: {.val {missing_sheets}}",
      "i" = "Available: {.val {sheets}}"
    ))
  }

  invisible(TRUE)
}
