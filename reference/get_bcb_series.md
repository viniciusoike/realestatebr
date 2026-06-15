# Download macroeconomic time-series from BCB

Download macroeconomic time-series from BCB

## Usage

``` r
get_bcb_series(
  table = "core",
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

  Character. Hierarchy level to return:

  "core"

  :   Core real estate credit series (default, ~40 series).

  "primary"

  :   Core plus key macro series such as SELIC, IPCA, INCC (~59 series).

  "secondary"

  :   Primary plus broader macro context such as GDP, unemployment (~109
      series).

  "tertiary"

  :   All series including less relevant and discontinued ones (~141
      series).

  "full"

  :   Equivalent to "tertiary". Returns all available series.

- cached:

  Logical. If `TRUE`, attempts to load data from package cache.

- date_start:

  A `Date` indicating the first period to extract. Defaults to
  2010-01-01.

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

- max_retries:

  Integer. Maximum retry attempts for failed API calls. Defaults to 3.

- ...:

  Additional arguments passed to
  [`rbcb::get_series`](https://wilsonfreitas.github.io/rbcb/reference/get_series.html).

## Value

A 4-column `tibble` with columns `date`, `code_bcb`, `name_simplified`,
and `value`. Series metadata is available in
[`bcb_metadata`](https://viniciusoike.github.io/realestatebr/reference/bcb_metadata.md).

## Details

Downloads macroeconomic time series from BCB. Series are organised by
relevance to the Brazilian real estate market using a four-level
hierarchy. The default ("core") returns the 40 most directly relevant
series covering real estate credit concession, interest rates, and
delinquency. Use broader levels to include macroeconomic context series.
