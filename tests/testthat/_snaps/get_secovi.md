# download_secovi drops indicators whose page fails

    Code
      tables <- download_secovi(table = "condo", quiet = TRUE, max_retries = 0,
        delay = 0)
    Condition
      Warning:
      Failed to import SECOVI-SP data for "default_condominio".
      ℹ These indicators are missing from the result.

# download_secovi errors when no indicator page can be read

    Code
      download_secovi(table = "condo", quiet = TRUE, max_retries = 0, delay = 0)
    Condition
      Error in `download_secovi()`:
      ! Failed to download SECOVI-SP data.
      ✖ No indicator page could be read.
      ℹ The SECOVI-SP website may be down or blocking automated requests.
      Caused by error in `download_with_retry()`:
      ! Scrape SECOVI indicator icon failed after 1 attempt.
      Caused by error in `secovi_read_page()`:
      ! HTTP 503

# SECOVI freshness validation rejects missing and stale series

    Code
      validate_secovi_freshness(missing, reference_date = as.Date("2026-08-23"))
    Condition
      Error in `validate_secovi_freshness()`:
      ! SECOVI data is missing actively published series.
      ✖ Missing series: "launches", "sales_1rooms", "sales_2rooms", "sales_3rooms",
        "sales_4rooms", and "sales"

---

    Code
      validate_secovi_freshness(stale, reference_date = as.Date("2026-08-23"))
    Condition
      Error in `validate_secovi_freshness()`:
      ! SECOVI data is older than 180 days.
      ✖ Stale series: "supply", "launches", "sales_1rooms", "sales_2rooms",
        "sales_3rooms", "sales_4rooms", and "sales"
      ℹ Fresh data must be dated on or after 2026-02-24.

