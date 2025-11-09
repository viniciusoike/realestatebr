#' User-Level Cache Management
#'
#' Functions for managing cached datasets in the user's home directory,
#' following R package best practices for data caching.
#'
#' @name cache-user
NULL

#' Get User Cache Directory
#'
#' Returns the path to the user-level cache directory for realestatebr package.
#' This directory is used to store downloaded datasets for faster subsequent access.
#'
#' @return Character. Path to user cache directory
#' @keywords internal
#' @export
#'
#' @examples
#' \dontrun{
#' cache_dir <- get_user_cache_dir()
#' print(cache_dir)
#' }
get_user_cache_dir <- function() {
  cache_dir <- rappdirs::user_cache_dir("realestatebr")
  return(cache_dir)
}

#' Ensure Cache Directory Exists
#'
#' Creates the user cache directory if it doesn't exist.
#'
#' @return Character. Path to cache directory (invisibly)
#' @keywords internal
ensure_cache_dir <- function() {
  cache_dir <- get_user_cache_dir()

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cli::cli_inform("Created cache directory: {cache_dir}")
  }

  invisible(cache_dir)
}

#' Get Cached File Path
#'
#' Returns the full path to a cached dataset file.
#'
#' @param dataset_name Character. Name of the dataset
#' @param extension Character. File extension (default: auto-detect)
#' @return Character. Full path to cached file, or NULL if not found
#' @keywords internal
get_cached_file_path <- function(dataset_name, extension = NULL) {
  cache_dir <- get_user_cache_dir()

  if (is.null(extension)) {
    # Try different extensions in order of preference
    extensions <- c("rds", "csv.gz", "csv")
    for (ext in extensions) {
      file_path <- file.path(cache_dir, paste0(dataset_name, ".", ext))
      if (file.exists(file_path)) {
        return(file_path)
      }
    }
    return(NULL)
  } else {
    file_path <- file.path(cache_dir, paste0(dataset_name, ".", extension))
    if (file.exists(file_path)) {
      return(file_path)
    }
    return(NULL)
  }
}

#' Load Dataset from User Cache
#'
#' Loads a dataset from the user-level cache directory.
#'
#' @param dataset_name Character. Name of the cached dataset
#' @param quiet Logical. Suppress informational messages (default: FALSE)
#' @return Dataset as tibble or list, or NULL if not found
#' @keywords internal
#' @export
load_from_user_cache <- function(dataset_name, quiet = FALSE) {
  # Ensure cache directory exists
  cache_dir <- ensure_cache_dir()

  # Try to find cached file
  file_path <- get_cached_file_path(dataset_name)

  if (is.null(file_path)) {
    if (!quiet) {
      cli::cli_inform("Dataset '{dataset_name}' not found in user cache")
    }
    return(NULL)
  }

  # Determine file type and load
  extension <- tools::file_ext(file_path)
  if (extension == "gz") {
    # Handle .csv.gz
    extension <- "csv.gz"
  }

  tryCatch({
    data <- switch(extension,
      "rds" = readRDS(file_path),
      "csv.gz" = readr::read_delim(file_path, show_col_types = FALSE),
      "csv" = readr::read_delim(file_path, show_col_types = FALSE)
    )

    # Check cache age and warn ONLY if significantly stale (relaxed thresholds)
    if (!quiet) {
      age <- get_cache_age(dataset_name)
      if (!is.na(age)) {
        stale <- is_cache_stale(dataset_name)

        if (isTRUE(stale)) {
          # Only warn if 2x update frequency exceeded (relaxed)
          cli::cli_warn(c(
            "Cached data for '{dataset_name}' is {round(age, 1)} days old",
            "i" = "Consider updating: update_cache_from_github('{dataset_name}')",
            "i" = "Or force fresh data: get_dataset('{dataset_name}', source='fresh')"
          ))
        }
        # NO MESSAGE for fresh cache - keep it quiet
      } else {
        # Only basic message if no metadata
        cli::cli_inform("Loaded '{dataset_name}' from user cache")
      }
    }

    return(data)

  }, error = function(e) {
    cli::cli_warn("Failed to load '{dataset_name}' from cache: {e$message}")
    return(NULL)
  })
}

