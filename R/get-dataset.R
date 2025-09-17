#' Get Dataset
#'
#' Unified interface for accessing all realestatebr package datasets with automatic
#' fallback between different data sources (cache, GitHub, fresh download).
#' 
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom yaml read_yaml
#' @importFrom tibble tibble
#'
#' @param name Character. Dataset name (see list_datasets() for available options)
#' @param source Character. Data source preference:
#'   \describe{
#'     \item{"auto"}{Automatic fallback: cache → GitHub → fresh (default)}
#'     \item{"cache"}{Local package cache only}
#'     \item{"github"}{GitHub repository cache}
#'     \item{"fresh"}{Fresh download from original source}
#'   }
#' @param category Character. Specific category within dataset (optional).
#'   Use get_dataset_info(name) to see available categories.
#' @param date_start Date. Start date for time series data (where applicable)
#' @param date_end Date. End date for time series data (where applicable)
#' @param ... Additional arguments passed to legacy functions
#'
#' @return Dataset as tibble or list, depending on the dataset structure.
#'   Use get_dataset_info(name) to see the expected structure.
#'
#' @examples
#' \dontrun{
#' # Get all ABECIP indicators
#' abecip_data <- get_dataset("abecip_indicators")
#'
#' # Get only SBPE data from ABECIP
#' sbpe_data <- get_dataset("abecip_indicators", category = "sbpe")
#'
#' # Force fresh download
#' fresh_data <- get_dataset("bcb_realestate", source = "fresh")
#'
#' # Get BCB data for specific time period
#' bcb_recent <- get_dataset("bcb_series", 
#'                          date_start = as.Date("2020-01-01"))
#' }
#'
#' @seealso \code{\link{list_datasets}} for available datasets,
#'   \code{\link{get_dataset_info}} for dataset details
#'
#' @export
get_dataset <- function(name, 
                       source = "auto", 
                       category = NULL, 
                       date_start = NULL,
                       date_end = NULL,
                       ...) {
  
  # Validate inputs
  source <- match.arg(source, choices = c("auto", "cache", "github", "fresh"))
  
  # Check if dataset exists
  registry <- load_dataset_registry()
  if (!name %in% names(registry$datasets)) {
    available <- paste(names(registry$datasets), collapse = ", ")
    cli::cli_abort("Dataset '{name}' not found. Available: {available}")
  }
  
  dataset_info <- registry$datasets[[name]]
  
  # Try to get data with fallback strategy
  if (source == "auto") {
    data <- get_dataset_with_fallback(name, dataset_info, category, date_start, date_end, ...)
  } else {
    data <- get_dataset_from_source(name, dataset_info, source, category, date_start, date_end, ...)
  }
  
  # Apply translations if available
  if (!is.null(data)) {
    data <- apply_translations(data, name, dataset_info)
  }
  
  return(data)
}

#' Get Dataset with Fallback Strategy
#'
#' Internal function implementing the auto fallback strategy:
#' cache → GitHub → fresh download
#'
#' @param name Dataset name
#' @param dataset_info Dataset metadata from registry
#' @param category Optional category filter
#' @param date_start Optional start date
#' @param date_end Optional end date
#' @param ... Additional arguments
#' @return Dataset or NULL if all methods fail
#' @keywords internal
get_dataset_with_fallback <- function(name, dataset_info, category, date_start, date_end, ...) {
  
  # Initialize error tracking
  errors <- list()
  
  # Try 1: GitHub cache (fastest for most users)
  cli::cli_inform("Attempting to load {name} from GitHub cache...")
  data <- tryCatch({
    get_dataset_from_source(name, dataset_info, "github", category, date_start, date_end, ...)
  }, error = function(e) {
    errors$github <<- e$message
    cli::cli_warn("GitHub cache failed: {e$message}")
    NULL
  })
  
  if (!is.null(data)) {
    cli::cli_inform("Successfully loaded from GitHub cache")
    return(data)
  }
  
  # Try 2: Fresh download
  cli::cli_inform("Attempting fresh download from original source...")
  data <- tryCatch({
    get_dataset_from_source(name, dataset_info, "fresh", category, date_start, date_end, ...)
  }, error = function(e) {
    errors$fresh <<- e$message
    cli::cli_warn("Fresh download failed: {e$message}")
    NULL
  })
  
  if (!is.null(data)) {
    cli::cli_inform("Successfully downloaded from original source")
    return(data)
  }
  
  # All sources failed - provide detailed error information
  error_details <- paste(
    "All data sources failed for dataset '{name}':",
    "- GitHub cache: {errors$github %||% 'Not attempted'}",
    "- Fresh download: {errors$fresh %||% 'Not attempted'}",
    "",
    "Troubleshooting:",
    "1. Check your internet connection",
    "2. Try again later (temporary server issues)",
    "3. Use source='fresh' to force fresh download",
    "4. Check dataset availability with list_datasets()",
    sep = "\n"
  )
  
  cli::cli_abort(error_details)
}

#' Get Dataset from Specific Source
#'
#' Internal function to get data from a specific source type.
#'
#' @param name Dataset name
#' @param dataset_info Dataset metadata
#' @param source Source type ("cache", "github", "fresh")
#' @param category Optional category
#' @param date_start Optional start date
#' @param date_end Optional end date
#' @param ... Additional arguments
#' @return Dataset or error
#' @keywords internal
get_dataset_from_source <- function(name, dataset_info, source, category, date_start, date_end, ...) {
  
  switch(source,
    "cache" = get_from_local_cache(name, dataset_info, category),
    "github" = get_from_github_cache(name, dataset_info, category),
    "fresh" = get_from_legacy_function(name, dataset_info, category, date_start, date_end, ...)
  )
}

