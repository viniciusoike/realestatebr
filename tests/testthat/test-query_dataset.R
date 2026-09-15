make_cno_query_fixture <- function() {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  skip_if_not_installed("jsonlite")

  fixture_dir <- tempfile("cno-query-fixture-")
  dir.create(fixture_dir)
  con <- DBI::dbConnect(
    duckdb::duckdb(dbdir = ":memory:", shared_home = FALSE)
  )
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))

  tables <- list(
    works = data.frame(
      cno = c("000000000001", "000000000002"),
      state = c("SP", "RJ"),
      work_name = c("Obra A", "Obra B"),
      registration_date = as.Date(c("2026-01-01", "2026-01-02"))
    ),
    areas = data.frame(
      cno = c("000000000001", "000000000001", "000000000002"),
      destination = c(
        "Residencial unifamiliar",
        "Comercial salas e lojas",
        "Residencial multifamiliar"
      ),
      area = c(100, 20, 80)
    ),
    cnaes = data.frame(
      cno = c("000000000001", "000000000002"),
      cnae = c("4120400", "4110700")
    ),
    responsibilities = data.frame(
      cno = "000000000001",
      responsible_role_code = "0053"
    )
  )

  table_entries <- lapply(names(tables), function(table) {
    DBI::dbWriteTable(con, table, tables[[table]])
    columns <- DBI::dbGetQuery(
      con,
      paste0("DESCRIBE ", DBI::dbQuoteIdentifier(con, table))
    )
    file_name <- paste0(table, ".parquet")
    file_path <- file.path(fixture_dir, file_name)
    quoted_path <- DBI::dbQuoteString(con, file_path)
    DBI::dbExecute(
      con,
      paste0(
        "COPY ",
        DBI::dbQuoteIdentifier(con, table),
        " TO ",
        quoted_path,
        " (FORMAT PARQUET)"
      )
    )

    list(
      name = table,
      files = list(file_name),
      rows = nrow(tables[[table]]),
      columns = Map(
        \(name, type) list(name = name, type = type),
        columns$column_name,
        columns$column_type
      )
    )
  })
  names(table_entries) <- names(tables)

  manifest <- list(
    dataset = "cno",
    version = "2026-01-02",
    schema_version = 1,
    schema_sha256 = "56d5bb0cff208e3817cf763fefc7490fa81edbf293066dfecb180b178a196faf",
    retrieved_at = "2026-01-03T12:00:00Z",
    tables = table_entries
  )
  manifest_path <- file.path(fixture_dir, "manifest.json")
  jsonlite::write_json(
    manifest,
    manifest_path,
    auto_unbox = TRUE,
    pretty = TRUE
  )

  return(manifest_path)
}

test_that("query_dataset returns a joinable CNO catalog", {
  manifest_path <- make_cno_query_fixture()
  withr::defer(unlink(dirname(manifest_path), recursive = TRUE))
  withr::local_options(
    realestatebr.query_manifest_urls = c(cno = manifest_path)
  )

  cno <- query_dataset("cno", quiet = TRUE)
  withr::defer(close(cno))

  expect_s3_class(cno, "realestatebr_query_dataset")
  expect_named(cno, c("works", "areas", "cnaes", "responsibilities"))

  joined <- cno$works |>
    dplyr::inner_join(cno$areas, by = "cno") |>
    dplyr::filter(.data$state == "SP") |>
    dplyr::collect()

  expect_equal(nrow(joined), 2L)
  expect_identical(unique(joined$cno), "000000000001")
})

test_that("query_dataset can return one CNO table", {
  manifest_path <- make_cno_query_fixture()
  withr::defer(unlink(dirname(manifest_path), recursive = TRUE))
  withr::local_options(
    realestatebr.query_manifest_urls = c(cno = manifest_path)
  )

  works <- query_dataset("cno", table = "works", quiet = TRUE)
  result <- works |>
    dplyr::filter(.data$state == "RJ") |>
    dplyr::collect()

  expect_s3_class(works, "tbl_lazy")
  expect_identical(result$cno, "000000000002")

  owner <- attr(works, "connection_owner")
  close(works)
  expect_identical(DBI::dbIsValid(owner$connection), FALSE)
})

