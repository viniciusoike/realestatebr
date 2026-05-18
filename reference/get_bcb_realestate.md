# Import Real Estate data from the Brazilian Central Bank

Imports real estate data from BCB including credit sources,
applications, financed units, and real estate indices.

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

  Logical. If `TRUE`, attempts to load data from cache.

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

- max_retries:

  Integer. Maximum retry attempts. Defaults to 3.

## Value

Tibble with BCB real estate data. Includes metadata attributes: source,
download_time.
