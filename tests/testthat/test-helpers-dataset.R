# Tests for Generic Dataset Helper Functions

# Parameter validation -------------------------------------------------------

test_that("validate_dataset_params() accepts valid parameters", {
  expect_invisible(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe", "units", "cgi"),
      quiet = FALSE,
      max_retries = 3
    )
  )

  expect_invisible(
    validate_dataset_params(
      table = "all",
      valid_tables = c("sbpe", "units"),
      quiet = TRUE,
      max_retries = 5,
      allow_all = TRUE
    )
  )
})

test_that("validate_dataset_params() rejects invalid table parameter", {
  expect_error(
    validate_dataset_params(
      table = 123,
      valid_tables = c("sbpe"),
      quiet = FALSE,
      max_retries = 3
    ),
    "must be a single character string"
  )

  expect_error(
    validate_dataset_params(
      table = c("sbpe", "units"),
      valid_tables = c("sbpe", "units"),
      quiet = FALSE,
      max_retries = 3
    ),
    "must be a single character string"
  )

  expect_error(
    validate_dataset_params(
      table = "invalid",
      valid_tables = c("sbpe", "units"),
      quiet = FALSE,
      max_retries = 3
    ),
    "Invalid table"
  )

  expect_error(
    validate_dataset_params(
      table = "all",
      valid_tables = c("sbpe", "units"),
      quiet = FALSE,
      max_retries = 3,
      allow_all = FALSE
    ),
    "Invalid table"
  )
})

test_that("validate_dataset_params() rejects invalid quiet parameter", {
  expect_error(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe"),
      quiet = "no",
      max_retries = 3
    ),
    "must be a logical value"
  )
})

test_that("validate_dataset_params() rejects invalid max_retries parameter", {
  expect_error(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe"),
      quiet = FALSE,
      max_retries = "3"
    ),
    "must be a positive integer"
  )

  expect_error(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe"),
      quiet = FALSE,
      max_retries = -1
    ),
    "must be a positive integer"
  )

  expect_error(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe"),
      quiet = FALSE,
      max_retries = 0
    ),
    "must be a positive integer"
  )
})

# ==============================================================================
# TEST SUITE 2: attach_dataset_metadata()
# ==============================================================================

test_that("attach_dataset_metadata() attaches correct metadata", {
  test_data <- data.frame(x = 1:5, y = letters[1:5])

  result <- attach_dataset_metadata(
    test_data,
    source = "web",
    category = "test_table"
  )

  # Check attributes exist
  expect_equal(attr(result, "source"), "web")
  expect_true(inherits(attr(result, "download_time"), "POSIXct"))
  expect_type(attr(result, "download_info"), "list")

  # Check download_info structure
  info <- attr(result, "download_info")
  expect_equal(info$source, "web")
  expect_equal(info$category, "test_table")
})

test_that("attach_dataset_metadata() accepts all valid sources", {
  test_data <- data.frame(x = 1:5)

  result_web <- attach_dataset_metadata(test_data, source = "web")
  expect_equal(attr(result_web, "source"), "web")

  result_github <- attach_dataset_metadata(test_data, source = "github")
  expect_equal(attr(result_github, "source"), "github")
})

test_that("attach_dataset_metadata() includes extra_info", {
  test_data <- data.frame(x = 1:5)

  result <- attach_dataset_metadata(
    test_data,
    source = "web",
    category = "test",
    extra_info = list(attempts = 2, url = "http://example.com")
  )

  info <- attr(result, "download_info")
  expect_equal(info$attempts, 2)
  expect_equal(info$url, "http://example.com")
  expect_equal(info$source, "web")
  expect_equal(info$category, "test")
})

test_that("attach_dataset_metadata() works without category", {
  test_data <- data.frame(x = 1:5)

  result <- attach_dataset_metadata(test_data, source = "github")

  info <- attr(result, "download_info")
  expect_equal(info$source, "github")
  expect_false("category" %in% names(info))
})

test_that("attach_dataset_metadata() rejects invalid source", {
  test_data <- data.frame(x = 1:5)

  expect_error(
    attach_dataset_metadata(test_data, source = "invalid"),
    "'arg' should be one of"
  )
})

# ==============================================================================
# TEST SUITE 3: validate_dataset()
# ==============================================================================

test_that("validate_dataset() accepts valid data", {
  test_data <- data.frame(
    date = seq.Date(as.Date("2020-01-01"), by = "month", length.out = 12),
    value = rnorm(12)
  )

  expect_invisible(
    validate_dataset(test_data, "test_dataset")
  )
})

