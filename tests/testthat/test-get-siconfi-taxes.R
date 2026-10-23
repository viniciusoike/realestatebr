# Failing tests for the `siconfi_taxes` dataset (TDD red phase). Everything
# here targets the dataset specified in data-raw/siconfi/dataset-plan.md.
#
# Internal contract these tests assume (the implementer must match it):
#
# - read_finbra_file(path)
#     Reads one FINBRA "Receitas Orçamentárias (Anexo I-C)" bulk file (.csv or
#     .zip). The zip file name and its entry name are ignored; the exercise
#     year comes from the `Exercício:` metadata line. Windows-1252 (latin1)
#     text, `;` delimiter, decimal comma, quoted fields whose names may carry
#     unescaped `"` — no standard CSV reader; identify rows by fields read
#     from the end of the line and require exactly 8 fields on tax rows.
#     Returns a tibble of tax rows (long form) with columns:
#       year (integer), code_muni (character, 7 digits), abbrev_state
#       (character), institution (character), tax ("iptu"/"itbi"),
#       value_kind ("gross"/"deduction"/"excluded_deduction"), value (double).
#     Value-kind mapping on column labels: `Receitas Realizadas` (2013) and
#     `Receitas Brutas Realizadas` (2014+) -> gross; `Deduções da Receita`
#     (2013) and `Outras Deduções da Receita` (2014+) -> deduction; `Deduções
#     - FUNDEB` and `Deduções - Transferências Constitucionais` ->
#     excluded_deduction (these rows never feed other_deductions or
#     net_revenue). Literal `0,00` parses to 0, never NA.
#     cli::cli_abort() on: missing or unsupported `Exercício` year, unknown
#     column label on a tax row, a tax code that does not belong to the
#     file year's vintage, malformed numeric values.
#
# - parse_siconfi_dca(items)
#     Items: list of /dca item lists (jsonlite::fromJSON(simplifyVector =
#     FALSE) `$items`), with fields `cod_ibge` (integer), `uf`, `coluna`,
#     `cod_conta`, `valor`, `instituicao`, `exercicio`. Returns the same long
#     form as read_finbra_file() with the 2014+ label mapping.
#     cli::cli_abort() on unknown `cod_conta` for the item's year, unknown
#     `coluna`, malformed `valor`.
#
# - fetch_siconfi_dca(code_muni, year, request = NULL)
#     Requests /dca for one municipality-year with
#     `no_anexo=DCA-Anexo I-C` and follows pagination: advance `offset` by
#     the returned `limit` while `hasMore` is true; reject a repeated page.
#     `request` is injectable for tests: a callable taking a URL string and
#     returning the parsed response body (list). Default performs the real
#     HTTP GET and parses the JSON. Returns the gathered raw items (list).
#
# - build_siconfi_taxes(finbra, api = NULL, municipalities)
#     finbra/api: long forms (source "finbra"/"api" respectively);
#     municipalities: tibble (code_muni integer 7 digits, abbrev_state) —
#     the per-year IBGE municipality universe. Returns one row per
#     municipality x year x tax for every year supplied, with columns
#     (in order):
#       code_muni (integer), abbrev_state, year (integer), tax,
#       reported (logical), value_status ("observed"/"missing_tax_row"/
#       "non_reporter"), gross_revenue, other_deductions, net_revenue,
#       account_scope ("legacy_line" <= 2017, "tax_family" >= 2018),
#       source ("finbra"/"api", NA for non-reporters).
#     API rows replace FINBRA rows for the same municipality-year (source
#     becomes "api"); rows supplied only by FINBRA keep "finbra";
#     non-reporters get reported = FALSE, NA values, value_status =
#     "non_reporter", source = NA. net_revenue = gross - deductions rounded
#     to cents when both exist, else NA. Missing deduction rows leave
#     other_deductions and net_revenue as NA. Literal zeros are preserved.
#
# - validate_siconfi_taxes(data)
#     cli::cli_abort() unless the published schema, types and keys hold:
#     expected columns and types, integer 7-digit code_muni, and unique
#     code_muni x year x tax keys.

