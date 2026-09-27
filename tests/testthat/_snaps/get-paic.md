# PAIC rejects unknown upstream variable IDs

    Code
      clean_paic_base(raw, 10442L)
    Condition
      Error in `clean_paic_base()`:
      ! Unknown PAIC variable ID: "99999".

# PAIC rejects unexpected units

    Code
      clean_paic_base(raw, 10442L)
    Condition
      Error in `clean_paic_base()`:
      ! Unexpected unit for PAIC variable ID: "631".

# PAIC activity rejects unknown category IDs

    Code
      clean_paic_activity(raw)
    Condition
      Error in `clean_paic_activity()`:
      ! Unknown PAIC activity category ID: "999999".

# PAIC state validation rejects a missing state

    Code
      validate_paic_state(dat)
    Condition
      Error in `validate_paic_state()`:
      ! PAIC state data is missing 6 expected observations.
      ℹ First missing key: year = 2024, geography_type = state, geography_code = 35,
        variable_id = 13807.

# PAIC validation rejects duplicate keys

    Code
      validate_paic_state(dat)
    Condition
      Error in `validate_paic_state()`:
      ! PAIC state data contains duplicate observation keys.

# PAIC validation enforces the headquarters basis for 13807

    Code
      validate_paic_state(dat)
    Condition
      Error in `validate_paic_state()`:
      ! PAIC variable 13807 must use the headquarters basis.

# PAIC size validation rejects state rows outside the 5+ band

    Code
      validate_paic_size(dat)
    Condition
      Error in `validate_paic_size()`:
      ! PAIC size data contains 1 unexpected observation.
      ℹ First unexpected key: year = 2024, geography_type = state, geography_code =
        11, variable_id = 1235, size_band = total.

# PAIC activity validation rejects inconsistent size bands

    Code
      validate_paic_activity(dat)
    Condition
      Error in `validate_paic_activity()`:
      ! PAIC activity size bands do not sum to the all-firm total for variable
        "631".

# PAIC cleaners reject malformed responses

    Code
      clean_paic_base(empty, 10442L)
    Condition
      Error in `clean_paic_base()`:
      ! PAIC response for SIDRA table 10442 is empty.

---

    Code
      clean_paic_base(wrong_table, 10442L)
    Condition
      Error in `clean_paic_base()`:
      ! PAIC response is not from SIDRA table 10442.

---

    Code
      clean_paic_base(no_geography, 10442L)
    Condition
      Error in `clean_paic_base()`:
      ! PAIC data contains observations without a geography code.

---

    Code
      clean_paic_base(bad_level, 10442L)
    Condition
      Error in `clean_paic_base()`:
      ! Unknown PAIC geography level: "N6".

---

    Code
      clean_paic_base(no_unit, 10442L)
    Condition
      Error in `clean_paic_base()`:
      ! PAIC data contains observations without a unit: "631".

---

    Code
      clean_paic_activity(no_classification)
    Condition
      Error in `clean_paic_activity()`:
      ! PAIC response lacks classification 12296.

---

    Code
      clean_paic_size(bad_size)
    Condition
      Error in `clean_paic_size()`:
      ! Unknown PAIC size category ID: "999999".

