# Get Property Records Table (DEPRECATED)

Downloads property transaction records from Registro de Imoveis
including capitals, cities, and regional aggregates data.

## Usage

``` r
get_property_records(
  table = "capitals",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
)
```

## Arguments

- table:

  Character. One of "capitals", "capitals_transfers", "cities",
  "aggregates", or "aggregates_transfers".

- cached:

  Logical. If `TRUE`, loads data from package cache.

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

- max_retries:

  Integer. Maximum retry attempts. Defaults to 3.

## Value

A tibble with property records data.

## Deprecation

This function is deprecated since v0.4.0. Use
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)("property_records")
instead.
