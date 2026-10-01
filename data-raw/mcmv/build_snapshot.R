# Build MCMV Parquet snapshots ----

source("data-raw/pipeline/snapshot_helpers.R", local = TRUE)

mcmv_layouts <- function(info) {
  canonical <- lapply(info$categories, function(category) {
    return(stats::setNames(names(category$source_columns),
      vapply(category$source_columns, `[[`, "", "name")))
  })
  legacy <- canonical$financing
  march <- legacy[names(legacy) != "sex"]
  march["state"] <- "mcmv_fgts_txt_uf"
  july <- legacy[!names(legacy) %in% c("birth_date", "project_name")]
  july["state"] <- "mcmv_fgts_txt_uf"
  annual <- canonical$financing_summary[!names(canonical$financing_summary) %in%
    c("region", "contract_month", "income_band")]
  annual["state"] <- "txt_uf"
  annual["contract_year"] <- "num_ano_financiamento"
  adapter <- function(table, columns, locale, grain) {
    return(list(table = table, columns = columns, locale = locale, grain = grain))
  }
  return(list(
    financing_legacy = adapter("financing", legacy, "br", "financing observation"),
    financing_march = adapter("financing", march, "decimal", "financing observation"),
    financing_july = adapter("financing", july, "br", "financing observation"),
    summary_annual = adapter("financing_summary", annual, "br", "municipality/year"),
    summary_monthly = adapter("financing_summary", canonical$financing_summary,
      "decimal", "municipality/year/month/income_band"),
    projects_march = adapter("subsidized_projects", canonical$subsidized_projects,
      "decimal", "published project record"),
    projects_june = adapter("subsidized_projects", canonical$subsidized_projects,
      "br", "published project record")
  ))
}

# Input is always text; locale is a declared part of the adapter, not guessed.
create_mcmv_table <- function(connection, path, layout, info, view) {
  adapter <- mcmv_layouts(info)[[layout]]
  if (is.null(adapter)) cli::cli_abort("Unrecognized MCMV layout {.val {layout}}.")
  qi <- function(x) quote_snapshot_identifier(connection, x)
  qs <- function(x) quote_snapshot_string(connection, x)
  raw <- paste0(view, "_source")
  DBI::dbExecute(connection, paste0("CREATE OR REPLACE VIEW ", qi(raw),
    " AS SELECT * FROM read_csv(", qs(path),
    ", delim = ';', header = true, all_varchar = true, strict_mode = true, nullstr = '')"))
  actual <- DBI::dbGetQuery(connection, paste("DESCRIBE", qi(raw)))$column_name
  if (!identical(actual, unname(adapter$columns))) {
    cli::cli_abort("Source headers changed for MCMV layout {.val {layout}}.")
  }
  columns <- info$categories[[adapter$table]]$source_columns
  expressions <- character()
  checks <- character()
  for (column in columns) {
    target <- column$name
    type <- column$type
    src <- unname(adapter$columns[target])
    if (is.na(src)) {
      expressions <- c(expressions, paste0("CAST(NULL AS ", type, ") AS ", qi(target)))
      next
    }
    value <- qi(src)
    parsed <- value
    if (type %in% c("DOUBLE", "INTEGER") || target == "code_muni_6") {
      pattern <- if (adapter$locale == "br") {
        if (type == "DOUBLE") "[+-]?([0-9]+|[0-9]{1,3}(\\.[0-9]{3})+)(,[0-9]+)?" else "[0-9]+|[0-9]{1,3}(\\.[0-9]{3})+"
      } else {
        if (type == "DOUBLE") "[+-]?[0-9]+(\\.[0-9]+)?" else "[0-9]+"
      }
      checks <- c(checks, paste0("(", value, " IS NOT NULL AND NOT regexp_full_match(", value, ", ", qs(pattern), "))"))
      if (adapter$locale == "br") parsed <- paste0("replace(replace(", value, ", '.', ''), ',', '.')")
      if (target == "code_muni_6") {
        checks <- c(checks, paste0("(", value, " IS NOT NULL AND length(", parsed, ") <> 6)"))
      }
    } else if (type == "DATE") {
      format <- if (target == "reference_date" || adapter$table == "subsidized_projects") "%d/%m/%Y" else if (target == "birth_date") "%Y-%m-%d" else "%Y-%m-%d %H:%M:%S.%g"
      parsed <- paste0("try_strptime(", value, ", ", qs(format), ")")
      checks <- c(checks, paste0("(", value, " IS NOT NULL AND (", parsed,
        " IS NULL OR CAST(", parsed, " AS TIME) <> TIME '00:00:00'))"))
    }
    expressions <- c(expressions, paste0("CAST(", parsed, " AS ", type, ") AS ", qi(target)))
  }
  invalid <- query_snapshot_scalar(connection, paste0("SELECT count(*) FROM ", qi(raw), " WHERE ", paste(checks, collapse = " OR ")))
  if (invalid > 0) cli::cli_abort("Layout {.val {layout}} has {invalid} rows with invalid numeric/date values or nonmidnight timestamps.")
  DBI::dbExecute(connection, paste0("CREATE OR REPLACE VIEW ", qi(view), " AS SELECT ",
    paste(expressions, collapse = ", "), " FROM ", qi(raw)))
  return(adapter)
}

