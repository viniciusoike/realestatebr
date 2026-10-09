test_that("SECOVI attaches each data table to its preceding year", {
  year <- function(value) {
    data.frame(X1 = "", X2 = "", X3 = paste("Ano:", value))
  }
  table <- function(value) {
    data.frame(X1 = c("MÊS", "JAN", "FEV"), X2 = c("Valor", value, value))
  }

  cleaned <- clean_secovi(list(
    year(2022),
    table("1,0"),
    table("2,0"),
    year(2023),
    table("3,0")
  ))

  expect_equal(
    cleaned$date,
    as.Date(c(
      "2022-01-01",
      "2022-02-01",
      "2022-01-01",
      "2022-02-01",
      "2023-01-01",
      "2023-02-01"
    ))
  )
  expect_error(clean_secovi(list(table("1,0"))), "year annotation")
  expect_error(
    clean_secovi(list(year("unknown"), table("1,0"))),
    "year annotation"
  )
})

test_that("Abrainc preserves missing series without treating spacers as series", {
  raw <- as.data.frame(rep(list(1), 31))
  raw[[1]] <- as.Date("2025-01-01")
  raw[c(6, 11, 16, 21, 26, 29)] <- NA_real_
  raw[[3]] <- NA_real_
  raw[[4]] <- 77

  cleaned <- suppressWarnings(clean_abrainc(list(indicator = raw), "indicator"))

  expect_true(is.na(cleaned$value[
    cleaned$category == "new_units" & cleaned$variable == "market_rate"
  ]))
  expect_equal(
    cleaned$value[
      cleaned$category == "new_units" & cleaned$variable == "social_housing"
    ],
    77
  )

  raw[[6]] <- 99
  expect_error(clean_abrainc(list(indicator = raw), "indicator"), "spacer")
})

test_that("ABECIP units preserve partial months and reject invalid dates", {
  raw <- tibble::tibble(
    date = c(
      "45658",
      "45689",
      "Total",
      NA_character_,
      "Source: ABECIP",
      "45720"
    ),
    units_construction = c(1, NA, 3, NA, NA, NA),
    units_acquisition = c(2, 4, 5, NA, NA, NA),
    units_total = c(3, 4, 8, NA, NA, NA),
    currency_construction = c(1, NA, 3, NA, NA, NA),
    currency_acquisition = c(2, 4, 5, NA, NA, NA),
    currency_total = c(3, 4, 8, NA, NA, NA)
  )
  local_mocked_bindings(read_excel = function(...) raw, .package = "readxl")

  cleaned <- clean_abecip_units("unused.xlsx")
  expect_equal(nrow(cleaned), 2L)
  expect_true(is.na(cleaned$units_construction[[2]]))
  expect_false(anyNA(cleaned$date))

  raw$date[[2]] <- "not a date"
  expect_error(clean_abecip_units("unused.xlsx"), "invalid date")
})
