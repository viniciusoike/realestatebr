# Regression tests for fixes from the 2026-06 code review.
# These cover deterministic, offline-only internal helpers.

# CGI parsers ----------------------------------------------------------------

test_that("parse_cgi_number returns NA when fewer than four digit groups", {
  expect_identical(parse_cgi_number("12,34", decimal = TRUE), NA_real_)
  expect_identical(parse_cgi_number("123", decimal = TRUE), NA_real_)
})

test_that("parse_cgi_number parses four-group decimals correctly", {
  # Three integer groups concatenated, fourth group as decimal
  expect_equal(parse_cgi_number("1.234.567,89", decimal = TRUE), 1234567.89)
})

test_that("parse_cgi_stock returns NA for unexpected prefixes", {
  expect_true(is.na(parse_cgi_stock("7.000")))
  expect_false(is.na(parse_cgi_stock("1.234")))
  expect_false(is.na(parse_cgi_stock("9.876")))
})

# RPPI change calculation ----------------------------------------------------

test_that("calculate_rppi_changes computes trailing month and year changes", {
  df <- data.frame(index = c(100, 110, 121))
  out <- calculate_rppi_changes(df, index_col = "index")

  expect_equal(out$chg, c(NA, 0.1, 0.1))
  # acum12m needs a full 12-month window; first values are NA
  expect_true(all(is.na(out$acum12m[1:11])))

  df13 <- data.frame(index = 100 * 1.01^(0:12))
  out13 <- calculate_rppi_changes(df13, index_col = "index")
  # 12 monthly steps of 1% compound to ~12.68% over the trailing year
  expect_equal(out13$acum12m[13], 1.01^12 - 1, tolerance = 1e-8)
})

# FipeZap harmonization validation -------------------------------------------

test_that("harmonize_fipezap_for_stacking rejects invalid transaction types", {
  dat <- data.frame(x = 1)
  expect_error(harmonize_fipezap_for_stacking(dat, "lease"))
  expect_error(harmonize_fipezap_for_stacking(dat, NULL))
  expect_error(harmonize_fipezap_for_stacking(dat, c("sale", "rent")))
})
