test_that("new architecture: list_datasets works", {
  
  # Test basic functionality
  datasets <- list_datasets()
  
  expect_s3_class(datasets, "data.frame")
  expect_true(nrow(datasets) > 0)
  expect_true("name" %in% names(datasets))
  expect_true("title" %in% names(datasets))
  expect_true("description" %in% names(datasets))
  
  # Test that priority datasets are included
  priority_datasets <- c("abecip", "abrainc", 
                         "bcb_realestate", "secovi", "bis_rppi")
  expect_true(all(priority_datasets %in% datasets$name))
})

test_that("new architecture: get_dataset_info works", {
  
  # Test with a known dataset
  info <- get_dataset_info("abecip")
  
  expect_type(info, "list")
  expect_true("metadata" %in% names(info))
  expect_true("categories" %in% names(info))
  expect_true("source_info" %in% names(info))
  
  # Test metadata structure
  expect_true("name" %in% names(info$metadata))
  expect_true("title" %in% names(info$metadata))
  expect_equal(info$metadata$name, "abecip")
})

test_that("new architecture: get_dataset requires table parameter for multi-table datasets", {
  
  skip_if_offline()
  
  # Multi-table dataset should require table parameter
  expect_error(
    get_dataset("abecip", source = "github"),
    "contains multiple tables"
  )
  
  # Should work when table is specified
  sbpe_data <- get_dataset("abecip", source = "github", table = "sbpe")
  
  expect_s3_class(sbpe_data, "data.frame")
  expect_true(nrow(sbpe_data) > 0)
  expect_true("date" %in% names(sbpe_data))
})

test_that("new architecture: get_dataset table filtering works", {
  
  skip_if_offline()
  
  # Test table filtering
  sbpe_data <- get_dataset("abecip", source = "github", table = "sbpe")
  
  expect_s3_class(sbpe_data, "data.frame")
  expect_true(nrow(sbpe_data) > 0)
  expect_true("date" %in% names(sbpe_data))
})

test_that("backward compatibility: legacy functions work", {
  
  skip_if_offline()
  
  # Test that legacy functions still work with cached=TRUE
  abecip_data <- get_abecip_indicators("sbpe", cached = TRUE)
  
  expect_s3_class(abecip_data, "data.frame")
  expect_true(nrow(abecip_data) > 0)
  expect_true("date" %in% names(abecip_data))
  
  # Test ABRAINC function
  abrainc_data <- get_abrainc_indicators("radar", cached = TRUE)
  
  expect_s3_class(abrainc_data, "data.frame")
  expect_true(nrow(abrainc_data) > 0)
})

test_that("error handling: invalid dataset name", {
  
  # Test invalid dataset name
  expect_error(
    get_dataset("nonexistent_dataset"),
    "Dataset 'nonexistent_dataset' not found"
  )
  
  expect_error(
    get_dataset_info("nonexistent_dataset"),
    "Dataset 'nonexistent_dataset' not found"
  )
})

test_that("error handling: invalid table", {
  
  skip_if_offline()
  
  # Test invalid table
  expect_error(
    get_dataset("abecip", source = "github", table = "invalid_table"),
    "Table 'invalid_table' not found"
  )
})

test_that("cache functions work", {
  
  # Test cache status
  cache_status <- check_cache_status()
  
  expect_s3_class(cache_status, "data.frame")
  expect_true("file" %in% names(cache_status))
  expect_true("size_mb" %in% names(cache_status))
  expect_true("modified" %in% names(cache_status))
})

test_that("translation system works", {
  
  skip_if_offline()
  
  # Test that data comes back translated
  data <- get_dataset("abecip", source = "github", table = "sbpe")
  
  # Check for English column names (not Portuguese)
  column_names <- names(data)
  
  # Should have English names, not Portuguese ones
  expect_true(any(grepl("date|stock|flow", column_names, ignore.case = TRUE)))
  
  # Should not have obvious Portuguese terms (though some might remain)
  expect_false(any(grepl("^data$|^valor$|^periodo$", column_names)))
})

# Helper function for offline testing
skip_if_offline <- function() {
  if (!pingr::is_online()) {
    testthat::skip("Offline")
  }
}