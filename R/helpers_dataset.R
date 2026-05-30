# Parameter validation -------------------------------------------------------

#' Generic Parameter Validation for Dataset Functions
#'
#' Validates common parameters used across all dataset functions.
#'
#' @param table Character. The table parameter to validate.
#' @param valid_tables Character vector. Valid table names for the dataset.
#' @param quiet Logical. Whether to suppress messages.
#' @param max_retries Numeric. Maximum number of retry attempts.
#' @param allow_all Logical. Whether "all" is a valid table value. Default TRUE.
#'
#' @return Invisible TRUE if all validations pass. Errors otherwise.
#'
#' @keywords internal
validate_dataset_params <- function(
  table,
  valid_tables,
  quiet,
  max_retries,
  allow_all = TRUE
) {
  if (!is.character(table) || length(table) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg table} parameter",
      "x" = "{.arg table} must be a single character string"
    ))
  }

  valid_values <- if (allow_all) c(valid_tables, "all") else valid_tables

  if (!table %in% valid_values) {
    cli::cli_abort(c(
      "Invalid table: {.val {table}}",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  if (!is.logical(quiet) || length(quiet) != 1) {
    cli::cli_abort("{.arg quiet} must be a logical value")
  }

  if (!is.numeric(max_retries) || length(max_retries) != 1 || max_retries < 1) {
    cli::cli_abort("{.arg max_retries} must be a positive integer")
  }

  invisible(TRUE)
}

# Metadata attachment --------------------------------------------------------

#' Attach Standard Metadata to Dataset
#'
#' Attaches standardized metadata attributes to a dataset. Consolidates
#' metadata attachment logic used across all dataset functions.
#'
#' @param data Data frame or tibble. The dataset to attach metadata to.
#' @param source Character. Data source: `"web"` (fresh from the original
#'   source), `"github"` (the package's GitHub release), or `"bundled"`
#'   (static file shipped with the package in `inst/extdata`).
#' @param category Character or NULL. Dataset category/table name.
#' @param extra_info List. Additional metadata to include in download_info.
#'
#' @return The data with metadata attributes attached.
#'
#' @keywords internal
attach_dataset_metadata <- function(
  data,
  source = c("web", "github", "bundled"),
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

# Data validation -------------------------------------------------------------

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
    date_range <- rlang::try_fetch(
      range(data$date, na.rm = FALSE),
      error = function(cnd) c(NA, NA)
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