extract_mcmv_source <- function(path, directory) {
  if (!file.exists(path)) cli::cli_abort("Missing source {.path {path}}.")
  extension <- tolower(tools::file_ext(path))
  if (extension == "csv") return(normalizePath(path))
  if (!extension %in% c("zip", "rar")) cli::cli_abort("Expected CSV, ZIP, or RAR input.")
  executable <- Sys.which("bsdtar")
  if (!nzchar(executable)) cli::cli_abort("Install bsdtar to extract MCMV archives.")
  members <- system2(executable, c("-tf", shQuote(path)), stdout = TRUE)
  if (!is.null(attr(members, "status")) || any(grepl("(^/|(^|/)\\.\\.(/|$))", members))) {
    cli::cli_abort("Invalid source archive {.path {path}}.")
  }
  csv <- members[grepl("[.]csv$", members, ignore.case = TRUE)]
  if (length(csv) != 1L) cli::cli_abort("An MCMV archive must contain exactly one CSV.")
  dir.create(directory, recursive = TRUE)
  dest <- file.path(directory, "source.csv")
  status <- system2(executable, c("-xOf", shQuote(path), shQuote(csv)), stdout = dest)
  if (status != 0L) cli::cli_abort("Source archive extraction failed.")
  return(dest)
}

profile_mcmv_table <- function(connection, view, columns) {
  qi <- function(x) quote_snapshot_identifier(connection, x)
  sql <- function(x) DBI::dbGetQuery(connection, paste0("SELECT ", x, " FROM ", qi(view)))
  missing <- sql(paste(vapply(columns, function(column) {
    return(paste0("count(*) FILTER (WHERE ", qi(column$name), " IS NULL) AS ", qi(column$name)))
  }, ""), collapse = ", "))
  ranges <- list()
  categories <- list()
  for (column in columns) {
    name <- column$name
    if (column$type != "VARCHAR") {
      ranges[[name]] <- sql(paste0("min(", qi(name), ") AS min, max(", qi(name), ") AS max"))
      if (column$type %in% c("DOUBLE", "INTEGER")) {
        ranges[[name]]$negative <- query_snapshot_scalar(connection,
          paste0("SELECT count(*) FROM ", qi(view), " WHERE ", qi(name), " < 0"))
      }
    } else if (name %in% c("state", "region", "income_band", "sex", "financing_program",
      "fgts_account_holder", "property_type", "amortization_system", "financial_agent", "modality", "project_status")) {
      categories[[name]] <- DBI::dbGetQuery(connection, paste0("SELECT ", qi(name),
        " AS value, count(*) AS rows FROM ", qi(view), " GROUP BY 1 ORDER BY 1"))
    }
  }
  duplicates <- query_snapshot_scalar(connection, paste0("SELECT sum(n - 1) FROM (SELECT *, count(*) n FROM ",
    qi(view), " GROUP BY ALL HAVING count(*) > 1)"))
  if (is.na(duplicates)) duplicates <- 0
  return(list(missing = as.list(missing[1, ]), ranges = ranges,
    categories = categories, exact_duplicate_rows = duplicates))
}

