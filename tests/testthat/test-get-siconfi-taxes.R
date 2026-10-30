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
#     The tibble carries the attribute "reporters": character keys
#     `<7-digit code_muni> <year>` for every municipality that has a valid
#     data line in the file (any account), not only tax rows; and the
#     attribute "context": a tibble (code_muni character, year integer,
#     current_revenue double, tax_revenue double) with the gross
#     realized values of the current-revenue and tax-revenue accounts
#     (`RO1.0.0.0.00.00.00`/`RO1.1.0.0.00.00.00` through 2017;
#     `RO1.0.0.0.00.0.0`/`RO1.1.0.0.00.0.0` from 2018). Population is not
#     read from the file: it comes from IBGE (see fetch_siconfi_population).
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
#     form as read_finbra_file() with the 2014+ label mapping, carrying the
#     same "reporters" attribute keyed from each item's cod_ibge x exercicio
#     (any account), and the same "context" attribute built from the
#     current-revenue and tax-revenue items (gross column only); the API's
#     `populacao` field is ignored: population comes from IBGE (see
#     fetch_siconfi_population).
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
#     the per-year IBGE municipality universe. The "reporters" attributes
#     decide `reported`: a key counts as filed whenever the municipality has
#     any account in the source, and keeps `source` accordingly; the long
#     forms' tax rows alone decide only `value_status`. Without the
#     attribute the reporter keys fall back to the tax rows of the long
#     form. Returns one row per
#     municipality x year x tax for every year supplied, with columns
#     (in order):
#       code_muni (integer), abbrev_state, year (integer), population
#       (integer), population_source ("estimate"/"census"/"interpolated"),
#       current_revenue (double), tax_revenue (double), tax,
#       reported (logical), value_status ("observed"/"missing_tax_row"/
#       "non_reporter"), gross_revenue, other_deductions,
#       deductions_reported (logical), net_revenue,
#       account_scope ("legacy_line" <= 2017, "tax_family" >= 2018),
#       source ("finbra"/"api", NA for non-reporters).
#     The context columns are municipality-year values repeated
#     identically on both tax rows. Population comes from the injected
#     `population` tibble (code_muni, year, population, population_source;
#     default NULL = all NA). It is independent of SICONFI reporting, so it
#     fills non-reporter rows too; municipality-years without a figure keep
#     NA population and NA population_source. current_revenue and
#     tax_revenue are gross realized values: FINBRA values, replaced by
#     the API values for API-covered municipality-years; a reporting
#     municipality without the account line gets NA, and non-reporters
#     get NA totals. Literal zeros stay zero.
#     API rows replace FINBRA rows for the same municipality-year (source
#     becomes "api"); rows supplied only by FINBRA keep "finbra";
#     non-reporters get reported = FALSE, NA values, value_status =
#     "non_reporter", source = NA. net_revenue = gross - deductions rounded
#     to cents whenever the gross row exists. Missing deduction rows are
#     counted as zero: other_deductions becomes 0, net_revenue is computed,
#     and deductions_reported = FALSE marks the assumption (TRUE when a
#     deduction row existed in the source, NA when there is no gross row; a
#     deduction row without a gross row keeps other_deductions and a TRUE
#     flag with gross_revenue and net_revenue NA). Literal zeros are
#     preserved.
#
# - validate_siconfi_taxes(data)
#     cli::cli_abort() unless the published schema, types and keys hold:
#     expected columns and types, integer 7-digit code_muni, the
#     population_source domain with NA exactly when population is NA,
#     and unique code_muni x year x tax keys.

# IBGE population -------------------------------------------------------------
#
# - fetch_siconfi_population(years, fetch = download_ibge_aggregate)
#     Estimates from SIDRA table 6579 (variable 9324, all available
#     periods, localities N6[all]); the 2022 Census count from table 4709
#     (variable 93); 2023 filled by siconfi_interpolate_population().
#     Returns a tibble code_muni (character 7 digits), year (integer),
#     population (integer), population_source ("estimate"/"census"/
#     "interpolated"). Dataset years without a figure are absent from
#     the result; non-requested years are dropped.
#
# - siconfi_interpolate_population(population)
#     Pure: fills 2023 per municipality as the midpoint of its 2022 and
#     2024 population, rounded to an integer (ties to even, R's round).
#     Missing either anchor keeps 2023 NA with NA source. Returns the
#     input rows plus the new 2023 rows.

local_edition(3)

siconfi_fixture <- function(...) {
  testthat::test_path("fixtures", "siconfi", ...)
}

siconfi_finbra_all <- function() {
  paths <- sprintf("finbra_extract_%02d.csv", seq_len(5))
  longs <- lapply(paths, \(path) read_finbra_file(siconfi_fixture(path)))
  reporters <- unlist(lapply(longs, \(long) attr(long, "reporters")))
  long <- dplyr::bind_rows(longs)
  # Carry the reporting keys and context rows across the bind as the
  # pipeline does; bind_rows alone would drop the attributes.
  attr(long, "reporters") <- unique(reporters)
  attr(long, "context") <- dplyr::bind_rows(Filter(
    Negate(is.null),
    lapply(longs, \(long) attr(long, "context"))
  ))
  return(long)
}

