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
#' @param name Character. Dataset name (see \code{\link{list_datasets}} for
#'   options). Each dataset has its own help topic documenting tables and
#'   columns: \link{abecip}, \link{abrainc}, \link{bcb_realestate},
#'   \link{bcb_series}, \link{fgv_ibre}, \link{rppi}, \link{rppi_bis},
#'   and \link{secovi}.
#' @param table Character. Specific table within a multi-table dataset. See
#'   \code{\link{get_dataset_info}} for available tables per dataset.
#' @param source Character. Data source preference:
#'   \describe{
#'     \item{"auto"}{Use the in-session memo if available, otherwise GitHub releases, otherwise fresh download (default).}
#'     \item{"github"}{Pre-processed asset from the package's GitHub release.}
#'     \item{"fresh"}{Fresh download from the original source.}
#'   }
#'   Use \code{\link{clear_session_cache}} to drop the in-session memo.
#' @param quiet Logical. If `TRUE`, suppresses informational messages. Errors
#'   and warnings are still shown.
#'
#' @return A tibble or named list, depending on the dataset. Use
#'   \code{\link{get_dataset_info}} to inspect the expected structure.
#'
#' @details
#' To restrict a time series to a date window, filter the returned `date`
#' column with \code{dplyr::filter()}.
#'
#' @examplesIf interactive()
#' abecip_data <- get_dataset("abecip")
#'
#' sbpe_data <- get_dataset("abecip", table = "sbpe")
#'
#' bcb_data <- get_dataset("bcb_series", quiet = TRUE)
#'
#' bcb_recent <- dplyr::filter(bcb_data, date >= as.Date("2020-01-01"))
#'
#' @seealso \code{\link{list_datasets}} for available datasets,
#'   \code{\link{get_dataset_info}} for dataset details,
#'   \code{\link{clear_session_cache}} to drop the in-session memo.
#'   For table and column documentation of each dataset, see the dataset
#'   help topics: \link{abecip}, \link{abrainc}, \link{bcb_realestate},
#'   \link{bcb_series}, \link{fgv_ibre}, \link{rppi}, \link{rppi_bis},
#'   \link{secovi}.
#'
#' @export
get_dataset <- function(
  name,
  table = NULL,
  source = "auto",
  quiet = FALSE
) {
  source <- match.arg(source, choices = c("auto", "github", "fresh"))

  if (!rlang::is_bool(quiet)) {
    cli::cli_abort("{.arg quiet} must be `TRUE` or `FALSE`.")
  }

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
    result <- get_dataset_with_fallback(
      name,
      dataset_info,
      resolved_table,
      quiet
    )
  } else {
    result <- get_dataset_from_source(
      name,
      dataset_info,
      source,
      resolved_table,
      quiet
    )
  }

  if (!is.null(result$data) && !quiet) {
    show_import_message(name, table_info, result$tier)
  }

  return(result$data)
}

#' Get Dataset with Fallback Strategy
#'
#' Auto strategy: in-session memo -> GitHub release -> fresh download.
#'
#' @return A list with elements `data` and `tier`, where `tier` names the
#'   source that served the data.
#' @keywords internal
get_dataset_with_fallback <- function(
  name,
  dataset_info,
  table,
  quiet
) {
  memoed <- memo_get(memo_key(name, table))
  if (!is.null(memoed)) {
    return(list(data = memoed, tier = "memo"))
  }

  errors <- list()

  result <- rlang::try_fetch(
    get_dataset_from_source(name, dataset_info, "github", table, quiet),
    error = function(cnd) {
      errors$github <<- cnd$message
      if (!quiet) {
        cli::cli_warn(
          "GitHub release unavailable for {name}, downloading from the
           original source."
        )
      }
      NULL
    }
  )

  if (!is.null(result$data)) {
    return(result)
  }

  result <- rlang::try_fetch(
    get_dataset_from_source(name, dataset_info, "fresh", table, quiet),
    error = function(cnd) {
      errors$fresh <<- cnd$message
      if (!quiet) {
        cli::cli_warn("Fresh download failed: {cnd$message}")
      }
      NULL
    }
  )

  if (!is.null(result$data)) {
    return(result)
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
#' @return A list with elements `data` and `tier`.
#' @keywords internal
get_dataset_from_source <- function(
  name,
  dataset_info,
  source,
  table,
  quiet
) {
  data <- switch(
    source,
    "github" = get_from_github_cache(name, dataset_info, table, quiet),
    "fresh" = get_from_internal_function(name, dataset_info, table)
  )

  if (!is.null(data)) {
    memo_set(memo_key(name, table), data)
  }

  return(list(data = data, tier = source))
}

#' Get Data from GitHub Release Cache
#'
#' Downloads the appropriate asset into a tempfile and returns the
#' deserialised object, applying table filtering where applicable.
#'
#' @keywords internal
get_from_github_cache <- function(name, dataset_info, table, quiet = FALSE) {
  cached_name <- get_cached_name(name, dataset_info, table)

  if (is.null(cached_name)) {
    cli::cli_abort("No GitHub release asset available for dataset '{name}'")
  }

  data <- fetch_github_release_asset(cached_name, quiet = quiet)

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
#' original source. Their step-by-step progress messages are suppressed
#' unless debug mode is on, since `get_dataset()` reports the source itself.
#'
#' @keywords internal
get_from_internal_function <- function(name, dataset_info, table) {
  internal_function <- dataset_info$dataset_function

  if (is.null(internal_function) || internal_function == "") {
    cli::cli_abort(
      "No internal function available for fresh download of '{name}'"
    )
  }

  args <- list(quiet = !is_debug_mode())

  if (internal_function == "get_rppi") {
    args$table <- table %||% "sale"
  } else if (!is.null(table)) {
    args$table <- table
  } else if (supports_table_all(internal_function)) {
    args$table <- "all"
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
#' Reports the dataset, the table served, and the source that answered, in a
#' single message. Datasets resolved to their default table also list the
#' other tables available.
#'
#' @param tier Character. One of "memo", "github", or "fresh".
#' @keywords internal
show_import_message <- function(name, table_info, tier) {
  origin <- switch(
    tier,
    "memo" = "the session cache",
    "github" = "GitHub releases",
    "fresh" = "the original source"
  )

  imported_table <- table_info$resolved_table

  if (is.null(table_info$available_tables)) {
    cli::cli_inform("Loaded {name} from {origin}.")
    return(invisible())
  }

  msg <- "Loaded {name} table {.val {imported_table}} from {origin}."

  if (!table_info$is_default) {
    cli::cli_inform(msg)
    return(invisible())
  }

  other_tables <- setdiff(table_info$available_tables, imported_table)

  if (length(other_tables) == 0) {
    cli::cli_inform(msg)
    return(invisible())
  }

  cli::cli_inform(c(msg, "*" = "Other tables: {.val {other_tables}}."))

  return(invisible())
}
