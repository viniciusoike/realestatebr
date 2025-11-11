# Get the IRE Index (DEPRECATED)

Deprecated since v0.4.0. Use
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)("nre_ire")
instead. Loads the Real Estate Index (IRE) from NRE-Poli (USP) tracking
average stock prices of real estate companies in Brazil.

## Usage

``` r
get_nre_ire(table = "indicators", cached = TRUE, quiet = FALSE)
```

## Source

<https://www.realestate.br/site/conteudo/pagina/1,84+Indice_IRE.html>

## Arguments

- table:

  Character. Which dataset to return: "indicators" (default) or "all".

- cached:

  Logical. If `TRUE` (default), loads data from cache.

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

## Value

Tibble with NRE-IRE index data. Includes metadata attributes: source,
download_time.
