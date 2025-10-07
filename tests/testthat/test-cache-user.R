test_that("get_user_cache_dir returns a valid path", {
  cache_dir <- get_user_cache_dir()

  expect_type(cache_dir, "character")
  expect_true(nchar(cache_dir) > 0)
  expect_true(grepl("realestatebr", cache_dir, ignore.case = TRUE))
})

test_that("ensure_cache_dir creates directory", {
  cache_dir <- ensure_cache_dir()

  expect_true(dir.exists(cache_dir))
})

test_that("save and load from user cache works", {
  skip_if_not_installed("tibble")

  # Create test data
  test_data <- tibble::tibble(
    x = 1:5,
    y = letters[1:5]
  )

  # Save to cache
  result <- save_to_user_cache(test_data, "test_dataset", format = "rds", quiet = TRUE)
  expect_true(result)

  # Load from cache
  loaded_data <- load_from_user_cache("test_dataset", quiet = TRUE)
  expect_equal(loaded_data, test_data)

  # Clean up
  clear_user_cache("test_dataset", confirm = FALSE)
})

test_that("is_cached correctly identifies cached datasets", {
  skip_if_not_installed("tibble")

  # Create and save test data
  test_data <- tibble::tibble(x = 1:3)
  save_to_user_cache(test_data, "test_is_cached", format = "rds", quiet = TRUE)

  expect_true(is_cached("test_is_cached"))
  expect_false(is_cached("nonexistent_dataset"))

  # Clean up
  clear_user_cache("test_is_cached", confirm = FALSE)
})

test_that("list_cached_files returns tibble", {
  result <- list_cached_files()

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("dataset", "format", "size_mb", "modified"))
})

test_that("clear_user_cache removes datasets", {
  skip_if_not_installed("tibble")

  # Create test data
  test_data <- tibble::tibble(x = 1:3)
  save_to_user_cache(test_data, "test_clear", format = "rds", quiet = TRUE)

  # Verify it exists
  expect_true(is_cached("test_clear"))

  # Clear without confirmation
  result <- clear_user_cache("test_clear", confirm = FALSE)
  expect_true(result)

  # Verify it's gone
  expect_false(is_cached("test_clear"))
})

test_that("load_from_user_cache returns NULL for non-existent dataset", {
  result <- load_from_user_cache("definitely_does_not_exist_12345", quiet = TRUE)
  expect_null(result)
})

test_that("save_to_user_cache handles CSV format", {
  skip_if_not_installed("tibble")
  skip_if_not_installed("readr")

  # Create test data
  test_data <- tibble::tibble(
    x = 1:5,
    y = letters[1:5]
  )

  # Save as CSV
  result <- save_to_user_cache(test_data, "test_csv", format = "csv.gz", quiet = TRUE)
  expect_true(result)

  # Load from cache
  loaded_data <- load_from_user_cache("test_csv", quiet = TRUE)
  expect_s3_class(loaded_data, "tbl_df")
  expect_equal(nrow(loaded_data), 5)

  # Clean up
  clear_user_cache("test_csv", confirm = FALSE)
})

test_that("cache metadata is saved and retrieved", {
  skip_if_not_installed("tibble")

  # Create and save test data
  test_data <- tibble::tibble(x = 1:3)
  save_to_user_cache(test_data, "test_metadata", format = "rds", quiet = TRUE)

  # Get metadata
  metadata <- get_cache_metadata("test_metadata")

  expect_type(metadata, "list")
  expect_true("format" %in% names(metadata))
  expect_true("cached_at" %in% names(metadata))
  expect_equal(metadata$format, "rds")

  # Clean up
  clear_user_cache("test_metadata", confirm = FALSE)
})

test_that("get_cached_file_path returns correct path", {
  skip_if_not_installed("tibble")

  # Create test data
  test_data <- tibble::tibble(x = 1:3)
  save_to_user_cache(test_data, "test_path", format = "rds", quiet = TRUE)

  # Get path
  file_path <- get_cached_file_path("test_path")

  expect_type(file_path, "character")
  expect_true(file.exists(file_path))
  expect_true(grepl("test_path\\.rds$", file_path))

  # Clean up
  clear_user_cache("test_path", confirm = FALSE)
})

test_that("load_from_user_cache handles corrupted files gracefully", {
  # Create a corrupted file
  cache_dir <- ensure_cache_dir()
  corrupted_file <- file.path(cache_dir, "corrupted_test.rds")
  writeLines("this is not valid RDS data", corrupted_file)

  # Try to load
  result <- load_from_user_cache("corrupted_test", quiet = TRUE)

  expect_null(result)

  # Clean up
  file.remove(corrupted_file)
})