test_that("validate_dataset() checks for empty data", {
  empty_data <- data.frame(date = as.Date(character()), value = numeric())

  expect_error(
    validate_dataset(empty_data, "test_dataset"),
    "data is empty"
  )
})

test_that("validate_dataset() checks minimum rows", {
  small_data <- data.frame(
    date = as.Date("2020-01-01"),
    value = 1
  )

  # Should warn when below minimum
  expect_warning(
    validate_dataset(small_data, "test_dataset", min_rows = 10),
    "has only 1 row"
  )

  # Should not warn when meeting minimum
  expect_invisible(
    validate_dataset(small_data, "test_dataset", min_rows = 1)
  )
})

test_that("validate_dataset() checks for required columns", {
  test_data <- data.frame(
    date = as.Date("2020-01-01"),
    value = 1
  )

  # Should pass with present columns
  expect_invisible(
    validate_dataset(test_data, "test_dataset", required_cols = c("date", "value"))
  )

  # Should error with missing columns
  expect_error(
    validate_dataset(test_data, "test_dataset", required_cols = c("date", "missing_col")),
    "Missing required columns"
  )
})

test_that("validate_dataset() validates dates", {
  # Valid dates
  valid_data <- data.frame(
    date = seq.Date(as.Date("2020-01-01"), by = "month", length.out = 12),
    value = rnorm(12)
  )

  expect_invisible(
    validate_dataset(valid_data, "test_dataset", check_dates = TRUE)
  )

  # Invalid dates (NA)
  invalid_data <- data.frame(
    date = c(as.Date("2020-01-01"), as.Date(NA)),
    value = c(1, 2)
  )

  expect_error(
    validate_dataset(invalid_data, "test_dataset", check_dates = TRUE),
    "Invalid dates"
  )
})

test_that("validate_dataset() warns about future dates", {
  # Dates far in future
  future_data <- data.frame(
    date = c(Sys.Date(), Sys.Date() + 200),
    value = c(1, 2)
  )

  expect_warning(
    validate_dataset(future_data, "test_dataset", check_dates = TRUE, max_future_days = 90),
    "more than 90 days in future"
  )

  # Dates within acceptable future range
  near_future_data <- data.frame(
    date = c(Sys.Date(), Sys.Date() + 30),
    value = c(1, 2)
  )

  expect_invisible(
    validate_dataset(near_future_data, "test_dataset", check_dates = TRUE, max_future_days = 90)
  )
})

test_that("validate_dataset() can skip date checking", {
  # Data without date column
  no_date_data <- data.frame(
    year = 2020:2022,
    value = rnorm(3)
  )

  expect_invisible(
    validate_dataset(
      no_date_data,
      "test_dataset",
      required_cols = "year",
      check_dates = FALSE
    )
  )
})

# Integration -----------------------------------------------------------------

test_that("helpers work together in typical workflow", {
  expect_invisible(
    validate_dataset_params(
      table = "test_table",
      valid_tables = c("test_table", "other_table"),
      quiet = TRUE,
      max_retries = 3
    )
  )

  test_data <- data.frame(
    date = seq.Date(as.Date("2020-01-01"), by = "month", length.out = 12),
    value = rnorm(12)
  )

  expect_invisible(
    validate_dataset(
      test_data,
      "test_dataset",
      required_cols = c("date", "value")
    )
  )

  result <- attach_dataset_metadata(
    test_data,
    source = "web",
    category = "test_table",
    extra_info = list(attempts = 1)
  )

  expect_equal(attr(result, "source"), "web")
  expect_true(!is.null(attr(result, "download_time")))
  expect_equal(attr(result, "download_info")$category, "test_table")
  expect_equal(attr(result, "download_info")$attempts, 1)
})

# Edge cases ------------------------------------------------------------------

test_that("helpers handle edge cases correctly", {
  expect_invisible(
    validate_dataset_params(
      table = "all",
      valid_tables = character(0),
      quiet = TRUE,
      max_retries = 1,
      allow_all = TRUE
    )
  )

  expect_invisible(
    validate_dataset_params(
      table = "test",
      valid_tables = "test",
      quiet = TRUE,
      max_retries = 1000
    )
  )

  test_tibble <- tibble::tibble(
    date = as.Date("2020-01-01"),
    value = 1
  )

  expect_invisible(
    validate_dataset(test_tibble, "test")
  )

  large_data <- data.frame(
    date = rep(as.Date("2020-01-01"), 10000),
    value = rnorm(10000)
  )

  expect_invisible(
    validate_dataset(large_data, "large_dataset", min_rows = 100)
  )
})
