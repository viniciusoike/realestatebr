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
