#' Cache Management Utilities (DEPRECATED)
#'
#' These functions are deprecated as of version 0.5.0. Use the new user-level
#' cache functions instead (see \code{\link{cache-user}}).
#'
#' @name cache-deprecated
NULL

#' Import Cached Dataset (DEPRECATED)
#'
#' \strong{DEPRECATED}: This function loaded data from \code{inst/cached_data/}
#' which is no longer included in the package. Use \code{\link{load_from_user_cache}}
#' or \code{\link{get_dataset}} with \code{source="cache"} instead.
#'
#' @param dataset_name Character. Name of the cached dataset (without extension)
#' @param cache_dir Character. Path to cache directory (default: "cached_data")
#' @param format Character. File format ("auto", "rds", "csv"). If "auto",
#'   will try RDS first, then compressed CSV.
#' @param quiet Logical. Suppress informational messages (default: FALSE)
#'
#' @return Dataset as tibble or list, depending on original structure
#'
#' @seealso \code{\link{load_from_user_cache}}, \code{\link{get_dataset}}
#' @keywords internal
#' @export
import_cached <- function(dataset_name,
                         cache_dir = "cached_data",
                         format = "auto",
                         quiet = FALSE) {

  # Deprecation warning
  if (!quiet) {
    lifecycle::deprecate_warn(
      when = "0.5.0",
      what = "import_cached()",
      with = "load_from_user_cache()",
      details = "import_cached() now loads from user cache (~/.local/share/realestatebr/) instead of inst/cached_data/"
    )
  }

  # Validate inputs
  if (!is.character(dataset_name) || length(dataset_name) != 1 || dataset_name == "") {
    cli::cli_abort("dataset_name must be a non-empty character string")
  }

  # Redirect to new user cache system
  # Ignore cache_dir and format parameters (they're deprecated)
  return(load_from_user_cache(dataset_name, quiet = quiet))
}

#' Try Loading Different File Formats
#'
#' Internal function to attempt loading a dataset from different file formats
#' in order of preference: RDS, CSV.gz, CSV
#'
#' @param dataset_name Character. Dataset name
#' @param cache_path Character. Path to cache directory  
#' @param quiet Logical. Suppress messages
#' @return Dataset or NULL if not found
#' @keywords internal
try_load_formats <- function(dataset_name, cache_path, quiet) {
  
  # Define file extensions in order of preference
  extensions <- c("rds", "csv.gz", "csv")
  
  for (ext in extensions) {
    file_path <- file.path(cache_path, paste0(dataset_name, ".", ext))
    
    if (file.exists(file_path)) {
      return(load_file_by_extension(file_path, ext, quiet))
    }
  }
  
  return(NULL)
}

#' Load Specific Format
#'
#' Load dataset from a specific file format
#'
#' @param dataset_name Character. Dataset name
#' @param cache_path Character. Cache directory path
#' @param format Character. File format
#' @param quiet Logical. Suppress messages
#' @return Dataset or NULL
#' @keywords internal  
load_specific_format <- function(dataset_name, cache_path, format, quiet) {
  
  # Map format to extension
  ext <- switch(format,
    "rds" = "rds",
    "csv" = "csv.gz"  # Prefer compressed CSV
  )
  
  file_path <- file.path(cache_path, paste0(dataset_name, ".", ext))
  
  if (!file.exists(file_path)) {
    # Try uncompressed CSV as fallback
    if (format == "csv") {
      file_path <- file.path(cache_path, paste0(dataset_name, ".csv"))
      if (!file.exists(file_path)) {
        return(NULL)
      }
      ext <- "csv"
    } else {
      return(NULL)
    }
  }
  
  return(load_file_by_extension(file_path, ext, quiet))
}

#' Load File by Extension
#'
#' Load a file using the appropriate method based on its extension
#'
#' @param file_path Character. Full path to file
#' @param extension Character. File extension
#' @param quiet Logical. Suppress messages
#' @return Loaded dataset
#' @keywords internal
load_file_by_extension <- function(file_path, extension, quiet) {
  
  tryCatch({
    data <- switch(extension,
      "rds" = readRDS(file_path),
      "csv.gz" = readr::read_delim(file_path, show_col_types = FALSE),
      "csv" = readr::read_delim(file_path, show_col_types = FALSE)
    )

    return(data)

  }, error = function(e) {
    if (!quiet) {
      cli::cli_warn("Failed to load {basename(file_path)}: {e$message}")
    }
    return(NULL)
  })
}


