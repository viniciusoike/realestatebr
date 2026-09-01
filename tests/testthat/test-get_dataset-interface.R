# Tests for the public get_dataset() argument contract and messaging.
# These run offline by seeding the in-session memo.

test_that("get_dataset rejects unknown arguments", {
  expect_error(get_dataset("abecip", cached = TRUE), "unused argument")
  expect_error(
    get_dataset("abecip", date_start = as.Date("2020-01-01")),
    "unused argument"
  )
  expect_error(get_dataset("abecip", quiet = "yes"), "must be")
})

test_that("get_dataset reports the source in a single message", {
  withr::defer(clear_session_cache())
  memo_set(memo_key("abecip", "sbpe"), tibble::tibble(date = Sys.Date()))

  expect_message(
    get_dataset("abecip", table = "sbpe"),
    "session cache"
  )
})

test_that("get_dataset lists other tables only for the default table", {
  withr::defer(clear_session_cache())
  memo_set(memo_key("abecip", "sbpe"), tibble::tibble(date = Sys.Date()))
  memo_set(memo_key("abecip", "cgi"), tibble::tibble(date = Sys.Date()))

  expect_message(get_dataset("abecip"), "Other tables")

  msg <- capture_messages(get_dataset("abecip", table = "cgi"))
  expect_length(msg, 1)
  expect_false(any(grepl("Other tables", msg)))
})

test_that("get_dataset is silent when quiet is TRUE", {
  withr::defer(clear_session_cache())
  memo_set(memo_key("abecip", "sbpe"), tibble::tibble(date = Sys.Date()))

  expect_silent(get_dataset("abecip", table = "sbpe", quiet = TRUE))
})

test_that("every RPPI table maps to a release asset", {
  registry <- load_dataset_registry()
  rppi_info <- registry$datasets$rppi
  expected <- c(
    sale = "rppi_sale",
    rent = "rppi_rent",
    all = "rppi_all",
    fipezap = "rppi_fipe",
    ivgr = "rppi_ivgr",
    igmi = "rppi_igmi",
    iqa = "rppi_iqa",
    iqaiw = "rppi_iqaiw",
    ivar = "rppi_ivar",
    secovi_sp = "rppi_secovi_sp"
  )

  actual <- vapply(
    names(expected),
    \(table) get_cached_name("rppi", rppi_info, table),
    character(1)
  )

  expect_equal(actual, expected)
})
