# Get Residential Property Price Indices from BIS (DEPRECATED)

Get Residential Property Price Indices from BIS (DEPRECATED)

## Usage

``` r
get_rppi_bis(
  table = "selected",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
)
```

## Source

<https://data.bis.org/topics/RPP>

## Arguments

- table:

  Character. Which dataset table to return:

  "selected"

  :   Selected RPPI series for major countries (default)

  "detailed_monthly"

  :   Monthly detailed RPPI data

  "detailed_quarterly"

  :   Quarterly detailed RPPI data

  "detailed_annual"

  :   Annual detailed RPPI data

  "detailed_semiannual"

  :   Semiannual detailed RPPI data

- cached:

  Logical. If `TRUE`, attempts to load data from package cache using the
  unified dataset architecture.

- quiet:

  Logical. If `TRUE`, suppresses progress messages and warnings. If
  `FALSE` (default), provides detailed progress reporting.

- max_retries:

  Integer. Maximum number of retry attempts for failed Excel download
  operations. Defaults to 3.

## Value

A `tibble` with the requested RPPI data. The return includes metadata
attributes:

- download_info:

  List with download statistics

- source:

  Data source used (web or cache)

- download_time:

  Timestamp of download

## Details

Downloads Residential Property Price Indices from BIS with support for
selected series and detailed monthly/quarterly/annual/semiannual
datasets.

## Deprecation

This function is deprecated since v0.4.0. Use
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)("rppi_bis")
instead:

      # Old way:
      data <- get_rppi_bis()

      # New way:
      data <- get_dataset("rppi_bis")