local_edition(3)

siconfi_fixture <- function(...) {
  testthat::test_path("fixtures", "siconfi", ...)
}

siconfi_finbra_all <- function() {
  paths <- sprintf("finbra_extract_%02d.csv", seq_len(5))
  return(dplyr::bind_rows(
    lapply(paths, \(path) read_finbra_file(siconfi_fixture(path)))
  ))
}

siconfi_municipalities_all <- tibble::tribble(
  ~code_muni , ~abbrev_state ,
  1100015L   , "RO"          , # in no fixture: a non-reporter in every year
  1100122L   , "RO"          , # Ji-Paraná (2024 fixture only)
  3304557L   , "RJ"          , # Rio de Janeiro (2013, 2017, 2018, 2022, 2024)
  3550308L   , "SP"          , # São Paulo (2013, 2017, 2018, 2022, 2024)
  4126652L   , "PR"          , # Sulina (2013 fixture only)
  4214201L   , "SC"          , # Quilombo (2022 fixture only)
  4304614L   , "RS"          , # Canudos do Vale (2017 fixture only)
  4315156L   , "RS"          , # Progresso (2022 fixture only)
  5203559L   , "GO" # Bonfinópolis (2018 fixture only)
)

# FINBRA anchor values re-verified on 23 Oct 2026 against the bulk files and
# equal to the live API for 2017 and 2024.
siconfi_anchors <- tibble::tribble(
  ~code_muni , ~year , ~tax   , ~gross_revenue , ~other_deductions , ~net_revenue   ,
  "3550308"  , 2017L , "iptu" ,  8391325245.30 , 127872602.67      ,  8263452642.63 ,
  "3550308"  , 2017L , "itbi" ,  1842891549.55 ,   2444356.68      ,  1840447192.87 ,
  "3304557"  , 2017L , "iptu" ,  2482263502.05 ,   5753178.48      ,  2476510323.57 ,
  "3304557"  , 2017L , "itbi" ,   655290000.06 ,   7424161.05      ,   647865839.01 ,
  "3550308"  , 2024L , "iptu" , 16533492276.91 , 153592524.11      , 16379899752.80 ,
  "3550308"  , 2024L , "itbi" ,  4335013258.17 ,   7005450.04      ,  4328007808.13 ,
  "3304557"  , 2024L , "iptu" ,  4946593936.34 ,  40587331.46      ,  4906006604.88 ,
  "3304557"  , 2024L , "itbi" ,  1442603315.39 ,   9399149.05      ,  1433204166.34
)

# Reading FINBRA bulk files ---------------------------------------------------

test_that("read_finbra_file reads the exercise year from the header, not the name", {
  local_edition(3)
  expected_years <- c(2013L, 2017L, 2018L, 2022L, 2024L)
  for (i in seq_along(expected_years)) {
    dat <- read_finbra_file(siconfi_fixture(sprintf(
      "finbra_extract_%02d.csv",
      i
    )))
    expect_equal(unique(dat$year), expected_years[[i]])
  }
  # The zipped copy keeps both an uninformative outer name and an
  # uninformative entry name; only the header knows the year.
  dat <- read_finbra_file(siconfi_fixture(
    "finbra_MUN_ReceitasOrcamentarias(AnexoI-C).zip"
  ))
  expect_equal(unique(dat$year), 2017L)
})

test_that("read_finbra_file handles latin1 and the unescaped quote row", {
  local_edition(3)
  dat <- read_finbra_file(siconfi_fixture("finbra_extract_01.csv"))
  sulina <- dat[dat$code_muni == "4126652" & dat$tax == "itbi", ]
  # This row's account name carries unescaped quotes ("Inter Vivos") yet
  # parses with the right institution and value.
  expect_equal(nrow(sulina), 1L)
  expect_equal(sulina$institution, "Prefeitura Municipal de Sulina - PR")
  expect_equal(sulina$value_kind, "gross")
  expect_equal(sulina$value, 112091.51)
  expect_equal(
    unique(dat$institution[dat$code_muni == "3550308"]),
    "Prefeitura Municipal de São Paulo - SP"
  )
  expect_equal(
    unique(dat$institution[dat$code_muni == "3304557"]),
    "Prefeitura Municipal do Rio de Janeiro - RJ"
  )
})

