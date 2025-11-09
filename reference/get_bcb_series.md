# Download macroeconomic time-series from BCB (DEPRECATED)

Download macroeconomic time-series from BCB (DEPRECATED)

## Usage

``` r
get_bcb_series(
  table = "all",
  cached = FALSE,
  date_start = as.Date("2010-01-01"),
  quiet = FALSE,
  max_retries = 3L,
  ...
)
```

## Source

<https://www3.bcb.gov.br/sgspub/localizarseries/localizarSeries.do?method=prepararTelaLocalizarSeries>

## Arguments

- table:

  Character. Which dataset to return: "all" (default), "credit",
  "exchange", "government", "interest-rate", "real-estate", "price", or
  "production".

- cached:

  Logical. If `TRUE`, attempts to load data from package cache using the
  unified dataset architecture.

- date_start:

  A `Date` argument indicating the first period to extract from the time
  series. Defaults to 2010-01-01.

- quiet:

  Logical. If `TRUE`, suppresses progress messages and warnings. If
  `FALSE` (default), provides detailed progress reporting.

- max_retries:

  Integer. Maximum number of retry attempts for failed BCB API calls.
  Defaults to 3.

- ...:

  Additional arguments passed to
  [`rbcb::get_series`](https://wilsonfreitas.github.io/rbcb/reference/get_series.html).

## Value

A 12-column `tibble` with all of the selected series from BCB. The
tibble includes metadata attributes:

- download_info:

  List with download statistics

- source:

  Data source used (api or cache)

- download_time:

  Timestamp of download

## Details

Downloads macroeconomic time series from BCB including price indices,
interest rates, credit indicators, and production metrics.

## Deprecation

This function is deprecated since v0.4.0. Use
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)("bcb_series")
instead:

      # Old way:
      data <- get_bcb_series()

      # New way:
      data <- get_dataset("bcb_series")
