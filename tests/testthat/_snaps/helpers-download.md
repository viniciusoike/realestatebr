# download_with_retry reports the root cause of wrapped errors

    Code
      download_with_retry(failing_map, max_retries = 1, desc = "Scrape page")
    Condition
      Warning:
      Scrape page attempt 1/2 failed: Timeout was reached
      Error in `download_with_retry()`:
      ! Scrape page failed after 2 attempts.
      Caused by error in `purrr::map()`:
      ℹ In index: 1.
      Caused by error in `.f()`:
      ! Timeout was reached

