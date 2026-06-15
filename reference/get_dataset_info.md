# Get Dataset Information

Returns detailed metadata for a single dataset, including available
tables and source information.

## Usage

``` r
get_dataset_info(name)
```

## Arguments

- name:

  Character. Dataset identifier (see
  [`list_datasets`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
  for options).

## Value

A named list with the following elements:

- metadata:

  Title, description, geography, frequency, and coverage.

- categories:

  Available tables/subtables and their descriptions.

- source_info:

  Source organisation and URL.

- technical_info:

  Cached file names and translation notes.

## Examples

``` r
info <- get_dataset_info("abecip")
str(info)
#> List of 4
#>  $ metadata      :List of 7
#>   ..$ name       : chr "abecip"
#>   ..$ title      : chr "ABECIP Housing Credit Indicators"
#>   ..$ title_pt   : chr "Indicadores de Crédito Habitacional ABECIP"
#>   ..$ description: chr "Housing credit data from Brazilian housing finance system (SFH) including SBPE flows, financed units, and home equity loans"
#>   ..$ geography  : chr "Brazil"
#>   ..$ frequency  : chr "monthly"
#>   ..$ coverage   : chr "1982-present (varies by category)"
#>  $ categories    :List of 3
#>   ..$ sbpe :List of 3
#>   .. ..$ name       : chr "SBPE Monetary Flows"
#>   .. ..$ description: chr "Monetary flows from SBPE (Sistema Brasileiro de Poupança e Empréstimo)"
#>   .. ..$ coverage   : chr "January 1982-present"
#>   ..$ units:List of 3
#>   .. ..$ name       : chr "Financed Units"
#>   .. ..$ description: chr "Number of units financed by SBPE, split by construction and acquisition"
#>   .. ..$ coverage   : chr "January 2002-present"
#>   ..$ cgi  :List of 3
#>   .. ..$ name       : chr "Home Equity Loans (CGI)"
#>   .. ..$ description: chr "Summary data on home equity loans including default rates and average terms"
#>   .. ..$ coverage   : chr "January 2017-present"
#>  $ source_info   :List of 2
#>   ..$ source: chr "ABECIP - Associação Brasileira das Entidades de Crédito Imobiliário"
#>   ..$ url   : chr "https://www.abecip.org.br"
#>  $ technical_info:List of 3
#>   ..$ cached_file      :List of 3
#>   .. ..$ sbpe : chr "abecip_sbpe.rds"
#>   .. ..$ units: chr "abecip_units.rds"
#>   .. ..$ cgi  : chr "abecip_cgi.rds"
#>   ..$ metadata_table   : NULL
#>   ..$ translation_notes: chr "Column names translated from Portuguese to English following standard patterns"
```
