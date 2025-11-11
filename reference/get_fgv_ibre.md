# Get FGV IBRE Confidence Indicators (DEPRECATED)

Deprecated since v0.4.0. Use
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)("fgv_ibre")
instead. Loads construction confidence indicators from FGV IBRE
including confidence indices, expectation indicators, and INCC price
indices.

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
