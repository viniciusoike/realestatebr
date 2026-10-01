make_pnad_housing_raw <- function(
  table,
  variable_id,
  unit,
  classification_id = NULL,
  category_id = NULL,
  category_name = "Category",
  periods = "2025",
  geography_level = "N1",
  geography_code = "1",
  geography_name = "Brasil",
  values = "100"
) {
  n <- max(
    length(variable_id),
    length(periods),
    length(values),
    length(geography_code),
    length(category_id)
  )
  recycle <- function(x) rep_len(x, n)

  dat <- tibble::tibble(
    aggregate_id = as.character(table),
    variable_id = recycle(as.character(variable_id)),
    variable_name = "Variable",
    unit = recycle(unit),
    period = recycle(periods),
    geography_level = recycle(geography_level),
    geography_level_name = "Level",
    geography_code = recycle(geography_code),
    geography_name = recycle(geography_name),
    value_raw = recycle(as.character(values)),
    value = parse_ibge_value(recycle(values))
  )

  if (!is.null(classification_id)) {
    code_col <- paste0("classification_", classification_id, "_code")
    name_col <- paste0("classification_", classification_id, "_name")
    dat[[code_col]] <- recycle(as.character(category_id))
    dat[[name_col]] <- recycle(category_name)
  }

  return(dat)
}

make_pnad_housing_complete_raw <- function(table) {
  table_id <- unname(pnad_housing_tables[[table]])
  variables <- pnad_housing_table_variables[[table]]
  units <- pnad_housing_variables$unit[
    match(variables, pnad_housing_variables$variable_id)
  ]

  geographies <- tibble::tibble(
    geography_level = rep(
      names(pnad_housing_expected_geography_codes),
      lengths(pnad_housing_expected_geography_codes)
    ),
    geography_code = unlist(
      pnad_housing_expected_geography_codes,
      use.names = FALSE
    )
  )

  if (table == "mean_household_size") {
    grid <- tidyr::expand_grid(variable_id = variables, geographies)
    raw <- make_pnad_housing_raw(
      table = table_id,
      variable_id = grid$variable_id,
      unit = pnad_housing_variables$unit[
        match(grid$variable_id, pnad_housing_variables$variable_id)
      ],
      geography_level = grid$geography_level,
      geography_code = grid$geography_code,
      values = ifelse(grid$variable_id == "10163", "2.7", "0.8")
    )
    attr(raw, "published_periods") <- "2025"
    return(raw)
  }

  category_ids <- names(pnad_housing_categories[[table]])
  grid <- tidyr::expand_grid(
    variable_id = variables,
    category_id = category_ids,
    geographies
  )
  component_count <- length(category_ids) - 1L
  values <- rep("1", nrow(grid))
  is_total <- grid$category_id == category_ids[[1]]
  values[grid$variable_id == "162" & is_total] <- as.character(component_count)
  values[grid$variable_id == "9784" & is_total] <- "100"
  values[grid$variable_id == "9784" & !is_total] <- as.character(
    100 / component_count
  )
  classification_id <- pnad_housing_classifications[[table]]
  raw <- make_pnad_housing_raw(
    table = table_id,
    variable_id = grid$variable_id,
    unit = pnad_housing_variables$unit[
      match(grid$variable_id, pnad_housing_variables$variable_id)
    ],
    classification_id = classification_id,
    category_id = grid$category_id,
    geography_level = grid$geography_level,
    geography_code = grid$geography_code,
    values = values
  )
  if (table == "household_composition") {
    raw$classification_293_code <- "100311"
    raw$classification_293_name <- "Total"
  }
  attr(raw, "published_periods") <- "2025"

  return(raw)
}

test_that("PNAD Housing source maps pin the approved contract", {
  expect_identical(
    names(pnad_housing_tables),
    c(
      "tenure",
      "dwelling_type",
      "household_size",
      "mean_household_size",
      "household_composition"
    )
  )
  expect_identical(
    unname(pnad_housing_tables),
    c(6821L, 6820L, 6678L, 6578L, 6788L)
  )
  expect_setequal(
    pnad_housing_table_variables[["tenure"]],
    c("162", "5123", "9784", "9785")
  )
  expect_setequal(
    pnad_housing_table_variables[["household_composition"]],
    c("162", "5123")
  )
  expect_false(any(c("9782", "9783") %in% unlist(pnad_housing_table_variables)))
})

