# data-raw/validation.R
# Simple validation functions for Phase 2 pipeline

#' Validate Dataset Structure and Content
#'
#' Perform basic validation checks on datasets without heavy dependencies
#'
#' @param data Dataset to validate (tibble or list)
#' @param dataset_name Name of the dataset for reporting
#' @param schema Optional list of expected column specifications
#'
#' @return List with validation results
validate_dataset <- function(data, dataset_name, schema = NULL) {
  checks <- list()
  dataset_type <- class(data)[1]

  cli::cli_inform("Validating {dataset_name} ({dataset_type})...")

  # ---- BASIC STRUCTURE CHECKS ----

  # Check if data exists and is not empty
  checks$data_exists <- !is.null(data)
  checks$not_empty <- if (is.data.frame(data)) {
    nrow(data) > 0
  } else if (is.list(data)) {
    length(data) > 0
  } else {
    length(data) > 0
  }

  # For data frames, check columns
  if (is.data.frame(data)) {
    checks$has_columns <- ncol(data) > 0

    # Check for required columns based on dataset
    required_cols <- get_required_columns(dataset_name)
    if (!is.null(required_cols)) {
      missing_cols <- setdiff(required_cols, names(data))
      checks$required_columns <- length(missing_cols) == 0
      if (length(missing_cols) > 0) {
        checks$missing_columns <- missing_cols
      }
    }

    # ---- DATE VALIDATION ----
    date_columns <- names(data)[sapply(data, function(x) inherits(x, "Date") || inherits(x, "POSIXt"))]
    if (length(date_columns) > 0) {
      for (date_col in date_columns) {
        col_name <- paste0("valid_dates_", date_col)
        date_values <- data[[date_col]][!is.na(data[[date_col]])]

        if (length(date_values) > 0) {
          # Check date range is reasonable
          min_date <- min(date_values)
          max_date <- max(date_values)

          checks[[col_name]] <- (
            min_date >= as.Date("1990-01-01") &&
            max_date <= (Sys.Date() + 365)  # Allow up to 1 year in future
          )

          # Check for date continuity (no huge gaps)
          if (length(date_values) > 1) {
            date_diff <- as.numeric(diff(sort(date_values)))
            max_gap <- max(date_diff, na.rm = TRUE)
            gap_name <- paste0("reasonable_gaps_", date_col)
            checks[[gap_name]] <- max_gap <= 366  # Max 1 year gap
          }
        }
      }
    }

    # ---- NUMERIC VALIDATION ----
    numeric_columns <- names(data)[sapply(data, is.numeric)]
    if (length(numeric_columns) > 0) {
      for (num_col in numeric_columns) {
        col_values <- data[[num_col]][!is.na(data[[num_col]])]

        if (length(col_values) > 0) {
          # Check for extreme outliers
          outlier_name <- paste0("outliers_", num_col)
          if (length(col_values) >= 10) {  # Need sufficient data for outlier detection
            Q1 <- quantile(col_values, 0.25, na.rm = TRUE)
            Q3 <- quantile(col_values, 0.75, na.rm = TRUE)
            IQR <- Q3 - Q1
            lower_bound <- Q1 - 3 * IQR
            upper_bound <- Q3 + 3 * IQR

            outliers <- sum(col_values < lower_bound | col_values > upper_bound)
            outlier_pct <- outliers / length(col_values)
            checks[[outlier_name]] <- outlier_pct < 0.05  # Less than 5% outliers
          }

          # Check for reasonable ranges for specific variables
          range_check <- check_variable_ranges(num_col, col_values, dataset_name)
          if (!is.null(range_check)) {
            range_name <- paste0("range_", num_col)
            checks[[range_name]] <- range_check
          }
        }
      }
    }

    # ---- DATA QUALITY CHECKS ----

    # Check for excessive missing data
    missing_pct <- sapply(data, function(x) sum(is.na(x)) / length(x))
    checks$acceptable_missing <- all(missing_pct < 0.5)  # Less than 50% missing per column

    # Check for duplicate rows
    if (nrow(data) > 1) {
      duplicate_rows <- sum(duplicated(data))
      checks$no_excessive_duplicates <- duplicate_rows < (nrow(data) * 0.1)  # Less than 10% duplicates
    }

  } else if (is.list(data)) {
    # For list data (like RPPI or ABRAINC), validate each component
    checks$valid_list_structure <- is.list(data) && length(names(data)) > 0

    # Check each list element
    for (element_name in names(data)) {
      element_data <- data[[element_name]]
      if (is.data.frame(element_data)) {
        element_checks <- validate_dataset(element_data, paste0(dataset_name, "_", element_name))
        checks[[paste0("element_", element_name, "_valid")]] <- element_checks$overall_passed
      }
    }
  }

  # ---- DATASET-SPECIFIC VALIDATION ----
  specific_checks <- validate_dataset_specific(data, dataset_name)
  if (!is.null(specific_checks)) {
    checks <- c(checks, specific_checks)
  }

  # ---- SUMMARY ----
  checks$overall_passed <- all(unlist(checks[sapply(checks, is.logical)]))

  validation_result <- list(
    dataset = dataset_name,
    timestamp = Sys.time(),
    dataset_type = dataset_type,
    checks = checks,
    passed = checks$overall_passed,
    summary = create_validation_summary(checks, dataset_name)
  )

  # Report results
  if (validation_result$passed) {
    cli::cli_alert_success("✓ {dataset_name} passed all validation checks")
  } else {
    failed_checks <- names(checks)[sapply(checks, function(x) is.logical(x) && !x)]
    cli::cli_alert_warning("⚠ {dataset_name} failed {length(failed_checks)} checks: {paste(failed_checks, collapse=', ')}")
  }

  return(validation_result)
}

