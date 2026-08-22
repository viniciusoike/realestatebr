# Tests for the BCB SGS fetcher used by get_bcb_series() and get_rppi_ivgr().

test_that("bcb_series_first_date reads the series start from metadata", {
  expected <- realestatebr::bcb_metadata$first_value[
    realestatebr::bcb_metadata$code_bcb == 432
  ]

  expect_equal(bcb_series_first_date(432), expected)
})

test_that("bcb_series_first_date falls back for unknown codes", {
  expect_equal(bcb_series_first_date(999999), BCB_SERIES_FLOOR)
})

test_that("fetch_sgs_series returns the package schema", {
  skip_on_cran()
  skip_if_offline()

  series <- suppressMessages(
    fetch_sgs_series(21340, Sys.Date() - 365)
  )

  expect_s3_class(series, "data.frame")
  expect_named(series, c("date", "value", "code_bcb"))
  expect_s3_class(series$date, "Date")
  expect_type(series$value, "double")
  expect_true(all(series$code_bcb == 21340))
  expect_false(anyNA(series$date))
})

test_that("fetch_sgs_series drops empty windows of a discontinued series", {
  skip_on_cran()
  skip_if_offline()

  # 13421 (TR) ended in 2022, so its final windows return no data
  series <- suppressMessages(fetch_sgs_series(13421, as.Date("2020-01-01")))

  expect_false(anyNA(series$date))
  expect_true(nrow(series) > 0)
})
