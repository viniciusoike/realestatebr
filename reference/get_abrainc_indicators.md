# Import Indicators from the Abrainc-Fipe Report

Import Indicators from the Abrainc-Fipe Report

## Usage

``` r
get_abrainc_indicators(table = "indicator", quiet = FALSE, max_retries = 3L)
```

## Source

Abrainc-Fipe available at
<https://www.fipe.org.br/pt-br/indices/abrainc>

## Arguments

- table:

  Character. One of `'indicator'` (default), `'radar'`, `'leading'`, or
  `'all'`.

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

  Data source used

- download_time:

  Timestamp of download

## Details

Downloads data from the Abrainc-Fipe Indicators report including
information on new launches, sales, delivered units, and market
indicators.
