# Import BCB Series Data with Robust Error Handling

Internal function to download BCB series data with retry logic.

## Usage

``` r
import_bcb_series_robust(codes_bcb, date_start, quiet, max_retries, ...)
```

## Arguments

- codes_bcb:

  Vector of BCB series codes

- date_start:

  Start date for series

- quiet:

  Logical controlling messages

- max_retries:

  Maximum number of retry attempts

- ...:

  Additional arguments passed to rbcb::get_series

## Value

Downloaded BCB API data
