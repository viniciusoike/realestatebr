test_that("SECOVI HTML is parsed as ISO-8859-1", {
  fixture_path <- testthat::test_path("fixtures", "secovi-latin1.html.fixture")
  fixture <- readLines(fixture_path, encoding = "UTF-8", warn = FALSE)
  latin1_text <- iconv(paste(fixture, collapse = "\n"), to = "ISO-8859-1")
  raw <- charToRaw(latin1_text)

  parsed <- secovi_parse_html(raw)
  tables <- rvest::html_table(parsed)
  cleaned <- janitor::clean_names(tables[[1]])

  expect_identical(names(cleaned)[[1]], "mes")
})

test_that("SECOVI metadata excludes discontinued indicators", {
  expect_setequal(
    secovi_metadata[["code"]],
    c(13, 14, 18, 26, 78, 80, 85, 86, 87, 88, 89, 90)
  )
})

test_that("SECOVI freshness validation accepts current active series", {
  active_variables <- c(
    "supply",
    "launches",
    "sales_1rooms",
    "sales_2rooms",
    "sales_3rooms",
    "sales_4rooms",
    "sales"
  )
  secovi <- tibble::tibble(
    date = as.Date("2026-05-01"),
    variable = active_variables
  )

  result <- validate_secovi_freshness(
    secovi,
    reference_date = as.Date("2026-08-23")
  )

  expect_identical(result, TRUE)
})

test_that("SECOVI freshness validation rejects missing and stale series", {
  local_edition(3)

  missing <- tibble::tibble(
    date = as.Date("2026-05-01"),
    variable = "supply"
  )
  stale <- tibble::tibble(
    date = as.Date("2026-02-01"),
    variable = c(
      "supply",
      "launches",
      "sales_1rooms",
      "sales_2rooms",
      "sales_3rooms",
      "sales_4rooms",
      "sales"
    )
  )

  expect_snapshot(
    validate_secovi_freshness(
      missing,
      reference_date = as.Date("2026-08-23")
    ),
    error = TRUE
  )
  expect_snapshot(
    validate_secovi_freshness(
      stale,
      reference_date = as.Date("2026-08-23")
    ),
    error = TRUE
  )
})
