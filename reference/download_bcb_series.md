# Download BCB Series Data

Downloads BCB series data with per-series retry logic. Uses
[`purrr::possibly()`](https://purrr.tidyverse.org/reference/possibly.html)
to collect failures without aborting, then reports any failed series
after the full map completes.

## Usage

``` r
download_bcb_series(codes_bcb, quiet, max_retries)
```

## Arguments

- codes_bcb:

  Vector of BCB series codes.

- quiet:

  Logical controlling messages.

- max_retries:

  Maximum number of retry attempts per series.

## Value

A long-format tibble with columns `date`, `value`, and `code_bcb`.
