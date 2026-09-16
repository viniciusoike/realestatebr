mcmv_builder <- function() {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  withr::with_dir(root, sys.source("data-raw/mcmv/build_snapshot.R", env))
  return(env)
}

test_that("known MCMV layouts preserve schema and parse explicit locales", {
  skip_if_not_installed("duckdb", "1.5.5")
  b <- mcmv_builder()
  con <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  registry <- yaml::read_yaml(test_path("../../inst/extdata/datasets.yaml"))$datasets$mcmv
  for (layout in names(b$mcmv_layouts(registry))) {
    adapter <- b$mcmv_layouts(registry)[[layout]]
    path <- test_path("fixtures/mcmv", paste0(layout, ".csv"))
    b$create_mcmv_table(con, path, layout, registry, "fixture")
    dat <- DBI::dbGetQuery(con, "SELECT * FROM fixture")
    expect_equal(nrow(dat), 3L)
    expect_named(dat, unname(vapply(registry$categories[[adapter$table]]$source_columns, `[[`, "", "name")))
    if (layout == "financing_july") {
      expect_equal(dat$amount_financed[1], 144415.57)
      expect_equal(dat$birth_date, as.Date(rep(NA_character_, 3)))
      expect_equal(dat$project_name, rep(NA_character_, 3))
    }
    if (layout == "financing_march") expect_equal(dat$sex, rep(NA_character_, 3))
    if (layout == "summary_annual") {
      expect_equal(dat$code_muni_6[1], "110001")
      expect_equal(dat$contract_year[1], 2009L)
      expect_equal(dat$contract_month, rep(NA_integer_, 3))
    }
    if (grepl("projects_", layout)) expect_equal(dat$amount_contracted[1], 13898046.25)
  }
})

mcmv_fixture_sources <- function() {
  return(c(financing = test_path("fixtures/mcmv/financing_july.csv"),
    financing_summary = test_path("fixtures/mcmv/summary_monthly.csv"),
    subsidized_projects = test_path("fixtures/mcmv/projects_june.csv")))
}

test_that("MCMV adapters reject drift, invalid numerics and nonmidnight dates", {
  b <- mcmv_builder()
  con <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  info <- yaml::read_yaml(test_path("../../inst/extdata/datasets.yaml"))$datasets$mcmv
  original <- readLines(test_path("fixtures/mcmv/financing_july.csv"))
  path <- tempfile(fileext = ".csv")
  withr::defer(unlink(path))
  for (replacement in list(c("cod_ibge", "unknown_column"),
    c("144.415,57", "144,415.57"), c("00:00:00.000", "12:00:00.000"))) {
    writeLines(gsub(replacement[1], replacement[2], original, fixed = TRUE), path)
    expect_error(b$create_mcmv_table(con, path, "financing_july", info, "fixture"),
      "headers changed|invalid numeric/date")
  }
  expect_error(b$create_mcmv_table(con, path, "unknown", info, "fixture"), "Unrecognized")
  expect_error(b$create_mcmv_table(con, test_path("fixtures/mcmv/projects_june.csv"),
    "projects_march", info, "fixture"), "invalid numeric/date")
  writeLines(sub(';"co_sexo"$', '', original[1]), path)
  expect_error(b$create_mcmv_table(con, path, "financing_july", info, "fixture"), "headers changed")
})

