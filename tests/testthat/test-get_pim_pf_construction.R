make_pim_pf_fixture <- function(table, start, values) {
  dates <- seq(as.Date(start), by = "month", length.out = length(values))
  tibble::tibble(
    aggregate_id = as.character(table),
    variable_id = "1",
    variable_name = "Index",
    unit = "Número-índice",
    period = format(dates, "%Y%m"),
    geography_level = "N1",
    geography_level_name = "Brasil",
    geography_code = "1",
    geography_name = "Brasil",
    value_raw = as.character(values),
    value = values
  )
}

test_that("PIM-PF links the old series through the 2012 overlap", {
  old <- make_pim_pf_fixture(
    2294,
    "2011-01-01",
    c(rep(50, 12), rep(100, 12))
  )
  current <- make_pim_pf_fixture(8886, "2012-01-01", rep(80, 13))

  result <- link_pim_pf_construction(old, current)

  expect_equal(nrow(result), 25L)
  expect_equal(result$value[1:12], rep(40, 12))
  expect_equal(result$value[13:25], rep(80, 13))
  expect_equal(result$source_table[12:13], c(2294L, 8886L))
  expect_equal(attr(result, "link_factor"), 0.8)
})

test_that("PIM-PF requires a complete overlap year", {
  local_edition(3)
  old <- make_pim_pf_fixture(2294, "2012-01-01", rep(100, 11))
  current <- make_pim_pf_fixture(8886, "2012-01-01", rep(80, 12))

  expect_snapshot(
    error = TRUE,
    link_pim_pf_construction(old, current)
  )
})
