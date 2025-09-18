# data-raw/targets_helpers.R
# Helper functions for the {targets} pipeline

#' Save Dataset to Cache
#'
#' Save a dataset to the package cache directory with appropriate format
#' based on data structure and size
#'
#' @param data Dataset to save (tibble or list)
#' @param name Cache filename (without extension)
#' @param format Either "auto", "rds", or "csv"
#'
save_dataset_to_cache <- function(data, name, format = "auto") {
  # Ensure cache directory exists
  cache_dir <- file.path("inst", "cached_data")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Determine format
  if (format == "auto") {
    # Use RDS for lists or complex structures, CSV for simple tibbles
    if (is.list(data) && !is.data.frame(data)) {
      format <- "rds"
    } else if (is.data.frame(data) && nrow(data) < 50000) {
      format <- "csv"
    } else {
      format <- "rds"
    }
  }

  # Save with appropriate format
  if (format == "rds") {
    file_path <- file.path(cache_dir, paste0(name, ".rds"))
    readr::write_rds(data, file_path, compress = "gz")
    cli::cli_inform("Saved {name} as compressed RDS ({file.size(file_path)} bytes)")
  } else if (format == "csv") {
    file_path <- file.path(cache_dir, paste0(name, ".csv.gz"))
    readr::write_delim(data, file_path, delim = ",")
    cli::cli_inform("Saved {name} as compressed CSV ({file.size(file_path)} bytes)")
  }

  # Add metadata
  metadata <- list(
    name = name,
    format = format,
    saved_at = Sys.time(),
    file_path = file_path,
    rows = if(is.data.frame(data)) nrow(data) else NA,
    cols = if(is.data.frame(data)) ncol(data) else length(data),
    size_bytes = file.size(file_path)
  )

  # Save metadata
  metadata_path <- file.path(cache_dir, paste0(name, "_metadata.rds"))
  readr::write_rds(metadata, metadata_path)

  return(file_path)
}

#' Check if Dataset Needs Update
#'
#' Determine if a dataset should be updated based on various criteria
#'
#' @param dataset_name Name of the dataset
#' @param max_age Maximum age in hours before forcing update
#' @param force_update Force update regardless of age
#'
should_update_dataset <- function(dataset_name, max_age = 24, force_update = FALSE) {
  if (force_update) return(TRUE)

  # Check if cached metadata exists
  cache_dir <- file.path("inst", "cached_data")
  metadata_path <- file.path(cache_dir, paste0(dataset_name, "_metadata.rds"))

  if (!file.exists(metadata_path)) {
    cli::cli_inform("No cached metadata for {dataset_name}, updating...")
    return(TRUE)
  }

  # Load metadata and check age
  metadata <- readr::read_rds(metadata_path)
  age_hours <- as.numeric(difftime(Sys.time(), metadata$saved_at, units = "hours"))

  if (age_hours > max_age) {
    cli::cli_inform("Dataset {dataset_name} is {round(age_hours, 1)} hours old, updating...")
    return(TRUE)
  }

  cli::cli_inform("Dataset {dataset_name} is {round(age_hours, 1)} hours old, skipping update")
  return(FALSE)
}

#' Get Cache Summary
#'
#' Generate summary information about cached datasets
#'
get_cache_summary <- function() {
  cache_dir <- file.path("inst", "cached_data")

  if (!dir.exists(cache_dir)) {
    return(data.frame(
      dataset = character(0),
      last_updated = as.POSIXct(character(0)),
      age_hours = numeric(0),
      size_mb = numeric(0),
      format = character(0)
    ))
  }

  # Find all metadata files
  metadata_files <- list.files(cache_dir, pattern = "*_metadata.rds$", full.names = TRUE)

  if (length(metadata_files) == 0) {
    return(data.frame(
      dataset = character(0),
      last_updated = as.POSIXct(character(0)),
      age_hours = numeric(0),
      size_mb = numeric(0),
      format = character(0)
    ))
  }

  # Load and combine metadata
  cache_info <- do.call(rbind, lapply(metadata_files, function(file) {
    metadata <- readr::read_rds(file)
    data.frame(
      dataset = metadata$name,
      last_updated = metadata$saved_at,
      age_hours = as.numeric(difftime(Sys.time(), metadata$saved_at, units = "hours")),
      size_mb = round(metadata$size_bytes / (1024^2), 2),
      format = metadata$format,
      rows = metadata$rows %||% NA,
      stringsAsFactors = FALSE
    )
  }))

  # Sort by last updated (most recent first)
  cache_info[order(cache_info$last_updated, decreasing = TRUE), ]
}

#' Validate Cache Integrity
#'
#' Check that cached files exist and are readable
#'
validate_cache_integrity <- function() {
  cache_dir <- file.path("inst", "cached_data")

  if (!dir.exists(cache_dir)) {
    cli::cli_warn("Cache directory does not exist: {cache_dir}")
    return(FALSE)
  }

  metadata_files <- list.files(cache_dir, pattern = "*_metadata.rds$", full.names = TRUE)

  if (length(metadata_files) == 0) {
    cli::cli_warn("No cached datasets found")
    return(TRUE)  # Empty cache is valid
  }

  issues <- 0

  for (metadata_file in metadata_files) {
    tryCatch({
      metadata <- readr::read_rds(metadata_file)

      # Check if data file exists
      if (!file.exists(metadata$file_path)) {
        cli::cli_warn("Data file missing: {metadata$file_path}")
        issues <- issues + 1
      } else {
        # Try to read the file
        if (metadata$format == "rds") {
          test_data <- readr::read_rds(metadata$file_path)
        } else if (metadata$format == "csv") {
          test_data <- readr::read_csv(metadata$file_path, n_max = 1, show_col_types = FALSE)
        }
        cli::cli_inform("✓ {metadata$name} cache is valid")
      }
    }, error = function(e) {
      cli::cli_warn("Error validating {basename(metadata_file)}: {e$message}")
      issues <- issues + 1
    })
  }

  if (issues == 0) {
    cli::cli_alert_success("All cached datasets are valid")
    return(TRUE)
  } else {
    cli::cli_alert_danger("Found {issues} cache integrity issues")
    return(FALSE)
  }
}

# Utility function for NULL default
`%||%` <- function(x, y) if (is.null(x)) y else x