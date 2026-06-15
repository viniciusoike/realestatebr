# Get FGV IBRE Confidence Indicators

Loads construction confidence indicators from FGV IBRE including
confidence indices, expectation indicators, and INCC price indices.

## Usage

``` r
get_fgv_ibre(table = "indicators", cached = TRUE, quiet = FALSE)
```

## Arguments

- table:

  Character. Which dataset to return: "indicators" (default) or "all".

- cached:

  Logical. If `TRUE` (default), loads data from cache.

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

## Value

Tibble with FGV IBRE indicators. Includes metadata attributes: source,
download_time.
