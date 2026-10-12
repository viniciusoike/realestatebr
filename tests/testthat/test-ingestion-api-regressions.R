test_that("requested date filters reject unparseable observations", {
  data <- tibble::tibble(
    date = c("2020-01-01", "not-a-date", NA_character_),
    value = 1:3
  )

  expect_error(
    filter_dataset_date_range(data, date_start = as.Date("2020-01-01")),
    "date column.*valid dates"
  )
  expect_error(
    filter_dataset_date_range(data, date_end = as.Date("2020-12-31")),
    "date column.*valid dates"
  )
  expect_equal(filter_dataset_date_range(data), data)
  expect_equal(
    filter_dataset_date_range(
      tibble::tibble(date = c("2020-01-01", NA_character_), value = 1:2),
      date_start = as.Date("2020-01-01")
    )$value,
    1L
  )
  expect_equal(
    filter_dataset_date_range(
      tibble::tibble(value = 1L),
      date_start = as.Date("2020-01-01")
    ),
    tibble::tibble(value = 1L)
  )
})

test_that("fresh and cached BCB table selections preserve long series", {
  raw <- tibble::tibble(
    Data = as.Date(c("2020-01-31", "2020-01-31", "2020-01-31")),
    Info = c(
      "contabil_estoque_carteira_br",
      "contabil_estoque_carteira_1_br",
      "fontes_poupanca_br"
    ),
    Valor = c("1,5", "2,5", "3,5")
  )
  local_mocked_bindings(download_bcb_realestate = function(...) raw)

  full <- get_bcb_realestate(table = "all", quiet = TRUE)
  local_mocked_bindings(fetch_github_release_asset = function(...) full)
  withr::defer(clear_session_cache())

  fresh <- get_dataset(
    "bcb_realestate",
    table = "accounting",
    source = "fresh",
    quiet = TRUE
  )
  cached <- get_dataset(
    "bcb_realestate",
    table = "accounting",
    source = "github",
    quiet = TRUE
  )

  expect_identical(names(fresh), names(cached))
  expect_equal(
    unname(lapply(fresh, identity)),
    unname(lapply(cached, identity))
  )
  expect_equal(nrow(fresh), 2L)
  expect_true(all(fresh$category == "contabil"))
  expect_true(all(c("series_info", "value", "type", "v1") %in% names(fresh)))
})