#' Save Dataset to User Cache
#'
#' Saves a dataset to the user-level cache directory.
#'
#' @param data Dataset to cache
#' @param dataset_name Character. Name to save as
#' @param format Character. File format ("rds" or "csv.gz")
#' @param quiet Logical. Suppress messages
#' @return Logical. TRUE if successful
#' @keywords internal
save_to_user_cache <- function(data, dataset_name, format = "rds", quiet = FALSE) {
  # Ensure cache directory exists
  cache_dir <- ensure_cache_dir()

  # Build file path
  file_path <- file.path(cache_dir, paste0(dataset_name, ".", format))

  tryCatch({
    if (format == "rds") {
      saveRDS(data, file_path, compress = TRUE)
    } else if (format == "csv.gz") {
      readr::write_delim(data, file_path)
    } else {
      cli::cli_abort("Unsupported format: {format}")
    }

    if (!quiet) {
      file_size <- file.info(file_path)$size / 1024^2
      cli::cli_inform("Saved '{dataset_name}' to cache ({round(file_size, 2)} MB)")
    }

    # Save metadata
    save_cache_metadata(dataset_name, format)

    return(TRUE)

  }, error = function(e) {
    cli::cli_warn("Failed to save '{dataset_name}' to cache: {e$message}")
    return(FALSE)
  })
}

#' List Cached Files
#'
#' Lists all datasets currently in the user cache.
#'
#' @return Tibble with file information
#' @export
#'
#' @examples
#' \dontrun{
#' cached_files <- list_cached_files()
#' print(cached_files)
#' }
list_cached_files <- function() {
  cache_dir <- get_user_cache_dir()

  if (!dir.exists(cache_dir)) {
    cli::cli_inform("Cache directory does not exist yet")
    return(tibble::tibble(
      dataset = character(0),
      format = character(0),
      size_mb = numeric(0),
      modified = as.POSIXct(character(0))
    ))
  }

  # List all cached files
  files <- list.files(
    cache_dir,
    pattern = "\\.(rds|csv|csv\\.gz)$",
    full.names = TRUE
  )

  if (length(files) == 0) {
    cli::cli_inform("No cached files found")
    return(tibble::tibble(
      dataset = character(0),
      format = character(0),
      size_mb = numeric(0),
      modified = as.POSIXct(character(0))
    ))
  }

  # Get file information
  file_info <- purrr::map_dfr(files, function(file) {
    info <- file.info(file)
    basename_file <- basename(file)

    # Extract dataset name and format
    if (grepl("\\.csv\\.gz$", basename_file)) {
      dataset_name <- sub("\\.csv\\.gz$", "", basename_file)
      format <- "csv.gz"
    } else {
      dataset_name <- tools::file_path_sans_ext(basename_file)
      format <- tools::file_ext(basename_file)
    }

    tibble::tibble(
      dataset = dataset_name,
      format = format,
      size_mb = round(info$size / 1024^2, 2),
      modified = info$mtime
    )
  })

  # Sort by modification time (newest first)
  file_info <- file_info[order(file_info$modified, decreasing = TRUE), ]

  cli::cli_inform("Found {nrow(file_info)} cached file{?s}")

  return(file_info)
}

#' Clear User Cache
#'
#' Removes cached datasets from user directory.
#'
#' @param dataset_names Character vector. Specific datasets to remove, or NULL for all
#' @param confirm Logical. Require confirmation (default: TRUE)
#' @return Logical. TRUE if successful
#' @export
#'
#' @examples
#' \dontrun{
#' # Clear specific dataset
#' clear_user_cache("abecip")
#'
#' # Clear all cache (with confirmation)
#' clear_user_cache()
#' }
clear_user_cache <- function(dataset_names = NULL, confirm = TRUE) {
  cache_dir <- get_user_cache_dir()

  if (!dir.exists(cache_dir)) {
    cli::cli_inform("Cache directory does not exist")
    return(TRUE)
  }

  # Get files to remove
  if (is.null(dataset_names)) {
    files_to_remove <- list.files(
      cache_dir,
      pattern = "\\.(rds|csv|csv\\.gz)$",
      full.names = TRUE
    )
    target_desc <- "all cached files"
  } else {
    files_to_remove <- c()
    for (name in dataset_names) {
      # Match all formats
      pattern <- paste0("^", name, "\\.(rds|csv|csv\\.gz)$")
      matching_files <- list.files(cache_dir, pattern = pattern, full.names = TRUE)
      files_to_remove <- c(files_to_remove, matching_files)
    }
    target_desc <- paste("cached files for:", paste(dataset_names, collapse = ", "))
  }

  if (length(files_to_remove) == 0) {
    cli::cli_inform("No files to remove")
    return(TRUE)
  }

  # Confirm removal
  if (confirm && interactive()) {
    response <- readline(
      paste0("Remove ", target_desc, " (", length(files_to_remove), " files)? [y/N]: ")
    )
    if (!tolower(response) %in% c("y", "yes")) {
      cli::cli_inform("Cache clear cancelled")
      return(FALSE)
    }
  }

  # Remove files
  removed_count <- 0
  for (file in files_to_remove) {
    if (file.remove(file)) {
      removed_count <- removed_count + 1
    } else {
      cli::cli_warn("Failed to remove {basename(file)}")
    }
  }

  cli::cli_inform("Removed {removed_count} file{?s} from cache")

  return(removed_count == length(files_to_remove))
}

