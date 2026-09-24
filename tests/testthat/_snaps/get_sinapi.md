# SINAPI rejects unknown upstream identifiers

    Code
      clean_sinapi(with_relief, without_relief)
    Condition
      Error in `clean_sinapi()`:
      ! Unknown SINAPI variable ID: "99999".

# SINAPI validation rejects observations without a unit

    Code
      validate_sinapi(dat)
    Condition
      Error in `validate_sinapi()`:
      ! SINAPI data contains observations without a unit.