test_that("query_dataset rejects Parquet whose schema differs from manifest", {
  local_edition(3)
  manifest_path <- make_cno_query_fixture()
  withr::defer(unlink(dirname(manifest_path), recursive = TRUE))
  withr::local_options(
    realestatebr.query_manifest_urls = c(cno = manifest_path)
  )

  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  manifest$tables$works$columns[[1]]$type <- "BIGINT"
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE)

  expect_snapshot(
    error = TRUE,
    query_dataset("cno", table = "works", quiet = TRUE)
  )
})

test_that("latest manifest pointers resolve snapshot-relative files", {
  manifest_path <- make_cno_query_fixture()
  fixture_dir <- dirname(manifest_path)
  snapshot_dir <- file.path(fixture_dir, "snapshots", "2026-01-02")
  dir.create(snapshot_dir, recursive = TRUE)

  resources <- c(
    manifest_path,
    file.path(
      fixture_dir,
      paste0(
        c("works", "areas", "cnaes", "responsibilities"),
        ".parquet"
      )
    )
  )
  file.rename(resources, file.path(snapshot_dir, basename(resources)))

  pointer_path <- file.path(fixture_dir, "latest.json")
  jsonlite::write_json(
    list(manifest_url = "snapshots/2026-01-02/manifest.json"),
    pointer_path,
    auto_unbox = TRUE
  )
  withr::defer(unlink(fixture_dir, recursive = TRUE))
  withr::local_options(
    realestatebr.query_manifest_urls = c(cno = pointer_path)
  )

  cno <- query_dataset("cno", quiet = TRUE)
  withr::defer(close(cno))

  expect_equal(dplyr::collect(cno$works) |> nrow(), 2L)
})

test_that("query_dataset pins an explicit version", {
  local_edition(3)
  manifest_path <- make_cno_query_fixture()
  withr::defer(unlink(dirname(manifest_path), recursive = TRUE))
  withr::local_options(
    realestatebr.query_manifest_urls = c(cno = manifest_path)
  )

  cno <- query_dataset("cno", version = "2026-01-02", quiet = TRUE)
  withr::defer(close(cno))

  expect_identical(attr(cno, "dataset_version"), "2026-01-02")

  expect_snapshot(
    error = TRUE,
    query_dataset("cno", version = "2025-12-31", quiet = TRUE)
  )
})

test_that("query_dataset rejects an incompatible schema", {
  manifest_path <- make_cno_query_fixture()
  withr::defer(unlink(dirname(manifest_path), recursive = TRUE))
  withr::local_options(
    realestatebr.query_manifest_urls = c(cno = manifest_path)
  )

  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  manifest$schema_sha256 <- paste(rep("b", 64), collapse = "")
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE)

  expect_error(
    query_dataset("cno", quiet = TRUE),
    "Dataset schema is not compatible with this package version.",
    fixed = TRUE
  )
})

test_that("materialized and queryable access modes are explicit", {
  local_edition(3)
  expect_snapshot(error = TRUE, get_dataset("cno", quiet = TRUE))
  expect_snapshot(error = TRUE, query_dataset("abecip", quiet = TRUE))

  datasets <- suppressMessages(list_datasets())
  expect_no_match(datasets$name, "cno", fixed = TRUE)
})

test_that("unpublished query datasets are unavailable without an override", {
  local_edition(3)
  withr::local_options(realestatebr.query_manifest_urls = NULL)

  expect_snapshot(error = TRUE, query_dataset("cno", quiet = TRUE))
})

test_that("closing a CNO catalog closes its connection", {
  manifest_path <- make_cno_query_fixture()
  withr::defer(unlink(dirname(manifest_path), recursive = TRUE))
  withr::local_options(
    realestatebr.query_manifest_urls = c(cno = manifest_path)
  )

  cno <- query_dataset("cno", quiet = TRUE)
  owner <- attr(cno, "connection_owner")

  expect_identical(DBI::dbIsValid(owner$connection), TRUE)
  close(cno)
  expect_identical(DBI::dbIsValid(owner$connection), FALSE)
})