#' Get Cache Metadata
#'
#' Returns metadata about cached datasets including download dates and versions.
#'
#' @param dataset_name Character. Name of dataset, or NULL for all
#' @return List or tibble with metadata
#' @keywords internal
get_cache_metadata <- function(dataset_name = NULL) {
  cache_dir <- get_user_cache_dir()
  metadata_file <- file.path(cache_dir, "cache_metadata.rds")

  if (!file.exists(metadata_file)) {
    return(NULL)
  }

  metadata <- readRDS(metadata_file)

  if (!is.null(dataset_name)) {
    return(metadata[[dataset_name]])
  }

  return(metadata)
}

#' Save Cache Metadata
#'
#' Saves metadata about a cached dataset.
#'
#' @param dataset_name Character. Name of dataset
#' @param format Character. File format
#' @param source Character. Data source (optional)
#' @return Logical. TRUE if successful
#' @keywords internal
save_cache_metadata <- function(dataset_name, format, source = NULL) {
  cache_dir <- get_user_cache_dir()
  metadata_file <- file.path(cache_dir, "cache_metadata.rds")

  # Load existing metadata or create new
  if (file.exists(metadata_file)) {
    metadata <- readRDS(metadata_file)
  } else {
    metadata <- list()
  }

  # Add/update entry
  metadata[[dataset_name]] <- list(
    format = format,
    cached_at = Sys.time(),
    source = source
  )

  # Save metadata
  tryCatch({
    saveRDS(metadata, metadata_file)
    return(TRUE)
  }, error = function(e) {
    cli::cli_warn("Failed to save cache metadata: {e$message}")
    return(FALSE)
  })
}

#' Check if Dataset is Cached
#'
#' Check if a dataset exists in the user cache.
#'
#' @param dataset_name Character. Name of dataset
#' @return Logical. TRUE if cached
#' @keywords internal
#' @export
is_cached <- function(dataset_name) {
  file_path <- get_cached_file_path(dataset_name)
  return(!is.null(file_path))
}

#' Get Cache Age in Days
#'
#' Calculate how old a cached dataset is in days.
#'
#' @param dataset_name Character. Name of dataset
#' @return Numeric. Age in days, or NA if can't determine
#' @keywords internal
get_cache_age <- function(dataset_name) {
  metadata <- get_cache_metadata(dataset_name)
  if (is.null(metadata) || is.null(metadata$cached_at)) {
    return(NA_real_)
  }
  as.numeric(difftime(Sys.time(), metadata$cached_at, units = "days"))
}

#' Check if Cache is Stale
#'
#' Determine if a cached dataset is older than its update schedule.
#' Uses relaxed thresholds by default (2x update frequency) to avoid
#' annoying users with unnecessary warnings.
#'
#' @param dataset_name Character. Name of dataset
#' @param warn_after_days Numeric. Override default warning threshold
#' @return Logical. TRUE if stale, FALSE if fresh, NA if can't determine
#' @keywords internal
#' @export
is_cache_stale <- function(dataset_name, warn_after_days = NULL) {
  age <- get_cache_age(dataset_name)
  if (is.na(age)) return(NA)

  if (is.null(warn_after_days)) {
    # Get default from registry (relaxed thresholds)
    registry <- load_dataset_registry()
    if (dataset_name %in% names(registry$datasets)) {
      dataset_info <- registry$datasets[[dataset_name]]

      # Use warn_after_days from registry, or default based on schedule
      warn_after_days <- dataset_info$warn_after_days

      if (is.null(warn_after_days)) {
        # Fallback defaults: 2x the update frequency
        schedule <- dataset_info$update_schedule %||% "weekly"
        warn_after_days <- switch(schedule,
          "weekly" = 14,   # 2 weeks
          "monthly" = 60,  # 2 months
          "manual" = 999999  # Never warn for manual datasets
        )
      }
    } else {
      warn_after_days <- 14  # Default to 2 weeks
    }
  }

  return(age > warn_after_days)
}

