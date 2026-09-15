# Build CNO Parquet snapshots ----

CNO_SOURCE_FILES <- c(
  works = "cno.csv",
  areas = "cno_areas.csv",
  cnaes = "cno_cnaes.csv",
  responsibilities = "cno_vinculos.csv"
)

build_cno_snapshot <- function(
  source_dir,
  output_dir = file.path("data-raw", "cno_output"),
  version = as.character(Sys.Date()),
  retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  registry_path = file.path("inst", "extdata", "datasets.yaml")
) {
  check_cno_build_dependencies()
  validate_cno_build_arguments(source_dir, output_dir, version, registry_path)

  registry <- yaml::read_yaml(registry_path)
  cno_info <- registry$datasets$cno
  if (is.null(cno_info)) {
    cli::cli_abort("The dataset registry has no {.val cno} entry.")
  }

  source_paths <- file.path(source_dir, unname(CNO_SOURCE_FILES))
  names(source_paths) <- names(CNO_SOURCE_FILES)
  totals_path <- file.path(source_dir, "cno_totais.csv")
  missing_files <- c(source_paths, totals_path)[
    !file.exists(c(source_paths, totals_path))
  ]
  if (length(missing_files) > 0) {
    cli::cli_abort("Missing CNO source files: {.path {missing_files}}.")
  }

  snapshot_dir <- file.path(output_dir, version)
  staging_dir <- paste0(snapshot_dir, ".staging")
  if (dir.exists(snapshot_dir) || dir.exists(staging_dir)) {
    cli::cli_abort(
      "Snapshot output already exists: {.path {snapshot_dir}}."
    )
  }
  dir.create(staging_dir, recursive = TRUE)
  complete <- FALSE
  on.exit(
    {
      if (!complete && dir.exists(staging_dir)) {
        unlink(staging_dir, recursive = TRUE)
      }
    },
    add = TRUE
  )

  connection <- DBI::dbConnect(
    duckdb::duckdb(dbdir = ":memory:", shared_home = FALSE)
  )
  on.exit(DBI::dbDisconnect(connection, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(connection, "INSTALL encodings")
  DBI::dbExecute(connection, "LOAD encodings")

  table_metadata <- list()
  schema_metadata <- list()
  for (table in names(CNO_SOURCE_FILES)) {
    cli::cli_inform("Building CNO table {.val {table}}.")
    category <- cno_info$categories[[table]]
    source_view <- paste0("source_", table)
    normalized_view <- paste0("normalized_", table)

    create_cno_source_view(connection, source_view, source_paths[[table]])
    validate_cno_source_headers(
      connection,
      source_view,
      names(category$source_columns),
      table
    )
    create_cno_normalized_view(
      connection,
      source_view,
      normalized_view,
      category$source_columns
    )

    parquet_path <- file.path(staging_dir, paste0(table, ".parquet"))
    order_columns <- if (table == "works") c("state", "cno") else "cno"
    source_rows <- write_cno_parquet(
      connection,
      normalized_view,
      parquet_path,
      order_columns
    )
    parquet_rows <- query_cno_scalar(
      connection,
      paste0(
        "SELECT count(*) FROM read_parquet(",
        quote_cno_string(connection, parquet_path),
        ")"
      )
    )
    if (!identical(source_rows, parquet_rows)) {
      cli::cli_abort(
        "Table {.val {table}} changed row count while writing Parquet."
      )
    }
    replace_cno_view_with_parquet(
      connection,
      normalized_view,
      parquet_path
    )

    distinct_cno <- query_cno_scalar(
      connection,
      paste0(
        "SELECT count(DISTINCT cno) FROM ",
        quote_cno_identifier(connection, normalized_view)
      )
    )
    columns <- lapply(category$source_columns, function(column) {
      list(name = column$name, type = column$type)
    })
    names(columns) <- NULL
    schema_metadata[[table]] <- columns
    table_metadata[[table]] <- list(
      grain = category$grain,
      primary_key = as_cno_manifest_array(category$primary_key),
      foreign_key = as_cno_manifest_array(category$foreign_key),
      columns = columns,
      rows = source_rows,
      distinct_cno = distinct_cno,
      files = list(paste0(table, ".parquet")),
      bytes = unname(file.size(parquet_path)),
      sha256 = digest::digest(parquet_path, algo = "sha256", file = TRUE)
    )
  }

  validate_cno_relations(connection)
  declared_totals <- read_cno_declared_totals(connection, totals_path)
  validate_cno_declared_totals(declared_totals, table_metadata)

  source_metadata <- lapply(source_paths, function(path) {
    list(
      file = basename(path),
      bytes = unname(file.size(path)),
      sha256 = digest::digest(path, algo = "sha256", file = TRUE)
    )
  })
  source_metadata$totals <- list(
    file = basename(totals_path),
    bytes = unname(file.size(totals_path)),
    sha256 = digest::digest(totals_path, algo = "sha256", file = TRUE)
  )

  schema_json <- jsonlite::toJSON(schema_metadata, auto_unbox = TRUE)
  schema_sha256 <- digest::digest(
    schema_json,
    algo = "sha256",
    serialize = FALSE
  )
  expected_schema_sha256 <- cno_info$query_manifest$schema_sha256
  if (!identical(schema_sha256, expected_schema_sha256)) {
    cli::cli_abort(c(
      "The generated CNO schema does not match the registry checksum.",
      "i" = "Generated checksum: {.val {schema_sha256}}."
    ))
  }

  manifest <- list(
    dataset = "cno",
    version = version,
    schema_version = 1L,
    schema_sha256 = schema_sha256,
    retrieved_at = retrieved_at,
    source = list(
      organization = cno_info$source,
      url = cno_info$url,
      license = "Creative Commons Attribution",
      files = source_metadata
    ),
    tables = table_metadata
  )
  manifest_path <- file.path(staging_dir, "manifest.json")
  jsonlite::write_json(
    manifest,
    manifest_path,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (!file.rename(staging_dir, snapshot_dir)) {
    cli::cli_abort(
      "Could not publish staged snapshot to {.path {snapshot_dir}}."
    )
  }
  complete <- TRUE
  cli::cli_inform(
    "Built CNO snapshot {.val {version}} at {.path {snapshot_dir}}."
  )

  return(file.path(snapshot_dir, "manifest.json"))
}

check_cno_build_dependencies <- function() {
  dependencies <- c("cli", "DBI", "digest", "duckdb", "jsonlite", "yaml")
  missing <- dependencies[
    !vapply(
      dependencies,
      requireNamespace,
      logical(1),
      quietly = TRUE
    )
  ]
  if (length(missing) > 0) {
    cli::cli_abort("Install build dependencies: {.pkg {missing}}.")
  }
  if (utils::packageVersion("duckdb") < base::package_version("1.5.5")) {
    cli::cli_abort("Building CNO snapshots requires DuckDB 1.5.5 or later.")
  }

  return(invisible(TRUE))
}

validate_cno_build_arguments <- function(
  source_dir,
  output_dir,
  version,
  registry_path
) {
  if (!dir.exists(source_dir)) {
    cli::cli_abort("{.arg source_dir} does not exist: {.path {source_dir}}.")
  }
  valid_version <- is.character(version) &&
    length(version) == 1L &&
    !is.na(version) &&
    grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", version) &&
    !is.na(as.Date(version, format = "%Y-%m-%d"))
  if (!valid_version) {
    cli::cli_abort("{.arg version} must use the YYYY-MM-DD format.")
  }
  if (!file.exists(registry_path)) {
    cli::cli_abort("Dataset registry not found: {.path {registry_path}}.")
  }
  if (!nzchar(output_dir)) {
    cli::cli_abort("{.arg output_dir} must be a non-empty path.")
  }

  return(invisible(TRUE))
}

create_cno_source_view <- function(connection, view, path) {
  statement <- paste0(
    "CREATE VIEW ",
    quote_cno_identifier(connection, view),
    " AS SELECT * FROM read_csv(",
    quote_cno_string(connection, path),
    ", header = true, all_varchar = true, encoding = 'cp1252', ",
    "strict_mode = true, nullstr = '')"
  )
  DBI::dbExecute(connection, statement)
  return(invisible(TRUE))
}

replace_cno_view_with_parquet <- function(
  connection,
  normalized_view,
  parquet_path
) {
  statement <- paste0(
    "CREATE OR REPLACE VIEW ",
    quote_cno_identifier(connection, normalized_view),
    " AS SELECT * FROM read_parquet(",
    quote_cno_string(connection, parquet_path),
    ")"
  )
  DBI::dbExecute(connection, statement)

  return(invisible(TRUE))
}

validate_cno_source_headers <- function(
  connection,
  source_view,
  expected,
  table
) {
  statement <- paste0(
    "DESCRIBE SELECT * FROM ",
    quote_cno_identifier(connection, source_view)
  )
  actual <- DBI::dbGetQuery(connection, statement)$column_name
  if (!identical(actual, expected)) {
    cli::cli_abort(c(
      "Source headers changed for CNO table {.val {table}}.",
      "x" = "Expected: {.val {expected}}.",
      "x" = "Found: {.val {actual}}."
    ))
  }

  return(invisible(TRUE))
}

create_cno_normalized_view <- function(
  connection,
  source_view,
  normalized_view,
  columns
) {
  expressions <- vapply(
    names(columns),
    function(source_name) {
      target <- columns[[source_name]]$name
      type <- columns[[source_name]]$type
      source_sql <- quote_cno_identifier(connection, source_name)
      target_sql <- quote_cno_identifier(connection, target)

      paste0(
        "CAST(NULLIF(",
        source_sql,
        ", '') AS ",
        type,
        ") AS ",
        target_sql
      )
    },
    character(1)
  )

  statement <- paste0(
    "CREATE VIEW ",
    quote_cno_identifier(connection, normalized_view),
    " AS SELECT ",
    paste(expressions, collapse = ", "),
    " FROM ",
    quote_cno_identifier(connection, source_view)
  )
  DBI::dbExecute(connection, statement)

  return(invisible(TRUE))
}

write_cno_parquet <- function(
  connection,
  normalized_view,
  parquet_path,
  order_columns
) {
  order_sql <- paste(
    vapply(
      order_columns,
      \(column) quote_cno_identifier(connection, column),
      character(1)
    ),
    collapse = ", "
  )
  statement <- paste0(
    "COPY (SELECT * FROM ",
    quote_cno_identifier(connection, normalized_view),
    " ORDER BY ",
    order_sql,
    ") TO ",
    quote_cno_string(connection, parquet_path),
    " (FORMAT PARQUET, COMPRESSION ZSTD, ROW_GROUP_SIZE 122880)"
  )
  rows <- DBI::dbExecute(connection, statement)

  return(as.numeric(rows))
}

validate_cno_relations <- function(connection) {
  duplicate_works <- query_cno_scalar(
    connection,
    paste(
      "SELECT count(*) - count(DISTINCT cno)",
      "FROM normalized_works"
    )
  )
  if (duplicate_works != 0) {
    cli::cli_abort(
      "CNO works contains {duplicate_works} duplicate identifiers."
    )
  }

  invalid_width <- query_cno_scalar(
    connection,
    paste(
      "SELECT count(*) FROM normalized_works",
      "WHERE cno IS NULL OR length(cno) <> 12"
    )
  )
  if (invalid_width != 0) {
    cli::cli_abort("CNO works contains {invalid_width} invalid identifiers.")
  }

  for (table in setdiff(names(CNO_SOURCE_FILES), "works")) {
    statement <- paste0(
      "SELECT count(*) FROM ",
      quote_cno_identifier(connection, paste0("normalized_", table)),
      " AS child LEFT JOIN normalized_works AS works USING (cno) ",
      "WHERE works.cno IS NULL"
    )
    orphan_rows <- query_cno_scalar(connection, statement)
    if (orphan_rows != 0) {
      cli::cli_abort(
        "CNO table {.val {table}} contains {orphan_rows} orphan rows."
      )
    }
  }

  return(invisible(TRUE))
}

read_cno_declared_totals <- function(connection, totals_path) {
  statement <- paste0(
    "SELECT CAST(\"Total de obras\" AS BIGINT) AS works, ",
    "CAST(\"Total de áreas\" AS BIGINT) AS areas, ",
    "CAST(\"Total de cnaes\" AS BIGINT) AS cnaes, ",
    "CAST(\"Total de vínculos\" AS BIGINT) AS responsibilities ",
    "FROM read_csv(",
    quote_cno_string(connection, totals_path),
    ", header = true, all_varchar = true, encoding = 'cp1252')"
  )

  return(DBI::dbGetQuery(connection, statement)[1, ])
}

validate_cno_declared_totals <- function(declared, table_metadata) {
  observed <- vapply(table_metadata, \(table) table$rows, numeric(1))
  declared <- unlist(declared[1, names(observed)], use.names = TRUE)
  if (!identical(unname(declared), unname(observed))) {
    cli::cli_abort(c(
      "CNO declared totals do not match the source tables.",
      "x" = "Declared: {.val {declared}}.",
      "x" = "Observed: {.val {observed}}."
    ))
  }

  return(invisible(TRUE))
}

query_cno_scalar <- function(connection, statement) {
  value <- DBI::dbGetQuery(connection, statement)[[1]][[1]]
  return(as.numeric(value))
}

quote_cno_identifier <- function(connection, value) {
  return(as.character(DBI::dbQuoteIdentifier(connection, value)))
}

quote_cno_string <- function(connection, value) {
  return(as.character(DBI::dbQuoteString(connection, value)))
}

as_cno_manifest_array <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }

  return(as.list(unname(value)))
}