siconfi_municipalities_all <- tibble::tribble(
  ~code_muni , ~abbrev_state ,
  1100015L   , "RO"          , # in no fixture: a non-reporter in every year
  1100122L   , "RO"          , # Ji-Paraná (2024 fixture only)
  1718501L   , "TO"          , # Recursolândia (files an account in 2018, no tax rows)
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

# Municipality-year revenue anchors re-verified on 24 Oct 2026 against the
# FINBRA bulk files (gross realized values). Population is not a FINBRA
# figure anymore: it comes from IBGE (see the population tests below).
siconfi_context_anchors <- tibble::tribble(
  ~code_muni , ~year , ~current_revenue , ~tax_revenue   ,
  "3550308"  , 2013L ,  37710663491.90  , 18565985119.76 ,
  "3304557"  , 2013L ,  19047283587.19  ,  8358058001.28 ,
  "3550308"  , 2024L , 101553334044.89  , 62707212200.14 ,
  "3304557"  , 2024L ,  37227244132.72  , 17876279031.64
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

test_that("read_finbra_file collects the municipality-year context anchors", {
  local_edition(3)

  dat2013 <- read_finbra_file(siconfi_fixture("finbra_extract_01.csv"))
  dat2024 <- read_finbra_file(siconfi_fixture("finbra_extract_05.csv"))

  for (anchor_year in list(
    list(dat = dat2013, year = 2013L),
    list(dat = dat2024, year = 2024L)
  )) {
    ctx <- attr(anchor_year$dat, "context")
    expect_equal(
      names(ctx),
      c("code_muni", "year", "current_revenue", "tax_revenue")
    )
    for (i in seq_len(nrow(siconfi_context_anchors))) {
      anchor <- siconfi_context_anchors[i, ]
      if (anchor$year != anchor_year$year) {
        next
      }
      row <- ctx[ctx$code_muni == anchor$code_muni, ]
      expect_equal(nrow(row), 1L)
      expect_equal(row$year, anchor$year)
      expect_equal(row$current_revenue, anchor$current_revenue)
      expect_equal(row$tax_revenue, anchor$tax_revenue)
    }
  }
  # A non-context account line (Recursolândia-TO transfers, extract_03)
  # produces no context row: only the two revenue accounts do.
  dat2018 <- read_finbra_file(siconfi_fixture("finbra_extract_03.csv"))
  ctx2018 <- attr(dat2018, "context")
  recursolandia <- ctx2018[ctx2018$code_muni == "1718501", ]
  expect_equal(nrow(recursolandia), 0L)
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

test_that("read_finbra_file aborts on a short line carrying a tax identifier", {
  local_edition(3)
  # A line with 7 fields that still carries the IPTU identifier: it must
  # abort loudly instead of silently vanishing from the parse.
  expect_error(
    read_finbra_file(siconfi_fixture("finbra_short_tax_line.csv")),
    "RO1.1.1.2.02.00.00"
  )
})

# Parsing the DCA API ---------------------------------------------------------

siconfi_dca_items <- function(...) {
  jsonlite::fromJSON(
    siconfi_fixture(...),
    simplifyVector = FALSE
  )$items
}

test_that("api rows replace the whole FINBRA municipality-year", {
  local_edition(3)
  finbra_2017 <- read_finbra_file(siconfi_fixture("finbra_extract_02.csv"))
  finbra_all <- siconfi_finbra_all()
  keep_years <- finbra_all[finbra_all$year != 2017L, ]
  finbra_mix <- rbind(keep_years, finbra_2017)

  # The API fixture carries only the IPTU rows with a gross value that
  # differs from FINBRA: whole-key replacement must erase the FINBRA ITBI
  # value too, and row-by-row merging would show the FINBRA values.
  api <- parse_siconfi_dca(siconfi_dca_items("dca_sp_iptu_2017.json"))
  dat <- build_siconfi_taxes(
    finbra_mix,
    api = api,
    municipalities = siconfi_municipalities_all
  )
  sp_2017 <- dat[dat$code_muni == 3550308L & dat$year == 2017L, ]
  expect_equal(nrow(sp_2017), 2L)
  expect_equal(unique(sp_2017$source), "api")
  expect_equal(
    sp_2017$gross_revenue[sp_2017$tax == "iptu"],
    1234567.89
  )
  expect_true(is.na(sp_2017$gross_revenue[sp_2017$tax == "itbi"]))
  expect_true(is.na(sp_2017$other_deductions[sp_2017$tax == "itbi"]))
  expect_true(is.na(sp_2017$net_revenue[sp_2017$tax == "itbi"]))
  expect_equal(
    unique(sp_2017$value_status),
    c("observed", "missing_tax_row")
  )
  # Rio keeps its FINBRA 2017 rows.
  rio <- dat[dat$code_muni == 3304557L & dat$year == 2017L, ]
  expect_equal(unique(rio$source), "finbra")
  expect_equal(rio$gross_revenue[rio$tax == "iptu"], 2482263502.05)
})

test_that("an empty API response keeps the FINBRA rows of the year", {
  local_edition(3)
  finbra_2017 <- read_finbra_file(siconfi_fixture("finbra_extract_02.csv"))
  # A 200 with zero /dca items declares no reporters: the municipality's
  # FINBRA rows (it filed there) must survive untouched.
  dat <- build_siconfi_taxes(
    finbra_2017,
    api = parse_siconfi_dca(list()),
    municipalities = siconfi_municipalities_all[
      siconfi_municipalities_all$code_muni %in% c(3304557L, 3550308L),
    ]
  )
  sp_2017 <- dat[dat$code_muni == 3550308L & dat$year == 2017L, ]
  expect_equal(unique(sp_2017$source), "finbra")
  expect_equal(
    sp_2017$gross_revenue[sp_2017$tax == "iptu"],
    8391325245.30
  )
})

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

test_that("parse_siconfi_dca collects context totals from the API", {
  local_edition(3)
  dat <- parse_siconfi_dca(siconfi_dca_items("dca_sp_context_2017.json"))
  expect_equal(nrow(dat), 0L)
  ctx <- attr(dat, "context")
  expect_equal(nrow(ctx), 1L)
  expect_equal(ctx$code_muni, "3550308")
  expect_equal(ctx$year, 2017L)
  expect_equal(ctx$current_revenue, 50970741521.99)
  expect_equal(ctx$tax_revenue, 25715190301.72)
  # Population is never taken from the API: it comes from IBGE (see
  # fetch_siconfi_population), so the context carries no population column
  # even though the items carry populacao.
  expect_false("population" %in% names(ctx))
  # The context also accumulates alongside tax rows in the same call.
  dat_tax <- parse_siconfi_dca(siconfi_dca_items("dca_sp_tax_2017.json"))
  expect_equal(nrow(dat_tax), 4L)
})

test_that("parse_siconfi_dca collects the 2018-vintage context codes", {
  local_edition(3)
  dat <- parse_siconfi_dca(siconfi_dca_items("dca_sp_context_2018.json"))
  ctx <- attr(dat, "context")
  expect_equal(nrow(ctx), 1L)
  expect_equal(ctx$year, 2018L)
  expect_equal(ctx$current_revenue, 52983577439.67)
  expect_equal(ctx$tax_revenue, 30083861181.61)
})

test_that("build_siconfi_taxes repeats the context identically on both tax rows", {
  local_edition(3)
  dat <- build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all
  )
  for (i in seq_len(nrow(siconfi_context_anchors))) {
    anchor <- siconfi_context_anchors[i, ]
    rows <- dat[
      dat$code_muni == anchor$code_muni & dat$year == anchor$year,
    ]
    expect_equal(nrow(rows), 2L)
    expect_equal(unique(rows$current_revenue), anchor$current_revenue)
    expect_equal(unique(rows$tax_revenue), anchor$tax_revenue)
  }
  # Context columns are integer/double as documented.
  expect_type(dat$population, "integer")
  expect_type(dat$population_source, "character")
  expect_type(dat$current_revenue, "double")
  expect_type(dat$tax_revenue, "double")
})

test_that("siconfi_interpolate_population fills 2023 with the midpoint of 2022 and 2024", {
  local_edition(3)
  population <- tibble::tribble(
    ~code_muni , ~year , ~population , ~population_source ,
    "3550308"  , 2022L ,    11451999 , "census"           ,
    "3550308"  , 2024L ,    11895578 , "estimate"         ,
    "3304557"  , 2022L ,     6211623 , "census"           ,
    "3304557"  , 2024L ,     6625849 , "estimate"
  )
  out <- siconfi_interpolate_population(population)

  # Anchors pass through unchanged; exactly one 2023 row per municipality.
  expect_equal(nrow(out[out$code_muni == "3550308" & out$year == 2022L, ]), 1L)
  expect_equal(nrow(out[out$year == 2023L, ]), 2L)
  sp <- out[out$code_muni == "3550308" & out$year == 2023L, ]
  # (11451999 + 11895578) / 2 = 11673788.5: R's round keeps the even
  # neighbour 11673788.
  expect_equal(sp$population, 11673788L)
  expect_equal(sp$population_source, "interpolated")
  rj <- out[out$code_muni == "3304557" & out$year == 2023L, ]
  # (6211623 + 6625849) / 2 = 6418736: no rounding tie.
  expect_equal(rj$population, 6418736L)
  expect_equal(rj$population_source, "interpolated")
  expect_type(sp$population, "integer")
})

test_that("siconfi_interpolate_population keeps 2023 NA when an anchor is missing", {
  local_edition(3)
  # No 2022 census figure for 3550308.
  out <- siconfi_interpolate_population(tibble::tribble(
    ~code_muni , ~year , ~population , ~population_source ,
    "3550308"  , 2024L ,    11895578 , "estimate"         ,
    "3304557"  , 2022L ,     6211623 , "census"
  ))
  sp <- out[out$code_muni == "3550308" & out$year == 2023L, ]
  expect_equal(nrow(sp), 1L)
  expect_true(is.na(sp$population))
  expect_true(is.na(sp$population_source))

  # No 2024 estimate figure for 3550308.
  out <- siconfi_interpolate_population(tibble::tribble(
    ~code_muni , ~year , ~population , ~population_source ,
    "3550308"  , 2022L ,    11451999 , "census"
  ))
  sp <- out[out$code_muni == "3550308" & out$year == 2023L, ]
  expect_true(is.na(sp$population))
  expect_true(is.na(sp$population_source))
})

test_that("fetch_siconfi_population wires the IBGE tables and labels sources", {
  local_edition(3)
  calls <- list()
  fake_fetch <- function(
    aggregate,
    variables = "all",
    periods = NULL,
    localities = "N1[all]",
    chunk_size = 120L
  ) {
    calls[[length(calls) + 1L]] <<- list(
      aggregate = aggregate,
      variables = variables,
      periods = periods,
      localities = localities,
      chunk_size = chunk_size
    )
    if (identical(aggregate, "6579")) {
      # A universe-sized fetch (the thin-fetch guard requires 5000+),
      # with the 2022 census year and 2023 (interpolated) absent.
      return(tibble::tibble(
        geography_code = sprintf(
          "%07d",
          1100015L + rep(seq_len(5000L), 8L)
        ),
        period = rep(
          c("2016", "2017", "2018", "2019", "2020", "2021", "2024", "2025"),
          each = 5000L
        ),
        value = rep(
          c(12038175, 12106920, 11900000, 11900000, 11950000, 11960000, 11895578, 11904961),
          each = 5000L
        )
      ))
    }
    return(tibble::tibble(
      geography_code = sprintf("%07d", 1100015L + seq_len(5000L)),
      period = "2022",
      value = 11451999
    ))
  }

  out <- fetch_siconfi_population(2017:2025, fetch = fake_fetch)
  # Table 6579 for the estimates, variable 9324; table 4709 for the 2022
  # Census, variable 93. All locality queries are municipalities; the
  # periods are exactly the requested years, let through in chunks of 5.
  expect_equal(
    vapply(calls, `[[`, character(1L), "aggregate"),
    c("6579", "4709")
  )
  expect_equal(calls[[1]]$variables, "9324")
  expect_equal(calls[[1]]$periods, as.character(2017:2025))
  expect_equal(calls[[1]]$localities, "N6[all]")
  expect_equal(calls[[1]]$chunk_size, 5L)
  expect_equal(calls[[2]]$variables, "93")
  expect_equal(calls[[2]]$periods, "2022")
  expect_equal(calls[[2]]$localities, "N6[all]")

  # Sources and years: estimate years from 6579, census 2022, 2023
  # interpolated; the non-requested 2016 row is dropped. Assertions read a
  # single municipality out of the universe-sized result.
  sp <- out[out$code_muni == "1100016", ]
  expect_equal(
    sp[sp$year == 2022L, c("population", "population_source")],
    tibble::tibble(population = 11451999L, population_source = "census")
  )
  expect_equal(
    sp$population_source[sp$year == 2017L],
    "estimate"
  )
  expect_false(2016L %in% out$year)
  interp <- sp[sp$year == 2023L, ]
  expect_equal(nrow(interp), 1L)
  expect_equal(
    interp$population,
    as.integer(round((11451999 + 11895578) / 2))
  )
  expect_equal(interp$population_source, "interpolated")
  expect_equal(
    names(out),
    c("code_muni", "year", "population", "population_source")
  )
  expect_type(out$population, "integer")
})

test_that("fetch_siconfi_population aborts on a thin IBGE fetch", {
  local_edition(3)
  fake_fetch <- function(
    aggregate,
    variables = "all",
    periods = NULL,
    localities = "N1[all]",
    chunk_size = 120L
  ) {
    if (identical(aggregate, "6579")) {
      # Only two municipalities come back for every requested period:
      # every year would fall below the 5000-municipality guard.
      return(tibble::tibble(
        geography_code = rep(c("1100016", "3550308"), 4L),
        period = rep(c("2016", "2017", "2024", "2025"), each = 2L),
        value = 12038175
      ))
    }
    return(tibble::tibble(
      geography_code = c("1100016", "3550308"),
      period = "2022",
      value = 11451999
    ))
  }
  expect_error(
    fetch_siconfi_population(2017:2025, fetch = fake_fetch),
    "5000",
    ignore.case = TRUE
  )

  # 2023 is exempt only when an anchor year is missing: requesting just
  # 2023 with no anchors keeps the NA interpolation instead of aborting.
  thin_2023 <- tibble::tibble(
    geography_code = c("1100015", "3550308"),
    period = "2023",
    value = 12038175
  )
  expect_no_error(
    fetch_siconfi_population(2023L, fetch = function(...) thin_2023)
  )
})

test_that("fetch_siconfi_population returns an empty tibble without years", {
  local_edition(3)
  empty <- fetch_siconfi_population(integer(), fetch = function(...) {
    cli::cli_abort("must not fetch without years")
  })
  expect_equal(
    names(empty),
    c("code_muni", "year", "population", "population_source")
  )
  expect_equal(nrow(empty), 0L)
})

test_that("build_siconfi_taxes injects IBGE population on reporter and non-reporter rows", {
  local_edition(3)
  population <- tibble::tribble(
    ~code_muni , ~year , ~population , ~population_source ,
    "3550308"  , 2017L ,    12106920 , "estimate"         ,
    "3550308"  , 2024L ,    11895578 , "estimate"         ,
    "3550308"  , 2022L ,    11451999 , "census"           ,
    "4304614"  , 2017L ,     2001234 , "census"           ,
    "4126652"  , 2018L ,        2712 , "interpolated"
  )
  dat <- build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all,
    population = population
  )

  # Both tax rows share the injected figure and label.
  sp_2017 <- dat[
    dat$code_muni == 3550308L & dat$year == 2017L,
  ]
  expect_equal(nrow(sp_2017), 2L)
  expect_equal(unique(sp_2017$population), 12106920L)
  expect_equal(unique(sp_2017$population_source), "estimate")

  # Different sources per year roundtrip correctly (2022 is a fixture
  # year; Sulina 2018 covers the interpolated label on a non-reporter).
  sp_2022 <- dat[dat$code_muni == 3550308L & dat$year == 2022L, ]
  expect_equal(unique(sp_2022$population_source), "census")

  # A municipality-year with no figure anywhere keeps NA + NA source.
  sp_2013 <- dat[dat$code_muni == 3550308L & dat$year == 2013L, ]
  expect_true(all(is.na(sp_2013$population)))
  expect_true(all(is.na(sp_2013$population_source)))

  # Population is independent of SICONFI reporting: non-reporter rows
  # keep their IBGE figure (Canudos do Vale reports in 2017; Sulina is a
  # non-reporter in 2018).
  canudos <- dat[dat$code_muni == 4304614L & dat$year == 2017L, ]
  expect_true(all(canudos$reported))
  expect_equal(unique(canudos$population), 2001234L)
  expect_equal(unique(canudos$population_source), "census")
  sulina_2018 <- dat[dat$code_muni == 4126652L & dat$year == 2018L, ]
  expect_false(any(sulina_2018$reported))
  expect_equal(unique(sulina_2018$population), 2712L)
  expect_equal(unique(sulina_2018$population_source), "interpolated")
})

test_that("an API-supplied year keeps revenue totals from the API and population from IBGE", {
  local_edition(3)
  finbra_all <- siconfi_finbra_all()
  # São Paulo's 2017 municipality-year moves to the API: the revenue totals
  # must come from the API items while the injected IBGE figure covers the
  # year regardless of the reporting source.
  api <- parse_siconfi_dca(siconfi_dca_items("dca_sp_context_2017.json"))
  population <- tibble::tibble(
    code_muni = "3550308",
    year = 2017L,
    population = 12106920L,
    population_source = "estimate"
  )
  dat <- build_siconfi_taxes(
    finbra_all,
    api = api,
    municipalities = siconfi_municipalities_all,
    population = population
  )
  sp_2017 <- dat[dat$code_muni == 3550308L & dat$year == 2017L, ]
  expect_equal(nrow(sp_2017), 2L)
  expect_equal(unique(sp_2017$source), "api")
  expect_equal(unique(sp_2017$population), 12106920L)
  expect_equal(unique(sp_2017$population_source), "estimate")
  expect_equal(unique(sp_2017$current_revenue), 50970741521.99)
  expect_equal(unique(sp_2017$tax_revenue), 25715190301.72)

  # The FINBRA 2017 fixture carries context totals deliberately different
  # from the API values (11111111111.11 and 22222222222.22): the covered
  # municipality-year must repeat the API values on both tax rows, one row
  # per municipality-year-tax, and never the API-precedence losers.
  expect_false(any(sp_2017$current_revenue == 11111111111.11))
  expect_false(any(sp_2017$tax_revenue == 22222222222.22))
  # Rio is not covered by the API response: it keeps its FINBRA context.
  rio_2017 <- dat[dat$code_muni == 3304557L & dat$year == 2017L, ]
  expect_equal(unique(rio_2017$source), "finbra")
  expect_equal(unique(rio_2017$current_revenue), 33333333333.33)
  expect_equal(unique(rio_2017$tax_revenue), 44444444444.44)

  # A 2018 API municipality-year without any FINBRA 2018 file in the build
  # and no injected population: population stays NA, totals come from the
  # API.
  finbra_no_2018 <- finbra_all[finbra_all$year != 2018L, ]
  attr(finbra_no_2018, "reporters") <- unique(
    paste(finbra_no_2018$code_muni, finbra_no_2018$year)
  )
  # The context rows of the dropped 2018 file are gone with it, as in a
  # build without that file.
  finbra_context <- attr(finbra_no_2018, "context")
  attr(finbra_no_2018, "context") <- finbra_context[
    finbra_context$year != 2018L,
  ]
  api_2018 <- parse_siconfi_dca(siconfi_dca_items("dca_sp_context_2018.json"))
  dat_2018 <- build_siconfi_taxes(
    finbra_no_2018,
    api = api_2018,
    municipalities = siconfi_municipalities_all
  )
  sp_2018 <- dat_2018[dat_2018$code_muni == 3550308L & dat_2018$year == 2018L, ]
  expect_equal(unique(sp_2018$source), "api")
  expect_true(all(is.na(sp_2018$population)))
  expect_true(all(is.na(sp_2018$population_source)))
  expect_equal(unique(sp_2018$current_revenue), 52983577439.67)
  expect_equal(unique(sp_2018$tax_revenue), 30083861181.61)

  # A non-reporter in an API-supplied year keeps NA in the context columns
  # (Alta Floresta d'Oeste appears in no fixture file).
  non_2018 <- dat_2018[
    dat_2018$code_muni == 1100015L & dat_2018$year == 2018L,
  ]
  expect_equal(nrow(non_2018), 2L)
  expect_false(any(non_2018$reported))
  expect_true(all(is.na(non_2018[c(
    "population",
    "current_revenue",
    "tax_revenue"
  )])))
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
  # The second request (offset 2) gets the first page again: the offset
  # guard must reject it.
  expect_error(
    fetch_siconfi_dca(3550308, 2024, request = endless),
    "offset|resent",
    ignore.case = TRUE
  )
})

test_that("fetch_siconfi_dca rejects an inconsistent item count", {
  local_edition(3)
  page <- jsonlite::fromJSON(
    siconfi_fixture("dca_page_1.json"),
    simplifyVector = FALSE
  )
  page$hasMore <- FALSE
  page$count <- 5L
  truncated <- function(url) {
    return(page)
  }
  expect_error(
    fetch_siconfi_dca(3550308, 2024, request = truncated),
    "count",
    ignore.case = TRUE
  )
})

test_that("fetch_siconfi_dca caps pagination", {
  local_edition(3)
  paged <- function(url) {
    offset <- as.integer(sub("^.*offset=", "", url))
    page <- jsonlite::fromJSON(
      siconfi_fixture("dca_page_1.json"),
      simplifyVector = FALSE
    )
    page$offset <- offset
    return(page)
  }
  expect_error(
    fetch_siconfi_dca(3550308, 2024, request = paged),
    "pag|pages",
    ignore.case = TRUE
  )
})

test_that("fetch_siconfi_dca asserts each page's offset", {
  local_edition(3)
  # The first page (offset 0) is valid and claims more; the follow-up
  # request (offset 2) gets a page claiming offset 349: the guard must
  # reject the misdirected second page.
  wrong_offset <- function(url) {
    if (grepl("[?&]offset=0($|[^0-9])", url)) {
      return(jsonlite::fromJSON(
        siconfi_fixture("dca_page_1.json"),
        simplifyVector = FALSE
      ))
    }
    page_2 <- jsonlite::fromJSON(
      siconfi_fixture("dca_page_1.json"),
      simplifyVector = FALSE
    )
    page_2$offset <- 349L
    return(page_2)
  }
  expect_error(
    fetch_siconfi_dca(3550308, 2024, request = wrong_offset),
    "offset",
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
      "population",
      "population_source",
      "current_revenue",
      "tax_revenue",
      "tax",
      "reported",
      "value_status",
      "gross_revenue",
      "other_deductions",
      "deductions_reported",
      "net_revenue",
      "account_scope",
      "source"
    )
  )
  # The universe has 10 municipalities for 5 years and 2 taxes.
  expect_equal(nrow(dat), 100L)

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
    # Every anchor carries a deduction row in the source.
    expect_true(row$deductions_reported)
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
  expect_equal(unique(dat$source[dat$reported]), "finbra")
  # Observed rows carry a gross value; missing_tax_row rows do not and are
  # always reported.
  expect_true(all(!is.na(dat$gross_revenue[dat$value_status == "observed"])))
  filing_rows <- dat[dat$value_status == "missing_tax_row", ]
  expect_true(all(filing_rows$reported))
  expect_true(all(is.na(filing_rows$gross_revenue)))
})

test_that("missing deduction rows count as zero with deductions_reported FALSE", {
  local_edition(3)
  dat <- build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all
  )
  # Sulina (2013) and the other gross-only municipalities in each fixture
  # file report gross rows for both taxes and no deduction rows: the
  # deduction is assumed 0, the net is computed, and deductions_reported
  # marks the assumption.
  for (pair in list(
    c(4126652L, 2013L),
    c(4304614L, 2017L),
    c(5203559L, 2018L),
    c(4315156L, 2022L),
    c(1100122L, 2024L)
  )) {
    rows <- dat[
      dat$code_muni == pair[[1]] & dat$year == pair[[2]],
    ]
    expect_equal(nrow(rows), 2L)
    expect_true(all(rows$reported))
    expect_true(all(is.finite(rows$gross_revenue)))
    expect_equal(rows$other_deductions, c(0, 0))
    expect_false(any(rows$deductions_reported))
    expect_false(any(is.na(rows$gross_revenue)))
    expect_equal(rows$value_status, c("observed", "observed"))
    expect_equal(rows$net_revenue, rows$gross_revenue)
  }

  deduction_only <- build_siconfi_taxes(
    tibble::tibble(
      year = 2018L,
      code_muni = "5203559",
      abbrev_state = "GO",
      institution = "Prefeitura Municipal de Bonfinópolis - GO",
      tax = "iptu",
      value_kind = "deduction",
      value = 1234.50
    ),
    api = NULL,
    municipalities = siconfi_municipalities_all[
      siconfi_municipalities_all$code_muni == 5203559L,
    ]
  )
  deduction <- deduction_only[
    deduction_only$tax == "iptu",
  ]
  # A deduction row without a gross row: the observed deduction stays, the
  # flag is TRUE, and both the gross and the net stay NA.
  expect_true(is.na(deduction$gross_revenue))
  expect_false(is.na(deduction$other_deductions))
  expect_equal(deduction$other_deductions, 1234.50)
  expect_true(deduction$deductions_reported)
  expect_true(is.na(deduction$net_revenue))
  expect_equal(deduction$value_status, "missing_tax_row")

  # Non-reporters keep NA values and an NA flag (no assumption made).
  non_reporter <- dat[
    dat$code_muni == 1100015L & dat$year == 2013L & dat$tax == "iptu",
  ]
  expect_true(all(is.na(non_reporter$other_deductions)))
  expect_true(is.na(non_reporter$deductions_reported))
})

