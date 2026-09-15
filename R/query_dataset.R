#' Query a Large Dataset Lazily
#'
#' Opens a large dataset as one or more lazy DuckDB tables. No observations
#' enter R memory until the query is explicitly collected with
#' [dplyr::collect()]. Related tables returned in the same catalog share one
#' database connection and can be joined with standard dplyr verbs.
#'
#' @param name Character. Dataset identifier. See [list_datasets()] for
#'   datasets whose `access_mode` is `"query"`.
#' @param table Character or `NULL`. Return one table when supplied. When
#'   `NULL`, return a named catalog containing every related table.
#' @param version Character. Immutable dataset version, or `"latest"` to use
#'   the version referenced by the latest manifest.
#' @param quiet Logical. If `TRUE`, suppress informational messages.
#'
#' @return If `table` is supplied, a closable lazy `dbplyr` table. Otherwise,
#'   a `realestatebr_query_dataset` catalog containing named lazy tables. Close
#'   either result explicitly with `close()` when it is no longer needed.
#'
#' @examplesIf interactive()
#' cno <- query_dataset("cno")
#' on.exit(close(cno))
#'
#' works_sp <- cno$works |>
#'   dplyr::filter(.data$state == "SP")
#'
#' result <- works_sp |>
#'   dplyr::inner_join(cno$areas, by = "cno") |>
#'   dplyr::collect()
#'
#' @seealso [get_dataset()] for datasets returned directly in memory.
#' @export
query_dataset <- function(
  name,
  table = NULL,
  version = "latest",
  quiet = FALSE
) {
  validate_query_arguments(name, table, version, quiet)

  registry <- load_dataset_registry()
  if (!name %in% names(registry$datasets)) {
    available <- paste(names(registry$datasets), collapse = ", ")
    cli::cli_abort(
      "Dataset {.val {name}} not found. Available datasets: {available}."
    )
  }

  dataset_info <- registry$datasets[[name]]
  overrides <- getOption("realestatebr.query_manifest_urls")
  has_override <- !is.null(overrides) && name %in% names(overrides)
  if (identical(dataset_info$status, "hidden") && !has_override) {
    cli::cli_abort(c(
      "Dataset {.val {name}} is not available in this version.",
      "i" = "The remote data snapshot has not been published."
    ))
  }

  access_mode <- dataset_info$access_mode %||% "materialized"
  if (access_mode != "query") {
    cli::cli_abort(c(
      "Dataset {.val {name}} uses materialized access.",
      "i" = "Use {.code get_dataset(\"{name}\")} instead."
    ))
  }

  check_query_dependencies()
  available_tables <- names(dataset_info$categories)
  if (!is.null(table) && !table %in% available_tables) {
    cli::cli_abort(c(
      "Table {.val {table}} is not available for dataset {.val {name}}.",
      "i" = "Available tables: {.val {available_tables}}."
    ))
  }

  manifest_location <- resolve_query_manifest_location(
    name,
    dataset_info,
    version
  )
  manifest <- read_query_manifest(manifest_location)
  manifest_location <- attr(manifest, "manifest_location")
  expected_schema <- query_registry_schema(dataset_info$categories)
  validate_query_manifest(
    manifest,
    name,
    version,
    available_tables,
    dataset_info$query_manifest$schema_sha256,
    expected_schema
  )

  tables_to_open <- if (is.null(table)) available_tables else table
  owner <- open_query_connection(
    manifest,
    manifest_location,
    tables_to_open,
    expected_schema
  )
  tables <- lapply(
    tables_to_open,
    \(table_name) dplyr::tbl(owner$connection, table_name)
  )
  names(tables) <- tables_to_open

  if (!quiet) {
    cli::cli_inform(
      "Opened {.val {name}} version {.val {manifest$version}} as lazy DuckDB tables."
    )
  }

  if (!is.null(table)) {
    result <- tables[[1]]
    class(result) <- c("realestatebr_query_table", class(result))
    attr(result, "connection_owner") <- owner
    attr(result, "dataset_version") <- manifest$version
    return(result)
  }

  result <- structure(
    tables,
    class = c("realestatebr_query_dataset", "list"),
    dataset_name = name,
    dataset_version = manifest$version,
    retrieved_at = manifest$retrieved_at,
    connection_owner = owner
  )

  return(result)
}

