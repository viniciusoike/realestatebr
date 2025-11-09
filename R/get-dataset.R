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
#'     \item{"auto"}{Automatic fallback: user cache → GitHub releases → fresh (default)}
#'     \item{"cache"}{User cache only (stored in ~/.local/share/realestatebr/)}
#'     \item{"github"}{Download from GitHub releases (requires piggyback package)}
#'     \item{"fresh"}{Fresh download from original source (saves to user cache)}
#'   }
#' @param date_start Date. Start date for time series data (where applicable)
#' @param date_end Date. End date for time series data (where applicable)
#' @param ... Additional arguments passed to internal functions
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
get_dataset <- function(
  name,
  table = NULL,
  source = "auto",
  date_start = NULL,
  date_end = NULL,
  ...
) {
  # Validate inputs
  source <- match.arg(source, choices = c("auto", "cache", "github", "fresh"))

  # Check if dataset exists
  registry <- load_dataset_registry()
  if (!name %in% names(registry$datasets)) {
    available <- paste(names(registry$datasets), collapse = ", ")
    cli::cli_abort("Dataset '{name}' not found. Available: {available}")
  }

  dataset_info <- registry$datasets[[name]]

  # Check if dataset is hidden
  if (!is.null(dataset_info$status) && dataset_info$status == "hidden") {
    cli::cli_abort(c(
      "Dataset '{name}' is not available in this version",
      "i" = "This dataset is under development",
      "i" = "Planned for future release"
    ))
  }

  # Validate and resolve table parameter
  table_info <- validate_and_resolve_table(name, dataset_info, table)
  resolved_table <- table_info$resolved_table

  # Try to get data with fallback strategy
  if (source == "auto") {
    data <- get_dataset_with_fallback(
      name,
      dataset_info,
      resolved_table,
      date_start,
      date_end,
      ...
    )
  } else {
    data <- get_dataset_from_source(
      name,
      dataset_info,
      source,
      resolved_table,
      date_start,
      date_end,
      ...
    )
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
get_dataset_with_fallback <- function(
  name,
  dataset_info,
  table,
  date_start,
  date_end,
  ...
) {
  # Initialize error tracking
  errors <- list()

  # Try 1: User cache (fastest - no network needed)
  cli::cli_inform("Checking user cache for {name}...")
  data <- tryCatch(
    {
      get_dataset_from_source(
        name,
        dataset_info,
        "cache",
        table,
        date_start,
        date_end,
        ...
      )
    },
    error = function(e) {
      errors$cache <<- e$message
      cli::cli_inform("User cache not available: {e$message}")
      NULL
    }
  )

  if (!is.null(data)) {
    cli::cli_inform("Successfully loaded from user cache")
    return(data)
  }

  # Try 2: GitHub releases (pre-processed data)
  cli::cli_inform("Attempting to download {name} from GitHub releases...")
  data <- tryCatch(
    {
      get_dataset_from_source(
        name,
        dataset_info,
        "github",
        table,
        date_start,
        date_end,
        ...
      )
    },
    error = function(e) {
      errors$github <<- e$message
      cli::cli_warn("GitHub download failed: {e$message}")
      NULL
    }
  )

  if (!is.null(data)) {
    cli::cli_inform("Successfully downloaded from GitHub releases")
    return(data)
  }

  # Try 3: Fresh download from original source
  cli::cli_inform("Attempting fresh download from original source...")
  data <- tryCatch(
    {
      get_dataset_from_source(
        name,
        dataset_info,
        "fresh",
        table,
        date_start,
        date_end,
        ...
      )
    },
    error = function(e) {
      errors$fresh <<- e$message
      cli::cli_warn("Fresh download failed: {e$message}")
      NULL
    }
  )

  if (!is.null(data)) {
    cli::cli_inform("Successfully downloaded from original source")
    return(data)
  }

  # All sources failed - provide detailed error information
  error_details <- paste(
    "All data sources failed for dataset '{name}':",
    "- User cache: {errors$cache %||% 'Not attempted'}",
    "- GitHub releases: {errors$github %||% 'Not attempted'}",
    "- Fresh download: {errors$fresh %||% 'Not attempted'}",
    "",
    "Troubleshooting:",
    "1. Check your internet connection",
    "2. Install piggyback: install.packages('piggyback')",
    "3. Try source='fresh' to force fresh download from original source",
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
get_dataset_from_source <- function(
  name,
  dataset_info,
  source,
  table,
  date_start,
  date_end,
  ...
) {
  switch(
    source,
    "cache" = get_from_local_cache(name, dataset_info, table),
    "github" = get_from_github_cache(name, dataset_info, table),
    "fresh" = get_from_internal_function(
      name,
      dataset_info,
      table,
      date_start,
      date_end,
      ...
    )
  )
}

#' Get Data from Local Cache
#'
#' Loads dataset from user-level cache directory.
#'
#' @keywords internal
get_from_local_cache <- function(name, dataset_info, table) {
  # Map dataset name to cache file name
  cached_name <- get_cached_name(name, dataset_info, table)

  if (is.null(cached_name)) {
    cli::cli_abort("No cache available for dataset '{name}'")
  }

  # Load from user cache
  data <- load_from_user_cache(cached_name, quiet = FALSE)

  if (is.null(data)) {
    cli::cli_abort(c(
      "Dataset '{name}' not found in cache",
      "i" = "Try source='github' to download from GitHub releases",
      "i" = "Or source='fresh' to download from original source"
    ))
  }

  # Apply table filtering if needed
  data <- apply_table_filtering(data, name, table)

  return(data)
}

#' Get Data from GitHub Cache
#'
#' Downloads dataset from GitHub releases to user cache, then loads it.
#'
#' @keywords internal
get_from_github_cache <- function(name, dataset_info, table) {
  # Special handling for RPPI stacked tables - these need fresh processing
  if (
    name == "rppi" && !is.null(table) && table %in% c("sale", "rent", "all")
  ) {
    cli::cli_warn(
      "RPPI stacked tables (sale/rent/all) require fresh processing"
    )
    cli::cli_inform("Falling back to fresh download...")
    # Force fresh download for stacked RPPI tables
    stop("GitHub cache incompatible with RPPI stacked tables")
  }

  # Map dataset name to cache file name
  cached_name <- get_cached_name(name, dataset_info, table)

  if (is.null(cached_name)) {
    cli::cli_abort("No GitHub cache available for dataset '{name}'")
  }

  # Download from GitHub releases to user cache
  data <- download_from_github_release(cached_name, overwrite = FALSE, quiet = FALSE)

  # Apply table filtering if needed
  # Note: For datasets with table-specific cached files (like BIS),
  # the table filtering is handled by get_cached_name() above
  data <- apply_table_filtering(data, name, table)

  return(data)
}

#' Get Data from Internal Function
#'
#' Calls internal dataset-specific functions (e.g., get_abecip_indicators) for
#' fresh data downloads. These are the core internal functions, not legacy code.
#'
#' @keywords internal
get_from_internal_function <- function(
  name,
  dataset_info,
  table,
  date_start,
  date_end,
  ...
) {
  # Get the dataset-specific function name from registry
  internal_function <- dataset_info$dataset_function

  if (is.null(internal_function) || internal_function == "") {
    cli::cli_abort(
      "No internal function available for fresh download of '{name}'"
    )
  }

  # Build arguments for internal function
  args <- list(...)

  # Special parameter mappings based on function requirements
  if (internal_function == "get_rppi") {
    # RPPI uses 'table' parameter (fixed from old 'category')
    if (!is.null(table)) {
      args$table <- table
    } else {
      args$table <- "sale"
    }
  } else if (internal_function == "get_property_records") {
    # Property records now uses 'table' parameter
    if (!is.null(table)) {
      args$table <- table
    } else {
      args$table <- "capitals" # Default to capitals since 'all' is no longer supported
    }
  } else {
    # All other functions use 'table' parameter
    if (!is.null(table)) {
      args$table <- table
    } else if (supports_table_all(internal_function)) {
      # Set appropriate defaults based on function
      if (internal_function == "get_cbic") {
        args$table <- "cement_monthly_consumption" # CBIC default
      } else {
        args$table <- "all" # Others default to all
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

  # Call the internal function
  func <- get(internal_function, mode = "function")
  data <- do.call(func, args)

  # Save freshly downloaded data to user cache for future use
  if (!is.null(data)) {
    cached_name <- get_cached_name(name, dataset_info, table)
    if (!is.null(cached_name)) {
      # Determine format based on data type
      format <- if (is.data.frame(data)) "csv.gz" else "rds"

      # Save to user cache (don't show message to avoid clutter)
      save_to_user_cache(data, cached_name, format = format, quiet = TRUE)
    }
  }

  return(data)
}

#' Apply Table Filtering to Loaded Dataset
#'
#' Applies table/category filtering logic for datasets that support multiple tables.
#' Used by both get_from_local_cache() and get_from_github_cache().
#'
#' @param data Dataset to filter
#' @param name Dataset name
#' @param table Table name to filter by (or NULL)
#' @return Filtered dataset
#' @keywords internal
apply_table_filtering <- function(data, name, table) {
  # No filtering needed if table is NULL or "all"
  if (is.null(table) || table == "all") {
    return(data)
  }

  # Special handling for property_records nested structure
  if (name == "property_records") {
    return(extract_property_table(data, table))
  }

  # For list data (not data frames), extract the named element
  if (is.list(data) && !inherits(data, "data.frame")) {
    if (table %in% names(data)) {
      return(data[[table]])
    } else {
      available_tables <- paste(names(data), collapse = ", ")
      cli::cli_abort("Table '{table}' not found. Available: {available_tables}")
    }
  }

  # Special handling for SECOVI table filtering
  if (name == "secovi" && "category" %in% names(data)) {
    valid_tables <- c("condo", "rent", "launch", "sale")
    if (table %in% valid_tables) {
      data <- data[data$category == table, ]
      if (nrow(data) == 0) {
        cli::cli_abort("No data found for SECOVI table '{table}'")
      }
      return(data)
    } else {
      cli::cli_abort(
        "Invalid SECOVI table: '{table}'. Valid options: {paste(valid_tables, collapse = ', ')}"
      )
    }
  }

  # Special handling for BCB Real Estate table filtering
  if (name == "bcb_realestate" && "category" %in% names(data)) {
    # Map user-facing table names to internal category values
    category_mapping <- c(
      "accounting" = "contabil",
      "application" = "direcionamento",
      "indices" = "indices",
      "sources" = "fontes",
      "units" = "imoveis"
    )

    target_category <- category_mapping[[table]]
    if (!is.null(target_category)) {
      data <- data[data$category == target_category, ]
      if (nrow(data) == 0) {
        cli::cli_abort("No data found for BCB Real Estate table '{table}'")
      }
      return(data)
    } else {
      valid_tables <- names(category_mapping)
      cli::cli_abort(
        "Invalid BCB Real Estate table: '{table}'. Valid options: {paste(valid_tables, collapse = ', ')}, all"
      )
    }
  }

  # Special handling for BCB Series table filtering
  if (name == "bcb_series" && "bcb_category" %in% names(data)) {
    valid_tables <- c(
      "price", "credit", "production", "interest-rate",
      "exchange", "government", "real-estate"
    )

    if (table %in% valid_tables) {
      data <- data[data$bcb_category == table, ]
      if (nrow(data) == 0) {
        cli::cli_abort("No data found for BCB Series table '{table}'")
      }
      return(data)
    } else {
      cli::cli_abort(
        "Invalid BCB Series table: '{table}'. Valid options: {paste(valid_tables, collapse = ', ')}, all"
      )
    }
  }

  # If no special handling applies, return data as-is
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
    "rppi_bis" = "bis_selected", # Updated to use rppi_bis dataset name
    "rppi" = if (
      !is.null(table) &&
        table %in% c("fipezap", "igmi", "ivgr", "iqa", "iqaiw", "ivar", "secovi_sp")
    ) {
      # Map individual RPPI tables to their cached files
      switch(
        table,
        "fipezap" = "rppi_fipe",
        "igmi" = "rppi_igmi",
        "ivgr" = "rppi_ivgr",
        "iqa" = "rppi_iqa",
        "iqaiw" = "rppi_iqaiw",
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
    "nre_ire" = "nre_ire"
  )

  return(name_mapping[[name]])
}

#' Check if Internal Function Supports table="all"
#'
#' @keywords internal
supports_table_all <- function(func_name) {
  functions_with_table <- c(
    "get_abecip_indicators",
    "get_abrainc_indicators",
    "get_bcb_realestate",
    "get_secovi",
    "get_rppi_bis", # Updated function name
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
    return(data) # No translation needed
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
      cli::cli_warn(
        "Dataset '{name}' has only one table. Ignoring table parameter."
      )
    }
    return(list(
      resolved_table = NULL,
      available_tables = NULL,
      is_default = TRUE
    ))
  }

  # Multi-table datasets
  if (is.null(table)) {
    # Check if dataset has a specified default_table in registry
    if (!is.null(dataset_info$default_table)) {
      resolved_table <- dataset_info$default_table
    } else {
      # Use first table as default (alphabetically)
      resolved_table <- available_tables[1]
    }
    return(list(
      resolved_table = resolved_table,
      available_tables = available_tables,
      is_default = TRUE
    ))
  }

  # Validate specified table
  # Allow "all" as a special value that means "all tables"
  if (table != "all" && !table %in% available_tables) {
    available_str <- paste(available_tables, collapse = "', '")
    cli::cli_abort(
      "Invalid table '{table}' for dataset '{name}'. Available tables: '{available_str}', 'all'."
    )
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
      cli::cli_inform(
        "Retrieved '{imported_table}' from '{name}' (default table). Available tables: '{available_str}'"
      )
    } else {
      cli::cli_inform(
        "Retrieved '{imported_table}' from '{name}'. Available tables: '{available_str}'"
      )
    }
  }
}
