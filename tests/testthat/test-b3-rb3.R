test_that("rb3-based B3 stocks function works", {
  skip_if_offline()
  
  # Test basic functionality with cached data first
  expect_no_error({
    stocks <- get_b3_stocks(cached = TRUE, quiet = TRUE)
  })
  
  # Test that the function still accepts legacy parameters with warnings
  expect_warning({
    stocks <- get_b3_stocks(cached = TRUE, src = "yahoo", quiet = TRUE)
  }, "deprecated")
  
  # Test that the function still accepts category parameter with warnings  
  expect_warning({
    stocks <- get_b3_stocks(cached = TRUE, category = "stocks", quiet = TRUE)
  }, "deprecated")
})

test_that("rb3 internal functions are available", {
  # Test that our internal functions exist
  expect_true(exists("fetch_b3_stocks_rb3"))
  expect_true(exists("setup_rb3_environment"))
})

test_that("B3 data structure is preserved", {
  skip_if_offline()
  
  # Get cached data and check structure
  stocks <- get_b3_stocks(cached = TRUE, quiet = TRUE)
  
  # Check basic structure
  expect_s3_class(stocks, "data.frame")
  expect_true(nrow(stocks) > 0)
  
  # Check required columns are present (may vary depending on implementation)
  expected_cols <- c("date", "symbol")
  expect_true(all(expected_cols %in% names(stocks)))
  
  # Check metadata attributes
  expect_true("source" %in% names(attributes(stocks)))
  expect_true("download_info" %in% names(attributes(stocks)))
  
  # Check that source reflects rb3 usage in fresh downloads
  download_info <- attr(stocks, "download_info")
  if (!is.null(download_info) && "source" %in% names(download_info)) {
    expect_true(download_info$source %in% c("cache", "rb3"))
  }
})

# Helper function for offline testing
skip_if_offline <- function() {
  if (!requireNamespace("pingr", quietly = TRUE)) {
    testthat::skip("pingr not available")
  }
  if (!pingr::is_online()) {
    testthat::skip("Offline")
  }
}