#' @export
close.realestatebr_query_table <- function(con, ...) {
  owner <- attr(con, "connection_owner")
  close_query_connection(owner)
  invisible(NULL)
}

#' @export
print.realestatebr_query_dataset <- function(x, ...) {
  cli::cli_text(
    paste0(
      "<{.cls realestatebr_query_dataset}> ",
      "{.val {attr(x, 'dataset_name')}} version ",
      "{.val {attr(x, 'dataset_version')}}"
    )
  )
  cli::cli_text("Lazy tables: {.val {names(x)}}")
  invisible(x)
}

#' @export
close.realestatebr_query_dataset <- function(con, ...) {
  owner <- attr(con, "connection_owner")
  close_query_connection(owner)
  invisible(NULL)
}

validate_query_arguments <- function(name, table, version, quiet) {
  if (!rlang::is_string(name) || name == "") {
    cli::cli_abort("{.arg name} must be one non-empty string.")
  }
  if (!is.null(table) && (!rlang::is_string(table) || table == "")) {
    cli::cli_abort("{.arg table} must be `NULL` or one non-empty string.")
  }
  if (!rlang::is_string(version) || version == "") {
    cli::cli_abort("{.arg version} must be one non-empty string.")
  }
  valid_version <- identical(version, "latest") ||
    (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", version) &&
      !is.na(as.Date(version, format = "%Y-%m-%d")))
  if (!valid_version) {
    cli::cli_abort(
      "{.arg version} must be {.val latest} or use the YYYY-MM-DD format."
    )
  }
  if (!rlang::is_bool(quiet)) {
    cli::cli_abort("{.arg quiet} must be `TRUE` or `FALSE`.")
  }

  return(invisible(TRUE))
}

check_query_dependencies <- function() {
  dependencies <- c("DBI", "dbplyr", "duckdb")
  missing <- dependencies[
    !vapply(
      dependencies,
      requireNamespace,
      logical(1),
      quietly = TRUE
    )
  ]

  if (length(missing) > 0) {
    cli::cli_abort(c(
      "Lazy dataset access requires optional packages.",
      "i" = "Install them with {.code install.packages(c({.val {missing}}))}."
    ))
  }

  minimum_duckdb_version <- base::package_version("1.5.5")
  installed_duckdb_version <- utils::packageVersion("duckdb")
  if (installed_duckdb_version < minimum_duckdb_version) {
    cli::cli_abort(c(
      "Lazy dataset access requires DuckDB 1.5.5 or later.",
      "i" = "Update it with {.code install.packages(\"duckdb\")}.",
      "i" = "Installed version: {.val {installed_duckdb_version}}."
    ))
  }

  return(invisible(TRUE))
}

resolve_query_manifest_location <- function(name, dataset_info, version) {
  overrides <- getOption("realestatebr.query_manifest_urls")
  if (!is.null(overrides) && name %in% names(overrides)) {
    return(unname(overrides[[name]]))
  }

  if (version == "latest") {
    location <- dataset_info$query_manifest$latest_url
  } else {
    template <- dataset_info$query_manifest$version_url_template
    location <- if (is.null(template)) {
      NULL
    } else {
      sub("{version}", version, template, fixed = TRUE)
    }
  }
  if (is.null(location) || location == "") {
    cli::cli_abort(c(
      "The publication endpoint for dataset {.val {name}} is not configured.",
      "i" = "The query interface is available, but the remote data snapshot has not been published."
    ))
  }

  return(location)
}

