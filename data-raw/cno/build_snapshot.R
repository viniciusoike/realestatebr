# Build CNO Parquet snapshots ----

source("data-raw/pipeline/snapshot_helpers.R")

CNO_SOURCE_FILES <- c(
  constructions = "cno.csv",
  areas = "cno_areas.csv",
  cnaes = "cno_cnaes.csv",
  responsibilities = "cno_vinculos.csv"
)

CNO_CROSSWALK_URL <- "https://www.gov.br/receitafederal/dados/municipios.csv"
CNO_SENTINEL_DATE <- "DATE '1900-01-01'"
CNO_PLUS_CODE_PATTERN <- paste0(
  "([23456789CFGHJMPQRVWX]{2}){1,4}[+][23456789CFGHJMPQRVWX]{2,3}"
)

build_cno_snapshot <- function(
  source_dir,
  crosswalk_path = file.path(source_dir, "municipios.csv"),
  max_unmatched_share = 0.001,
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
  required_paths <- c(source_paths, totals_path, crosswalk_path)
  missing_files <- required_paths[!file.exists(required_paths)]
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
  create_cno_crosswalk(connection, crosswalk_path)

  table_metadata <- list()
  schema_metadata <- list()
  for (table in names(CNO_SOURCE_FILES)) {
    cli::cli_inform("Building CNO table {.val {table}}.")
    category <- cno_info$categories[[table]]
    source_view <- paste0("source_", table)
    typed_view <- paste0("typed_", table)
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
      typed_view,
      category$source_columns
    )
    create_cno_silver_view(
      connection,
      table,
      typed_view,
      normalized_view,
      category$source_columns
    )

    parquet_path <- file.path(staging_dir, paste0(table, ".parquet"))
    order_columns <- if (table == "constructions") c("state", "cno") else "cno"
    source_rows <- query_snapshot_scalar(
      connection,
      paste0(
        "SELECT count(*) FROM ",
        quote_snapshot_identifier(connection, typed_view)
      )
    )
    rows <- write_snapshot_parquet(
      connection,
      normalized_view,
      parquet_path,
      order_columns
    )
    parquet_rows <- query_snapshot_scalar(
      connection,
      paste0(
        "SELECT count(*) FROM read_parquet(",
        quote_snapshot_string(connection, parquet_path),
        ")"
      )
    )
    if (!identical(rows, parquet_rows)) {
      cli::cli_abort(
        "Table {.val {table}} changed row count while writing Parquet."
      )
    }
    replace_snapshot_view_with_parquet(
      connection,
      normalized_view,
      parquet_path
    )
    cleaning <- count_cno_fixes(
      connection,
      table,
      typed_view,
      normalized_view,
      category$source_columns
    )
    if (table == "constructions") {
      validate_cno_municipality_match(connection, max_unmatched_share)
    }

    distinct_cno <- query_snapshot_scalar(
      connection,
      paste0(
        "SELECT count(DISTINCT cno) FROM ",
        quote_snapshot_identifier(connection, normalized_view)
      )
    )
    columns <- snapshot_schema(cno_info$categories[table])[[table]]
    schema_metadata[[table]] <- columns
    table_metadata[[table]] <- list(
      grain = category$grain,
      primary_key = as_snapshot_manifest_array(category$primary_key),
      foreign_key = as_snapshot_manifest_array(category$foreign_key),
      columns = columns,
      source_rows = source_rows,
      rows = rows,
      cleaning = cleaning,
      distinct_cno = distinct_cno,
      files = list(paste0(table, ".parquet")),
      bytes = unname(file.size(parquet_path)),
      sha256 = digest::digest(parquet_path, algo = "sha256", file = TRUE)
    )
  }

  validate_cno_relations(connection)
  declared_totals <- read_cno_declared_totals(connection, totals_path)
  validate_cno_declared_totals(declared_totals, table_metadata)

  source_metadata <- lapply(source_paths, snapshot_file_metadata)
  source_metadata$totals <- snapshot_file_metadata(totals_path)
  source_metadata$crosswalk <- c(
    snapshot_file_metadata(crosswalk_path),
    url = CNO_CROSSWALK_URL
  )

  schema_sha256 <- snapshot_schema_hash(schema_metadata)
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
  write_snapshot_manifest(manifest, manifest_path)

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
    quote_snapshot_identifier(connection, view),
    " AS SELECT * FROM read_csv(",
    quote_snapshot_string(connection, path),
    ", header = true, all_varchar = true, encoding = 'cp1252', ",
    "strict_mode = true, nullstr = '')"
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
    quote_snapshot_identifier(connection, source_view)
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
      source_sql <- quote_snapshot_identifier(connection, source_name)
      target_sql <- quote_snapshot_identifier(connection, target)

      paste0(
        "CAST(NULLIF(trim(",
        source_sql,
        "), '') AS ",
        type,
        ") AS ",
        target_sql
      )
    },
    character(1)
  )

  statement <- paste0(
    "CREATE VIEW ",
    quote_snapshot_identifier(connection, normalized_view),
    " AS SELECT ",
    paste(expressions, collapse = ", "),
    " FROM ",
    quote_snapshot_identifier(connection, source_view)
  )
  DBI::dbExecute(connection, statement)

  return(invisible(TRUE))
}

