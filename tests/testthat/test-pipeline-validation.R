pipeline_validation_env <- function() {
  path <- testthat::test_path("..", "..", "data-raw", "pipeline")
  testthat::skip_if_not(file.exists(file.path(path, "validation.R")))
  env <- new.env(parent = globalenv())
  sys.source(file.path(path, "validation.R"), env)
  sys.source(file.path(path, "targets_helpers.R"), env)
  return(env)
}

test_that("pipeline required columns follow the current catalog", {
  env <- pipeline_validation_env()
  expect_identical(
    env$get_required_columns("bcb_series"),
    c("date", "code_bcb", "name_simplified", "value")
  )
  expect_identical(
    env$get_required_columns("bcb_realestate"),
    names(load_dataset_registry()$datasets$bcb_realestate$columns)
  )
  expect_identical(
    env$get_required_columns("abecip_units"),
    names(load_dataset_registry()$datasets$abecip$categories$units$columns)
  )
  expect_identical(
    env$get_required_columns("bis_selected"),
    names(load_dataset_registry()$datasets$rppi_bis$categories$selected$columns)
  )
})

test_that("malformed data cannot overwrite an existing cache", {
  env <- pipeline_validation_env()
  wrote <- FALSE
  env$save_dataset_to_cache <- function(...) {
    wrote <<- TRUE
  }
  invalid <- tibble::tibble(date = as.Date("2024-01-01"), value = 1)
  expect_error(env$save_to_cache(invalid, "bcb_series"), "Validation failed")
  expect_false(wrote)
})

test_that("valid historical negative and missing observations are preserved", {
  env <- pipeline_validation_env()
  dat <- tibble::tibble(
    date = as.Date(c("1982-01-01", "1982-02-01")),
    code_bcb = 1,
    name_simplified = "rate",
    value = c(-0.2, NA_real_)
  )
  validation <- env$validate_dataset(dat, "bcb_series")
  expect_true(validation$structural_passed)
  expect_no_error(env$assert_validation_passed(validation))
  saved <- NULL
  env$save_dataset_to_cache <- function(data, name) {
    saved <<- data
    "cache.rds"
  }
  expect_identical(env$save_to_cache(dat, "bcb_series"), "cache.rds")
  expect_identical(saved, dat)
})

test_that("missing and non-Date observation dates block cache writes", {
  env <- pipeline_validation_env()
  dat <- tibble::tibble(
    date = as.Date(NA),
    code_bcb = 1,
    name_simplified = "rate",
    value = 1
  )
  expect_error(env$save_to_cache(dat, "bcb_series"), "Validation failed")
  dat$date <- "not a date"
  expect_error(env$save_to_cache(dat, "bcb_series"), "Validation failed")
})

test_that("a materialized cache rejects lists instead of tables", {
  env <- pipeline_validation_env()
  expect_error(
    env$save_to_cache(list(series = 1), "bcb_series"),
    "Validation failed"
  )
})

test_that("unknown names and unsupported list children fail predictably", {
  env <- pipeline_validation_env()
  expect_null(env$get_required_columns("unknown_dataset"))
  expect_false(
    env$validate_dataset(list(series = 1), "abrainc")$structural_passed
  )
})