#' Get Data from Local Cache
#'
#' @keywords internal
get_from_local_cache <- function(name, dataset_info, category) {
  # Implementation for local cache (placeholder for now)
  cli::cli_abort("Local cache not yet implemented. Use source='github' or source='fresh'.")
}

#' Get Data from GitHub Cache
#'
#' @keywords internal
get_from_github_cache <- function(name, dataset_info, category) {
  
  # Map dataset name to import_cached parameter
  cached_name <- get_cached_name(name, dataset_info, category)
  
  if (is.null(cached_name)) {
    cli::cli_abort("No GitHub cache available for dataset '{name}'")
  }
  
  # Use existing import_cached function
  data <- import_cached(cached_name)
  
  # Filter by category if requested and data is a list
  if (!is.null(category) && is.list(data) && !inherits(data, "data.frame")) {
    if (category %in% names(data)) {
      data <- data[[category]]
    } else {
      available_cats <- paste(names(data), collapse = ", ")
      cli::cli_abort("Category '{category}' not found. Available: {available_cats}")
    }
  }
  # Note: For datasets with category-specific cached files (like BIS), 
  # the category filtering is handled by get_cached_name() above
  
  return(data)
}

#' Get Data from Legacy Function
#'
#' @keywords internal
get_from_legacy_function <- function(name, dataset_info, category, date_start, date_end, ...) {
  
  legacy_function <- dataset_info$legacy_function
  
  if (is.null(legacy_function) || legacy_function == "") {
    cli::cli_abort("No legacy function available for fresh download of '{name}'")
  }
  
  # Build arguments for legacy function
  args <- list(...)
  
  # Add category/table parameter based on function requirements
  if (!is.null(category)) {
    if (legacy_function %in% c("get_abecip_indicators", "get_abrainc_indicators")) {
      args$table <- category
    } else if (legacy_function == "get_rppi") {
      args$category <- category
    } else if (supports_category_all(legacy_function)) {
      args$category <- category
    }
  } else if (supports_category_all(legacy_function)) {
    args$category <- "all"
  }
  
  # Add date arguments if provided
  if (!is.null(date_start)) {
    args$date_start <- date_start
  }
  if (!is.null(date_end)) {
    args$date_end <- date_end
  }
  
  # Set cached = FALSE for fresh download
  args$cached <- FALSE
  
  # Call the legacy function
  func <- get(legacy_function, mode = "function")
  data <- do.call(func, args)
  
  return(data)
}

#' Get Cached Name for import_cached Function
#'
#' Maps dataset names to the parameter names used by import_cached()
#'
#' @keywords internal
get_cached_name <- function(name, dataset_info, category = NULL) {
  
  # First, check if cached_file is specified in registry
  cached_file <- dataset_info$cached_file
  
  if (!is.null(cached_file)) {
    # Handle both single files and lists of files
    if (is.character(cached_file)) {
      # Extract base name without extension
      return(gsub("\\.(rds|csv\\.gz)$", "", basename(cached_file)))
    } else if (is.list(cached_file)) {
      # If category is specified and exists in cached_file list, use it
      if (!is.null(category) && category %in% names(cached_file)) {
        selected_file <- cached_file[[category]]
        return(gsub("\\.(rds|csv\\.gz)$", "", basename(selected_file)))
      }
      # For multiple files, use the first one as default
      # (specific category selection handled separately)
      first_file <- cached_file[[1]]
      return(gsub("\\.(rds|csv\\.gz)$", "", basename(first_file)))
    }
  }
  
  # Fallback to mapping based on name
  name_mapping <- list(
    "abecip_indicators" = "abecip",
    "abrainc_indicators" = "abrainc", 
    "bcb_realestate" = "bcb_realestate",
    "secovi" = "secovi_sp",
    "bis_rppi" = "bis_selected",
    "rppi" = "rppi_sale",
    "bcb_series" = "bcb_series",
    "b3_stocks" = "b3_stocks",
    "fgv_indicators" = "fgv_indicators"
  )
  
  return(name_mapping[[name]])
}

#' Check if Legacy Function Supports category="all"
#'
#' @keywords internal
supports_category_all <- function(func_name) {
  functions_with_category <- c(
    "get_abecip_indicators",
    "get_abrainc_indicators", 
    "get_bcb_realestate",
    "get_secovi",
    "get_bis_rppi",
    "get_bcb_series"
  )
  
  return(func_name %in% functions_with_category)
}

#' Apply Translations to Dataset
#'
#' Apply standard Portuguese to English translations to column names and values
#'
#' @param data Dataset to translate
#' @param name Dataset name
#' @param dataset_info Dataset metadata
#' @return Translated dataset
#' @keywords internal
apply_translations <- function(data, name, dataset_info) {
  
  # Check if translation is enabled for this dataset
  translation_notes <- dataset_info$translation_notes
  
  if (is.null(translation_notes) || translation_notes == "") {
    return(data)  # No translation needed
  }
  
  # Apply translations using the translation utility
  # (Will implement in translation.R)
  if (exists("translate_dataset", mode = "function")) {
    data <- translate_dataset(data, name)
  }
  
  return(data)
}