test_that("a deduction row without a gross row keeps the deduction", {
  local_edition(3)
  # A deduction row with no corresponding gross row: other_deductions
  # keeps the observed value, deductions_reported is TRUE, and both the
  # gross and the net stay NA with value_status missing_tax_row.
  dat <- build_siconfi_taxes(
    tibble::tibble(
      year = 2018L,
      code_muni = "5203559",
      abbrev_state = "GO",
      institution = "Prefeitura Municipal de Bonfinópolis - GO",
      tax = "iptu",
      value_kind = "deduction",
      value = 1000.00
    ),
    api = NULL,
    municipalities = siconfi_municipalities_all[
      siconfi_municipalities_all$code_muni == 5203559L,
    ]
  )
  row <- dat[
    dat$code_muni == 5203559L & dat$year == 2018L & dat$tax == "iptu",
  ]
  expect_equal(nrow(row), 1L)
  expect_equal(row$value_status, "missing_tax_row")
  expect_true(is.na(row$gross_revenue))
  expect_equal(row$other_deductions, 1000.00)
  expect_true(row$deductions_reported)
  expect_true(is.na(row$net_revenue))
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
    missing[
      c(
        "population",
        "current_revenue",
        "tax_revenue",
        "gross_revenue",
        "other_deductions",
        "net_revenue"
      )
    ]
  )))
  expect_true(all(is.na(missing$source)))

  # Sulina reports in 2013 only; every other year is a non-reporter year.
  absent <- dat[dat$code_muni == 4126652L & dat$year != 2013L, ]
  expect_equal(nrow(absent), 8L)
  expect_false(any(absent$reported))
  expect_equal(unique(absent$value_status), "non_reporter")
})