read_query_manifest <- function(location, allow_pointer = TRUE) {
  text <- read_query_text(location)
  manifest <- tryCatch(
    jsonlite::fromJSON(text, simplifyVector = FALSE),
    error = function(cnd) {
      cli::cli_abort("Could not parse dataset manifest: {cnd$message}")
    }
  )

  if (is.null(manifest$tables) && !is.null(manifest$manifest_url)) {
    if (!allow_pointer) {
      cli::cli_abort("Dataset manifest contains more than one pointer level.")
    }
    target <- resolve_manifest_resource(location, manifest$manifest_url)
    return(read_query_manifest(target, allow_pointer = FALSE))
  }

  attr(manifest, "manifest_location") <- location

  return(manifest)
}

read_query_text <- function(location) {
  if (file.exists(location)) {
    return(paste(
      readLines(location, encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    ))
  }

  if (!grepl("^https://", location)) {
    cli::cli_abort(
      "Manifest location must be an existing file or an HTTPS URL: {.path {location}}."
    )
  }

  response <- tryCatch(
    httr::GET(location, httr::user_agent("realestatebr R package")),
    error = function(cnd) {
      cli::cli_abort("Could not download dataset manifest: {cnd$message}")
    }
  )
  if (httr::http_error(response)) {
    cli::cli_abort(
      "Could not download dataset manifest: HTTP {httr::status_code(response)}."
    )
  }

  return(httr::content(response, as = "text", encoding = "UTF-8"))
}

validate_query_manifest <- function(
  manifest,
  name,
  version,
  tables,
  expected_schema_sha256,
  expected_schema
) {
  required <- c(
    "dataset",
    "version",
    "schema_version",
    "schema_sha256",
    "retrieved_at",
    "tables"
  )
  missing <- setdiff(required, names(manifest))
  if (length(missing) > 0) {
    cli::cli_abort("Dataset manifest is missing fields: {.field {missing}}.")
  }
  if (!identical(manifest$dataset, name)) {
    cli::cli_abort(
      "Dataset manifest identifies {.val {manifest$dataset}}, not {.val {name}}."
    )
  }
  if (!identical(manifest$schema_version, 1L)) {
    cli::cli_abort(
      "Dataset manifest uses unsupported schema version {.val {manifest$schema_version}}."
    )
  }
  if (
    !rlang::is_string(manifest$schema_sha256) ||
      !grepl("^[0-9a-f]{64}$", manifest$schema_sha256)
  ) {
    cli::cli_abort("Dataset manifest has an invalid schema checksum.")
  }
  if (!identical(manifest$schema_sha256, expected_schema_sha256)) {
    cli::cli_abort(c(
      "Dataset schema is not compatible with this package version.",
      "i" = "Update {.pkg realestatebr} or select a compatible dataset snapshot."
    ))
  }
  if (version != "latest" && !identical(manifest$version, version)) {
    cli::cli_abort(c(
      "Requested dataset version {.val {version}} is not available at this manifest.",
      "i" = "The manifest contains version {.val {manifest$version}}."
    ))
  }

  missing_tables <- setdiff(tables, names(manifest$tables))
  if (length(missing_tables) > 0) {
    cli::cli_abort(
      "Dataset manifest is missing tables: {.val {missing_tables}}."
    )
  }

  for (table in tables) {
    files <- unlist(manifest$tables[[table]]$files, use.names = FALSE)
    valid_files <- vapply(files, rlang::is_string, logical(1))
    if (
      length(files) == 0 ||
        !all(valid_files) ||
        any(files == "")
    ) {
      cli::cli_abort(
        "Manifest table {.val {table}} has no valid Parquet files."
      )
    }
    if (
      !identical(manifest$tables[[table]]$columns, expected_schema[[table]])
    ) {
      cli::cli_abort(
        "Manifest schema does not match the package registry for table {.val {table}}."
      )
    }
  }

  return(invisible(TRUE))
}

query_registry_schema <- function(categories) {
  schema <- lapply(categories, function(category) {
    columns <- lapply(category$source_columns, function(column) {
      list(name = column$name, type = column$type)
    })
    names(columns) <- NULL
    return(columns)
  })

  return(schema)
}

open_query_connection <- function(
  manifest,
  manifest_location,
  tables,
  expected_schema
) {
  connection <- DBI::dbConnect(
    duckdb::duckdb(dbdir = ":memory:", shared_home = FALSE)
  )
  owner <- new.env(parent = emptyenv())
  owner$connection <- connection
  owner$closed <- FALSE
  reg.finalizer(owner, close_query_connection, onexit = TRUE)

  tryCatch(
    {
      resources <- lapply(tables, function(table) {
        files <- unlist(manifest$tables[[table]]$files, use.names = FALSE)
        vapply(
          files,
          \(file) resolve_manifest_resource(manifest_location, file),
          character(1)
        )
      })
      needs_httpfs <- any(vapply(
        resources,
        \(files) any(grepl("^https://", files)),
        logical(1)
      ))
      if (needs_httpfs) {
        DBI::dbExecute(connection, "INSTALL httpfs")
        DBI::dbExecute(connection, "LOAD httpfs")
      }

      for (index in seq_along(tables)) {
        table <- tables[[index]]
        create_query_view(
          connection,
          table,
          resources[[index]],
          expected_schema[[table]]
        )
      }
    },
    error = function(cnd) {
      close_query_connection(owner)
      cli::cli_abort("Could not open lazy dataset tables: {cnd$message}")
    }
  )

  return(owner)
}

create_query_view <- function(connection, table, files, expected_columns) {
  if (!grepl("^[a-z][a-z0-9_]*$", table)) {
    cli::cli_abort("Invalid table name in dataset manifest: {.val {table}}.")
  }

  quoted_files <- DBI::dbQuoteString(connection, files)
  files_sql <- paste(as.character(quoted_files), collapse = ", ")
  table_sql <- as.character(DBI::dbQuoteIdentifier(connection, table))
  statement <- paste0(
    "CREATE VIEW ",
    table_sql,
    " AS SELECT * FROM read_parquet([",
    files_sql,
    "], union_by_name = true)"
  )
  DBI::dbExecute(connection, statement)
  validate_query_view_schema(connection, table, expected_columns)

  return(invisible(TRUE))
}

validate_query_view_schema <- function(connection, table, expected_columns) {
  if (!is.list(expected_columns) || length(expected_columns) == 0) {
    cli::cli_abort(
      "Manifest table {.val {table}} has no declared column schema."
    )
  }

  expected_names <- unname(
    vapply(expected_columns, `[[`, character(1), "name")
  )
  expected_types <- unname(
    vapply(expected_columns, `[[`, character(1), "type")
  )
  statement <- paste0(
    "DESCRIBE SELECT * FROM ",
    as.character(DBI::dbQuoteIdentifier(connection, table))
  )
  actual <- DBI::dbGetQuery(connection, statement)

  if (
    !identical(actual$column_name, expected_names) ||
      !identical(actual$column_type, expected_types)
  ) {
    cli::cli_abort(c(
      "Parquet schema does not match the package registry for table {.val {table}}.",
      "x" = "Expected: {.val {paste(expected_names, expected_types)}}.",
      "x" = "Found: {.val {paste(actual$column_name, actual$column_type)}}."
    ))
  }

  return(invisible(TRUE))
}

resolve_manifest_resource <- function(manifest_location, resource) {
  if (grepl("^(https://|/)", resource)) {
    return(resource)
  }
  if (grepl("^https://", manifest_location)) {
    base_url <- sub("[^/]*$", "", manifest_location)
    return(paste0(base_url, resource))
  }

  path <- file.path(dirname(manifest_location), resource)
  return(normalizePath(path, mustWork = FALSE))
}

close_query_connection <- function(owner) {
  if (is.null(owner) || isTRUE(owner$closed)) {
    return(invisible(NULL))
  }
  if (DBI::dbIsValid(owner$connection)) {
    DBI::dbDisconnect(owner$connection, shutdown = TRUE)
  }
  owner$closed <- TRUE

  return(invisible(NULL))
}
