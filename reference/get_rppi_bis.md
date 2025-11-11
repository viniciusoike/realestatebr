# Get Residential Property Price Indices from BIS (DEPRECATED)

Deprecated since v0.4.0. Use
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)("rppi_bis")
instead. Downloads Residential Property Price Indices from BIS with
support for selected series and detailed
monthly/quarterly/annual/semiannual datasets.

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
  "detailed_quarterly", "detailed_annual", or "detailed_semiannual".

- cached:

  Logical. If `TRUE`, loads data from cache.

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

- max_retries:

  Integer. Maximum retry attempts. Defaults to 3.

## Value

Tibble with BIS RPPI data. Includes metadata attributes: source,
download_time.
