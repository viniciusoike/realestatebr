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
#' @param table Character. Specific table within dataset (optional).
#'   Use get_dataset_info(name) to see available tables.
#' @param source Character. Data source preference:
#'   \describe{
#'     \item{"auto"}{Automatic fallback: cache → GitHub → fresh (default)}
#'     \item{"cache"}{Local package cache only}
#'     \item{"github"}{GitHub repository cache}
#'     \item{"fresh"}{Fresh download from original source}
#'   }
#' @param date_start Date. Start date for time series data (where applicable)
#' @param date_end Date. End date for time series data (where applicable)
#' @param ... Additional arguments passed to legacy functions
#'
#' @return Dataset as tibble or list, depending on the dataset structure.
#'   Use get_dataset_info(name) to see the expected structure.
#'
#' @examples
#' \dontrun{
#' # Get all ABECIP indicators (default table)
#' abecip_data <- get_dataset("abecip")
#'
#' # Get only SBPE data from ABECIP
#' sbpe_data <- get_dataset("abecip", "sbpe")
#'
#' # Force fresh download
#' fresh_data <- get_dataset("bcb_realestate", source = "fresh")
#'
#' # Get BCB data for specific time period
#' bcb_recent <- get_dataset("bcb_series",
#'                          date_start = as.Date("2020-01-01"))
#' }
#'
#' @section Debug Mode:
#' The realestatebr package includes a comprehensive debug mode for development
#' and troubleshooting. Debug mode shows detailed processing messages including
#' file-by-file progress, data type detection, web scraping steps, and more.
#'
#' \strong{Enable debug mode:}
#' \describe{
#'   \item{Environment variable}{Set \code{REALESTATEBR_DEBUG=TRUE} in your environment}
#'   \item{Package option}{Use \code{options(realestatebr.debug = TRUE)}}
#' }
#'
#' \strong{Debug mode examples:}
#' \preformatted{
#' # Enable debug mode via environment variable
#' Sys.setenv(REALESTATEBR_DEBUG = "TRUE")
#' data <- get_dataset("cbic")  # Shows detailed processing messages
#'
#' # Enable debug mode via package option
#' options(realestatebr.debug = TRUE)
#' data <- get_dataset("rppi")  # Shows detailed processing messages
#'
#' # Disable debug mode
#' options(realestatebr.debug = FALSE)
#' # or
#' Sys.unsetenv("REALESTATEBR_DEBUG")
#' }
#'
#' \strong{What debug mode shows:}
#' \itemize{
#'   \item File download progress and retry attempts
#'   \item Excel sheet processing steps
#'   \item Data type detection and validation
#'   \item Web scraping details and error handling
#'   \item Cache access and fallback operations
#'   \item Data cleaning and transformation steps
#' }
#'
#' Debug mode is particularly useful when troubleshooting data access issues,
#' understanding complex dataset processing, or developing new functionality.
#'
#' @seealso \code{\link{list_datasets}} for available datasets,
#'   \code{\link{get_dataset_info}} for dataset details
#'
#' @export
get_dataset <- function(name,
                       table = NULL,
                       source = "auto",
                       date_start = NULL,
                       date_end = NULL,
                       ...) {
  
  # Validate inputs
  source <- match.arg(source, choices = c("auto", "cache", "github", "fresh"))

  # Handle legacy dataset names
  if (name == "abecip_indicators") {
    cli::cli_warn("Dataset name 'abecip_indicators' is deprecated. Use 'abecip' instead.")
    name <- "abecip"
  }

  # Check if dataset exists
  registry <- load_dataset_registry()
  if (!name %in% names(registry$datasets)) {
    available <- paste(names(registry$datasets), collapse = ", ")
    cli::cli_abort("Dataset '{name}' not found. Available: {available}")
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

  # Show informative message about what was imported
  if (!is.null(data)) {
    show_import_message(name, table_info)
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

  # Special handling for RPPI stacked tables - these need fresh processing
  if (name == "rppi" && !is.null(table) && table %in% c("sale", "rent", "all")) {
    cli::cli_warn("RPPI stacked tables (sale/rent/all) require fresh processing due to outdated cache")
    cli::cli_inform("Falling back to fresh download...")
    # Force fresh download for stacked RPPI tables
    stop("GitHub cache incompatible with RPPI stacked tables")
  }

  # Map dataset name to import_cached parameter
  cached_name <- get_cached_name(name, dataset_info, table)

  if (is.null(cached_name)) {
    cli::cli_abort("No GitHub cache available for dataset '{name}'")
  }

  # Use existing import_cached function
  data <- import_cached(cached_name)
  
  # Filter by table if requested and data is a list
  if (!is.null(table) && is.list(data) && !inherits(data, "data.frame")) {
    if (table %in% names(data)) {
      data <- data[[table]]
    } else {
      available_tables <- paste(names(data), collapse = ", ")
      cli::cli_abort("Table '{table}' not found. Available: {available_tables}")
    }
  }

  # Special handling for SECOVI table filtering
  if (!is.null(table) && name == "secovi" && table != "all") {
    if ("category" %in% names(data)) {
      valid_tables <- c("condo", "rent", "launch", "sale")
      if (table %in% valid_tables) {
        data <- data[data$category == table, ]
        if (nrow(data) == 0) {
          cli::cli_abort("No data found for SECOVI table '{table}'")
        }
      } else {
        cli::cli_abort("Invalid SECOVI table: '{table}'. Valid options: {paste(valid_tables, collapse = ', ')}")
      }
    }
  }

  # Note: For datasets with table-specific cached files (like BIS),
  # the table filtering is handled by get_cached_name() above
  
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

  # Special parameter mappings based on function requirements
  if (legacy_function == "get_rppi") {
    # RPPI uses 'table' parameter (fixed from old 'category')
    if (!is.null(table)) {
      args$table <- table
    } else {
      args$table <- "sale"
    }
  } else if (legacy_function == "get_property_records") {
    # Property records now uses 'table' parameter
    if (!is.null(table)) {
      args$table <- table
    } else {
      args$table <- "capitals"  # Default to capitals since 'all' is no longer supported
    }
  } else {
    # All other functions use 'table' parameter
    if (!is.null(table)) {
      args$table <- table
    } else if (supports_table_all(legacy_function)) {
      # Set appropriate defaults based on function
      if (legacy_function == "get_cbic") {
        args$table <- "cement_monthly_consumption"  # CBIC default
      } else {
        args$table <- "all"  # Others default to all
      }
    }
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
    "abecip" = "abecip",
    "abrainc_indicators" = "abrainc",
    "bcb_realestate" = "bcb_realestate",
    "secovi" = "secovi_sp",
    "rppi_bis" = "bis_selected",  # Updated to use rppi_bis dataset name
    "rppi" = if (!is.null(table) && table %in% c("fipezap", "igmi", "ivgr", "iqa", "ivar", "secovi_sp")) {
      # Map individual RPPI tables to their cached files
      switch(table,
        "fipezap" = "rppi_fipe",
        "igmi" = "rppi_igmi",
        "ivgr" = "rppi_ivgr",
        "iqa" = "rppi_iqa",
        "ivar" = "rppi_ivar",
        "secovi_sp" = "secovi_sp"
      )
    } else {
      # Default to FipeZap for backwards compatibility and stacked tables
      "rppi_fipe"
    },
    "bcb_series" = "bcb_series",
    "b3_stocks" = "b3_stocks",
    "fgv_ibre" = "fgv_ibre",
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
    "get_rppi_bis",  # Updated function name
    "get_bcb_series",
    "get_cbic",
    "get_fgv_ibre",
    "get_property_records"
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

  # Special formatting for CBIC's many tables
  if (name == "cbic" && length(table_info$available_tables) > 5) {
    cli::cli_inform(c(
      "i" = "Retrieved '{imported_table}' from CBIC dataset",
      "i" = "For other tables use: get_dataset('cbic', table = '[table_name]')",
      "i" = "Run list_datasets() to see all available CBIC tables"
    ))
  } else {
    # Standard message for other datasets
    available_str <- paste(table_info$available_tables, collapse = "', '")

    if (table_info$is_default) {
      cli::cli_inform("Retrieved '{imported_table}' from '{name}' (default table). Available tables: '{available_str}'")
    } else {
      cli::cli_inform("Retrieved '{imported_table}' from '{name}'. Available tables: '{available_str}'")
    }
  }
}