# Import BCB Real Estate Data with Robust Error Handling

Modern version of import_bcb_realestate with retry logic.

## Usage

``` r
import_bcb_realestate_robust(quiet, max_retries)
```

## Arguments

- quiet:

  Logical controlling messages

- max_retries:

  Maximum number of retry attempts

## Value

Raw BCB data or error
