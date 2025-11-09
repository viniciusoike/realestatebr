# Import Real Estate data from the Brazilian Central Bank (DEPRECATED)

Import Real Estate data from the Brazilian Central Bank (DEPRECATED)

## Usage

``` r
get_bcb_realestate(
  table = "all",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
)
```

## Source

<https://dadosabertos.bcb.gov.br/dataset/informacoes-do-mercado-imobiliario>

## Arguments

- table:

  Character. One of `'accounting'`, `'application'`, `'indices'`,
  `'sources'`, `'units'`, or `'all'` (default).

- cached:

  Logical. If `TRUE`, attempts to load data from package cache using the
  unified dataset architecture.

- quiet:

  Logical. If `TRUE`, suppresses progress messages and warnings. If
  `FALSE` (default), provides detailed progress reporting.

- max_retries:

  Integer. Maximum number of retry attempts for failed API calls.
  Defaults to 3.

## Value

If `table = 'all'` returns a `tibble` with 13 columns where:

- `series_info`: the full name identifying each series.

- `category`: category of the series (first element of `series_info`).

- `type`: subcategory of the series (second element of `series_info`).

- `v1` to `v5`: elements of `series_info`.

- `value`: numeric value of the series.

- `abbrev_state`: two letter state abbreviation.

  The tibble includes metadata attributes:

  - download_info:

    List with download statistics

  - source:

    Data source used (api or cache)

  - download_time:

    Timestamp of download

## Details

Imports real estate data from BCB including credit sources, credit
applications, financed units, and real estate indices.

## Deprecation

This function is deprecated since v0.4.0. Use
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)("bcb_realestate")
instead:

      # Old way:
      data <- get_bcb_realestate()

      # New way:
      data <- get_dataset("bcb_realestate")
