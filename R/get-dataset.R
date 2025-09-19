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
#' @param table Character. Specific table within dataset (optional).
#'   Use get_dataset_info(name) to see available tables.
#' @param date_start Date. Start date for time series data (where applicable)
#' @param date_end Date. End date for time series data (where applicable)
#' @param ... Additional arguments passed to legacy functions
#'
#' @return Dataset as a tibble. For multi-table datasets, use the `table` parameter
#'   to specify which table to return. Use list_datasets() to see available tables.
#'
#' @examples
#' \dontrun{
#' # Get SBPE data from ABECIP (specify table for multi-table datasets)
#' sbpe_data <- get_dataset("abecip", table = "sbpe")
#'
#' # Get units data from ABECIP  
#' units_data <- get_dataset("abecip", table = "units")
#'
#' # Single-table datasets don't require table parameter
#' secovi_data <- get_dataset("secovi")
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
                       table = NULL,
                       date_start = NULL,
                       date_end = NULL,
                       ...) {
  
  # Validate inputs
  source <- match.arg(source, choices = c("auto", "cache", "github", "fresh"))
  
  # Check if dataset exists
  registry <- load_dataset_registry()
  if (!name %in% names(registry$datasets)) {
    available <- names(registry$datasets)
    cli::cli_abort(c(
      "Dataset '{name}' not found.",
      "i" = "Use list_datasets() to see all available datasets.",
      "i" = "Available datasets: {paste(head(available, 5), collapse = ', ')}{if(length(available) > 5) '...' else ''}"
    ))
  }
  
  dataset_info <- registry$datasets[[name]]

  # Validate and resolve table parameter
  table_info <- validate_and_resolve_table(name, dataset_info, table)
  resolved_table <- table_info$resolved_table

  # Try to get data with fallback strategy
  if (source == "auto") {
    data <- get_dataset_with_fallback(name, dataset_info, resolved_table, date_start, date_end, ...)
  } else {
    data <- get_dataset_from_source(name, dataset_info, source, resolved_table, date_start, date_end, ...)
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
#' @param table Optional table filter
#' @param date_start Optional start date
#' @param date_end Optional end date
#' @param ... Additional arguments
#' @return Dataset or NULL if all methods fail
#' @keywords internal
get_dataset_with_fallback <- function(name, dataset_info, table, date_start, date_end, ...) {
  
  # Initialize error tracking
  errors <- list()
  
  # Try 1: GitHub cache (fastest for most users)
  cli::cli_inform("Attempting to load {name} from GitHub cache...")
  data <- tryCatch({
    get_dataset_from_source(name, dataset_info, "github", table, date_start, date_end, ...)
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
    get_dataset_from_source(name, dataset_info, "fresh", table, date_start, date_end, ...)
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
#' @param table Optional table
#' @param date_start Optional start date
#' @param date_end Optional end date
#' @param ... Additional arguments
#' @return Dataset or error
#' @keywords internal
get_dataset_from_source <- function(name, dataset_info, source, table, date_start, date_end, ...) {
  
  switch(source,
    "cache" = get_from_local_cache(name, dataset_info, table),
    "github" = get_from_github_cache(name, dataset_info, table),
    "fresh" = get_from_legacy_function(name, dataset_info, table, date_start, date_end, ...)
  )
}

#' Get Data from Local Cache
#'
#' @keywords internal
get_from_local_cache <- function(name, dataset_info, table) {
  # Implementation for local cache (placeholder for now)
  cli::cli_abort("Local cache not yet implemented. Use source='github' or source='fresh'.")
}

#' Get Data from GitHub Cache
#'
#' @keywords internal
get_from_github_cache <- function(name, dataset_info, table) {

  # Map dataset name to import_cached parameter
  cached_name <- get_cached_name(name, dataset_info, table)
  
  if (is.null(cached_name)) {
    cli::cli_abort("No GitHub cache available for dataset '{name}'")
  }
  
  # Use existing import_cached function
  data <- import_cached(cached_name)
  
  # CORE REQUIREMENT: Always return a single tibble
  # For multi-table datasets, user MUST specify which table they want
  if (is.list(data) && !inherits(data, "data.frame")) {
    # Multi-table dataset
    if (is.null(table)) {
      # No table specified - provide helpful guidance
      available_tables <- paste(names(data), collapse = ", ")
      cli::cli_abort(c(
        "Dataset '{name}' contains multiple tables. Please specify which table you want:",
        "i" = "Available tables: {available_tables}",
        "i" = "Example: get_dataset('{name}', table = '{names(data)[1]}')"
      ))
    }
    
    # Table specified - extract it
    if (table %in% names(data)) {
      # Show info about other available tables before extracting
      other_tables <- setdiff(names(data), table)
      data <- data[[table]]
      if (length(other_tables) > 0) {
        cli::cli_inform(c(
          "✓ Loaded table '{table}' from dataset '{name}'",
          "i" = "Other available tables: {paste(other_tables, collapse = ', ')}"
        ))
      } else {
        cli::cli_inform("✓ Loaded table '{table}' from dataset '{name}'")
      }
    } else {
      available_tables <- paste(names(data), collapse = ", ")
      cli::cli_abort(c(
        "Table '{table}' not found in dataset '{name}'.",
        "i" = "Available tables: {available_tables}"
      ))
    }
  } else if (!is.null(table)) {
    # Single-table dataset but user specified table parameter
    cli::cli_inform(c(
      "✓ Loaded dataset '{name}' (single table)",
      "i" = "This dataset contains only one table, so the table parameter is ignored."
    ))
  } else {
    # Single-table dataset, normal case
    cli::cli_inform("✓ Loaded dataset '{name}'")
  }
  
  # Ensure we always return a tibble/data.frame, never a list
  if (!inherits(data, "data.frame")) {
    cli::cli_abort("Error: Dataset '{name}' did not return a data.frame/tibble. This is a package bug.")
  }
  
  return(data)
}

#' Get Data from Legacy Function
#'
#' @keywords internal
get_from_legacy_function <- function(name, dataset_info, table, date_start, date_end, ...) {
  
  legacy_function <- dataset_info$legacy_function
  
  if (is.null(legacy_function) || legacy_function == "") {
    cli::cli_abort("No legacy function available for fresh download of '{name}'")
  }
  
  # Build arguments for legacy function
  args <- list(...)
  
  # Add table parameter based on function requirements
  if (!is.null(table)) {
    if (legacy_function %in% c("get_abecip_indicators", "get_abrainc_indicators")) {
      args$table <- table
    } else if (legacy_function == "get_rppi") {
      # get_rppi still uses category parameter for backward compatibility
      args$category <- table
    } else if (supports_table_all(legacy_function)) {
      args$table <- table
    }
  } else if (supports_table_all(legacy_function)) {
    args$table <- "all"
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
get_cached_name <- function(name, dataset_info, table = NULL) {
  
  # First, check if cached_file is specified in registry
  cached_file <- dataset_info$cached_file
  
  if (!is.null(cached_file)) {
    # Handle both single files and lists of files
    if (is.character(cached_file)) {
      # Extract base name without extension
      return(gsub("\\.(rds|csv\\.gz)$", "", basename(cached_file)))
    } else if (is.list(cached_file)) {
      # If table is specified and exists in cached_file list, use it
      if (!is.null(table) && table %in% names(cached_file)) {
        selected_file <- cached_file[[table]]
        return(gsub("\\.(rds|csv\\.gz)$", "", basename(selected_file)))
      }
      # For multiple files, use the first one as default
      # (specific table selection handled separately)
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
    "fgv_indicators" = "fgv_indicators",
    "nre_ire" = "ire"
  )
  
  return(name_mapping[[name]])
}

#' Check if Legacy Function Supports table="all"
#'
#' @keywords internal
supports_table_all <- function(func_name) {
  functions_with_table <- c(
    "get_abecip_indicators",
    "get_abrainc_indicators",
    "get_bcb_realestate",
    "get_secovi",
    "get_bis_rppi",
    "get_bcb_series",
    "get_cbic",
    "get_fgv_indicators",
    "get_bcb_series",
    "get_b3_stocks"
  )

  return(func_name %in% functions_with_table)
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

#' Get Available Tables from Dataset Info
#'
#' Extract list of available tables/categories from dataset registry information
#'
#' @param dataset_info Dataset metadata from registry
#' @return Character vector of available table names, or NULL if no categories
#' @keywords internal
get_available_tables <- function(dataset_info) {
  categories <- dataset_info$categories
  if (is.null(categories)) {
    return(NULL)
  }
  return(names(categories))
}

#' Validate and Resolve Table Parameter
#'
#' Validates table parameter against available tables and resolves default table
#'
#' @param name Dataset name
#' @param dataset_info Dataset metadata from registry
#' @param table User-specified table name (can be NULL)
#' @return List with resolved_table, available_tables, and is_default
#' @keywords internal
validate_and_resolve_table <- function(name, dataset_info, table = NULL) {
  available_tables <- get_available_tables(dataset_info)

  # Single-table datasets
  if (is.null(available_tables)) {
    if (!is.null(table)) {
      cli::cli_warn("Dataset '{name}' has only one table. Ignoring table parameter.")
    }
    return(list(
      resolved_table = NULL,
      available_tables = NULL,
      is_default = TRUE
    ))
  }

  # Multi-table datasets
  if (is.null(table)) {
    # Use first table as default
    resolved_table <- available_tables[1]
    return(list(
      resolved_table = resolved_table,
      available_tables = available_tables,
      is_default = TRUE
    ))
  }

  # Validate specified table
  if (!table %in% available_tables) {
    available_str <- paste(available_tables, collapse = "', '")
    cli::cli_abort("Invalid table '{table}' for dataset '{name}'. Available tables: '{available_str}'.")
  }

  return(list(
    resolved_table = table,
    available_tables = available_tables,
    is_default = FALSE
  ))
}

#' Show Dataset Import Message
#'
#' Display informative message about which table was imported and what's available
#'
#' @param name Dataset name
#' @param table_info Result from validate_and_resolve_table()
#' @keywords internal
show_import_message <- function(name, table_info) {
  if (is.null(table_info$available_tables)) {
    # Single-table dataset - no message needed
    return(invisible())
  }

  # Multi-table dataset
  imported_table <- table_info$resolved_table
  available_str <- paste(table_info$available_tables, collapse = "', '")

  if (table_info$is_default) {
    cli::cli_inform("Imported '{imported_table}' table from '{name}'. All tables available: '{available_str}'.")
  } else {
    cli::cli_inform("Imported '{imported_table}' table from '{name}'. All tables available: '{available_str}'.")
  }
}