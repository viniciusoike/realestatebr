# Tests for Generic Dataset Helper Functions
# Created: 2025-10-15 (v0.6.0 Phase 3)

# ==============================================================================
# TEST SUITE 1: validate_dataset_params()
# ==============================================================================

test_that("validate_dataset_params() accepts valid parameters", {
  # Should pass with valid parameters
  expect_invisible(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe", "units", "cgi"),
      cached = FALSE,
      quiet = FALSE,
      max_retries = 3
    )
  )

  # Should accept "all" when allow_all = TRUE
  expect_invisible(
    validate_dataset_params(
      table = "all",
      valid_tables = c("sbpe", "units"),
      cached = TRUE,
      quiet = TRUE,
      max_retries = 5,
      allow_all = TRUE
    )
  )
})

test_that("validate_dataset_params() rejects invalid table parameter", {
  # Non-character table
  expect_error(
    validate_dataset_params(
      table = 123,
      valid_tables = c("sbpe"),
      cached = FALSE,
      quiet = FALSE,
      max_retries = 3
    ),
    "must be a single character string"
  )

  # Multiple values
  expect_error(
    validate_dataset_params(
      table = c("sbpe", "units"),
      valid_tables = c("sbpe", "units"),
      cached = FALSE,
      quiet = FALSE,
      max_retries = 3
    ),
    "must be a single character string"
  )

  # Invalid table name
  expect_error(
    validate_dataset_params(
      table = "invalid",
      valid_tables = c("sbpe", "units"),
      cached = FALSE,
      quiet = FALSE,
      max_retries = 3
    ),
    "Invalid table"
  )

  # "all" when allow_all = FALSE
  expect_error(
    validate_dataset_params(
      table = "all",
      valid_tables = c("sbpe", "units"),
      cached = FALSE,
      quiet = FALSE,
      max_retries = 3,
      allow_all = FALSE
    ),
    "Invalid table"
  )
})

test_that("validate_dataset_params() rejects invalid cached parameter", {
  expect_error(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe"),
      cached = "yes",
      quiet = FALSE,
      max_retries = 3
    ),
    "must be a logical value"
  )

  expect_error(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe"),
      cached = c(TRUE, FALSE),
      quiet = FALSE,
      max_retries = 3
    ),
    "must be a logical value"
  )
})

test_that("validate_dataset_params() rejects invalid quiet parameter", {
  expect_error(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe"),
      cached = FALSE,
      quiet = "no",
      max_retries = 3
    ),
    "must be a logical value"
  )
})

