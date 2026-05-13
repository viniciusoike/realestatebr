#' List Available Datasets
#'
#' Returns a tibble describing all datasets available in the realestatebr package.
#' Optionally filter by category, source organisation, or geographic coverage.
#'
#' @param category Optional character. Keyword matched against the dataset description
#'   (e.g., \code{"indicators"}, \code{"prices"}, \code{"credit"}).
#' @param source Optional character. Filter by data source organisation
#'   (e.g., \code{"BCB"}, \code{"FIPE"}, \code{"ABRAINC"}).
#' @param geography Optional character. Filter by geographic coverage
#'   (e.g., \code{"Brazil"}, \code{"São Paulo"}).
#'
#' @return A tibble with one row per dataset and the following columns:
#'   \describe{
#'     \item{name}{Dataset identifier used with \code{\link{get_dataset}}.}
#'     \item{title}{English dataset name.}
#'     \item{title_pt}{Portuguese dataset name.}
#'     \item{description}{Brief description.}
#'     \item{source}{Data source organisation.}
#'     \item{geography}{Geographic coverage.}
#'     \item{frequency}{Update frequency.}
#'     \item{coverage}{Time period covered.}
#'     \item{available_tables}{Comma-separated table names for multi-table datasets.}
#'   }
#'
#' @examples
#' # List all available datasets
#' datasets <- list_datasets()
#'
#' # Filter by data source
#' bcb_data <- list_datasets(source = "abecip")
#'
#' # Filter by geography
#' sao_paulo_data <- list_datasets(geography = "São Paulo")
#'
#' @seealso \code{\link{get_dataset}} for retrieving data,
#'   \code{\link{get_dataset_info}} for detailed metadata on a single dataset.
#'
#' @export
list_datasets <- function(
  category = NULL,
  source = NULL,
  geography = NULL
) {
  # Load the dataset registry
  registry <- load_dataset_registry()

  # Convert registry to tibble format
  datasets_df <- registry_to_tibble(registry)

  # Apply filters if provided
  if (!is.null(category)) {
    # Simple pattern matching for category filter
    datasets_df <- datasets_df[
      grepl(category, datasets_df$description, ignore.case = TRUE),
    ]
  }

  if (!is.null(source)) {
    datasets_df <- datasets_df[
      grepl(source, datasets_df$source, ignore.case = TRUE),
    ]
  }

  if (!is.null(geography)) {
    datasets_df <- datasets_df[
      grepl(geography, datasets_df$geography, ignore.case = TRUE),
    ]
  }

  # Sort by name for consistent output
  datasets_df <- datasets_df[order(datasets_df$name), ]

  # Add helpful message about usage
  if (nrow(datasets_df) > 0) {
    cli::cli_inform(
      "Found {nrow(datasets_df)} dataset{?s}. Use get_dataset(name) to retrieve data."
    )
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
  registry_path <- system.file(
    "extdata",
    "datasets.yaml",
    package = "realestatebr"
  )

  # Check if file exists
  if (!file.exists(registry_path) || registry_path == "") {
    cli::cli_abort(
      "Dataset registry not found. Package may not be properly installed."
    )
  }

  # Load and parse YAML
  tryCatch(
    {
      registry <- yaml::read_yaml(registry_path)
      return(registry)
    },
    error = function(e) {
      cli::cli_abort("Failed to load dataset registry: {e$message}")
    }
  )
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
      available_tables = available_tables,
      description = dataset$description %||% "",
      geography = dataset$geography %||% "",
      coverage = dataset$coverage %||% "",
      frequency = dataset$frequency %||% "",
      title_pt = dataset$name_pt %||% "",
      source = dataset$source %||% "",
      url = dataset$url %||% ""
    )
  })

  return(dataset_info)
}

#' Get Dataset Information
#'
#' Returns detailed metadata for a single dataset, including available tables
#' and source information.
#'
#' @param name Character. Dataset identifier (see \code{\link{list_datasets}} for options).
#'
#' @return A named list with the following elements:
#'   \describe{
#'     \item{metadata}{Title, description, geography, frequency, and coverage.}
#'     \item{categories}{Available tables/subtables and their descriptions.}
#'     \item{source_info}{Source organisation and URL.}
#'     \item{technical_info}{Cached file names and translation notes.}
#'   }
#'
#' @examples
#' info <- get_dataset_info("abecip")
#' str(info)
#'
#' @export
get_dataset_info <- function(name) {
  # Load registry
  registry <- load_dataset_registry()

  # Check if dataset exists
  if (!name %in% names(registry$datasets)) {
    available <- paste(names(registry$datasets), collapse = ", ")
    cli::cli_abort(
      "Dataset '{name}' not found. Available datasets: {available}"
    )
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
      coverage = dataset$coverage
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