create_cno_silver_view <- function(
  connection,
  table,
  typed_view,
  silver_view,
  columns
) {
  expressions <- vapply(
    columns,
    function(column) {
      target <- quote_snapshot_identifier(connection, column$name)
      if (column$type == "DATE") {
        return(paste0(
          "NULLIF(",
          target,
          ", ",
          CNO_SENTINEL_DATE,
          ") AS ",
          target
        ))
      }
      if (column$name == "plus_code") {
        return(paste0(
          "CASE WHEN regexp_full_match(upper(",
          target,
          "), ",
          quote_snapshot_string(connection, CNO_PLUS_CODE_PATTERN),
          ") THEN upper(",
          target,
          ") END AS ",
          target
        ))
      }
      return(target)
    },
    character(1)
  )
  from <- quote_snapshot_identifier(connection, typed_view)
  if (table == "constructions") {
    expressions <- c(expressions, "crosswalk.code_muni AS code_muni")
    from <- paste(
      from,
      "LEFT JOIN crosswalk ON municipality_tom_code = crosswalk.tom"
    )
  }
  # Areas have no row identifier; exact duplicates inflate area sums.
  select <- if (table == "areas") "SELECT DISTINCT " else "SELECT "

  statement <- paste0(
    "CREATE VIEW ",
    quote_snapshot_identifier(connection, silver_view),
    " AS ",
    select,
    paste(expressions, collapse = ", "),
    " FROM ",
    from
  )
  DBI::dbExecute(connection, statement)

  return(invisible(TRUE))
}

count_cno_fixes <- function(
  connection,
  table,
  typed_view,
  silver_view,
  columns
) {
  typed_sql <- quote_snapshot_identifier(connection, typed_view)
  silver_sql <- quote_snapshot_identifier(connection, silver_view)
  count_rows <- function(view_sql, expression = "count(*)") {
    query_snapshot_scalar(
      connection,
      paste("SELECT", expression, "FROM", view_sql)
    )
  }

  date_columns <- Filter(\(column) column$type == "DATE", columns)
  sentinel_dates <- lapply(date_columns, function(column) {
    target <- quote_snapshot_identifier(connection, column$name)
    count_rows(
      typed_sql,
      paste0("count(*) FILTER (WHERE ", target, " = ", CNO_SENTINEL_DATE, ")")
    )
  })
  names(sentinel_dates) <- vapply(date_columns, `[[`, "", "name")
  cleaning <- list(sentinel_dates = sentinel_dates)

  if (table == "constructions") {
    cleaning$invalid_plus_codes <- count_rows(typed_sql, "count(plus_code)") -
      count_rows(silver_sql, "count(plus_code)")
    cleaning$unmatched_municipalities <- count_rows(
      silver_sql,
      paste(
        "count(*) FILTER",
        "(WHERE municipality_tom_code IS NOT NULL AND code_muni IS NULL)"
      )
    )
  }
  if (table == "areas") {
    cleaning$duplicate_rows <- count_rows(typed_sql) - count_rows(silver_sql)
  }

  return(cleaning)
}

