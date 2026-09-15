test_that("download_with_retry reports the root cause of wrapped errors", {
  local_edition(3)

  failing_map <- function() {
    purrr::map(1, \(x) cli::cli_abort("Timeout was reached"))
  }

  expect_snapshot(
    download_with_retry(failing_map, max_retries = 1, desc = "Scrape page"),
    error = TRUE
  )
})

test_that("download_with_retry returns the first successful result", {
  attempts <- 0
  flaky <- function() {
    attempts <<- attempts + 1
    if (attempts == 1) {
      stop("Temporary failure")
    }
    "ok"
  }

  result <- download_with_retry(flaky, max_retries = 1, quiet = TRUE)

  expect_identical(result, "ok")
  expect_identical(attempts, 2)
})

test_that("root_cause_message returns the innermost message on one line", {
  inner <- rlang::error_cnd(message = "Timeout\nwas reached")
  outer <- rlang::error_cnd(message = "In index: 1.", parent = inner)

  expect_identical(root_cause_message(outer), "Timeout was reached")
})