reconcile_mcmv <- function(connection, monthly) {
  query <- function(sql) DBI::dbGetQuery(connection, sql)
  refs <- query("SELECT (SELECT min(reference_date) FROM financing) a_min,
    (SELECT max(reference_date) FROM financing) a_max,
    (SELECT min(reference_date) FROM financing_summary) s_min,
    (SELECT max(reference_date) FROM financing_summary) s_max")
  if (!monthly || anyNA(refs) || length(unique(unlist(refs))) != 1L) {
    return(list(status = "not comparable", reason = "different reference dates or historical annual grain"))
  }
  DBI::dbExecute(connection, "CREATE TEMP TABLE analytical_groups AS
    SELECT code_muni_6, year(contract_date) contract_year, month(contract_date) contract_month,
    income_band, sum(units_financed) units, sum(amount_financed) amount,
    sum(coalesce(subsidy_fgts_discount, 0) + coalesce(subsidy_ogu_discount, 0) +
      coalesce(subsidy_fgts_interest, 0) + coalesce(subsidy_ogu_interest, 0)) subsidy,
    count(*) records FROM financing GROUP BY ALL")
  DBI::dbExecute(connection, "CREATE TEMP TABLE summary_groups AS
    SELECT code_muni_6, contract_year, contract_month, income_band,
    sum(units_financed) units, sum(amount_financed) amount, sum(subsidy_total) subsidy,
    count(*) records FROM financing_summary GROUP BY ALL")
  result <- query("SELECT count(*) AS group_count,
    count(*) FILTER (WHERE a.records IS NULL OR s.records IS NULL) unmatched_groups,
    count(*) FILTER (WHERE a.units IS DISTINCT FROM s.units) unit_mismatches,
    count(*) FILTER (WHERE abs(a.amount-s.amount) > 0.01 OR ((a.amount IS NULL) <> (s.amount IS NULL))) amount_mismatches,
    count(*) FILTER (WHERE abs(a.subsidy-s.subsidy) > 0.01 OR ((a.subsidy IS NULL) <> (s.subsidy IS NULL))) subsidy_mismatches,
    max(abs(a.amount-s.amount)) max_amount_difference,
    max(abs(a.subsidy-s.subsidy)) max_subsidy_difference,
    count(*) FILTER (WHERE s.records > 1) repeated_summary_groups
    FROM analytical_groups a FULL OUTER JOIN summary_groups s
    ON a.code_muni_6 IS NOT DISTINCT FROM s.code_muni_6
    AND a.contract_year IS NOT DISTINCT FROM s.contract_year
    AND a.contract_month IS NOT DISTINCT FROM s.contract_month
    AND a.income_band IS NOT DISTINCT FROM s.income_band")
  return(c(list(status = "compared", tolerance_brl = 0.01,
    subsidy_null_policy = "sum available components for audit only; published NULLs unchanged"),
    as.list(result[1, ])))
}

build_mcmv_snapshot <- function(
  sources,
  layouts = c(financing = "financing_july", financing_summary = "summary_monthly",
    subsidized_projects = "projects_june"),
  output_dir = "data-raw/mcmv_output", version = as.character(Sys.Date()),
  registry_path = "inst/extdata/datasets.yaml", source_urls = NULL,
  source_license = "Unconfirmed; publication requires an explicit license review",
  memory_limit = "2GB", threads = 2L,
  retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
) {
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", version) || is.na(as.Date(version))) {
    cli::cli_abort("Snapshot version must use YYYY-MM-DD.")
  }
  info <- yaml::read_yaml(registry_path)$datasets$mcmv
  tables <- names(info$categories)
  if (!setequal(names(sources), tables) || !setequal(names(layouts), tables)) {
    cli::cli_abort("Supply exactly one source and layout for each MCMV table.")
  }
  schema <- snapshot_schema(info$categories)
  checksum <- snapshot_schema_hash(schema)
  if (!identical(checksum, info$query_manifest$schema_sha256)) cli::cli_abort("MCMV registry schema checksum mismatch.")
  snapshot_dir <- file.path(output_dir, version)
  staging <- paste0(snapshot_dir, ".staging")
  if (dir.exists(snapshot_dir) || dir.exists(staging)) cli::cli_abort("Snapshot output already exists.")
  dir.create(staging, recursive = TRUE)
  complete <- FALSE
  on.exit(if (!complete) unlink(staging, recursive = TRUE), add = TRUE)
  workspace <- tempfile("mcmv-build-")
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  con <- DBI::dbConnect(duckdb::duckdb(dbdir = ":memory:", shared_home = FALSE))
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, paste("SET memory_limit =", quote_snapshot_string(con, memory_limit)))
  DBI::dbExecute(con, paste("SET temp_directory =", quote_snapshot_string(con, workspace)))
  DBI::dbExecute(con, paste("SET threads =", as.integer(threads)))
  DBI::dbExecute(con, "SET preserve_insertion_order = false")
  metadata <- list()
  provenance <- list()
  for (table in tables) {
    cli::cli_inform("Building MCMV table {.val {table}} using {.val {layouts[[table]]}}.")
    path <- extract_mcmv_source(sources[[table]], file.path(workspace, table))
    adapter <- create_mcmv_table(con, path, layouts[[table]], info, table)
    if (adapter$table != table) cli::cli_abort("Layout does not match requested table.")
    source_rows <- query_snapshot_scalar(con, paste("SELECT count(*) FROM", paste0(table, "_source")))
    if (source_rows == 0) cli::cli_abort("MCMV source {.val {table}} has no rows.")
    parquet <- file.path(staging, paste0(table, ".parquet"))
    order <- c("state", "code_muni_6", if (table == "financing_summary") "contract_year" else "contract_date")
    fingerprint_sql <- paste0("SELECT CAST(sum(CAST(hash(",
      paste(vapply(schema[[table]], function(column) quote_snapshot_identifier(con, column$name), ""), collapse = ", "),
      ") AS HUGEINT)) AS VARCHAR) fingerprint FROM ", table)
    source_fingerprint <- DBI::dbGetQuery(con, fingerprint_sql)$fingerprint
    rows <- write_snapshot_parquet(con, table, parquet, order)
    replace_snapshot_view_with_parquet(con, table, parquet)
    parquet_rows <- query_snapshot_scalar(con, paste("SELECT count(*) FROM", table))
    parquet_fingerprint <- DBI::dbGetQuery(con, fingerprint_sql)$fingerprint
    if (!identical(source_fingerprint, parquet_fingerprint)) cli::cli_abort("Source/Parquet record fingerprints differ.")
    if (rows != source_rows || rows != parquet_rows) cli::cli_abort("Source/Parquet row counts differ.")
    actual <- DBI::dbGetQuery(con, paste("DESCRIBE", table))
    if (!identical(actual$column_name, vapply(schema[[table]], `[[`, "", "name")) ||
      !identical(actual$column_type, vapply(schema[[table]], `[[`, "", "type"))) {
      cli::cli_abort("MCMV Parquet schema mismatch.")
    }
    cli::cli_inform("Profiling {rows} rows in {.val {table}}.")
    profile <- profile_mcmv_table(con, table, schema[[table]])
    dates <- DBI::dbGetQuery(con, paste("SELECT DISTINCT reference_date FROM", table, "ORDER BY 1"))$reference_date
    file <- snapshot_file_metadata(parquet)
    metadata[[table]] <- list(grain = adapter$grain, columns = schema[[table]], rows = rows,
      files = list(file$file), bytes = file$bytes, sha256 = file$sha256,
      reference_dates = as.list(as.character(dates)), profile = profile,
      record_fingerprint = source_fingerprint)
    provenance[[table]] <- c(snapshot_file_metadata(sources[[table]]), list(
      url = if (is.null(source_urls)) NULL else source_urls[[table]],
      extracted_csv = snapshot_file_metadata(path), layout = layouts[[table]],
      numeric_locale = adapter$locale, source_rows = source_rows,
      source_columns = as.list(unname(adapter$columns)),
      available_columns = as.list(names(adapter$columns)),
      absent_columns = as.list(setdiff(actual$column_name, names(adapter$columns)))))
  }
  accounting <- DBI::dbGetQuery(con, "SELECT
    count(*) FILTER (WHERE operation_code IS NULL) missing_operation_codes,
    count(operation_code) - count(DISTINCT operation_code) repeated_operation_codes,
    count(*) FILTER (WHERE units_contracted IS NOT NULL AND units_delivered IS NOT NULL
      AND units_outstanding IS NOT NULL AND units_cancelled IS NOT NULL) complete_rows,
    count(*) FILTER (WHERE units_cancelled IS NULL) missing_cancellation_counts,
    count(*) FILTER (WHERE units_contracted <> units_delivered + units_outstanding + units_cancelled) unit_identity_mismatches
    FROM subsidized_projects")
  reconciliation <- reconcile_mcmv(con, layouts[["financing_summary"]] == "summary_monthly")
  if (layouts[["financing_summary"]] == "summary_monthly") {
    if (reconciliation$status != "compared") {
      cli::cli_abort("Monthly MCMV financing reconciliation requires matching reference dates.")
    }
    checks <- unlist(reconciliation[c("unmatched_groups", "unit_mismatches",
      "amount_mismatches", "subsidy_mismatches", "repeated_summary_groups")])
    if (!isTRUE(all(checks == 0))) {
      cli::cli_abort("Monthly MCMV financing reconciliation failed.")
    }
  }
  manifest <- list(dataset = "mcmv", version = version, schema_version = 1L,
    schema_sha256 = checksum, retrieved_at = retrieved_at,
    source = list(organization = info$source, url = info$url, license = source_license, files = provenance),
    tables = metadata, validation = list(project_accounting = as.list(accounting[1, ]), reconciliation = reconciliation))
  write_snapshot_manifest(manifest, file.path(staging, "manifest.json"))
  if (!file.rename(staging, snapshot_dir)) cli::cli_abort("Could not finalize staged snapshot.")
  complete <- TRUE
  cli::cli_inform("Built MCMV snapshot at {.path {snapshot_dir}}.")
  return(file.path(snapshot_dir, "manifest.json"))
}

validate_mcmv_existing_release <- function(candidate, published, assets) {
  # Parquet bytes may differ between rebuilds, so identity rests on record
  # fingerprints and source hashes rather than on Parquet checksums.
  signature <- function(manifest) {
    return(list(
      dataset = manifest$dataset, version = manifest$version,
      schema_version = manifest$schema_version,
      schema_sha256 = manifest$schema_sha256,
      source = list(
        organization = manifest$source$organization,
        url = manifest$source$url,
        license = manifest$source$license,
        files = lapply(manifest$source$files, function(file) {
          return(file[c("sha256", "url", "layout", "source_rows")])
        })
      ),
      tables = lapply(manifest$tables, function(table) {
        return(table[c("rows", "record_fingerprint", "columns", "files",
          "reference_dates")])
      })
    ))
  }
  if (!identical(signature(candidate), signature(published))) {
    cli::cli_abort("Existing MCMV release does not match the validated inputs.")
  }

  expected_files <- c("manifest.json", unlist(lapply(published$tables, `[[`, "files")))
  asset_names <- vapply(assets, `[[`, "", "name")
  if (anyDuplicated(asset_names) || !setequal(asset_names, expected_files)) {
    cli::cli_abort("Existing MCMV release assets do not match its manifest.")
  }
  for (table in published$tables) {
    file <- unlist(table$files, use.names = FALSE)
    if (length(file) != 1L) {
      cli::cli_abort("Existing MCMV release assets do not match its manifest.")
    }
    asset <- assets[[match(file, asset_names)]]
    if (!identical(as.numeric(asset$size), as.numeric(table$bytes))) {
      cli::cli_abort("Existing MCMV release assets do not match its manifest.")
    }
  }

  return(invisible(TRUE))
}
