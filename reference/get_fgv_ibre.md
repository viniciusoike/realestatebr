# Get FGV IBRE Confidence Indicators (DEPRECATED)

Get FGV IBRE Confidence Indicators (DEPRECATED)

## Usage

``` r
get_fgv_ibre(table = "indicators", cached = TRUE, quiet = FALSE)
```

## Arguments

- table:

  Character. Which dataset to return: "indicators" (default) or "all".

- cached:

  Logical. If `TRUE` (default), loads data from package cache using the
  unified dataset architecture. If `FALSE`, uses internal package data
  objects.

- quiet:

  Logical. If `TRUE`, suppresses progress messages and warnings. If
  `FALSE` (default), provides detailed progress reporting.

## Value

A `tibble` containing all construction confidence indicator series from
FGV IBRE. The tibble includes metadata attributes:

- download_info:

  List with access statistics

- source:

  Data source used (cache or internal)

- download_time:

  Timestamp of access

## Details

Downloads construction confidence indicators from FGV IBRE including
confidence indices, expectation indicators, and INCC price indices.

## Deprecation

This function is deprecated since v0.4.0. Use
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)("fgv_ibre")
instead:

      # Old way:
      data <- get_fgv_ibre()

      # New way:
      data <- get_dataset("fgv_ibre")
