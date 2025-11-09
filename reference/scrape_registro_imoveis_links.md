# Scrape Download Links from Registro de Imoveis Website

Internal function to scrape Excel file download links with retry logic.

## Usage

``` r
scrape_registro_imoveis_links(quiet, max_retries)
```

## Arguments

- quiet:

  Logical controlling messages

- max_retries:

  Maximum number of retry attempts

## Value

Character vector of download links or NULL if failed
