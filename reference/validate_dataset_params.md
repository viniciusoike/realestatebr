# Generic Parameter Validation for Dataset Functions

Validates common parameters used across all dataset functions. This
consolidates repetitive validation logic into a single reusable
function.

## Usage

``` r
validate_dataset_params(
  table,
  valid_tables,
  cached,
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

- cached:

  Logical. Whether to use cached data.

- quiet:

  Logical. Whether to suppress messages.

- max_retries:

  Numeric. Maximum number of retry attempts.

- allow_all:

  Logical. Whether "all" is a valid table value. Default TRUE.

## Value

Invisible TRUE if all validations pass. Errors otherwise.

## Details

This function performs standard validation for:

- table: Must be character, length 1, in valid_tables (or "all" if
  allowed)

- cached: Must be logical, length 1

- quiet: Must be logical, length 1

- max_retries: Must be numeric, length 1, positive