#' Check Cache Status
#'
#' Check the availability and status of cached datasets
#'
#' @param cache_dir Character. Cache directory path
#' @return Tibble with cache status information
#' @keywords internal
#' @export
check_cache_status <- function(cache_dir = "cached_data") {
  
  cache_path <- system.file(cache_dir, package = "realestatebr")
  
  if (!dir.exists(cache_path) || cache_path == "") {
    cli::cli_warn("Cache directory not found")
    return(tibble::tibble(
      file = character(0),
      size_mb = numeric(0),
      modified = as.POSIXct(character(0))
    ))
  }
  
  # List all cached files
  files <- list.files(cache_path, 
                     pattern = "\\.(rds|csv|csv\\.gz)$", 
                     full.names = TRUE)
  
  if (length(files) == 0) {
    cli::cli_inform("No cached files found")
    return(tibble::tibble(
      file = character(0),
      size_mb = numeric(0),
      modified = as.POSIXct(character(0))
    ))
  }
  
  # Get file information
  file_info <- purrr::map_dfr(files, function(file) {
    info <- file.info(file)
    tibble::tibble(
      file = basename(file),
      size_mb = round(info$size / 1024^2, 2),
      modified = info$mtime
    )
  })
  
  # Sort by modification time (newest first)
  file_info <- file_info[order(file_info$modified, decreasing = TRUE), ]
  
  cli::cli_inform("Found {nrow(file_info)} cached file{?s}")
  
  return(file_info)
}

#' Clear Cache
#'
#' Remove cached datasets (development utility)
#'
#' @param dataset_names Character vector. Specific datasets to remove, or NULL for all
#' @param cache_dir Character. Cache directory path
#' @param confirm Logical. Require confirmation (default: TRUE)
#' @return Logical. TRUE if successful
#' @keywords internal
clear_cache <- function(dataset_names = NULL, 
                       cache_dir = "cached_data", 
                       confirm = TRUE) {
  
  cache_path <- system.file(cache_dir, package = "realestatebr")
  
  if (!dir.exists(cache_path) || cache_path == "") {
    cli::cli_warn("Cache directory not found")
    return(FALSE)
  }
  
  # Get files to remove
  if (is.null(dataset_names)) {
    files_to_remove <- list.files(cache_path, 
                                 pattern = "\\.(rds|csv|csv\\.gz)$", 
                                 full.names = TRUE)
    target_desc <- "all cached files"
  } else {
    files_to_remove <- c()
    for (name in dataset_names) {
      pattern <- paste0("^", name, "\\.(rds|csv|csv\\.gz)$")
      matching_files <- list.files(cache_path, pattern = pattern, full.names = TRUE)
      files_to_remove <- c(files_to_remove, matching_files)
    }
    target_desc <- paste("cached files for:", paste(dataset_names, collapse = ", "))
  }
  
  if (length(files_to_remove) == 0) {
    cli::cli_inform("No files to remove")
    return(TRUE)
  }
  
  # Confirm removal
  if (confirm) {
    response <- readline(paste0("Remove ", target_desc, " (", length(files_to_remove), " files)? [y/N]: "))
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

#' Get Cache Path
#'
#' Get the full path to the package cache directory
#'
#' @param cache_dir Character. Cache subdirectory name
#' @return Character. Full path to cache directory
#' @keywords internal
#' @export
get_cache_path <- function(cache_dir = "cached_data") {
  
  cache_path <- system.file(cache_dir, package = "realestatebr")
  
  if (cache_path == "") {
    cli::cli_abort("Cache directory '{cache_dir}' not found in package")
  }
  
  return(cache_path)
}

#' Validate Cached Dataset
#'
#' Check if a cached dataset exists and is valid
#'
#' @param dataset_name Character. Name of dataset to validate
#' @param cache_dir Character. Cache directory
#' @return List with validation results
#' @keywords internal
validate_cached_dataset <- function(dataset_name, cache_dir = "cached_data") {
  
  cache_path <- system.file(cache_dir, package = "realestatebr")
  
  result <- list(
    exists = FALSE,
    format = NA_character_,
    size_mb = NA_real_,
    modified = as.POSIXct(NA),
    valid = FALSE,
    error = NULL
  )
  
  if (!dir.exists(cache_path) || cache_path == "") {
    result$error <- "Cache directory not found"
    return(result)
  }
  
  # Check for file existence
  extensions <- c("rds", "csv.gz", "csv")
  found_file <- NULL
  found_ext <- NULL
  
  for (ext in extensions) {
    file_path <- file.path(cache_path, paste0(dataset_name, ".", ext))
    if (file.exists(file_path)) {
      found_file <- file_path
      found_ext <- ext
      break
    }
  }
  
  if (is.null(found_file)) {
    result$error <- "Dataset file not found"
    return(result)
  }
  
  # File exists
  result$exists <- TRUE
  result$format <- found_ext
  
  # Get file info
  file_info <- file.info(found_file)
  result$size_mb <- round(file_info$size / 1024^2, 2)
  result$modified <- file_info$mtime
  
  # Try to load and validate
  tryCatch({
    data <- load_file_by_extension(found_file, found_ext, quiet = TRUE)
    
    if (!is.null(data)) {
      result$valid <- TRUE
    } else {
      result$error <- "Failed to load dataset"
    }
    
  }, error = function(e) {
    result$error <- paste("Load error:", e$message)
  })
  
  return(result)
}