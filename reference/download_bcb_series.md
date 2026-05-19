# Download BCB Series Data with Robust Error Handling

Downloads BCB series data with per-series retry logic. Uses
[`purrr::possibly()`](https://purrr.tidyverse.org/reference/possibly.html)
to collect failures without aborting, then reports any failed series
after the full map completes.

## Usage

``` r
download_bcb_series(codes_bcb, date_start, quiet, max_retries, ...)
```

## Arguments

- codes_bcb:

  Vector of BCB series codes.

- date_start:

  Start date for series.

- quiet:

  Logical controlling messages.

- max_retries:

  Maximum number of retry attempts per series.

- ...:

  Additional arguments passed to
  [`rbcb::get_series`](https://wilsonfreitas.github.io/rbcb/reference/get_series.html).

## Value

A long-format tibble with columns `date`, `value`, and `code_bcb`.
