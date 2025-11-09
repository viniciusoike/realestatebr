# Import Indicators from the Abrainc-Fipe Report (DEPRECATED)

Import Indicators from the Abrainc-Fipe Report (DEPRECATED)

## Usage

``` r
get_abrainc_indicators(
  table = "indicator",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
)
```

## Source

Abrainc-Fipe available at
<https://www.fipe.org.br/pt-br/indices/abrainc>

## Arguments

- table:

  Character. One of `'indicator'` (default), `'radar'`, `'leading'`, or
  `'all'`.

- cached:

  Logical. If `TRUE`, attempts to load data from package cache using the
  unified dataset architecture.

- quiet:

  Logical. If `TRUE`, suppresses progress messages and warnings. If
  `FALSE` (default), provides detailed progress reporting.

- max_retries:

  Integer. Maximum number of retry attempts for failed downloads.
  Defaults to 3.

## Value

Either a named `list` (when table is `'all'`) or a `tibble` (for
specific tables). The return includes metadata attributes:

- download_info:

  List with download statistics

- source:

  Data source used (web or cache)

- download_time:

  Timestamp of download

## Details

Downloads data from the Abrainc-Fipe Indicators report including
information on new launches, sales, delivered units, and market
indicators.

## Deprecation

This function is deprecated since v0.4.0. Use
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)("abrainc")
instead:

      # Old way:
      data <- get_abrainc_indicators()

      # New way:
      data <- get_dataset("abrainc")
