# Get Residential Property Price Indices from BIS

Downloads Residential Property Price Indices from BIS with support for
selected series and detailed monthly/quarterly/annual/halfyearly
datasets.

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

  Character. Dataset table: "selected", "detailed_monthly",
  "detailed_quarterly", "detailed_annual", or "detailed_halfyearly".

- cached:

  Logical. If `TRUE`, loads data from cache.

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

- max_retries:

  Integer. Maximum retry attempts. Defaults to 3.

## Value

Tibble with BIS RPPI data. Includes metadata attributes: source,
download_time.