test_that("read_finbra_file maps both label vintages and all three code periods", {
  local_edition(3)

  dat2013 <- read_finbra_file(siconfi_fixture("finbra_extract_01.csv"))
  sp_2013_iptu <- dat2013[
    dat2013$code_muni == "3550308" &
      dat2013$tax == "iptu" &
      dat2013$value_kind == "gross",
  ]
  expect_equal(sp_2013_iptu$value, 5448089754.40)
  sp_2013_ded <- dat2013[
    dat2013$code_muni == "3550308" &
      dat2013$tax == "itbi" &
      dat2013$value_kind == "deduction",
  ]
  expect_equal(sp_2013_ded$value, 2331688.10)

  dat2017 <- read_finbra_file(siconfi_fixture("finbra_extract_02.csv"))
  expect_setequal(unique(dat2017$tax), c("iptu", "itbi"))
  sp_2017_iptu <- dat2017[
    dat2017$code_muni == "3550308" &
      dat2017$tax == "iptu" &
      dat2017$value_kind == "gross",
  ]
  expect_equal(sp_2017_iptu$value, 8391325245.30)

  # 2018 recode: the tax parent may contain digits from another family, so
  # the mapping must follow the vintage-specific codes, not loose suffixes.
  dat2018 <- read_finbra_file(siconfi_fixture("finbra_extract_03.csv"))
  sp_2018_iptu <- dat2018[
    dat2018$code_muni == "3550308" &
      dat2018$tax == "iptu" &
      dat2018$value_kind == "gross",
  ]
  expect_equal(sp_2018_iptu$value, 10071810109.96)
  sp_2018_itbi <- dat2018[
    dat2018$code_muni == "3550308" &
      dat2018$tax == "itbi" &
      dat2018$value_kind == "deduction",
  ]
  expect_equal(sp_2018_itbi$value, 9922454.76)

  # 2022 recode
  dat2022 <- read_finbra_file(siconfi_fixture("finbra_extract_04.csv"))
  sp_2022_iptu <- dat2022[
    dat2022$code_muni == "3550308" &
      dat2022$tax == "iptu" &
      dat2022$value_kind == "gross",
  ]
  expect_equal(sp_2022_iptu$value, 14451490842.17)
  expect_setequal(
    unique(dat2022$value_kind),
    c("gross", "deduction", "excluded_deduction")
  )

  dat2024 <- read_finbra_file(siconfi_fixture("finbra_extract_05.csv"))
  expect_equal(
    unique(dat2024$year),
    2024L
  )
  expect_setequal(unique(dat2024$tax), c("iptu", "itbi"))
})

test_that("read_finbra_file keeps literal zeros and separates non-tax deductions", {
  local_edition(3)
  dat2022 <- read_finbra_file(siconfi_fixture("finbra_extract_04.csv"))
  quilombo <- dat2022[dat2022$code_muni == "4214201", ]
  zeros <- quilombo[quilombo$value == 0, ]
  # Quilombo reports Transferências and FUNDEB rows for its tax identifiers
  # with literal 0,00: they must be parsed as zero (not NA) and land in
  # value_kind "excluded_deduction", never in the tax deduction itself.
  expect_equal(nrow(zeros), 4L)
  expect_equal(sum(zeros$value), 0)
  expect_true(is.numeric(zeros$value))
  expect_true(all(zeros$value_kind == "excluded_deduction"))
  expect_false(any(is.na(zeros$value)))
})

test_that("read_finbra_file rejects bad headers, labels, codes and numbers", {
  local_edition(3)
  expect_error(
    read_finbra_file(siconfi_fixture("finbra_bad_year.csv")),
    "2099"
  )
  expect_error(
    read_finbra_file(siconfi_fixture("finbra_unknown_label.csv")),
    "Receitas Previstas"
  )
  expect_error(
    read_finbra_file(siconfi_fixture("finbra_unknown_code.csv")),
    "RO1.1.1.2.50.0.0"
  )
  expect_error(
    read_finbra_file(siconfi_fixture("finbra_bad_number.csv")),
    "12x34,56"
  )
})

