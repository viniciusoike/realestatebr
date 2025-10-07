# Integration Tests for get_dataset()
# These tests verify that get_dataset() works correctly with real data sources
# and catches regressions that devtools::check() might miss.

# Skip on CRAN since these tests require network access
skip_on_cran <- function() {
  skip_if(
    !identical(Sys.getenv("NOT_CRAN"), "true"),
    "Skipping integration tests on CRAN"
  )
}

# Helper to check if data is a single tibble (not a list)
is_single_tibble <- function(x) {
  inherits(x, "data.frame") &&
    !is.list(x) ||
    (inherits(x, "data.frame") && length(x) > 0)
}

# RPPI BIS Tests
test_that("rppi_bis with fresh source works (no closure error)", {
  skip_on_cran()

  # This previously failed with: "cannot coerce type 'closure' to vector of type 'character'"
  expect_no_error({
    result <- get_dataset("rppi_bis", "detailed_monthly", source = "fresh")
  })

  result <- get_dataset("rppi_bis", "detailed_monthly", source = "fresh")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
  expect_true("date" %in% names(result))
})

test_that("rppi_bis all tables work with fresh source", {
  skip_on_cran()

  tables <- c(
    "selected",
    "detailed_monthly",
    "detailed_quarterly",
    "detailed_annual",
    "detailed_semiannual"
  )

  for (tbl in tables) {
    expect_no_error({
      result <- get_dataset("rppi_bis", tbl, source = "fresh")
    })

    result <- get_dataset("rppi_bis", tbl, source = "fresh")
    expect_s3_class(result, "data.frame")
    expect_true(nrow(result) > 0)
  }
})

# FipeZap Tests
test_that("FipeZap uses 'Brazil' instead of 'Índice Fipezap' in name_muni", {
  skip_on_cran()

  fz <- get_dataset("rppi", table = "fipezap", source = "fresh")

  expect_true(
    "Brazil" %in% unique(fz$name_muni),
    info = paste("Actual values:", paste(unique(fz$name_muni), collapse = ", "))
  )

  expect_false(
    "Índice Fipezap" %in% unique(fz$name_muni),
    info = "Should not contain 'Índice Fipezap'"
  )
})

# Property Records Tests
test_that("property_records returns tibble, not nested list", {
  skip_on_cran()

  # Test default (should be capitals records)
  result <- get_dataset("property_records")
  expect_s3_class(result, "data.frame")
  expect_false(
    is.list(result) && !inherits(result, "data.frame"),
    info = "Should return data.frame, not plain list"
  )
  expect_true(nrow(result) > 0)
})

test_that("property_records all tables return tibbles", {
  skip_on_cran()

  tables <- c(
    "capitals",
    "capitals_transfers",
    "cities",
    "aggregates",
    "aggregates_transfers"
  )

  for (tbl in tables) {
    result <- get_dataset("property_records", table = tbl)

    expect_s3_class(result, "data.frame")
    expect_false(is.list(result) && !inherits(result, "data.frame"))
    expect_true(nrow(result) > 0)
  }
})

# RPPI Individual Tables Tests
test_that("RPPI individual tables work with fresh source", {
  skip_on_cran()

  # Test a few key individual tables
  tables <- c("fipezap", "ivgr", "igmi")

  for (tbl in tables) {
    expect_no_error({
      result <- get_dataset("rppi", table = tbl, source = "fresh")
    })

    result <- get_dataset("rppi", table = tbl, source = "fresh")
    expect_s3_class(result, "data.frame")
    expect_true(nrow(result) > 0)
    expect_true("date" %in% names(result))
  }
})

# SECOVI Tests
test_that("SECOVI table parameter works correctly", {
  skip_on_cran()

  # Previously reported that table argument wasn't working
  tables <- c("condo", "launch", "sale")

  for (tbl in tables) {
    result <- get_dataset("secovi", table = tbl)

    expect_s3_class(result, "data.frame")
    expect_true(nrow(result) > 0)

    # Verify we got the right table
    if ("category" %in% names(result)) {
      expect_true(all(result$category == tbl))
    }
  }
})

