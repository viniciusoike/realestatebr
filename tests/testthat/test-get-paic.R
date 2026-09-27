make_paic_raw <- function(
  table,
  variable_id,
  unit,
  category_code = NULL,
  category_name = "Category",
  periods = "2024",
  geography_level = "N1",
  geography_code = "1",
  geography_name = "Brasil",
  values = "100"
) {
  n <- max(
    length(variable_id),
    length(periods),
    length(values),
    length(geography_code)
  )
  recycle <- function(x) rep_len(x, n)

  dat <- tibble::tibble(
    aggregate_id = as.character(table),
    variable_id = recycle(variable_id),
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

  if (!is.null(category_code)) {
    classification_col <- switch(
      as.character(table),
      "10463" = "classification_12296_code",
      "10441" = "classification_319_code"
    )
    name_col <- switch(
      as.character(table),
      "10463" = "classification_12296_name",
      "10441" = "classification_319_name"
    )
    dat[[classification_col]] <- recycle(category_code)
    dat[[name_col]] <- recycle(category_name)
  }

  return(dat)
}

# Raw SIDRA response for table 10442, 2024, all variables at N1, N2, and N3
# (retrieved 2026-09-27).
read_paic_state_fixture <- function() {
  path <- testthat::test_path("fixtures", "paic_10442_2024.json")
  json <- jsonlite::fromJSON(path, simplifyVector = FALSE)

  return(parse_ibge_aggregate_chunk(json, 10442L))
}

# Synthetic raw response covering every expected key. Activity totals equal
# the sum of the three size-band subtotals; state cells in the size table's
# total and 1-4 bands carry SIDRA's "-" as the live API does.
make_paic_complete_raw <- function(table) {
  if (table == "activity") {
    grid <- tidyr::expand_grid(
      variable_id = paic_activity_variables,
      category_code = paic_activity_categories$category_id
    )
    grid$values <- ifelse(grid$category_code == "105185", "3", "1")
    return(make_paic_raw(
      table = 10463,
      variable_id = grid$variable_id,
      unit = unname(paic_variable_units[grid$variable_id]),
      category_code = grid$category_code,
      values = grid$values
    ))
  }

  geographies <- tibble::tibble(
    level = c("N1", rep("N2", 5), rep("N3", length(paic_state_codes))),
    code = c("1", as.character(1:5), paic_state_codes)
  )
  grid <- tidyr::expand_grid(
    variable_id = paic_size_variables,
    category_code = names(paic_size_categories),
    geographies
  )
  grid$values <- ifelse(
    grid$level == "N3" & grid$category_code != "104030",
    "-",
    "10"
  )

  return(make_paic_raw(
    table = 10441,
    variable_id = grid$variable_id,
    unit = unname(paic_variable_units[grid$variable_id]),
    category_code = grid$category_code,
    geography_level = grid$level,
    geography_code = grid$code,
    geography_name = grid$code,
    values = grid$values
  ))
}

test_that("PAIC derives value_status from SIDRA symbols", {
  expect_equal(
    paic_value_status(c("10", "-", "..", "...", "X", "X ", NA, "")),
    c(
      "observed",
      "zero",
      "not_applicable",
      "not_available",
      "suppressed",
      "suppressed",
      "missing",
      "missing"
    )
  )
})

test_that("PAIC base keeps observed values in original units", {
  raw <- make_paic_raw(
    table = 10442,
    variable_id = c("631", "673"),
    unit = c("Pessoas", "Mil Reais"),
    geography_level = "N1",
    values = c("2181647", "100")
  )

  result <- clean_paic_base(raw, expected_table = 10442L)

  expect_equal(result$year, c(2024L, 2024L))
  expect_equal(result$source_table, c(10442L, 10442L))
  expect_equal(result$variable, c("employment", "wages"))
  expect_equal(result$unit, c("Pessoas", "Mil Reais"))
  expect_equal(result$value_status, c("observed", "observed"))
})

test_that("PAIC rejects unknown upstream variable IDs", {
  local_edition(3)
  raw <- make_paic_raw(
    table = 10442,
    variable_id = "99999",
    unit = "Pessoas"
  )

  expect_snapshot(error = TRUE, clean_paic_base(raw, 10442L))
})

test_that("PAIC rejects unexpected units", {
  local_edition(3)
  raw <- make_paic_raw(
    table = 10442,
    variable_id = "631",
    unit = "Mil Reais"
  )

  expect_snapshot(error = TRUE, clean_paic_base(raw, 10442L))
})

test_that("PAIC activity parses size and CNAE hierarchy from the crosswalk", {
  raw <- make_paic_raw(
    table = 10463,
    variable_id = "631",
    unit = "Pessoas",
    category_code = c("105185", "8415", "8419", "8431", "30084", "8458"),
    values = c("2503478", "143812", "100", "200", "300", "400")
  )

  result <- clean_paic_activity(raw)

  # Rows arrange by year, variable, size band, and activity code.
  expect_equal(
    result$size_band,
    c("1_4", "30_plus", "30_plus", "30_plus", "5_29", "total")
  )
  expect_equal(
    result$activity_code,
    c("41", "41.10", "43.3", "43.30", "41.1", NA)
  )
  expect_equal(
    result$activity_level,
    c("division", "class", "group", "class", "group", "total")
  )
  expect_equal(result$division_code, c("41", "41", "43", "43", "41", NA))
  expect_equal(
    result$group_code,
    c(NA, "41.1", "43.3", "43.3", "41.1", NA)
  )
  expect_equal(
    result$activity_name,
    c(
      "Construção de edifícios",
      "Incorporação de empreendimentos imobiliários",
      "Obras de acabamento",
      "Obras de acabamento",
      "Incorporação de empreendimentos imobiliários",
      NA
    )
  )
})

test_that("PAIC activity rejects unknown category IDs", {
  local_edition(3)
  raw <- make_paic_raw(
    table = 10463,
    variable_id = "631",
    unit = "Pessoas",
    category_code = "999999"
  )

  expect_snapshot(error = TRUE, clean_paic_activity(raw))
})

test_that("PAIC size keeps level variables with three size bands", {
  raw <- make_paic_raw(
    table = 10441,
    variable_id = "410",
    unit = "Unidades",
    category_code = c("104029", "111261", "104030"),
    values = c("191026", "120948", "70078")
  )

  result <- clean_paic_size(raw)

  expect_equal(result$size_band, c("1_4", "5_plus", "total"))
  expect_equal(result$value, c(120948, 70078, 191026))
  expect_equal(result$variable, rep("firms", 3))
  expect_named(
    result,
    c(
      "year",
      "source_table",
      "geography_type",
      "geography_code",
      "geography_name",
      "size_band",
      "variable_id",
      "variable",
      "variable_name_pt",
      "unit",
      "value",
      "value_raw",
      "value_status"
    )
  )
})

test_that("PAIC size drops share variables", {
  raw <- dplyr::bind_rows(
    make_paic_raw(
      table = 10441,
      variable_id = "410",
      unit = "Unidades",
      category_code = "104029",
      values = "191026"
    ),
    tibble::tibble(
      aggregate_id = "10441",
      variable_id = "1000410",
      variable_name = "Share",
      unit = "%",
      period = "2024",
      geography_level = "N1",
      geography_level_name = "Level",
      geography_code = "1",
      geography_name = "Brasil",
      value_raw = "63.3",
      value = 63.3,
      classification_319_code = "104029",
      classification_319_name = "Total"
    )
  )

  result <- clean_paic_size(raw)

  expect_equal(nrow(result), 1L)
  expect_equal(result$variable_id, "410")
})

test_that("PAIC state records geography basis per variable", {
  raw <- make_paic_raw(
    table = 10442,
    variable_id = c("13807", "13808", "631"),
    unit = c("Unidades", "Unidades", "Pessoas"),
    geography_level = "N3",
    geography_code = "33",
    geography_name = "Rio de Janeiro",
    values = c("4232", "4564", "100")
  )

  result <- clean_paic_state(raw)

  expect_equal(
    result$geography_basis,
    c("headquarters", "work_location", "work_location")
  )
  expect_equal(result$geography_type, rep("state", 3))
})

test_that("PAIC keys include the geography level", {
  # IBGE codes collide across levels (Brazil and Norte are both "1").
  raw <- dplyr::bind_rows(
    make_paic_raw(
      table = 10442,
      variable_id = c("13807", "13807", "631", "631"),
      unit = c("Unidades", "Unidades", "Pessoas", "Pessoas"),
      geography_level = c("N1", "N2", "N1", "N2"),
      geography_code = "1",
      geography_name = c("Brasil", "Norte", "Brasil", "Norte"),
      values = c("15000", "500", "2181647", "130268")
    )
  )

  result <- clean_paic_state(raw)

  expect_equal(
    result$geography_type,
    c("brazil", "brazil", "region", "region")
  )
  expect_equal(
    result$variable_id,
    c("13807", "631", "13807", "631")
  )
})

test_that("PAIC state matches published SIDRA figures", {
  dat <- clean_paic_state(read_paic_state_fixture())

  expect_no_error(validate_paic_state(dat))

  employment <- dat[dat$variable_id == "631", ]
  national <- employment$value[employment$geography_type == "brazil"]
  states <- employment[employment$geography_type == "state", ]

  expect_equal(national, 2181647)
  expect_equal(nrow(states), 27L)
  expect_equal(sum(states$value), national)
})

test_that("PAIC state validation rejects a missing state", {
  local_edition(3)
  dat <- clean_paic_state(read_paic_state_fixture())
  dat <- dat[!(dat$geography_type == "state" & dat$geography_code == "35"), ]

  expect_snapshot(error = TRUE, validate_paic_state(dat))
})

test_that("PAIC validation rejects duplicate keys", {
  local_edition(3)
  dat <- clean_paic_state(read_paic_state_fixture())
  dat <- dplyr::bind_rows(dat, dat[1, ])

  expect_snapshot(error = TRUE, validate_paic_state(dat))
})

test_that("PAIC validation enforces the headquarters basis for 13807", {
  local_edition(3)
  dat <- clean_paic_state(read_paic_state_fixture())
  dat$geography_basis[dat$variable_id == "13807"] <- "work_location"

  expect_snapshot(error = TRUE, validate_paic_state(dat))
})

test_that("PAIC size drops unpublished state cells", {
  # SIDRA publishes state figures in table 10441 for firms with five or
  # more workers only; "-" in the state total and 1-4 bands is not a zero.
  raw <- make_paic_raw(
    table = 10441,
    variable_id = "410",
    unit = "Unidades",
    category_code = c("104029", "111261", "104030", "104029"),
    geography_level = c("N3", "N3", "N3", "N2"),
    geography_code = c("35", "35", "35", "3"),
    geography_name = c("São Paulo", "São Paulo", "São Paulo", "Sudeste"),
    values = c("-", "-", "20878", "94818")
  )

  result <- clean_paic_size(raw)

  expect_equal(result$geography_type, c("region", "state"))
  expect_equal(result$size_band, c("total", "5_plus"))
  expect_equal(result$value, c(94818, 20878))
})

test_that("PAIC size validation accepts complete data", {
  dat <- clean_paic_size(make_paic_complete_raw("size"))

  expect_no_error(validate_paic_size(dat))
  expect_setequal(dat$size_band[dat$geography_type == "state"], "5_plus")
})

test_that("PAIC size validation rejects state rows outside the 5+ band", {
  local_edition(3)
  dat <- clean_paic_size(make_paic_complete_raw("size"))
  extra <- dat[dat$geography_type == "state", ][1, ]
  extra$size_band <- "total"
  dat <- dplyr::bind_rows(dat, extra)

  expect_snapshot(error = TRUE, validate_paic_size(dat))
})

test_that("PAIC activity validation accepts consistent size bands", {
  dat <- clean_paic_activity(make_paic_complete_raw("activity"))

  expect_no_error(validate_paic_activity(dat))
})

test_that("PAIC activity validation rejects inconsistent size bands", {
  local_edition(3)
  dat <- clean_paic_activity(make_paic_complete_raw("activity"))
  broken <- dat$variable_id == "631" &
    dat$activity_level == "total" &
    dat$size_band == "5_29"
  dat$value[broken] <- 5

  expect_snapshot(error = TRUE, validate_paic_activity(dat))
})

test_that("PAIC cleaners reject malformed responses", {
  local_edition(3)
  empty <- make_paic_raw(table = 10442, variable_id = "631", unit = "Pessoas")
  empty <- empty[0, ]
  wrong_table <- make_paic_raw(
    table = 10441,
    variable_id = "631",
    unit = "Pessoas"
  )
  no_geography <- make_paic_raw(
    table = 10442,
    variable_id = "631",
    unit = "Pessoas",
    geography_code = NA_character_
  )
  bad_level <- make_paic_raw(
    table = 10442,
    variable_id = "631",
    unit = "Pessoas",
    geography_level = "N6"
  )
  no_unit <- make_paic_raw(table = 10442, variable_id = "631", unit = "")
  no_classification <- make_paic_raw(
    table = 10463,
    variable_id = "631",
    unit = "Pessoas"
  )
  bad_size <- make_paic_raw(
    table = 10441,
    variable_id = "410",
    unit = "Unidades",
    category_code = "999999"
  )

  expect_snapshot(error = TRUE, clean_paic_base(empty, 10442L))
  expect_snapshot(error = TRUE, clean_paic_base(wrong_table, 10442L))
  expect_snapshot(error = TRUE, clean_paic_base(no_geography, 10442L))
  expect_snapshot(error = TRUE, clean_paic_base(bad_level, 10442L))
  expect_snapshot(error = TRUE, clean_paic_base(no_unit, 10442L))
  expect_snapshot(error = TRUE, clean_paic_activity(no_classification))
  expect_snapshot(error = TRUE, clean_paic_size(bad_size))
})

test_that("get_dataset dispatches PAIC tables with the registry schema", {
  local_edition(3)
  clear_session_cache()
  withr::defer(clear_session_cache())
  local_mocked_bindings(
    download_paic_table = function(table, quiet, max_retries) {
      switch(
        table,
        "activity" = make_paic_complete_raw("activity"),
        "size" = make_paic_complete_raw("size"),
        "state" = read_paic_state_fixture()
      )
    }
  )

  result <- get_dataset("paic", table = "all", source = "fresh", quiet = TRUE)
  columns <- load_dataset_registry()$datasets$paic$categories

  expect_named(result, c("activity", "size", "state"))
  for (tbl in names(result)) {
    expect_s3_class(result[[tbl]], "tbl_df")
    expect_named(result[[tbl]], names(columns[[tbl]]$columns))
  }

  clear_session_cache()
  state <- get_dataset(
    "paic",
    table = "state",
    source = "fresh",
    quiet = TRUE
  )
  expect_equal(state, result$state, ignore_attr = TRUE)
})

test_that("PAIC fresh download matches the registry schema", {
  skip_on_cran()
  skip_if_offline()

  result <- get_paic("all", quiet = TRUE)
  columns <- load_dataset_registry()$datasets$paic$categories

  expect_named(result, c("activity", "size", "state"))
  for (tbl in names(result)) {
    expect_named(result[[tbl]], names(columns[[tbl]]$columns))
  }
  employment <- result$state[
    result$state$variable_id == "631" &
      result$state$geography_type == "brazil" &
      result$state$year == 2024L,
  ]
  expect_equal(employment$value, 2181647)
})

test_that("PAIC registry documents three tables with activity as default", {
  registry <- load_dataset_registry()
  paic <- registry$datasets$paic

  expect_equal(paic$default_table, "activity")
  expect_equal(sort(names(paic$categories)), c("activity", "size", "state"))
  expect_equal(paic$dataset_function, "get_paic")
})
