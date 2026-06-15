# Import data from Secovi-SP

Import data from Secovi-SP

## Usage

``` r
get_secovi(table = "all", cached = FALSE, quiet = FALSE, max_retries = 3L)
```

## Arguments

- table:

  Character. One of `'condo'`, `'rent'`, `'launch'`, `'sale'` or `'all'`
  (default).

- cached:

  Logical. If `TRUE`, attempts to load data from package cache using the
  unified dataset architecture.

- quiet:

  Logical. If `TRUE`, suppresses progress messages and warnings. If
  `FALSE` (default), provides detailed progress reporting.

- max_retries:

  Integer. Maximum number of retry attempts for failed web scraping
  operations. Defaults to 3.

## Value

A `tibble` with SECOVI-SP real estate data. The return includes metadata
attributes:

- download_info:

  List with download statistics

- source:

  Data source used (web or cache)

- download_time:

  Timestamp of download

## Details

Scrapes real estate data from SECOVI-SP including condominium fees,
rental market data, launches, and sales information.