test_that("PNAD Housing fixtures preserve dated official values", {
  read_fixture <- function(name, table) {
    path <- testthat::test_path("fixtures", "pnad_housing", name)
    raw <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    parse_ibge_aggregate_chunk(raw, table)
  }

  size <- read_fixture("6678_brazil_2025.json", 6678L)
  composition <- read_fixture("6788_brazil_2025.json", 6788L)
  pandemic <- read_fixture("6788_brazil_2020_2021.json", 6788L)
  geographies <- read_fixture("6821_geographies_2016_2025.json", 6821L)
  audit <- readr::read_csv(
    testthat::test_path("fixtures", "pnad_housing", "source_audit.csv"),
    show_col_types = FALSE
  )

  expect_identical(size$value, c(79305, 15633))
  expect_identical(composition$value, c(79305, 15633))
  expect_identical(composition$classification_293_code, c("100311", "100311"))
  expect_identical(sort(unique(pandemic$period)), c("2020", "2021"))
  expect_setequal(
    geographies$geography_level,
    c("N1", "N6", "N7", "N14")
  )
  expect_match(
    geographies$geography_level_name[geographies$geography_level == "N7"][1],
    "até 2020"
  )
  expect_setequal(audit$table, c(6821, 6820, 6678, 6578, 6788))
  expect_identical(nrow(audit), 46L)
  expect_identical(audit$domains_n7, rep(20, nrow(audit)))
  expect_identical(audit$domains_n14, rep(1, nrow(audit)))
  expect_equal(
    audit$period[audit$selector == "household_composition"],
    2012:2025
  )
  expect_length(which(is.na(audit$variable_ids)), 0)
  expect_length(which(is.na(audit$units)), 0)
  expect_length(which(is.na(audit$observed_raw_symbols)), 0)
})

test_that("PNAD Housing derives and rejects source statuses", {
  local_edition(3)
  expect_identical(
    pnad_housing_value_status(c("10", "-", "..", "...", "X", NA, "")),
    c(
      "observed",
      "zero",
      "not_applicable",
      "not_available",
      "suppressed",
      "missing",
      "missing"
    )
  )

  expect_error(
    pnad_housing_value_status("?"),
    'Unknown PNAD Housing value symbol: "?".',
    fixed = TRUE
  )
})

test_that("PNAD Housing cleans a categorized table", {
  raw <- make_pnad_housing_raw(
    table = 6821,
    variable_id = c("162", "9784"),
    unit = c("Mil unidades", "%"),
    classification_id = 63,
    category_id = c("1055", "1055"),
    category_name = "Alugado",
    geography_level = "N7",
    geography_code = "3550308",
    geography_name = "São Paulo (SP)",
    values = c("1800", "22.7")
  )

  result <- clean_pnad_housing(raw, "tenure")

  expect_identical(
    names(result),
    c(
      "year",
      "source_table",
      "geography_type",
      "geography_code",
      "geography_name",
      "geography_level_name",
      "classification_id",
      "category_id",
      "category",
      "category_name_pt",
      "variable_id",
      "variable",
      "variable_name_pt",
      "unit",
      "value",
      "value_raw",
      "value_status"
    )
  )
  expect_identical(result$year, c(2025L, 2025L))
  expect_identical(result$source_table, c(6821L, 6821L))
  expect_identical(
    result$geography_type,
    c("metropolitan_region", "metropolitan_region")
  )
  expect_identical(result$classification_id, c("63", "63"))
  expect_identical(result$category, c("rented", "rented"))
  expect_identical(result$variable, c("households", "household_share"))
  expect_identical(result$value_status, c("observed", "observed"))
})