#' Check Cache Status
#'
#' Display status of all locally cached datasets. Uses relaxed staleness
#' thresholds (2x update frequency) to identify datasets that may benefit
#' from updating.
#'
#' @param verbose Logical. Show detailed formatted output (default: TRUE)
#' @return Tibble with cache status information (invisibly)
#' @export
#'
#' @examples
#' \dontrun{
#' # Check which datasets might benefit from updating
#' check_cache_status()
#'
#' # Get status table for programmatic use
#' status <- check_cache_status(verbose = FALSE)
#' old_datasets <- status[status$age_days > 30, ]
#' }
check_cache_status <- function(verbose = TRUE) {
  cached_files <- list_cached_files()

  if (nrow(cached_files) == 0) {
    if (verbose) {
      cli::cli_inform("No cached datasets found")
    }
    return(invisible(cached_files))
  }

  # Load registry
  registry <- load_dataset_registry()

  # Enhance with age and staleness info
  status <- cached_files
  status$age_days <- NA_real_
  status$stale <- NA
  status$update_schedule <- NA_character_
  status$warn_threshold <- NA_real_

  for (i in seq_len(nrow(status))) {
    dataset <- status$dataset[i]

    age <- get_cache_age(dataset)
    status$age_days[i] <- age

    stale <- is_cache_stale(dataset)
    status$stale[i] <- stale

    if (dataset %in% names(registry$datasets)) {
      ds_info <- registry$datasets[[dataset]]
      status$update_schedule[i] <- ds_info$update_schedule %||% "unknown"

      # Show warning threshold
      schedule <- ds_info$update_schedule %||% "weekly"
      status$warn_threshold[i] <- switch(schedule,
        "weekly" = 14,
        "monthly" = 60,
        "manual" = NA_real_
      )
    }
  }

  # Sort by staleness, then age
  status <- status[order(status$stale, status$age_days, decreasing = TRUE, na.last = TRUE), ]

  if (verbose) {
    cli::cli_h1("Cache Status")

    stale_count <- sum(status$stale, na.rm = TRUE)
    fresh_count <- sum(!status$stale, na.rm = TRUE)

    cli::cli_alert_info("Using relaxed thresholds: weekly=14 days, monthly=60 days")
    cli::cli_text("")

    if (stale_count > 0) {
      cli::cli_alert_warning("{stale_count} dataset{?s} could benefit from updating")
    }
    if (fresh_count > 0) {
      cli::cli_alert_success("{fresh_count} dataset{?s} are reasonably fresh")
    }

    if (stale_count > 0) {
      cli::cli_h2("Consider Updating")
      stale_datasets <- status[isTRUE(status$stale), ]
      for (i in seq_len(nrow(stale_datasets))) {
        ds <- stale_datasets[i, ]
        cli::cli_li(
          "{ds$dataset}: {round(ds$age_days, 1)} days old (threshold: {ds$warn_threshold} days)"
        )
      }
      cli::cli_text("")
      cli::cli_code("update_cache_from_github(c('{paste(stale_datasets$dataset, collapse=\"', '\")}'))")
    }

    cli::cli_h2("Recently Updated")
    fresh_datasets <- status[!isTRUE(status$stale) & !is.na(status$stale), ]
    if (nrow(fresh_datasets) > 0) {
      for (i in seq_len(min(5, nrow(fresh_datasets)))) {  # Show max 5
        ds <- fresh_datasets[i, ]
        cli::cli_li(
          "{ds$dataset}: {round(ds$age_days, 1)} days old"
        )
      }
      if (nrow(fresh_datasets) > 5) {
        cli::cli_text("... and {nrow(fresh_datasets) - 5} more")
      }
    }
  }

  return(invisible(status))
}
