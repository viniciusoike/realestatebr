skip_if_not_live <- function() {
  testthat::skip_if_not(
    identical(Sys.getenv("REALESTATEBR_RUN_LIVE"), "true"),
    "Set REALESTATEBR_RUN_LIVE=true to test external sources"
  )
}
