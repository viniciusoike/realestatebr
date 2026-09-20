make_sinapi_adapter_fixture <- function(variable_id, values) {
  tibble::tibble(
    aggregate_id = "2296",
    variable_id = variable_id,
    variable_name = "Custo médio m²",
    unit = "Reais",
    period = names(values),
    geography_level = "N1",
    geography_level_name = "Brasil",
    geography_code = "1",
    geography_name = "Brasil",
    value_raw = as.character(values),
    value = as.numeric(values)
  )
}

test_that("SINAPI combines and identifies payroll-relief variants", {
  with_relief <- make_sinapi_adapter_fixture(
    "48",
    c("201701" = 1031.21, "201702" = 1040)
  )
  without_relief <- make_sinapi_adapter_fixture(
    "9327",
    c("201701" = 1107.94, "201702" = 1115)
  )

  result <- clean_sinapi(with_relief, without_relief)

  expect_named(
    result,
    c(
      "date",
      "geography_type",
      "geography_code",
      "geography_name",
      "payroll_relief",
      "variable",
      "variable_label",
      "unit",
      "value"
    )
  )
  expect_equal(result$value, c(1107.94, 1031.21, 1115, 1040))
  expect_equal(result$payroll_relief, c(FALSE, TRUE, FALSE, TRUE))
  expect_equal(unique(result$variable), "cost")
})

test_that("SINAPI rejects unknown upstream identifiers", {
  local_edition(3)
  with_relief <- make_sinapi_adapter_fixture("99999", c("201701" = 1))
  without_relief <- make_sinapi_adapter_fixture("9327", c("201701" = 1))

  expect_snapshot(
    error = TRUE,
    clean_sinapi(with_relief, without_relief)
  )
})