test_that("validate_dataset_params() rejects invalid max_retries parameter", {
  # Character
  expect_error(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe"),
      cached = FALSE,
      quiet = FALSE,
      max_retries = "3"
    ),
    "must be a positive integer"
  )

  # Negative
  expect_error(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe"),
      cached = FALSE,
      quiet = FALSE,
      max_retries = -1
    ),
    "must be a positive integer"
  )

  # Zero
  expect_error(
    validate_dataset_params(
      table = "sbpe",
      valid_tables = c("sbpe"),
      cached = FALSE,
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

  # Test "web"
  result_web <- attach_dataset_metadata(test_data, source = "web")
  expect_equal(attr(result_web, "source"), "web")

  # Test "cache"
  result_cache <- attach_dataset_metadata(test_data, source = "cache")
  expect_equal(attr(result_cache, "source"), "cache")

  # Test "github"
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

  result <- attach_dataset_metadata(test_data, source = "cache")

  info <- attr(result, "download_info")
  expect_equal(info$source, "cache")
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

# ==============================================================================
# TEST SUITE 4: download_with_retry()
# ==============================================================================

# NOTE: download_with_retry() is defined in R/rppi-helpers.R
# Tests for it are in test-rppi-helpers.R
# We reuse that existing implementation rather than creating our own
# The signature is: download_with_retry(fn, max_retries = 3, quiet = FALSE, desc = "Download")

# ==============================================================================
# TEST SUITE 5: validate_excel_file()
# ==============================================================================

test_that("validate_excel_file() detects missing file", {
  expect_error(
    validate_excel_file(
      "/nonexistent/file.xlsx",
      expected_sheets = c("Sheet1")
    ),
    "Excel file not found"
  )
})

test_that("validate_excel_file() checks file size", {
  # Create a very small temp file
  small_file <- tempfile(fileext = ".xlsx")
  writeLines("tiny", small_file)

  expect_error(
    validate_excel_file(
      small_file,
      expected_sheets = c("Sheet1"),
      min_size = 1000
    ),
    "too small or empty"
  )

  unlink(small_file)
})

# Note: Full Excel validation tests would require creating actual Excel files,
# which is complex in unit tests. These tests cover the basic validation logic.
# Integration tests will cover the full Excel reading workflow.

# ==============================================================================
# TEST SUITE 6: handle_dataset_cache() - Integration-style tests
# ==============================================================================

# Note: These tests require the actual cache infrastructure to be working.
# They're more integration tests than pure unit tests, but they're important
# for validating the cache handling logic.

test_that("handle_dataset_cache() returns NULL on cache miss with on_miss='return_null'", {
  # Test with a dataset that definitely doesn't exist
  result <- handle_dataset_cache(
    "nonexistent_dataset_12345",
    quiet = TRUE,
    on_miss = "return_null"
  )

  expect_null(result)
})

test_that("handle_dataset_cache() errors on cache miss with on_miss='error'", {
  expect_error(
    handle_dataset_cache(
      "nonexistent_dataset_12345",
      quiet = TRUE,
      on_miss = "error"
    ),
    "Cache miss"
  )
})

# ==============================================================================
# INTEGRATION TESTS: Test helpers work together
# ==============================================================================

test_that("helpers work together in typical workflow", {
  # Simulate a typical dataset function workflow

  # 1. Validate parameters
  expect_invisible(
    validate_dataset_params(
      table = "test_table",
      valid_tables = c("test_table", "other_table"),
      cached = FALSE,
      quiet = TRUE,
      max_retries = 3
    )
  )

  # 2. Create mock data
  test_data <- data.frame(
    date = seq.Date(as.Date("2020-01-01"), by = "month", length.out = 12),
    value = rnorm(12)
  )

  # 3. Validate data
  expect_invisible(
    validate_dataset(
      test_data,
      "test_dataset",
      required_cols = c("date", "value")
    )
  )

  # 4. Attach metadata
  result <- attach_dataset_metadata(
    test_data,
    source = "web",
    category = "test_table",
    extra_info = list(attempts = 1)
  )

  # 5. Verify all metadata is present
  expect_equal(attr(result, "source"), "web")
  expect_true(!is.null(attr(result, "download_time")))
  expect_equal(attr(result, "download_info")$category, "test_table")
  expect_equal(attr(result, "download_info")$attempts, 1)
})

# ==============================================================================
# EDGE CASE TESTS
# ==============================================================================

test_that("helpers handle edge cases correctly", {
  # Empty valid_tables should work
  expect_invisible(
    validate_dataset_params(
      table = "all",
      valid_tables = character(0),
      cached = FALSE,
      quiet = TRUE,
      max_retries = 1,
      allow_all = TRUE
    )
  )

  # Very large max_retries should work
  expect_invisible(
    validate_dataset_params(
      table = "test",
      valid_tables = "test",
      cached = FALSE,
      quiet = TRUE,
      max_retries = 1000
    )
  )

  # Tibble instead of data.frame should work
  test_tibble <- tibble::tibble(
    date = as.Date("2020-01-01"),
    value = 1
  )

  expect_invisible(
    validate_dataset(test_tibble, "test")
  )

  # Large dataset should work
  large_data <- data.frame(
    date = rep(as.Date("2020-01-01"), 10000),
    value = rnorm(10000)
  )

  expect_invisible(
    validate_dataset(large_data, "large_dataset", min_rows = 100)
  )
})