test_that("PNAD Housing mean table has typed missing categories", {
  raw <- make_pnad_housing_raw(
    table = 6578,
    variable_id = c("10163", "10164"),
    unit = c("Pessoas", "%"),
    values = c("2.7", "0.8")
  )

  result <- clean_pnad_housing(raw, "mean_household_size")

  expect_identical(result$classification_id, rep(NA_character_, 2))
  expect_identical(result$category_id, rep(NA_character_, 2))
  expect_identical(result$category, rep(NA_character_, 2))
  expect_identical(result$variable, c("mean_residents", "mean_residents_cv"))
})

test_that("PNAD Housing composition requires total reference-person sex", {
  local_edition(3)
  raw <- make_pnad_housing_raw(
    table = 6788,
    variable_id = "162",
    unit = "Mil unidades",
    classification_id = 460,
    category_id = "12076",
    category_name = "Unipessoal",
    values = "15633"
  )
  raw$classification_293_code <- "100311"
  raw$classification_293_name <- "Total"

  result <- clean_pnad_housing(raw, "household_composition")
  expect_identical(result$category, "one_person")

  raw$classification_293_code <- "100312"
  expect_error(
    clean_pnad_housing(raw, "household_composition"),
    "PNAD Housing composition must use total reference-person sex.",
    fixed = TRUE
  )
})

test_that("PNAD Housing rejects unknown IDs, units, and geographies", {
  local_edition(3)
  raw <- make_pnad_housing_raw(
    table = 6821,
    variable_id = "999",
    unit = "Mil unidades",
    classification_id = 63,
    category_id = "1055"
  )
  expect_error(
    clean_pnad_housing(raw, "tenure"),
    'Unknown PNAD Housing variable ID: "999".',
    fixed = TRUE
  )

  raw$variable_id <- "162"
  raw$unit <- "%"
  expect_error(
    clean_pnad_housing(raw, "tenure"),
    'Unexpected unit for PNAD Housing variable ID: "162".',
    fixed = TRUE
  )

  raw$unit <- "Mil unidades"
  raw$geography_level <- "N9"
  expect_error(
    clean_pnad_housing(raw, "tenure"),
    'Unknown PNAD Housing geography level: "N9".',
    fixed = TRUE
  )
})

test_that("PNAD Housing validation rejects duplicate keys", {
  local_edition(3)
  raw <- make_pnad_housing_raw(
    table = 6578,
    variable_id = "10163",
    unit = "Pessoas",
    values = "2.7"
  )
  dat <- clean_pnad_housing(raw, "mean_household_size")
  dat <- dplyr::bind_rows(dat, dat)

  expect_error(
    validate_pnad_housing(dat, "mean_household_size"),
    "contains duplicate",
    fixed = TRUE
  )
})

test_that("PNAD Housing validation rejects failed reconciliation", {
  local_edition(3)
  dat <- clean_pnad_housing(
    make_pnad_housing_complete_raw("household_size"),
    "household_size"
  )
  broken <- dat$variable == "households" & dat$category == "one_resident"
  dat$value[broken] <- 100

  expect_error(
    validate_pnad_housing(dat, "household_size"),
    "category counts do not reconcile",
    fixed = TRUE
  )
})

test_that("PNAD Housing validation compares published and derived shares", {
  local_edition(3)
  dat <- clean_pnad_housing(
    make_pnad_housing_complete_raw("household_size"),
    "household_size"
  )
  first_geo <- dat$geography_type == "brazil"
  first_share <- first_geo &
    dat$variable == "household_share" &
    dat$category == "one_resident"
  second_share <- first_geo &
    dat$variable == "household_share" &
    dat$category == "two_residents"
  dat$value[first_share] <- dat$value[first_share] + 0.8
  dat$value[second_share] <- dat$value[second_share] - 0.8

  expect_error(
    validate_pnad_housing(dat, "household_size"),
    "published shares do not reconcile",
    fixed = TRUE
  )
})

test_that("PNAD Housing validation rejects a missing published domain", {
  local_edition(3)
  dat <- clean_pnad_housing(
    make_pnad_housing_complete_raw("mean_household_size"),
    "mean_household_size"
  )
  dat <- dat[dat$geography_type != "integrated_development_region", ]

  expect_error(
    validate_pnad_housing(dat, "mean_household_size"),
    "does not contain every published",
    fixed = TRUE
  )
})

