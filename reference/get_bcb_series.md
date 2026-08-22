# Download macroeconomic time-series from BCB

Download macroeconomic time-series from BCB

## Usage

``` r
get_bcb_series(table = "core", quiet = FALSE, max_retries = 3L)
```

## Source

Brazilian Central Bank (BCB) Time Series Management System (SGS)

## Arguments

- table:

  Character. Hierarchy level to return:

  "core"

  :   Core real estate credit series (default, ~40 series).

  "primary"

  :   Core plus key macro series such as inflation rate (~59 series).

  "secondary"

  :   Primary plus broader macro context such as GDP, unemployment (~109
      series).

  "tertiary"

  :   All series including less relevant and discontinued ones (~141
      series).

  "full"

  :   Equivalent to "tertiary". Returns all available series.

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

- max_retries:

  Integer. Maximum retry attempts for failed API calls. Defaults to 3.

## Value

A 4-column `tibble` with columns `date`, `code_bcb`, `name_simplified`,
and `value`. Series metadata is available in
[`bcb_metadata`](https://viniciusoike.github.io/realestatebr/reference/bcb_metadata.md).

## Details

Downloads macroeconomic time series from BCB. Series are organized by
relevance to the Brazilian real estate market using a four-level
hierarchy. The default ("core") returns the 40 most directly relevant
series covering real estate credit concession, interest rates, and
delinquency. Use broader levels to include macroeconomic context series.

Each series is downloaded in full, from its first published observation
to the present. Filter the returned `date` column to restrict the
window.
