# Shared Parquet snapshot mechanics ----

replace_snapshot_view_with_parquet <- function(
  connection,
  normalized_view,
  parquet_path
) {
  statement <- paste0(
    "CREATE OR REPLACE VIEW ",
    quote_snapshot_identifier(connection, normalized_view),
    " AS SELECT * FROM read_parquet(",
    quote_snapshot_string(connection, parquet_path),
    ")"
  )
  DBI::dbExecute(connection, statement)

  return(invisible(TRUE))
}


write_snapshot_parquet <- function(
  connection,
  normalized_view,
  parquet_path,
  order_columns
) {
  order_sql <- paste(
    vapply(
      order_columns,
      \(column) quote_snapshot_identifier(connection, column),
      character(1)
    ),
    collapse = ", "
  )
  statement <- paste0(
    "COPY (SELECT * FROM ",
    quote_snapshot_identifier(connection, normalized_view),
    " ORDER BY ",
    order_sql,
    ") TO ",
    quote_snapshot_string(connection, parquet_path),
    " (FORMAT PARQUET, COMPRESSION ZSTD, ROW_GROUP_SIZE 122880)"
  )
  rows <- DBI::dbExecute(connection, statement)

  return(as.numeric(rows))
}


query_snapshot_scalar <- function(connection, statement) {
  value <- DBI::dbGetQuery(connection, statement)[[1]][[1]]
  return(as.numeric(value))
}


quote_snapshot_identifier <- function(connection, value) {
  return(as.character(DBI::dbQuoteIdentifier(connection, value)))
}


quote_snapshot_string <- function(connection, value) {
  return(as.character(DBI::dbQuoteString(connection, value)))
}


as_snapshot_manifest_array <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }

  return(as.list(unname(value)))
}


snapshot_schema <- function(categories) {
  return(lapply(categories, function(category) {
    columns <- lapply(category$source_columns, function(column) {
      return(list(name = column$name, type = column$type))
    })
    names(columns) <- NULL
    return(columns)
  }))
}

snapshot_schema_hash <- function(schema) {
  return(digest::digest(jsonlite::toJSON(schema, auto_unbox = TRUE),
    algo = "sha256", serialize = FALSE))
}

snapshot_file_metadata <- function(path) {
  return(list(file = basename(path), bytes = unname(file.size(path)),
    sha256 = digest::digest(path, algo = "sha256", file = TRUE)))
}

write_snapshot_manifest <- function(manifest, path) {
  jsonlite::write_json(manifest, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  return(invisible(path))
}
