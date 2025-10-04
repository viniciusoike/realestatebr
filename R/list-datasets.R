#' List Available Datasets
#'
#' Returns information about all available datasets in the realestatebr package.
#' This provides a unified interface to discover all data sources and their
#' characteristics.
#'
#' @param category Optional. Filter datasets by category. Common categories include:
#'   "indicators", "prices", "credit", "stocks". Leave NULL to see all datasets.
#' @param source Optional. Filter by data source (e.g., "BCB", "FIPE", "ABRAINC").
#' @param geography Optional. Filter by geographic coverage (e.g., "Brazil", "São Paulo").
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{name}{Dataset identifier for use with get_dataset()}
#'     \item{title}{Human-readable name in English}
#'     \item{title_pt}{Human-readable name in Portuguese}
#'     \item{description}{Brief description of the dataset}
#'     \item{source}{Data source organization}
#'     \item{geography}{Geographic coverage}
#'     \item{frequency}{Update frequency}
#'     \item{coverage}{Time period coverage}
#'     \item{categories}{Number of categories/subtables}
#'     \item{available_tables}{Names of available tables (for multi-table datasets)}
#'     \item{data_type}{Type of data structure (tibble/list)}
#'     \item{legacy_function}{Original function name for backward compatibility}
#'   }
#'
#' @examples
#' \dontrun{
#' # List all available datasets
#' datasets <- list_datasets()
#'
#' # Filter by data source
#' bcb_data <- list_datasets(source = "BCB")
#'
#' # Filter by geography
#' sao_paulo_data <- list_datasets(geography = "São Paulo")
#'
#' # View available tables for multi-table datasets
#' View(list_datasets()$available_tables)
#'
#' # Get specific table from multi-table dataset
#' abecip_sbpe <- get_dataset("abecip", table = "sbpe")
#' }
#'
#' @seealso \code{\link{get_dataset}} for retrieving the actual data
#'
#' @export
list_datasets <- function(category = NULL, source = NULL, geography = NULL) {
  
  # Load the dataset registry
  registry <- load_dataset_registry()
  
  # Convert registry to tibble format
  datasets_df <- registry_to_tibble(registry)
  
  # Apply filters if provided
  if (!is.null(category)) {
    # Simple pattern matching for category filter
    datasets_df <- datasets_df[grepl(category, datasets_df$description, ignore.case = TRUE), ]
  }
  
  if (!is.null(source)) {
    datasets_df <- datasets_df[grepl(source, datasets_df$source, ignore.case = TRUE), ]
  }
  
  if (!is.null(geography)) {
    datasets_df <- datasets_df[grepl(geography, datasets_df$geography, ignore.case = TRUE), ]
  }
  
  # Sort by name for consistent output
  datasets_df <- datasets_df[order(datasets_df$name), ]
  
  # Add helpful message about usage
  if (nrow(datasets_df) > 0) {
    cli::cli_inform("Found {nrow(datasets_df)} dataset{?s}. Use get_dataset(name) to retrieve data.")
  } else {
    cli::cli_warn("No datasets found matching the specified criteria.")
  }
  
  return(datasets_df)
}

#' Load Dataset Registry from YAML
#'
#' Internal function to load the dataset registry from the inst/extdata/datasets.yaml file.
#'
#' @return A list containing the parsed YAML registry
#' @keywords internal
load_dataset_registry <- function() {
  
  # Find the datasets.yaml file
  registry_path <- system.file("extdata", "datasets.yaml", package = "realestatebr")
  
  # Check if file exists
  if (!file.exists(registry_path) || registry_path == "") {
    cli::cli_abort("Dataset registry not found. Package may not be properly installed.")
  }
  
  # Load and parse YAML
  tryCatch({
    registry <- yaml::read_yaml(registry_path)
    return(registry)
  }, error = function(e) {
    cli::cli_abort("Failed to load dataset registry: {e$message}")
  })
}

#' Convert Registry to Tibble
#'
#' Internal function to convert the nested YAML registry structure to a flat tibble
#' suitable for display and filtering.
#'
#' @param registry List containing the parsed YAML registry
#' @return A tibble with dataset information
#' @keywords internal
registry_to_tibble <- function(registry) {
  
  datasets <- registry$datasets
  
  # Extract information for each dataset
  dataset_info <- purrr::map_dfr(names(datasets), function(name) {
    dataset <- datasets[[name]]
    
    # Count categories and extract table names
    if (!is.null(dataset$categories)) {
      n_categories <- length(dataset$categories)
      available_tables <- paste(names(dataset$categories), collapse = ", ")
    } else {
      n_categories <- 1
      available_tables <- "(single table)"
    }

    # Create row
    tibble::tibble(
      name = name,
      title = dataset$name %||% name,
      title_pt = dataset$name_pt %||% "",
      description = dataset$description %||% "",
      source = dataset$source %||% "",
      geography = dataset$geography %||% "",
      frequency = dataset$frequency %||% "",
      coverage = dataset$coverage %||% "",
      categories = n_categories,
      available_tables = available_tables,
      data_type = dataset$data_type %||% "unknown",
      legacy_function = dataset$legacy_function %||% "",
      url = dataset$url %||% ""
    )
  })
  
  return(dataset_info)
}

#' Get Dataset Information
#'
#' Get detailed metadata for a specific dataset including available categories
#' and column descriptions.
#'
#' @param name Character. Name of the dataset (use list_datasets() to see available names)
#'
#' @return A list with detailed dataset information including:
#'   \describe{
#'     \item{metadata}{Basic dataset information}
#'     \item{categories}{Available categories/subtables}
#'     \item{source_info}{Data source details}
#'   }
#'
#' @examples
#' \dontrun{
#' # Get detailed info for ABECIP indicators
#' info <- get_dataset_info("abecip")
#' str(info)
#' }
#'
#' @export
get_dataset_info <- function(name) {
  
  # Load registry
  registry <- load_dataset_registry()
  
  # Check if dataset exists
  if (!name %in% names(registry$datasets)) {
    available <- paste(names(registry$datasets), collapse = ", ")
    cli::cli_abort("Dataset '{name}' not found. Available datasets: {available}")
  }
  
  dataset <- registry$datasets[[name]]
  
  # Structure the information
  info <- list(
    metadata = list(
      name = name,
      title = dataset$name,
      title_pt = dataset$name_pt,
      description = dataset$description,
      geography = dataset$geography,
      frequency = dataset$frequency,
      coverage = dataset$coverage,
      data_type = dataset$data_type,
      legacy_function = dataset$legacy_function
    ),
    categories = dataset$categories,
    source_info = list(
      source = dataset$source,
      url = dataset$url
    ),
    technical_info = list(
      cached_file = dataset$cached_file,
      metadata_table = dataset$metadata_table,
      translation_notes = dataset$translation_notes
    )
  )
  
  return(info)
}

# Helper function for null coalescing
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}