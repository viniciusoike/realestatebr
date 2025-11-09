# Generic Data Validation

Validates basic dataset requirements. Consolidates validation logic used
across all dataset functions.

## Usage

``` r
validate_dataset(
  data,
  dataset_name,
  required_cols = "date",
  min_rows = 1,
  check_dates = TRUE,
  max_future_days = 90
)
```

## Arguments

- data:

  Data frame or tibble. The dataset to validate.

- dataset_name:

  Character. Name of dataset for error messages.

- required_cols:

  Character vector. Required column names. Default is "date".

- min_rows:

  Integer. Minimum expected number of rows. Default 1.

- check_dates:

  Logical. Whether to validate date column. Default TRUE.

- max_future_days:

  Integer. Maximum days in future allowed for dates. Default 90.

## Value

Invisible TRUE if all validations pass. Errors or warns otherwise.

## Details

Performs the following checks:

1.  Data is not empty (nrow \> 0)

2.  Minimum row count met

3.  Required columns present

4.  Date column valid (if check_dates = TRUE)

5.  Dates not too far in future (if check_dates = TRUE)

Throws errors for critical issues (empty data, missing columns, invalid
dates). Issues warnings for suspicious values (low row count, future
dates).

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic validation (just check for date column)
validate_dataset(data, "abecip")

# Validate specific columns
validate_dataset(
  data,
  "abecip_units",
  required_cols = c("date", "units_construction", "units_acquisition")
)

# Skip date validation
validate_dataset(data, "cbic", check_dates = FALSE)
} # }
```
