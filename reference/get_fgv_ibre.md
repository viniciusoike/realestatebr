# Get FGV IBRE Confidence Indicators

Loads construction confidence indicators from FGV IBRE including
confidence indices, expectation indicators, and INCC price indices. FGV
data is not available via API; this function fetches the pre-processed
dataset from the package's GitHub release.

## Usage

``` r
get_fgv_ibre(table = "indicators", quiet = FALSE)
```

## Arguments

- table:

  Character. Which dataset to return: "indicators" (default) or "all".

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

## Value

Tibble with FGV IBRE indicators. Includes metadata attributes: source,
download_time.
