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

# PAIC validation rejects duplicate keys

    Code
      suppressWarnings(validate_paic_state(dat))
    Condition
      Error in `validate_paic_state()`:
      ! PAIC state data contains duplicate observation keys.

# PAIC validation enforces the headquarters basis for 13807

    Code
      suppressWarnings(validate_paic_state(dat))
    Condition
      Error in `validate_paic_state()`:
      ! PAIC variable 13807 must use the headquarters basis.

