cno_builder <- function() {
  testthat::skip_if_not(
    file.exists(testthat::test_path(
      "..",
      "..",
      "data-raw",
      "cno",
      "build_snapshot.R"
    )),
    "Source-only CNO builder is not installed"
  )
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("duckdb", "1.5.5")
  testthat::skip_if_not_installed("digest")
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  withr::with_dir(root, sys.source("data-raw/cno/build_snapshot.R", env))
  return(env)
}

write_cp1252_csv <- function(lines, path) {
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeLines(
    iconv(lines, from = "UTF-8", to = "CP1252"),
    con,
    sep = "\r\n",
    useBytes = TRUE
  )
  return(invisible(path))
}

csv_line <- function(...) {
  values <- c(...)
  return(paste0('"', values, '"', collapse = ","))
}

make_cno_source_fixture <- function() {
  source_dir <- withr::local_tempdir(
    "cno-source-",
    .local_envir = parent.frame()
  )
  registry <- yaml::read_yaml(test_path("../../inst/extdata/datasets.yaml"))
  headers <- lapply(
    registry$datasets$cno$categories,
    \(category) names(category$source_columns)
  )

  construction <- function(
    cno,
    start,
    tom,
    municipality,
    state,
    country,
    plus
  ) {
    csv_line(
      cno,
      "105",
      country,
      start,
      start,
      "2019-01-01",
      "",
      "01001000",
      "00000000000000",
      "0053",
      "OBRA",
      tom,
      municipality,
      "RUA",
      "TESTE",
      "1",
      "CENTRO",
      state,
      "",
      "",
      "m2",
      "120.00",
      "02",
      "2020-01-01",
      "EMPRESA",
      plus
    )
  }
  write_cp1252_csv(
    c(
      csv_line(headers$constructions),
      construction(
        "000000000001",
        "1900-01-01",
        "7107",
        "SÃO PAULO",
        "SP",
        "BRASIL",
        "00000000+00"
      ),
      construction(
        "000000000002",
        "1905-03-01",
        "1182",
        "BOA ESPERANÇA DO NORTE",
        "MT",
        "BRASIL",
        "6mvw+jm"
      ),
      construction(
        "000000000003",
        "2020-05-01",
        " ",
        "LUANDA",
        "",
        "ANGOLA",
        "58PJ642P+4Q"
      )
    ),
    file.path(source_dir, "cno.csv")
  )
  area <- function(cno, destination, area) {
    csv_line(cno, "Obra Nova", destination, "Alvenaria", "Principal", "", area)
  }
  write_cp1252_csv(
    c(
      csv_line(headers$areas),
      area("000000000001", "Residencial unifamiliar", "100.00"),
      area("000000000001", "Residencial unifamiliar", "100.00"),
      area("000000000001", "Comercial salas e lojas", "20.00"),
      area("000000000002", "Residencial multifamiliar", "120.00")
    ),
    file.path(source_dir, "cno_areas.csv")
  )
  write_cp1252_csv(
    c(
      csv_line(headers$cnaes),
      csv_line("000000000001", "4120400", "2019-01-01")
    ),
    file.path(source_dir, "cno_cnaes.csv")
  )
  write_cp1252_csv(
    c(
      csv_line(headers$responsibilities),
      csv_line(
        "000000000001",
        "1900-01-01",
        "",
        "2019-01-01",
        "0053",
        "00000000000000"
      )
    ),
    file.path(source_dir, "cno_vinculos.csv")
  )
  write_cp1252_csv(
    c(
      csv_line(
        "Total de obras",
        "Total de áreas",
        "Total de cnaes",
        "Total de vínculos"
      ),
      csv_line("3", "4", "1", "1")
    ),
    file.path(source_dir, "cno_totais.csv")
  )
  write_cp1252_csv(
    c(
      "CÓDIGO DO MUNICÍPIO - TOM;CÓDIGO DO MUNICÍPIO - IBGE;MUNICÍPIO - TOM;MUNICÍPIO - IBGE;UF",
      "7107;3550308;SÃO PAULO;São Paulo;SP",
      "1;1100106;GUAJARÁ-MIRIM;Guajará-Mirim;RO",
      "9707;0;EXTERIOR;;EX"
    ),
    file.path(source_dir, "municipios.csv")
  )

  return(source_dir)
}