test_that("MCMV keeps categories, NULLs and exact repeated observations", {
  b <- mcmv_builder()
  con <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  info <- yaml::read_yaml(test_path("../../inst/extdata/datasets.yaml"))$datasets$mcmv
  dat <- utils::read.csv2(test_path("fixtures/mcmv/financing_july.csv"),
    colClasses = "character", check.names = FALSE, na.strings = "")
  dat$bln_cotista <- c("S", "1", "unrecognized")
  dat$txt_compatibilidade_faixa_renda <- c("4", "Fora MCMV/CVA", NA)
  dat$txt_tipo_imovel <- c("Rural", "RURAL", " rural ")
  dat$data_assinatura_financiamento[3] <- NA
  dat$vlr_subsidio_equilíbrio_fgts[1] <- NA
  dat <- rbind(dat, dat[1, ])
  path <- tempfile(fileext = ".csv")
  withr::defer(unlink(path))
  utils::write.table(dat, path, sep = ";", row.names = FALSE, na = "", fileEncoding = "UTF-8")
  b$create_mcmv_table(con, path, "financing_july", info, "fixture")
  result <- DBI::dbGetQuery(con, "SELECT * FROM fixture")
  expect_equal(result$fgts_account_holder, dat$bln_cotista)
  expect_equal(result$income_band, dat$txt_compatibilidade_faixa_renda)
  expect_equal(result$property_type, dat$txt_tipo_imovel)
  expect_equal(as.list(result[1, ]), as.list(result[4, ]))
  expect_equal(sum(is.na(result$subsidy_fgts_interest)), 2L)
  expect_equal(sum(is.na(result$contract_date)), 1L)
})

test_that("MCMV snapshots use existing lazy catalog and manifest contracts", {
  skip_if_not_installed("duckdb", "1.5.5")
  b <- mcmv_builder()
  output <- tempfile("mcmv-snapshot-")
  withr::defer(unlink(output, recursive = TRUE))
  path <- b$build_mcmv_snapshot(mcmv_fixture_sources(), output_dir = output,
    version = "2026-07-24", registry_path = test_path("../../inst/extdata/datasets.yaml"))
  withr::local_options(realestatebr.query_manifest_urls = c(mcmv = path))
  catalog <- query_dataset("mcmv", version = "2026-07-24", quiet = TRUE)
  withr::defer(close(catalog))
  expect_s3_class(catalog$financing, "tbl_lazy")
  result <- catalog$financing |>
    dplyr::filter(state == "RO") |>
    dplyr::summarise(units = sum(units_financed)) |>
    dplyr::collect()
  expect_equal(result$units, 3)
  owner <- attr(catalog, "connection_owner")
  close(catalog)
  close(catalog)
  expect_identical(DBI::dbIsValid(owner$connection), FALSE)
  expect_error(query_dataset("mcmv", version = "2025-01-01"), "not available at this manifest")
  manifest <- jsonlite::read_json(path)
  expect_equal(manifest$tables$financing$rows, 3)
  expect_equal(unlist(manifest$source$files$financing$absent_columns), c("birth_date", "project_name"))
  expect_equal(manifest$tables$financing$reference_dates[[1]], "2026-07-24")
  expect_equal(manifest$tables$subsidized_projects$reference_dates[[1]], "2026-06-30")
  manifest$schema_sha256 <- paste(rep("0", 64), collapse = "")
  jsonlite::write_json(manifest, path, auto_unbox = TRUE)
  expect_error(query_dataset("mcmv"), "not compatible")
  expect_error(b$build_mcmv_snapshot(mcmv_fixture_sources(), output_dir = output,
    version = "2026-07-24", registry_path = test_path("../../inst/extdata/datasets.yaml")), "already exists")
})

test_that("failed MCMV builds clean staging and hidden catalogs stay hidden", {
  b <- mcmv_builder()
  output <- tempfile()
  withr::defer(unlink(output, recursive = TRUE))
  sources <- mcmv_fixture_sources()
  sources[1] <- "missing.csv"
  expect_error(b$build_mcmv_snapshot(sources, output_dir = output,
    registry_path = test_path("../../inst/extdata/datasets.yaml")), "Missing source")
  expect_length(list.files(output, all.files = FALSE), 0L)
  withr::local_options(realestatebr.query_manifest_urls = NULL)
  expect_error(query_dataset("mcmv"), "not available")
  expect_equal(sum(list_datasets()$name == "mcmv"), 0L)
})

test_that("shared snapshot schema hashing preserves CNO checksum", {
  b <- mcmv_builder()
  info <- yaml::read_yaml(test_path("../../inst/extdata/datasets.yaml"))$datasets$cno
  expect_identical(b$snapshot_schema_hash(b$snapshot_schema(info$categories)),
    info$query_manifest$schema_sha256)
})
