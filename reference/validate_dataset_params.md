# Generic Parameter Validation for Dataset Functions

Validates common parameters used across all dataset functions.

## Usage

``` r
validate_dataset_params(
  table,
  valid_tables,
  quiet,
  max_retries,
  allow_all = TRUE
)
```

## Arguments

- table:

  Character. The table parameter to validate.

- valid_tables:

  Character vector. Valid table names for the dataset.

- quiet:

  Logical. Whether to suppress messages.

- max_retries:

  Numeric. Maximum number of retry attempts.

- allow_all:

  Logical. Whether "all" is a valid table value. Default TRUE.

## Value

Invisible TRUE if all validations pass. Errors otherwise.
