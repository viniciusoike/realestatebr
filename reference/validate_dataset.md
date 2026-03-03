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