test_that("a municipality that filed but has no tax row is a reporter", {
  local_edition(3)
  finbra_2018 <- read_finbra_file(siconfi_fixture("finbra_extract_03.csv"))
  # Recursolândia-TO has an ordinary revenue line in the 2018 file but no
  # IPTU/ITBI row; the reporters attribute must record it.
  expect_true("1718501 2018" %in% attr(finbra_2018, "reporters"))

  dat <- validate_siconfi_taxes(build_siconfi_taxes(
    finbra_2018,
    api = NULL,
    municipalities = siconfi_municipalities_all
  ))
  rows <- dat[dat$code_muni == 1718501L & dat$year == 2018L, ]
  expect_equal(nrow(rows), 2L)
  expect_true(all(rows$reported))
  expect_equal(unique(rows$value_status), "missing_tax_row")
  expect_equal(unique(rows$source), "finbra")
  expect_true(all(is.na(rows$gross_revenue)))
  expect_true(all(is.na(rows$net_revenue)))
  # The 2018 fixture carries no context-account lines: the reporting
  # municipality-year keeps NA totals, never 0.
  expect_true(all(is.na(rows$current_revenue)))
  expect_true(all(is.na(rows$tax_revenue)))
  # Everything else about Recursolândia: no other years in this single-file
  # long form.
  absent <- dat[dat$code_muni == 1718501L & dat$year != 2018L, ]
  expect_equal(nrow(absent), 0L)
})

