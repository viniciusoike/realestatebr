# data-raw/targets_helpers.R
# Helper functions for the {targets} pipeline

#' Save dataset to the pipeline cache directory as compressed RDS
#'
#' @param data Dataset to save (tibble or list)
#' @param name Cache filename (without extension)
save_dataset_to_cache <- function(data, name) {
  cache_dir <- file.path("data-raw", "cache_output")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  file_path <- file.path(cache_dir, paste0(name, ".rds"))
  readr::write_rds(data, file_path, compress = "gz")
  cli::cli_inform("Saved {name} as compressed RDS ({file.size(file_path)} bytes)")

  return(file_path)
}

#' Get Cache Summary
#'
#' Generate summary information about cached datasets
#'
get_cache_summary <- function() {
  cache_dir <- file.path("data-raw", "cache_output")

  empty_df <- data.frame(
    dataset = character(0),
    last_updated = as.POSIXct(character(0)),
    age_hours = numeric(0),
    size_mb = numeric(0),
    stringsAsFactors = FALSE
  )

  if (!dir.exists(cache_dir)) return(empty_df)

  # Find all .rds data files (not metadata)
  data_files <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)
  data_files <- data_files[!grepl("_metadata\\.rds$", data_files)]

  if (length(data_files) == 0) return(empty_df)

  cache_info <- do.call(rbind, lapply(data_files, function(file) {
    name <- gsub("\\.rds$", "", basename(file))
    info <- file.info(file)
    data.frame(
      dataset = name,
      last_updated = info$mtime,
      age_hours = as.numeric(difftime(Sys.time(), info$mtime, units = "hours")),
      size_mb = round(info$size / (1024^2), 2),
      stringsAsFactors = FALSE
    )
  }))

  cache_info[order(cache_info$last_updated, decreasing = TRUE), ]
}

#' Validate Cache Integrity
#'
#' Check that cached .rds files exist and are readable
#'
validate_cache_integrity <- function() {
  cache_dir <- file.path("data-raw", "cache_output")

  if (!dir.exists(cache_dir)) {
    cli::cli_warn("Cache directory does not exist: {cache_dir}")
    return(FALSE)
  }

  data_files <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)
  data_files <- data_files[!grepl("_metadata\\.rds$", data_files)]

  if (length(data_files) == 0) {
    cli::cli_warn("No cached datasets found")
    return(TRUE)
  }

  issues <- 0

  for (file in data_files) {
    name <- gsub("\\.rds$", "", basename(file))
    tryCatch({
      fsize <- file.size(file)
      if (fsize < 200) {
        cli::cli_warn("{name}: suspiciously small ({fsize} bytes)")
        issues <- issues + 1
      } else {
        test_data <- readr::read_rds(file)
        cli::cli_inform("{name}: valid ({fsize} bytes)")
      }
    }, error = function(e) {
      cli::cli_warn("Error validating {name}: {e$message}")
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
