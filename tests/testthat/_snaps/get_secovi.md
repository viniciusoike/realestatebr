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