#' Get Required Columns for Dataset
#'
#' Define expected columns for each dataset type
#'
get_required_columns <- function(dataset_name) {
  required_columns <- list(
    "bcb_series" = c("date", "series_code", "series_name", "value"),
    "bcb_realestate" = c("date", "series_code", "series_name", "value"),
    "b3_stocks" = c("date", "ticker", "close_price"),
    "fgv_indicators" = c("date", "indicator", "value"),
    "secovi_sp" = c("date", "region", "indicator", "value"),
    "bis_selected" = c("date", "country", "value"),
    "cbic" = c("date", "indicator", "value"),
    "property_records" = c("date", "state", "transactions"),
    "nre_ire" = c("date", "type", "value")
  )

  return(required_columns[[dataset_name]])
}

#' Check Variable Ranges
#'
#' Validate that numeric variables are within reasonable ranges
#'
check_variable_ranges <- function(column_name, values, dataset_name) {
  # Define reasonable ranges for common variables
  ranges <- list(
    # Prices and indices (should be positive)
    "value" = c(0, Inf),
    "price" = c(0, Inf),
    "index" = c(0, 1000),
    "close_price" = c(0, Inf),

    # Percentage changes (reasonable for Brazilian real estate)
    "change" = c(-50, 100),
    "pct_change" = c(-50, 100),
    "growth" = c(-50, 100),

    # Interest rates (Brazilian context)
    "interest_rate" = c(0, 50),
    "selic" = c(0, 30),

    # Transaction counts
    "transactions" = c(0, Inf),
    "volume" = c(0, Inf)
  )

  # Check if column matches any known patterns
  for (pattern in names(ranges)) {
    if (grepl(pattern, column_name, ignore.case = TRUE)) {
      range_bounds <- ranges[[pattern]]
      min_bound <- range_bounds[1]
      max_bound <- range_bounds[2]

      if (is.finite(max_bound)) {
        return(all(values >= min_bound & values <= max_bound, na.rm = TRUE))
      } else {
        return(all(values >= min_bound, na.rm = TRUE))
      }
    }
  }

  return(NULL)  # No specific range check
}

#' Dataset-Specific Validation
#'
#' Additional validation rules specific to certain datasets
#'
validate_dataset_specific <- function(data, dataset_name) {
  specific_checks <- list()

  if (dataset_name == "bcb_series") {
    # BCB series should have reasonable series codes
    if ("series_code" %in% names(data)) {
      specific_checks$valid_series_codes <- all(nchar(as.character(data$series_code)) > 0)
    }

  } else if (dataset_name == "b3_stocks") {
    # B3 stocks should have valid ticker symbols
    if ("ticker" %in% names(data)) {
      tickers <- unique(data$ticker)
      specific_checks$valid_tickers <- all(nchar(as.character(tickers)) >= 4)  # Brazilian tickers are usually 4+ chars
    }

  } else if (dataset_name == "rppi_sale" || dataset_name == "rppi_rent") {
    # RPPI data should have reasonable geographic coverage
    if ("city" %in% names(data) || "region" %in% names(data)) {
      geo_col <- if("city" %in% names(data)) "city" else "region"
      unique_regions <- length(unique(data[[geo_col]]))
      specific_checks$adequate_geographic_coverage <- unique_regions >= 3  # At least 3 regions/cities
    }
  }

  if (length(specific_checks) == 0) {
    return(NULL)
  }

  return(specific_checks)
}

#' Create Validation Summary
#'
#' Generate human-readable summary of validation results
#'
create_validation_summary <- function(checks, dataset_name) {
  logical_checks <- checks[sapply(checks, is.logical)]
  passed_count <- sum(unlist(logical_checks))
  total_count <- length(logical_checks)

  summary <- list(
    total_checks = total_count,
    passed_checks = passed_count,
    failed_checks = total_count - passed_count,
    pass_rate = round(passed_count / total_count * 100, 1)
  )

  return(summary)
}

#' Generate Validation Report
#'
#' Create a comprehensive validation report for all datasets
#'
generate_validation_report <- function(validation_results) {
  if (length(validation_results) == 0) {
    return("No validation results to report.")
  }

  report_lines <- c(
    "# Data Validation Report",
    paste0("Generated: ", Sys.time()),
    "",
    "## Summary",
    ""
  )

  # Overall summary
  total_datasets <- length(validation_results)
  passed_datasets <- sum(sapply(validation_results, function(x) x$passed))

  report_lines <- c(report_lines,
    paste0("- Total datasets validated: ", total_datasets),
    paste0("- Datasets passed: ", passed_datasets),
    paste0("- Datasets failed: ", total_datasets - passed_datasets),
    paste0("- Overall pass rate: ", round(passed_datasets / total_datasets * 100, 1), "%"),
    ""
  )

  # Individual dataset results
  report_lines <- c(report_lines, "## Individual Dataset Results", "")

  for (result in validation_results) {
    status_icon <- if (result$passed) "✅" else "❌"
    report_lines <- c(report_lines,
      paste0("### ", result$dataset, " ", status_icon),
      paste0("- Validation time: ", result$timestamp),
      paste0("- Checks passed: ", result$summary$passed_checks, "/", result$summary$total_checks,
             " (", result$summary$pass_rate, "%)"),
      ""
    )

    # Show failed checks if any
    if (!result$passed) {
      failed_checks <- names(result$checks)[sapply(result$checks, function(x) is.logical(x) && !x)]
      if (length(failed_checks) > 0) {
        report_lines <- c(report_lines,
          "**Failed checks:**",
          paste0("- ", failed_checks),
          ""
        )
      }
    }
  }

  return(paste(report_lines, collapse = "\n"))
}