# Parsing the DCA API ---------------------------------------------------------

siconfi_dca_items <- function(...) {
  jsonlite::fromJSON(
    siconfi_fixture(...),
    simplifyVector = FALSE
  )$items
}

test_that("parse_siconfi_dca turns real /dca tax items into the long form", {
  local_edition(3)
  dat <- parse_siconfi_dca(siconfi_dca_items("dca_sp_tax_2017.json"))
  expect_equal(nrow(dat), 4L)
  expect_equal(unique(dat$year), 2017L)
  expect_equal(unique(dat$code_muni), "3550308")
  iptu_gross <- dat[dat$tax == "iptu" & dat$value_kind == "gross", ]
  iptu_ded <- dat[dat$tax == "iptu" & dat$value_kind == "deduction", ]
  itbi_gross <- dat[dat$tax == "itbi" & dat$value_kind == "gross", ]
  itbi_ded <- dat[dat$tax == "itbi" & dat$value_kind == "deduction", ]
  expect_equal(iptu_gross$value, 8391325245.30)
  expect_equal(iptu_ded$value, 127872602.67)
  expect_equal(itbi_gross$value, 1842891549.55)
  expect_equal(itbi_ded$value, 2444356.68)
})

test_that("parse_siconfi_dca rejects unknown vintages, columns and values", {
  local_edition(3)
  items <- siconfi_dca_items("dca_sp_tax_2017.json")

  unknown_code <- items[[1]]
  unknown_code$cod_conta <- "RO1.1.1.2.99.0.0"
  expect_error(
    parse_siconfi_dca(list(unknown_code)),
    "RO1.1.1.2.99.0.0"
  )

  unknown_coluna <- items[[1]]
  unknown_coluna$coluna <- "Previsão Atualizada"
  expect_error(
    parse_siconfi_dca(list(unknown_coluna)),
    "Previsão Atualizada"
  )

  malformed <- items[[1]]
  malformed$valor <- "abc"
  expect_error(
    parse_siconfi_dca(list(malformed)),
    "abc"
  )
})

# Fetching from the DCA API ---------------------------------------------------

test_that("fetch_siconfi_dca follows hasMore across two pages", {
  local_edition(3)
  requested_urls <- character()
  pages <- list(
    jsonlite::fromJSON(
      siconfi_fixture("dca_page_1.json"),
      simplifyVector = FALSE
    ),
    jsonlite::fromJSON(
      siconfi_fixture("dca_page_2.json"),
      simplifyVector = FALSE
    )
  )
  # The first page is fetched at offset 0; the follower must advance by the
  # page's reported limit (2), which the mock answers with the second page.
  request <- function(url) {
    requested_urls <<- c(requested_urls, url)
    if (grepl("[?&]offset=0($|[^0-9])", url)) {
      return(pages[[1]])
    }
    return(pages[[2]])
  }
  items <- fetch_siconfi_dca(3550308, 2024, request = request)

  expect_equal(length(items), 4L)
  expect_length(requested_urls, 2L)
  expect_match(requested_urls[1], "an_exercicio=2024")
  expect_match(requested_urls[1], "no_anexo=DCA-Anexo", fixed = TRUE)
  expect_match(requested_urls[1], "id_ente=3550308")
  expect_match(requested_urls[2], "offset=2")
})

test_that("fetch_siconfi_dca rejects a repeated page", {
  local_edition(3)
  page <- jsonlite::fromJSON(
    siconfi_fixture("dca_page_1.json"),
    simplifyVector = FALSE
  )
  endless <- function(url) {
    return(page)
  }
  expect_error(
    fetch_siconfi_dca(3550308, 2024, request = endless),
    "repeated|same page",
    ignore.case = TRUE
  )
})

# Building the dataset --------------------------------------------------------

