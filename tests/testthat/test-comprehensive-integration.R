test_that("comprehensive integration: new API works end-to-end", {
  
  # Test 1: Dataset registry loading
  expect_no_error({
    datasets <- list_datasets()
  })
  
  datasets <- list_datasets()
  expect_s3_class(datasets, "data.frame")
  expect_true(nrow(datasets) > 0)
  expect_true("name" %in% names(datasets))
  
  # Test 2: Core datasets are available with correct names
  expected_datasets <- c("abecip", "abrainc", "bcb_realestate", "secovi", "bis_rppi", "b3_stocks")
  expect_true(all(expected_datasets %in% datasets$name))
  
  # Test 3: Dataset info works
  expect_no_error({
    info <- get_dataset_info("abecip")
  })
  
  info <- get_dataset_info("abecip")
  expect_type(info, "list")
  expect_true("metadata" %in% names(info))
  expect_true("categories" %in% names(info))
  
  # Test 4: Multi-table dataset validation
  expect_error(
    get_dataset("abecip"),
    regex = "contains multiple tables.*specify which table"
  )
  
  # Test 5: Invalid dataset name handling
  expect_error(
    get_dataset("nonexistent_dataset"),
    regex = "Dataset 'nonexistent_dataset' not found"
  )
  
  # Test 6: Invalid table name handling (if we can test with mock data)
  # This would require a working data source, so skip for now
  
  # Test 7: Check cache status function works
  expect_no_error({
    cache_status <- check_cache_status()
  })
  
  cache_status <- check_cache_status()
  expect_s3_class(cache_status, "data.frame")
})

test_that("integration: dataset registry structure is valid", {
  
  # Load registry directly
  registry_path <- system.file("extdata", "datasets.yaml", package = "realestatebr")
  
  # If package isn't installed, try local path
  if (registry_path == "") {
    registry_path <- "inst/extdata/datasets.yaml"
  }
  
  # Skip if file doesn't exist (for CI environments without package structure)
  skip_if_not(file.exists(registry_path), "Registry file not found")
  
  expect_no_error({
    registry <- yaml::read_yaml(registry_path)
  })
  
  registry <- yaml::read_yaml(registry_path) 
  
  # Test registry structure
  expect_true("datasets" %in% names(registry))
  expect_type(registry$datasets, "list")
  expect_true(length(registry$datasets) > 0)
  
  # Test that key datasets have proper structure
  abecip <- registry$datasets$abecip
  expect_true(!is.null(abecip))
  expect_true("name" %in% names(abecip))
  expect_true("categories" %in% names(abecip))
  expect_type(abecip$categories, "list")
  
  # Test single-table dataset structure  
  b3_stocks <- registry$datasets$b3_stocks
  expect_true(!is.null(b3_stocks))
  expect_true("name" %in% names(b3_stocks))
  # Single-table datasets should not have categories
  expect_true(is.null(b3_stocks$categories))
})