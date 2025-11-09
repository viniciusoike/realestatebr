# Get the IRE Index (DEPRECATED)

Get the IRE Index (DEPRECATED)

## Usage

``` r
get_nre_ire(table = "indicators", cached = TRUE, quiet = FALSE)
```

## Source

Original series and methodology available at
<https://www.realestate.br/site/conteudo/pagina/1,84+Indice_IRE.html>.

## Arguments

- table:

  Character. Which dataset to return: "indicators" (default) or "all".

- cached:

  Logical. If `TRUE` (default), loads data from package cache using the
  unified dataset architecture. This is currently the only supported
  method for this dataset.

- quiet:

  Logical. If `TRUE`, suppresses progress messages and warnings. If
  `FALSE` (default), provides detailed progress reporting.

## Value

A tibble with 8 columns where:

- `ire` is the IRE Index.

- `ire_r50_plus` is the IRE Index of the top 50% companies.

- `ire_r50_minus` is the IRE Index of the bottom 50% companies.

- `ire_bi` is the IRE-BI Index (non-residential).

- `ibov` is the Ibovespa Index.

- `ibov_points` is the Ibovespa Index in points.

- `ire_ibov` is the ratio of the IRE Index and the Ibovespa Index.

The tibble includes metadata attributes:

- download_info:

  List with access statistics

- source:

  Data source used (cache)

- download_time:

  Timestamp of access

## Details

Downloads the Real Estate Index (IRE) from NRE-Poli (USP) tracking
average stock prices of real estate companies in Brazil. Values indexed
to 100 = May/2006.

## Deprecation

This function is deprecated since v0.4.0. Use
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)("nre_ire")
instead:

      # Old way:
      data <- get_nre_ire()

      # New way:
      data <- get_dataset("nre_ire")
