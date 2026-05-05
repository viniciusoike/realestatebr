# Get Dataset Information

Get detailed metadata for a specific dataset including available
categories and column descriptions.

## Usage

``` r
get_dataset_info(name)
```

## Arguments

- name:

  Character. Name of the dataset (use list_datasets() to see available
  names)

## Value

A list with detailed dataset information including:

- metadata:

  Basic dataset information

- categories:

  Available categories/subtables

- source_info:

  Data source details

## Examples

``` r
# Get detailed info for ABECIP indicators
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