# ABECIP Tests
test_that("ABECIP CGI table works without confusing messaging", {
  skip_on_cran()

  # CGI is a static dataset - should work with both fresh and cached
  expect_no_error({
    result <- get_dataset("abecip", table = "cgi", source = "fresh")
  })

  result <- get_dataset("abecip", table = "cgi")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

# General Tests
test_that("get_dataset returns correct structure for all major datasets", {
  skip_on_cran()

  # Test that key datasets return proper data structures
  datasets_to_test <- list(
    list(name = "abecip", table = "sbpe", should_be_tibble = TRUE),
    list(name = "abrainc", table = "radar", should_be_tibble = TRUE),
    list(name = "bcb_realestate", table = NULL, should_be_tibble = TRUE),
    list(name = "secovi", table = "condo", should_be_tibble = TRUE),
    list(name = "fgv_ibre", table = NULL, should_be_tibble = TRUE)
  )

  for (ds in datasets_to_test) {
    result <- get_dataset(ds$name, table = ds$table)

    if (ds$should_be_tibble) {
      expect_s3_class(result, "data.frame")
      expect_true(nrow(result) > 0)
    }
  }
})

test_that("get_dataset with source='fresh' doesn't produce closure errors", {
  skip_on_cran()

  # Test datasets that previously had closure errors
  # These should all work without "cannot coerce type 'closure'" errors

  expect_no_error({
    get_dataset("rppi_bis", "selected", source = "fresh")
  })

  expect_no_error({
    get_dataset("rppi", "ivgr", source = "fresh")
  })
})

# BCB Real Estate Tests
test_that("bcb_realestate table parameter filters correctly", {
  skip_on_cran()

  # Previously reported that all tables returned identical 379,901 rows
  tables <- c("application", "indices", "sources")

  results <- list()
  for (tbl in tables) {
    result <- get_dataset("bcb_realestate", table = tbl)

    expect_s3_class(result, "data.frame")
    expect_true(nrow(result) > 0)

    # Verify we got the right table by checking category column
    if ("category" %in% names(result)) {
      # Map table names to internal categories
      category_mapping <- c(
        "accounting" = "contabil",
        "application" = "direcionamento",
        "indices" = "indices",
        "sources" = "fontes",
        "units" = "imoveis"
      )

      expected_category <- category_mapping[[tbl]]
      actual_categories <- unique(result$category)
      expect_true(
        expected_category %in% actual_categories,
        label = paste("Expected category", expected_category, "in table", tbl)
      )
    }

    results[[tbl]] <- nrow(result)
  }

  # Verify that different tables have different row counts
  # (they should not all be identical)
  unique_counts <- unique(unlist(results))
  expect_true(
    length(unique_counts) > 1,
    label = paste(
      "Tables should have different row counts. Got:",
      paste(names(results), results, sep = "=", collapse = ", ")
    )
  )
})

# BCB Series Tests
test_that("bcb_series table parameter filters correctly", {
  skip_on_cran()

  # Previously reported that all tables returned identical 27,181 rows
  tables <- c("credit", "price", "production")

  results <- list()
  for (tbl in tables) {
    result <- get_dataset("bcb_series", table = tbl)

    expect_s3_class(result, "data.frame")
    expect_true(nrow(result) > 0)

    # Verify we got the right table by checking bcb_category column
    if ("bcb_category" %in% names(result)) {
      actual_categories <- unique(result$bcb_category)
      expect_true(
        tbl %in% actual_categories,
        label = paste("Expected category", tbl, "in results")
      )
    }

    results[[tbl]] <- nrow(result)
  }

  # Verify that different tables have different row counts
  unique_counts <- unique(unlist(results))
  expect_true(
    length(unique_counts) > 1,
    label = paste(
      "Tables should have different row counts. Got:",
      paste(names(results), results, sep = "=", collapse = ", ")
    )
  )
})

# BCB Series Graceful Degradation Tests
test_that("bcb_series handles partial failures gracefully with fresh download", {
  skip_on_cran()

  # One series (432 - daily Selic) may fail, but function should return the others
  # This should succeed even if one series fails
  result <- suppressWarnings(
    get_dataset("bcb_series", table = "all", source = "fresh", quiet = TRUE)
  )

  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)

  # Should have at least some of the 15 series
  unique_codes <- unique(result$code_bcb)
  expect_true(
    length(unique_codes) >= 10,
    label = paste("Expected at least 10 series, got", length(unique_codes))
  )

  # Should have joined with metadata
  expect_true("bcb_category" %in% names(result))
})

test_that("bcb_series table filtering works with fresh download", {
  skip_on_cran()

  # Get just price series
  price_data <- suppressWarnings(
    get_dataset("bcb_series", table = "price", source = "fresh", quiet = TRUE)
  )

  expect_s3_class(price_data, "data.frame")
  expect_true(nrow(price_data) > 0)

  # Should only have price category
  if ("bcb_category" %in% names(price_data)) {
    categories <- unique(price_data$bcb_category)
    expect_true(
      all(categories == "price"),
      label = paste("Expected only 'price', got:", paste(categories, collapse = ", "))
    )
  }

  # Get credit series
  credit_data <- suppressWarnings(
    get_dataset("bcb_series", table = "credit", source = "fresh", quiet = TRUE)
  )

  # Should be different from price data
  expect_false(
    identical(nrow(price_data), nrow(credit_data)),
    label = "Price and credit tables should have different row counts"
  )
})