test_that("PNAD Housing validation rejects a missing published period", {
  local_edition(3)
  dat <- clean_pnad_housing(
    make_pnad_housing_complete_raw("mean_household_size"),
    "mean_household_size"
  )
  attr(dat, "published_periods") <- c("2024", "2025")

  expect_error(
    validate_pnad_housing(dat, "mean_household_size"),
    "does not contain every published",
    fixed = TRUE
  )
})

test_that("pipeline validation exposes the PNAD source-contract result", {
  local_edition(3)
  pipeline_env <- new.env(parent = globalenv())
  sys.source(
    testthat::test_path("..", "..", "data-raw", "pipeline", "validation.R"),
    envir = pipeline_env
  )
  dat <- clean_pnad_housing(
    make_pnad_housing_complete_raw("household_size"),
    "household_size"
  )

  valid <- pipeline_env$validate_dataset(dat, "pnad_housing_household_size")
  expect_identical(valid$passed, TRUE)

  mean_dat <- clean_pnad_housing(
    make_pnad_housing_complete_raw("mean_household_size"),
    "mean_household_size"
  )
  mean_valid <- pipeline_env$validate_dataset(
    mean_dat,
    "pnad_housing_mean_household_size"
  )
  expect_identical(mean_valid$passed, TRUE)

  dat <- dplyr::bind_rows(dat, dat[1, ])
  expect_error(
    suppressMessages(
      pipeline_env$validate_dataset(dat, "pnad_housing_household_size")
    ),
    "PNAD Housing household_size data contains duplicate observation keys.",
    fixed = TRUE
  )
})

test_that("pipeline cache gate rejects failed validation", {
  local_edition(3)
  pipeline_env <- new.env(parent = globalenv())
  sys.source(
    testthat::test_path("..", "..", "data-raw", "pipeline", "validation.R"),
    envir = pipeline_env
  )
  invalid <- list(dataset = "pnad_housing_household_size", passed = FALSE)

  expect_error(
    pipeline_env$assert_validation_passed(invalid),
    'Validation failed for "pnad_housing_household_size"; cache was not[[:space:]]+written\\.'
  )
})

test_that("get_dataset dispatches PNAD Housing with the registry schema", {
  clear_session_cache()
  withr::defer(clear_session_cache())
  local_mocked_bindings(
    download_pnad_housing_table = function(table, quiet, max_retries) {
      make_pnad_housing_complete_raw(table)
    }
  )

  result <- get_dataset(
    "pnad_housing",
    table = "all",
    source = "fresh",
    quiet = TRUE
  )
  registry <- load_dataset_registry()$datasets$pnad_housing

  expect_named(result, names(pnad_housing_tables))
  for (tbl in names(result)) {
    expect_s3_class(result[[tbl]], "tbl_df")
    expect_named(result[[tbl]], names(registry$columns))
  }
})

test_that("PNAD Housing registry maps every selector to a cache asset", {
  registry <- load_dataset_registry()$datasets$pnad_housing
  expected <- paste0("pnad_housing_", names(pnad_housing_tables))
  actual <- vapply(
    names(pnad_housing_tables),
    \(table) get_cached_name("pnad_housing", registry, table),
    character(1)
  )

  expect_identical(
    actual,
    stats::setNames(expected, names(pnad_housing_tables))
  )
  expect_identical(registry$default_table, "tenure")
  expect_identical(registry$dataset_function, "get_pnad_housing")
})

test_that("PNAD Housing fresh download matches the live source contract", {
  skip_on_cran()
  skip_if_offline()

  result <- get_pnad_housing("all", quiet = TRUE)
  housing_years <- c(2016:2019, 2022:2025)
  geography_types <- unname(pnad_housing_geography_names)

  expect_named(result, names(pnad_housing_tables))
  for (table in setdiff(names(result), "household_composition")) {
    expect_identical(sort(unique(result[[table]]$year)), housing_years)
    expect_setequal(result[[table]]$geography_type, geography_types)
  }
  expect_identical(
    sort(unique(result$household_composition$year)),
    2012:2025
  )
  expect_setequal(
    result$household_composition$geography_type,
    geography_types
  )
})
