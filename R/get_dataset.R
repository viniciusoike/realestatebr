#' Get Dataset
#'
#' Unified interface for accessing all realestatebr datasets. Resolves data
#' from the package's GitHub release assets when possible (fast, pre-processed,
#' updated weekly by CI) and falls back to a fresh download from the original
#' source. Repeated calls within one R session are served from an in-memory
#' memo to avoid redundant network traffic.
#'
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom yaml read_yaml
#' @importFrom tibble tibble
#'
#' @param name Character. Dataset name (see \code{\link{list_datasets}} for options).
#' @param table Character. Specific table within a multi-table dataset. See
#'   \code{\link{get_dataset_info}} for available tables per dataset.
#' @param source Character. Data source preference:
#'   \describe{
#'     \item{"auto"}{Use the in-session memo if available, otherwise GitHub releases, otherwise fresh download (default).}
#'     \item{"github"}{Pre-processed asset from the package's GitHub release.}
#'     \item{"fresh"}{Fresh download from the original source.}
#'   }
#'   Use \code{\link{clear_session_cache}} to drop the in-session memo.
#' @param date_start Date. Start date for time series filtering (where applicable).
#' @param date_end Date. End date for time series filtering (where applicable).
#' @param ... Additional arguments passed to internal dataset functions.
#'
#' @return A tibble or named list, depending on the dataset. Use
#'   \code{\link{get_dataset_info}} to inspect the expected structure.
#'
#' @examplesIf interactive()
#' abecip_data <- get_dataset("abecip")
#'
#' sbpe_data <- get_dataset("abecip", table = "sbpe")
#'
#' bcb_recent <- get_dataset("bcb_series", date_start = as.Date("2020-01-01"))
#'
#' @seealso \code{\link{list_datasets}} for available datasets,
#'   \code{\link{get_dataset_info}} for dataset details,
#'   \code{\link{clear_session_cache}} to drop the in-session memo.
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
  source <- match.arg(source, choices = c("auto", "github", "fresh"))

  registry <- load_dataset_registry()
  if (!name %in% names(registry$datasets)) {
    available <- paste(names(registry$datasets), collapse = ", ")
    cli::cli_abort("Dataset '{name}' not found. Available: {available}")
  }

  dataset_info <- registry$datasets[[name]]

  if (!is.null(dataset_info$status) && dataset_info$status == "hidden") {
    cli::cli_abort(c(
      "Dataset '{name}' is not available in this version",
      "i" = "This dataset is under development",
      "i" = "Planned for future release"
    ))
  }

  table_info <- validate_and_resolve_table(name, dataset_info, table)
  resolved_table <- table_info$resolved_table

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

  if (!is.null(data)) {
    show_import_message(name, table_info)
  }

  return(data)
}

#' Get Dataset with Fallback Strategy
#'
#' Auto strategy: in-session memo -> GitHub release -> fresh download.
#'
#' @keywords internal
get_dataset_with_fallback <- function(
  name,
  dataset_info,
  table,
  date_start,
  date_end,
  ...
) {
  memoed <- memo_get(memo_key(name, table))
  if (!is.null(memoed)) {
    cli::cli_inform("Loaded {name} from in-session memo")
    return(memoed)
  }

  errors <- list()

  cli::cli_inform("Attempting to load {name} from GitHub releases...")
  data <- rlang::try_fetch(
    get_dataset_from_source(
      name,
      dataset_info,
      "github",
      table,
      date_start,
      date_end,
      ...
    ),
    error = function(cnd) {
      errors$github <<- cnd$message
      cli::cli_warn("GitHub release fetch failed: {cnd$message}")
      NULL
    }
  )

  if (!is.null(data)) {
    return(data)
  }

  cli::cli_inform("Attempting fresh download from original source...")
  data <- rlang::try_fetch(
    get_dataset_from_source(
      name,
      dataset_info,
      "fresh",
      table,
      date_start,
      date_end,
      ...
    ),
    error = function(cnd) {
      errors$fresh <<- cnd$message
      cli::cli_warn("Fresh download failed: {cnd$message}")
      NULL
    }
  )

  if (!is.null(data)) {
    return(data)
  }

  cli::cli_abort(paste(
    "All data sources failed for dataset '{name}':",
    "- GitHub release: {errors$github %||% 'Not attempted'}",
    "- Fresh download: {errors$fresh %||% 'Not attempted'}",
    "",
    "Troubleshooting:",
    "1. Check your internet connection",
    "2. Try source='fresh' to force a fresh download",
    "3. Check dataset availability with list_datasets()",
    sep = "\n"
  ))
}

#' Get Dataset from Specific Source
#'
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
  data <- switch(
    source,
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

  if (!is.null(data)) {
    memo_set(memo_key(name, table), data)
  }

  return(data)
}

#' Get Data from GitHub Release Cache
#'
#' Downloads the appropriate asset into a tempfile and returns the
#' deserialised object, applying table filtering where applicable.
#'
#' @keywords internal
get_from_github_cache <- function(name, dataset_info, table) {
  cached_name <- get_cached_name(name, dataset_info, table)

  if (is.null(cached_name)) {
    cli::cli_abort("No GitHub release asset available for dataset '{name}'")
  }

  data <- fetch_github_release_asset(cached_name, quiet = FALSE)

  if (is.null(data)) {
    cli::cli_abort(c(
      "Dataset '{name}' not found in GitHub release",
      "i" = "Try source='fresh' to download from the original source"
    ))
  }

  data <- apply_table_filtering(data, name, table)

  return(data)
}

