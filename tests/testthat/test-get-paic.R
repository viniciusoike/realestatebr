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
    value = suppressWarnings(as.numeric(recycle(values)))
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

test_that("PAIC activity size bands sum to the all-firm total", {
  # National division total is the sum of the three size bands; only
  # "Total das empresas" covers all firms.
  raw <- make_paic_raw(
    table = 10463,
    variable_id = "631",
    unit = "Pessoas",
    category_code = c("105185", "8415", "8418", "8432"),
    values = c("1000", "100", "300", "600")
  )

  result <- clean_paic_activity(raw)
  total <- result$value[result$size_band == "total"]
  bands <- sum(result$value[result$size_band != "total"])

  expect_equal(total, bands)
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

  result <- suppressWarnings(clean_paic_state(raw))

  expect_equal(
    result$geography_type,
    c("brazil", "brazil", "region", "region")
  )
  expect_equal(
    result$variable_id,
    c("13807", "631", "13807", "631")
  )
  expect_no_error(suppressWarnings(validate_paic_state(result)))
})

test_that("PAIC validation rejects duplicate keys", {
  local_edition(3)
  raw <- make_paic_raw(
    table = 10442,
    variable_id = c("631", "631"),
    unit = "Pessoas",
    values = c("100", "200")
  )
  dat <- suppressWarnings(clean_paic_state(raw))

  expect_snapshot(error = TRUE, suppressWarnings(validate_paic_state(dat)))
})

test_that("PAIC validation enforces the headquarters basis for 13807", {
  local_edition(3)
  raw <- make_paic_raw(
    table = 10442,
    variable_id = "13807",
    unit = "Unidades",
    values = "4232"
  )
  dat <- suppressWarnings(clean_paic_state(raw))
  dat$geography_basis <- "work_location"

  expect_snapshot(error = TRUE, suppressWarnings(validate_paic_state(dat)))
})

test_that("PAIC registry documents three tables with activity as default", {
  registry <- load_dataset_registry()
  paic <- registry$datasets$paic

  expect_equal(paic$default_table, "activity")
  expect_equal(sort(names(paic$categories)), c("activity", "size", "state"))
  expect_equal(paic$dataset_function, "get_paic")
})