test_that("parse_siconfi_dca records reporters from any account", {
  local_edition(3)
  # dca_page_1.json carries only non-tax revenue accounts: the municipality
  # still counts as a reporter, and no tax rows come back.
  dat <- parse_siconfi_dca(siconfi_dca_items("dca_page_1.json"))
  expect_equal(attr(dat, "reporters"), "3550308 2024")
  expect_equal(nrow(dat), 0L)

  empty <- parse_siconfi_dca(list())
  expect_equal(attr(empty, "reporters"), character())
  expect_equal(nrow(empty), 0L)
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

# Builder pipeline ------------------------------------------------------------

#' Source the maintainer build script into the test frame
#'
#' The script lives in data-raw, which is excluded from the R build bundle;
#' the tests simply skip where it is unavailable (R CMD check).
siconfi_load_builder <- function() {
  path <- file.path(
    test_path("..", ".."),
    "data-raw",
    "siconfi",
    "build_snapshot.R"
  )
  skip_if_not(file.exists(path))
  skip_if_not_installed("devtools")
  skip_if_not_installed("digest")
  source(path, local = FALSE, chdir = FALSE)
  invisible(TRUE)
}

test_that("siconfi_harvest_api checkpoints only consistent fetches", {
  siconfi_load_builder()
  checkpoint_dir <- withr::local_tempdir()
  universe <- tibble::tibble(
    code_muni = c(3550308L, 3304557L),
    abbrev_state = c("SP", "RJ")
  )
  saveRDS(universe, file.path(checkpoint_dir, "universe_entes.rds"))
  items_sp <- siconfi_dca_items("dca_sp_tax_2017.json")

  # São Paulo fetches fine; Rio's response claims a count it did not send
  # and must abort before any checkpoint is written.
  local_mocked_bindings(
    fetch_siconfi_dca = function(code_muni, year, ...) {
      if (identical(code_muni, "3304557")) {
        cli::cli_abort("Inconsistent SICONFI response: count 5 items.")
      }
      return(items_sp)
    }
  )
  expect_error(
    siconfi_harvest_api(2017L, checkpoint_dir),
    "count|Inconsistent",
    ignore.case = TRUE
  )
  expect_false(file.exists(file.path(checkpoint_dir, "dca_3304557_2017.rds")))

  # Rerun: São Paulo is served from its checkpoint (no re-fetch), Rio is
  # fetched now; the checkpoint records the raw item count.
  calls <- new.env(parent = emptyenv())
  local_mocked_bindings(
    fetch_siconfi_dca = function(code_muni, year, ...) {
      calls$n <- (calls$n %||% 0L) + 1L
      if (identical(code_muni, "3304557")) {
        return(list())
      }
      return(items_sp)
    }
  )
  res <- siconfi_harvest_api(2017L, checkpoint_dir)
  expect_equal(calls$n, 1L)
  expect_equal(nrow(res), 4L)
  expect_equal(attr(res, "reporters"), "3550308 2017")
  checkpoint <- readRDS(file.path(checkpoint_dir, "dca_3550308_2017.rds"))
  expect_equal(checkpoint$raw_items, 4L)
  empty_checkpoint <- readRDS(file.path(checkpoint_dir, "dca_3304557_2017.rds"))
  expect_equal(empty_checkpoint$raw_items, 0L)
  expect_equal(empty_checkpoint$reporters, character())
})

test_that("siconfi_harvest_finbra aborts on two files for the same year", {
  siconfi_load_builder()
  dir <- withr::local_tempdir()
  zip <- siconfi_fixture("finbra_MUN_ReceitasOrcamentarias(AnexoI-C).zip")
  file.copy(zip, file.path(dir, "copy_a.zip"))
  file.copy(zip, file.path(dir, "copy_b.zip"))

  expect_error(
    siconfi_harvest_finbra(dir),
    r"(2017.*(copy_a\.zip|copy_b\.zip).*(copy_a\.zip|copy_b\.zip))",
    ignore.case = TRUE
  )
})

test_that("siconfi_harvest_finbra attaches reporting keys per year", {
  siconfi_load_builder()
  dir <- withr::local_tempdir()
  file.copy(
    siconfi_fixture("finbra_MUN_ReceitasOrcamentarias(AnexoI-C).zip"),
    file.path(dir, "extract_2017.zip")
  )
  file.copy(
    siconfi_fixture("finbra_extract_03.csv"),
    file.path(dir, "extract_2018.csv")
  )
  harvest <- siconfi_harvest_finbra(dir)
  expect_true("1718501 2018" %in% attr(harvest$long, "reporters"))
  expect_true("3550308 2017" %in% attr(harvest$long, "reporters"))
  expect_equal(length(unique(harvest$files)), 2L)
  expect_equal(
    sort(vapply(harvest$files, `[[`, integer(1L), "exercise")),
    c(2017L, 2018L)
  )
  # The per-file context rows are aggregated through siconfi_build_context()
  # (dedup and conflict abort included): the 2017 zip copy carries São
  # Paulo's context lines, the 2018 file carries none, and the FINBRA
  # `População` field is no longer read (population comes from IBGE).
  ctx <- attr(harvest$long, "context")
  expect_false("population" %in% names(ctx))
  sp_2017 <- ctx[ctx$code_muni == "3550308" & ctx$year == 2017L, ]
  expect_equal(nrow(sp_2017), 1L)
  expect_equal(sp_2017$current_revenue, 11111111111.11)
  expect_equal(sp_2017$tax_revenue, 22222222222.22)
  expect_equal(nrow(ctx[ctx$year == 2018L, ]), 0L)
})

test_that("siconfi_entes_universe drops Brasília and reports the exclusion", {
  siconfi_load_builder()
  checkpoint_dir <- withr::local_tempdir()
  cached <- tibble::tibble(
    code_muni = c(3550308L, 5300108L, 4126652L),
    abbrev_state = c("SP", "DF", "PR")
  )
  saveRDS(cached, file.path(checkpoint_dir, "universe_entes.rds"))
  expect_message(
    universe <- siconfi_entes_universe(checkpoint_dir),
    "5300108|Distrito Federal",
    ignore.case = TRUE
  )
  expect_false(5300108L %in% universe$code_muni)
  expect_setequal(universe$code_muni, c(3550308L, 4126652L))
})

test_that("siconfi_check_universe_coverage aborts on munis in no FINBRA year", {
  siconfi_load_builder()
  universe <- tibble::tibble(
    code_muni = c(3550308L, 1718505L),
    abbrev_state = c("SP", "TO")
  )
  finbra <- read_finbra_file(siconfi_fixture("finbra_extract_03.csv"))
  expect_error(
    siconfi_check_universe_coverage(universe, attr(finbra, "reporters")),
    "1718505"
  )
  # São Paulo files in the fixture: no error.
  ok_universe <- universe[universe$code_muni == 3550308L, ]
  expect_no_error(
    siconfi_check_universe_coverage(ok_universe, attr(finbra, "reporters"))
  )
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

test_that("validate_siconfi_taxes checks every published column type", {
  local_edition(3)
  dat <- build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all
  )

  for (column in c(
    "abbrev_state",
    "tax",
    "population",
    "population_source",
    "reported",
    "value_status",
    "deductions_reported",
    "account_scope",
    "source"
  )) {
    wrong <- dat
    wrong[[column]] <- as.numeric(
      if (
        column %in%
          c(
            "reported",
            "deductions_reported"
          )
      ) {
        rep(1L, nrow(wrong))
      } else {
        rep(0L, nrow(wrong))
      }
    )
    expect_error(
      validate_siconfi_taxes(wrong),
      column,
      info = column
    )
  }

  # The two revenue-total columns must stay double: character coercion
  # aborts naming the column.
  wrong_totals <- dat
  wrong_totals$current_revenue <- as.character(wrong_totals$current_revenue)
  expect_error(validate_siconfi_taxes(wrong_totals), "current_revenue")
  wrong_totals <- dat
  wrong_totals$tax_revenue <- as.character(wrong_totals$tax_revenue)
  expect_error(validate_siconfi_taxes(wrong_totals), "tax_revenue")
})

test_that("validate_siconfi_taxes checks the documented value domains", {
  local_edition(3)
  dat <- build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all
  )

  bad_status <- dat
  bad_status$value_status[[1]] <- "hallucinated"
  expect_error(validate_siconfi_taxes(bad_status), "value_status")

  bad_scope <- dat
  bad_scope$account_scope[[1]] <- "legacy_parent"
  expect_error(validate_siconfi_taxes(bad_scope), "account_scope")

  bad_reported <- dat
  bad_reported$reported[[1]] <- NA
  expect_error(validate_siconfi_taxes(bad_reported), "reported")

  bad_source <- dat
  bad_source$population_source[[1]] <- "hallucinated"
  expect_error(validate_siconfi_taxes(bad_source), "population_source")
})

test_that("validate_siconfi_taxes checks non-reporter NA and net invariants", {
  local_edition(3)
  dat <- build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all
  )

  # A non-reporter row cannot carry a source or revenue values, but
  # population is independent of reporting and may carry an IBGE figure.
  leak_source <- dat
  leak_source$source[which(!leak_source$reported)[1L]] <- "finbra"
  expect_error(validate_siconfi_taxes(leak_source), "source")

  leak_value <- dat
  leak_value$gross_revenue[which(!leak_value$reported)[1L]] <- 1.00
  expect_error(validate_siconfi_taxes(leak_value), "gross_revenue")

  leak_context <- dat
  leak_context$tax_revenue[which(!leak_context$reported)[1L]] <- 1.00
  expect_error(validate_siconfi_taxes(leak_context), "tax_revenue")

  # population_source must be NA exactly when population is NA, on every
  # row, reporter or not.
  orphan_source <- dat
  first_na_population <- which(is.na(orphan_source$population))
  orphan_source$population_source[first_na_population[[1L]]] <- "census"
  expect_error(
    validate_siconfi_taxes(orphan_source),
    "population_source"
  )

  orphan_population <- dat
  first_na_source <- which(is.na(orphan_population$population_source))
  orphan_population$population[first_na_source[[1L]]] <- 1000L
  expect_error(
    validate_siconfi_taxes(orphan_population),
    "population_source"
  )

  # net_revenue must equal gross minus deductions where both exist.
  bad_net <- dat
  observed <- which(
    is.finite(bad_net$net_revenue) & bad_net$deductions_reported == TRUE
  )
  bad_net$net_revenue[observed[1L]] <-
    bad_net$net_revenue[observed[1L]] + 1
  expect_error(validate_siconfi_taxes(bad_net), "net_revenue")
})

test_that("validate_siconfi_taxes names the row of a net mismatch", {
  local_edition(3)
  dat <- build_siconfi_taxes(
    siconfi_finbra_all(),
    api = NULL,
    municipalities = siconfi_municipalities_all
  )

  # Corrupt the last checked row: the error must name that row's key,
  # not an unrelated earlier one.
  checked <- which(
    !is.na(dat$deductions_reported) & is.finite(dat$net_revenue)
  )
  last <- checked[length(checked)]
  bad_net <- dat
  bad_net$net_revenue[last] <- bad_net$net_revenue[last] + 1
  expect_error(
    validate_siconfi_taxes(bad_net),
    sprintf("%.0f", dat$code_muni[last]),
    fixed = TRUE
  )

  # The identity also holds where the deduction was assumed 0: there the
  # net must equal the gross.
  assumed <- which(
    !is.na(dat$deductions_reported) &
      !dat$deductions_reported &
      is.finite(dat$net_revenue)
  )
  bad_assumed <- dat
  bad_assumed$net_revenue[assumed[1]] <-
    bad_assumed$net_revenue[assumed[1]] + 1
  expect_error(
    validate_siconfi_taxes(bad_assumed),
    sprintf("%.0f", dat$code_muni[assumed[1]]),
    fixed = TRUE
  )
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
  expect_true(isTRUE(info$cache_only))
  expect_equal(sum(list_datasets()$name == "siconfi_taxes"), 1L)
})

test_that("get_dataset fresh aborts naming the pipeline and the release cache", {
  local_edition(3)
  clear_session_cache()
  withr::defer(clear_session_cache())
  cli_error <- rlang::catch_cnd(
    get_dataset("siconfi_taxes", source = "fresh", quiet = TRUE),
    classes = "error"
  )
  expect_false(is.null(cli_error))
  expect_match(conditionMessage(cli_error), "data-raw pipeline", fixed = TRUE)
  expect_match(conditionMessage(cli_error), "release cache", fixed = TRUE)
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
  # Auto must abort with the cache-only message: it names the cache and
  # never advises source='fresh', which cannot work for this dataset.
  expect_false(is.null(cli_error))
  expect_match(conditionMessage(cli_error), "release cache", fixed = TRUE)
  expect_false(
    grepl("Try source", conditionMessage(cli_error), fixed = TRUE)
  )
})

test_that("source auto on cache-only data never warns about a fresh download", {
  local_edition(3)
  clear_session_cache()
  withr::defer(clear_session_cache())
  local_mocked_bindings(
    fetch_github_release_asset = function(cached_name, quiet = FALSE) {
      cli::cli_abort("release asset unavailable")
    }
  )
  # With quiet = FALSE the GitHub failure must not raise the "downloading
  # from the original source" advice that can never be honored for a
  # cache-only dataset; the run aborts with the cache-only message.
  expect_no_warning(
    expect_error(
      get_dataset("siconfi_taxes", source = "auto", quiet = FALSE),
      "release cache",
      fixed = TRUE
    )
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