#' Get Data from Internal Function
#'
#' Calls dataset-specific internal functions for a fresh download from the
#' original source.
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
  internal_function <- dataset_info$dataset_function

  if (is.null(internal_function) || internal_function == "") {
    cli::cli_abort(
      "No internal function available for fresh download of '{name}'"
    )
  }

  args <- list(...)

  if (internal_function == "get_rppi") {
    args$table <- table %||% "sale"
  } else if (!is.null(table)) {
    args$table <- table
  } else if (supports_table_all(internal_function)) {
    args$table <- "all"
  }

  if (!is.null(date_start)) {
    args$date_start <- date_start
  }
  if (!is.null(date_end)) {
    args$date_end <- date_end
  }

  func <- get(internal_function, mode = "function")
  data <- do.call(func, args)

  return(data)
}

#' Apply Table Filtering to Loaded Dataset
#'
#' @keywords internal
apply_table_filtering <- function(data, name, table) {
  if (is.null(table) || table == "all") {
    return(data)
  }

  if (is.list(data) && !inherits(data, "data.frame")) {
    if (table %in% names(data)) {
      return(data[[table]])
    } else {
      available_tables <- paste(names(data), collapse = ", ")
      cli::cli_abort("Table '{table}' not found. Available: {available_tables}")
    }
  }

  if (name == "secovi" && "category" %in% names(data)) {
    valid_tables <- c("condo", "rent", "launch", "sale")
    if (table %in% valid_tables) {
      data <- dplyr::filter(data, .data$category == table)
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

  if (name == "bcb_realestate" && "category" %in% names(data)) {
    category_mapping <- c(
      "accounting" = "contabil",
      "application" = "direcionamento",
      "indices" = "indices",
      "sources" = "fontes",
      "units" = "imoveis"
    )

    target_category <- category_mapping[[table]]
    if (!is.null(target_category)) {
      data <- dplyr::filter(data, .data$category == target_category)
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

  if (name == "bcb_series" && "code_bcb" %in% names(data)) {
    valid_tables <- c("core", "primary", "secondary", "tertiary", "full")

    if (table %in% valid_tables) {
      codes_bcb <- resolve_bcb_hierarchy(table)
      data <- dplyr::filter(data, .data$code_bcb %in% codes_bcb)

      cols_select <- c("date", "code_bcb", "name_simplified", "value")
      cols_present <- intersect(cols_select, names(data))
      data <- dplyr::select(data, dplyr::all_of(cols_present))

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

  return(data)
}

#' Build Memo Key for Dataset + Table
#'
#' @keywords internal
memo_key <- function(name, table) {
  paste(name, table %||% "_default_", sep = ":")
}

#' Get Cached Asset Stem for Dataset
#'
#' Maps a dataset name (and optional table) to the asset stem used in GitHub
#' releases — i.e. the file name without extension.
#'
#' @keywords internal
get_cached_name <- function(name, dataset_info, table = NULL) {
  cached_file <- dataset_info$cached_file

  if (!is.null(cached_file)) {
    if (is.character(cached_file)) {
      return(gsub("\\.(rds|csv\\.gz)$", "", basename(cached_file)))
    } else if (is.list(cached_file)) {
      if (!is.null(table) && table %in% names(cached_file)) {
        selected_file <- cached_file[[table]]
        return(gsub("\\.(rds|csv\\.gz)$", "", basename(selected_file)))
      }
      if (
        !is.null(table) && (table == "all" || !table %in% names(cached_file))
      ) {
        return(NULL)
      }
      first_file <- cached_file[[1]]
      return(gsub("\\.(rds|csv\\.gz)$", "", basename(first_file)))
    }
  }

  name_mapping <- list(
    "abecip" = "abecip",
    "abrainc_indicators" = "abrainc",
    "bcb_realestate" = "bcb_realestate",
    "secovi" = "secovi_sp",
    "rppi_bis" = "bis_selected",
    "rppi" = if (
      !is.null(table) &&
        table %in%
          c("fipezap", "igmi", "ivgr", "iqa", "iqaiw", "ivar", "secovi_sp")
    ) {
      switch(
        table,
        "fipezap" = "rppi_fipe",
        "igmi" = "rppi_igmi",
        "ivgr" = "rppi_ivgr",
        "iqa" = "rppi_iqa",
        "iqaiw" = "rppi_iqaiw",
        "ivar" = "rppi_ivar",
        "secovi_sp" = "rppi_secovi_sp"
      )
    } else {
      "rppi_fipe"
    },
    "bcb_series" = "bcb_series",
    "b3_stocks" = "b3_stocks",
    "fgv_ibre" = "fgv_ibre"
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
    "get_rppi_bis",
    "get_bcb_series",
    "get_fgv_ibre"
  )

  return(func_name %in% functions_with_table)
}

#' Get Available Tables from Dataset Info
#'
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
#' @keywords internal
validate_and_resolve_table <- function(name, dataset_info, table = NULL) {
  available_tables <- get_available_tables(dataset_info)

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

  if (is.null(table)) {
    if (!is.null(dataset_info$default_table)) {
      resolved_table <- dataset_info$default_table
    } else {
      resolved_table <- available_tables[1]
    }
    return(list(
      resolved_table = resolved_table,
      available_tables = available_tables,
      is_default = TRUE
    ))
  }

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
#' @keywords internal
show_import_message <- function(name, table_info) {
  if (is.null(table_info$available_tables)) {
    return(invisible())
  }

  imported_table <- table_info$resolved_table

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