create_cno_crosswalk <- function(connection, path) {
  statement <- paste0(
    "CREATE TABLE crosswalk AS SELECT ",
    "lpad(trim(\"CÓDIGO DO MUNICÍPIO - TOM\"), 4, '0') AS tom, ",
    "CAST(trim(\"CÓDIGO DO MUNICÍPIO - IBGE\") AS INTEGER) AS code_muni ",
    "FROM read_csv(",
    quote_snapshot_string(connection, path),
    ", delim = ';', header = true, all_varchar = true, encoding = 'cp1252') ",
    # TOM 9707 (EXTERIOR) has IBGE code 0.
    "WHERE code_muni <> 0"
  )
  DBI::dbExecute(connection, statement)

  invalid <- query_snapshot_scalar(
    connection,
    paste(
      "SELECT count(*) - count(DISTINCT tom) +",
      "count(*) - count(DISTINCT code_muni) +",
      "count(*) FILTER (WHERE code_muni NOT BETWEEN 1100000 AND 5399999)",
      "FROM crosswalk"
    )
  )
  if (invalid != 0) {
    cli::cli_abort(
      "The TOM-to-IBGE crosswalk has repeated or invalid municipality codes."
    )
  }

  return(invisible(TRUE))
}

validate_cno_municipality_match <- function(connection, max_unmatched_share) {
  share <- query_snapshot_scalar(
    connection,
    paste(
      "SELECT count(*) FILTER (WHERE code_muni IS NULL) /",
      "greatest(count(*), 1) FROM normalized_constructions",
      "WHERE municipality_tom_code IS NOT NULL"
    )
  )
  if (share > max_unmatched_share) {
    cli::cli_abort(c(
      "CNO municipality codes do not match the TOM-to-IBGE crosswalk.",
      "x" = "Unmatched share: {.val {round(share, 4)}}."
    ))
  }

  return(invisible(TRUE))
}

validate_cno_relations <- function(connection) {
  duplicate_constructions <- query_snapshot_scalar(
    connection,
    paste(
      "SELECT count(*) - count(DISTINCT cno)",
      "FROM normalized_constructions"
    )
  )
  if (duplicate_constructions != 0) {
    cli::cli_abort(
      "CNO constructions contains {duplicate_constructions} duplicate identifiers."
    )
  }

  invalid_width <- query_snapshot_scalar(
    connection,
    paste(
      "SELECT count(*) FROM normalized_constructions",
      "WHERE cno IS NULL OR length(cno) <> 12"
    )
  )
  if (invalid_width != 0) {
    cli::cli_abort(
      "CNO constructions contains {invalid_width} invalid identifiers."
    )
  }

  for (table in setdiff(names(CNO_SOURCE_FILES), "constructions")) {
    statement <- paste0(
      "SELECT count(*) FROM ",
      quote_snapshot_identifier(connection, paste0("normalized_", table)),
      " AS child LEFT JOIN normalized_constructions AS constructions USING (cno) ",
      "WHERE constructions.cno IS NULL"
    )
    orphan_rows <- query_snapshot_scalar(connection, statement)
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
    "SELECT CAST(\"Total de obras\" AS BIGINT) AS constructions, ",
    "CAST(\"Total de áreas\" AS BIGINT) AS areas, ",
    "CAST(\"Total de cnaes\" AS BIGINT) AS cnaes, ",
    "CAST(\"Total de vínculos\" AS BIGINT) AS responsibilities ",
    "FROM read_csv(",
    quote_snapshot_string(connection, totals_path),
    ", header = true, all_varchar = true, encoding = 'cp1252')"
  )

  return(DBI::dbGetQuery(connection, statement)[1, ])
}

validate_cno_declared_totals <- function(declared, table_metadata) {
  observed <- vapply(table_metadata, \(table) table$source_rows, numeric(1))
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
