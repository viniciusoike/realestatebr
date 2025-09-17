test_that("new architecture: list_datasets works", {
  
  # Test basic functionality
  datasets <- list_datasets()
  
  expect_s3_class(datasets, "data.frame")
  expect_true(nrow(datasets) > 0)
  expect_true("name" %in% names(datasets))
  expect_true("title" %in% names(datasets))
  expect_true("description" %in% names(datasets))
  
  # Test that priority datasets are included
  priority_datasets <- c("abecip_indicators", "abrainc_indicators", 
                         "bcb_realestate", "secovi", "bis_rppi")
  expect_true(all(priority_datasets %in% datasets$name))
})

test_that("new architecture: get_dataset_info works", {
  
  # Test with a known dataset
  info <- get_dataset_info("abecip_indicators")
  
  expect_type(info, "list")
  expect_true("metadata" %in% names(info))
  expect_true("categories" %in% names(info))
  expect_true("source_info" %in% names(info))
  
  # Test metadata structure
  expect_true("name" %in% names(info$metadata))
  expect_true("title" %in% names(info$metadata))
  expect_equal(info$metadata$name, "abecip_indicators")
})

test_that("new architecture: get_dataset works with GitHub cache", {
  
  skip_if_offline()
  
  # Test basic functionality
  data <- get_dataset("abecip_indicators", source = "github")
  
  expect_type(data, "list")
  expect_true(length(data) > 0)
  expect_true("sbpe" %in% names(data))
  expect_true("units" %in% names(data))
  expect_true("cgi" %in% names(data))
})

test_that("new architecture: get_dataset category filtering works", {
  
  skip_if_offline()
  
  # Test category filtering
  sbpe_data <- get_dataset("abecip_indicators", source = "github", category = "sbpe")
  
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

test_that("error handling: invalid category", {
  
  skip_if_offline()
  
  # Test invalid category
  expect_error(
    get_dataset("abecip_indicators", source = "github", category = "invalid_category"),
    "Category 'invalid_category' not found"
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
  data <- get_dataset("abecip_indicators", source = "github", category = "sbpe")
  
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