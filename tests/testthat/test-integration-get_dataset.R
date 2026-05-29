# Integration Tests for get_dataset()
# These tests verify that get_dataset() works correctly with real data sources
# and catches regressions that devtools::check() might miss.

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
    "detailed_halfyearly"
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
test_that("bcb_series hierarchy levels filter cumulatively", {
  skip_on_cran()

  # Hierarchy levels are cumulative: primary includes core, secondary
  # includes primary, etc. (introduced in 1.0.0).
  tables <- c("core", "primary", "secondary", "tertiary")

  code_counts <- vapply(
    tables,
    function(tbl) {
      result <- get_dataset("bcb_series", table = tbl)

      expect_s3_class(result, "data.frame")
      expect_true(nrow(result) > 0)
      expect_true(all(
        c("date", "code_bcb", "name_simplified", "value") %in% names(result)
      ))

      length(unique(result$code_bcb))
    },
    integer(1)
  )

  expect_true(
    all(diff(code_counts) >= 0),
    label = paste(
      "Hierarchy must be cumulative. Code counts:",
      paste(tables, code_counts, sep = "=", collapse = ", ")
    )
  )
})

# BCB Series Graceful Degradation Tests
test_that("bcb_series handles partial failures gracefully with fresh download", {
  skip_on_cran()

  # One series (e.g., daily Selic) may fail, but function should return the rest
  result <- suppressWarnings(
    get_dataset("bcb_series", table = "core", source = "fresh", quiet = TRUE)
  )

  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
  expect_true(all(
    c("date", "code_bcb", "name_simplified", "value") %in% names(result)
  ))

  unique_codes <- unique(result$code_bcb)
  expect_true(
    length(unique_codes) >= 30,
    label = paste("Expected at least 30 core series, got", length(unique_codes))
  )
})

test_that("bcb_series table filtering works with fresh download", {
  skip_on_cran()

  core_data <- suppressWarnings(
    get_dataset("bcb_series", table = "core", source = "fresh", quiet = TRUE)
  )
  primary_data <- suppressWarnings(
    get_dataset("bcb_series", table = "primary", source = "fresh", quiet = TRUE)
  )

  expect_s3_class(core_data, "data.frame")
  expect_s3_class(primary_data, "data.frame")
  expect_true(nrow(core_data) > 0)
  expect_true(nrow(primary_data) > 0)

  # Primary must be a strict superset of core (cumulative hierarchy)
  core_codes <- unique(core_data$code_bcb)
  primary_codes <- unique(primary_data$code_bcb)

  expect_true(
    all(core_codes %in% primary_codes),
    label = "Primary should include every code in core"
  )
  expect_true(
    length(primary_codes) > length(core_codes),
    label = "Primary should add codes beyond core"
  )
})