test_that("build_siconfi_taxes reproduces the FINBRA anchors with net and scope", {
  local_edition(3)
  dat <- validate_siconfi_taxes(build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all
  ))

  expect_named(
    dat,
    c(
      "code_muni",
      "abbrev_state",
      "year",
      "tax",
      "reported",
      "value_status",
      "gross_revenue",
      "other_deductions",
      "net_revenue",
      "account_scope",
      "source"
    )
  )
  # The universe has 9 municipalities for 5 years and 2 taxes.
  expect_equal(nrow(dat), 90L)

  for (i in seq_len(nrow(siconfi_anchors))) {
    anchor <- siconfi_anchors[i, ]
    row <- dat[
      dat$code_muni == anchor$code_muni &
        dat$year == anchor$year &
        dat$tax == anchor$tax,
    ]
    expect_equal(
      nrow(row),
      1L,
      info = sprintf(
        "anchor row %s/%s/%s",
        anchor$code_muni,
        anchor$year,
        anchor$tax
      )
    )
    expect_equal(row$gross_revenue, anchor$gross_revenue)
    expect_equal(row$other_deductions, anchor$other_deductions)
    expect_equal(row$net_revenue, anchor$net_revenue)
  }

  expect_equal(
    unique(dat$account_scope[dat$year <= 2017L]),
    "legacy_line"
  )
  expect_equal(
    unique(dat$account_scope[dat$year >= 2018L]),
    "tax_family"
  )
  expect_true(all(dat$reported[dat$source %in% c("finbra", "api")]))
  expect_equal(unique(dat$source), "finbra")
  expect_true(all(dat$value_status[dat$reported] == "observed"))
})

test_that("build_siconfi_taxes keeps missing deductions and their net as NA", {
  local_edition(3)
  dat <- build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all
  )
  # Sulina (2013) and the other gross-only municipalities in each fixture
  # file report gross rows for both taxes and no deduction rows.
  for (pair in list(
    c(4126652L, 2013L),
    c(4304614L, 2017L),
    c(5203559L, 2018L),
    c(4315156L, 2022L),
    c(1100122L, 2024L)
  )) {
    rows <- dat[
      dat$code_muni == pair[[1]] & dat$year == pair[[2]] & dat$tax == "iptu",
    ]
    expect_equal(nrow(rows), 1L)
    expect_true(rows$reported)
    expect_true(is.na(rows$other_deductions))
    expect_true(is.na(rows$net_revenue))
    expect_false(is.na(rows$gross_revenue))
    expect_equal(rows$value_status, "observed")
  }
})

test_that("build_siconfi_taxes fills non-reporters with NA values", {
  local_edition(3)
  dat <- build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all
  )
  # Alta Floresta d'Oeste appears in no fixture file: a non-reporter in all
  # five years.
  missing <- dat[dat$code_muni == 1100015L, ]
  expect_equal(nrow(missing), 10L)
  expect_false(any(missing$reported))
  expect_equal(unique(missing$value_status), "non_reporter")
  expect_true(all(is.na(
    missing[c("gross_revenue", "other_deductions", "net_revenue")]
  )))
  expect_true(all(is.na(missing$source)))

  # Sulina reports in 2013 only; every other year is a non-reporter year.
  absent <- dat[dat$code_muni == 4126652L & dat$year != 2013L, ]
  expect_equal(nrow(absent), 8L)
  expect_false(any(absent$reported))
  expect_equal(unique(absent$value_status), "non_reporter")
})

test_that("API rows replace FINBRA rows for the same year and set source", {
  local_edition(3)
  finbra_2017 <- read_finbra_file(siconfi_fixture("finbra_extract_02.csv"))
  api <- parse_siconfi_dca(siconfi_dca_items("dca_sp_tax_2017.json"))
  dat <- validate_siconfi_taxes(build_siconfi_taxes(
    finbra_2017,
    api = api,
    municipalities = siconfi_municipalities_all[
      siconfi_municipalities_all$code_muni %in% c(3304557L, 3550308L),
    ]
  ))

  sao_paulo <- dat[dat$code_muni == 3550308L & dat$year == 2017L, ]
  expect_equal(unique(sao_paulo$source), "api")
  expect_true(all(sao_paulo$reported))
  expect_equal(
    sao_paulo$gross_revenue[sao_paulo$tax == "iptu"],
    8391325245.30
  )
  rio <- dat[dat$code_muni == 3304557L & dat$year == 2017L, ]
  expect_equal(unique(rio$source), "finbra")

  # The replacement must not duplicate keys.
  expect_false(anyDuplicated(dat[c("code_muni", "year", "tax")]) > 0)
})

