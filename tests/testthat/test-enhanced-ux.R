test_that("enhanced user experience: informative error messages", {
  
  # Test dataset not found error message
  expect_error(
    get_dataset("nonexistent_dataset"),
    "Dataset 'nonexistent_dataset' not found"
  )
  
  # Test invalid dataset info error
  expect_error(
    get_dataset_info("nonexistent_dataset"),
    "Dataset 'nonexistent_dataset' not found"
  )
})

test_that("enhanced user experience: single table datasets work without table parameter", {
  
  skip_if_offline()
  
  # Test single-table datasets (these should work without table parameter)
  # Note: Using source="github" to test with cached data
  
  # b3_stocks should be single-table
  expect_no_error({
    stocks <- get_dataset("b3_stocks", source = "github")
  })
  
  # Should return a data.frame
  stocks <- get_dataset("b3_stocks", source = "github")
  expect_s3_class(stocks, "data.frame")
})

test_that("enhanced user experience: multi-table datasets provide helpful guidance", {
  
  skip_if_offline()
  
  # Multi-table dataset without table parameter should provide helpful error
  expect_error(
    get_dataset("abecip", source = "github"),
    regex = "contains multiple tables.*specify which table"
  )
  
  # Should suggest available tables and provide example
  expect_error(
    get_dataset("abecip", source = "github"), 
    regex = "Available tables.*Example"
  )
})

test_that("enhanced user experience: successful load messages", {
  
  skip_if_offline()
  
  # Should get informative success message
  expect_message(
    get_dataset("abecip", source = "github", table = "sbpe"),
    "✓ Loaded table 'sbpe'"
  )
  
  # Should mention other available tables
  expect_message(
    get_dataset("abecip", source = "github", table = "sbpe"),
    "Other available tables"
  )
})

# Helper function for offline testing
skip_if_offline <- function() {
  if (!pingr::is_online()) {
    testthat::skip("Offline")
  }
}