build_cno_fixture <- function(b, source_dir, ...) {
  output_dir <- withr::local_tempdir(
    "cno-output-",
    .local_envir = parent.frame()
  )
  root <- normalizePath(test_path("..", ".."))
  manifest_path <- b$build_cno_snapshot(
    source_dir = source_dir,
    output_dir = output_dir,
    version = "2026-01-02",
    retrieved_at = "2026-01-03T00:00:00Z",
    registry_path = file.path(root, "inst", "extdata", "datasets.yaml"),
    crosswalk_path = file.path(source_dir, "municipios.csv"),
    ...
  )
  return(manifest_path)
}

read_cno_fixture_table <- function(manifest_path, table) {
  con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE))
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  path <- file.path(dirname(manifest_path), paste0(table, ".parquet"))
  return(DBI::dbGetQuery(
    con,
    paste0(
      "SELECT * FROM read_parquet(",
      DBI::dbQuoteString(con, path),
      ") ORDER BY ALL"
    )
  ))
}

test_that("CNO builder publishes the silver layer and counts each fix", {
  b <- cno_builder()
  source_dir <- make_cno_source_fixture()
  manifest_path <- build_cno_fixture(b, source_dir, max_unmatched_share = 0.5)
  manifest <- jsonlite::read_json(manifest_path)

  constructions <- read_cno_fixture_table(manifest_path, "constructions")
  expect_identical(
    constructions$start_date,
    as.Date(c(NA, "1905-03-01", "2020-05-01"))
  )
  expect_identical(constructions$plus_code, c(NA, "6MVW+JM", "58PJ642P+4Q"))
  expect_identical(constructions$municipality_tom_code, c("7107", "1182", NA))
  expect_identical(constructions$state, c("SP", "MT", NA))
  expect_identical(constructions$code_muni, c(3550308L, NA, NA))

  areas <- read_cno_fixture_table(manifest_path, "areas")
  expect_equal(nrow(areas), 3)
  expect_equal(sum(areas$area[areas$cno == "000000000001"]), 120)

  responsibilities <- read_cno_fixture_table(manifest_path, "responsibilities")
  expect_identical(responsibilities$start_date, as.Date(NA))

  expect_equal(
    manifest$tables$constructions$cleaning$sentinel_dates$start_date,
    1
  )
  expect_equal(manifest$tables$constructions$cleaning$invalid_plus_codes, 1)
  expect_equal(
    manifest$tables$constructions$cleaning$unmatched_municipalities,
    1
  )
  expect_equal(manifest$tables$areas$source_rows, 4)
  expect_equal(manifest$tables$areas$rows, 3)
  expect_equal(manifest$tables$areas$cleaning$duplicate_rows, 1)
  expect_equal(
    manifest$tables$responsibilities$cleaning$sentinel_dates$start_date,
    1
  )
  expect_identical(manifest$source$files$crosswalk$file, "municipios.csv")
})

test_that("CNO builder aborts when the municipality crosswalk barely matches", {
  b <- cno_builder()
  source_dir <- make_cno_source_fixture()
  expect_error(
    build_cno_fixture(b, source_dir),
    "do not match the TOM-to-IBGE crosswalk"
  )
})

test_that("CNO Plus Code pattern follows Open Location Code rules", {
  b <- cno_builder()
  valid <- c(
    "6MVW+JM",
    "58PJ642P+4Q",
    "5879XJ00+",
    "58790000+",
    "58000000+",
    "6FG22222+2222222",
    "+22",
    "CFX3+",
    "CVXW0000+",
    "99999999+99"
  )
  invalid <- c(
    "XXXXXXXX+XX",
    "00000000+00",
    "HTTPSPLU+SC",
    "5879XJ0+",
    "5879X000+",
    "5879XJ00+22",
    "00000000+",
    "6FG22222+2",
    "6FG2222+22",
    "6FG2222222+22",
    "6FG2+22+22",
    "+",
    "F2222222+22",
    "2W222222+22"
  )
  con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE))
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  matches <- function(codes) {
    DBI::dbGetQuery(
      con,
      "SELECT regexp_full_match(code, ?) AS ok FROM unnest(?) AS t(code)",
      params = list(b$CNO_PLUS_CODE_PATTERN, list(codes))
    )$ok
  }

  expect_identical(
    setNames(matches(valid), valid),
    setNames(rep(TRUE, length(valid)), valid)
  )
  expect_identical(
    setNames(matches(invalid), invalid),
    setNames(rep(FALSE, length(invalid)), invalid)
  )
})