# Validation ------------------------------------------------------------------

test_that("validate_siconfi_taxes accepts the built data", {
  local_edition(3)
  dat <- build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all
  )
  expect_no_error(validate_siconfi_taxes(dat))
})

test_that("validate_siconfi_taxes rejects duplicates and bad codes", {
  local_edition(3)
  dat <- build_siconfi_taxes(
    siconfi_finbra_all()[siconfi_finbra_all()$year == 2017L, ],
    api = NULL,
    municipalities = siconfi_municipalities_all
  )

  duplicate <- rbind(dat, dat[1, ])
  expect_error(validate_siconfi_taxes(duplicate), "duplicate")

  bad_code <- dat
  bad_code$code_muni <- 123456L
  expect_error(validate_siconfi_taxes(bad_code), "code_muni|7")

  wrong_type <- dat
  wrong_type$net_revenue <- as.character(wrong_type$net_revenue)
  expect_error(validate_siconfi_taxes(wrong_type), "net_revenue|type")
})

# Registry and interface ------------------------------------------------------

test_that("the siconfi_taxes registry entry exists and stays cache-only", {
  registry <- load_dataset_registry()
  expect_true("siconfi_taxes" %in% names(registry$datasets))
  info <- registry$datasets$siconfi_taxes
  expect_identical(
    get_cached_name("siconfi_taxes", info, "all"),
    "siconfi_taxes"
  )
  # No fresh download path: rebuilds live in the data-raw pipeline only.
  expect_true(is.null(info$dataset_function) || info$dataset_function == "")
  expect_equal(sum(list_datasets()$name == "siconfi_taxes"), 1L)
})

test_that("get_dataset aborts on a fresh rebuild of siconfi_taxes", {
  local_edition(3)
  clear_session_cache()
  withr::defer(clear_session_cache())
  cli_error <- rlang::catch_cnd(
    get_dataset("siconfi_taxes", source = "fresh", quiet = TRUE),
    classes = "error"
  )
  expect_false(is.null(cli_error))
  expect_match(conditionMessage(cli_error), "fresh|FINBRA|pipeline")
})

test_that("source auto never falls back to a fresh siconfi rebuild", {
  local_edition(3)
  clear_session_cache()
  withr::defer(clear_session_cache())
  local_mocked_bindings(
    fetch_github_release_asset = function(cached_name, quiet = FALSE) {
      cli::cli_abort("release asset unavailable")
    }
  )
  cli_error <- rlang::catch_cnd(
    get_dataset("siconfi_taxes", source = "auto", quiet = TRUE),
    classes = "error"
  )
  # Auto must abort with the cache-only message, not attempt the fresh
  # builder.
  expect_false(is.null(cli_error))
  expect_false(
    grepl("faint: fresh", conditionMessage(cli_error), fixed = TRUE)
  )
})

test_that("source github reads the siconfi_taxes release asset", {
  local_edition(3)
  clear_session_cache()
  withr::defer(clear_session_cache())

  snapshot <- build_siconfi_taxes(
    read_finbra_file(siconfi_fixture("finbra_extract_02.csv")),
    api = NULL,
    municipalities = siconfi_municipalities_all[
      siconfi_municipalities_all$code_muni %in% c(3304557L, 3550308L),
    ]
  )
  local_mocked_bindings(
    fetch_github_release_asset = function(cached_name, quiet = FALSE) {
      expect_identical(cached_name, "siconfi_taxes")
      return(snapshot)
    }
  )
  result <- get_dataset("siconfi_taxes", source = "github", quiet = TRUE)
  expect_equal(result, snapshot, ignore_attr = TRUE)
})
