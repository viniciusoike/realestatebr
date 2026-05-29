# Get Credit Indicators from Abecip

Get Credit Indicators from Abecip

## Usage

``` r
get_abecip_indicators(table = "sbpe", quiet = FALSE, max_retries = 3L)
```

## Source

<https://www.abecip.org.br>

## Arguments

- table:

  Character. One of `'sbpe'` (default), `'units'`, or `'cgi'`.

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

Downloads housing credit data from Abecip including SBPE monetary flows,
financed units, and home-equity loan data.
