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

  Source organization and URL.

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
#>   ..$ sbpe :List of 4
#>   .. ..$ name       : chr "SBPE Monetary Flows"
#>   .. ..$ description: chr "Monetary flows from SBPE (Sistema Brasileiro de Poupança e Empréstimo)"
#>   .. ..$ coverage   : chr "January 1982-present"
#>   .. ..$ columns    :List of 15
#>   .. .. ..$ date             : chr "Reference month."
#>   .. .. ..$ sbpe_inflow      : chr "Deposits into SBPE savings accounts during the month (R$ million; historical values in the currency of the period)."
#>   .. .. ..$ sbpe_outflow     : chr "Withdrawals from SBPE savings accounts during the month (R$ million)."
#>   .. .. ..$ sbpe_netflow     : chr "Net savings flow: inflow minus outflow (R$ million)."
#>   .. .. ..$ sbpe_netflow_pct : chr "Net flow as a share of the SBPE savings stock."
#>   .. .. ..$ sbpe_yield       : chr "Interest credited to SBPE savings accounts (R$ million)."
#>   .. .. ..$ sbpe_stock       : chr "End-of-month SBPE savings stock (R$ million)."
#>   .. .. ..$ rural_inflow     : chr "Deposits into rural savings accounts during the month (R$ million)."
#>   .. .. ..$ rural_outflow    : chr "Withdrawals from rural savings accounts during the month (R$ million)."
#>   .. .. ..$ rural_netflow    : chr "Net rural savings flow: inflow minus outflow (R$ million)."
#>   .. .. ..$ rural_netflow_pct: chr "Net rural flow as a share of the rural savings stock."
#>   .. .. ..$ rural_yield      : chr "Interest credited to rural savings accounts (R$ million)."
#>   .. .. ..$ rural_stock      : chr "End-of-month rural savings stock (R$ million)."
#>   .. .. ..$ total_stock      : chr "Combined SBPE and rural savings stock (R$ million)."
#>   .. .. ..$ total_netflow    : chr "Combined SBPE and rural net savings flow (R$ million)."
#>   ..$ units:List of 4
#>   .. ..$ name       : chr "Financed Units"
#>   .. ..$ description: chr "Number of units financed by SBPE, split by construction and acquisition"
#>   .. ..$ coverage   : chr "January 2002-present"
#>   .. ..$ columns    :List of 7
#>   .. .. ..$ date                 : chr "Reference month."
#>   .. .. ..$ units_construction   : chr "Number of units financed for construction."
#>   .. .. ..$ units_acquisition    : chr "Number of units financed for acquisition."
#>   .. .. ..$ units_total          : chr "Total number of financed units."
#>   .. .. ..$ currency_construction: chr "Value of construction financing (R$ million)."
#>   .. .. ..$ currency_acquisition : chr "Value of acquisition financing (R$ million)."
#>   .. .. ..$ currency_total       : chr "Total value of financing (R$ million)."
#>   ..$ cgi  :List of 4
#>   .. ..$ name       : chr "Home Equity Loans (CGI)"
#>   .. ..$ description: chr "Summary data on home equity loans including default rates and average terms"
#>   .. ..$ coverage   : chr "January 2017-present"
#>   .. ..$ columns    :List of 8
#>   .. .. ..$ year               : chr "Reference year."
#>   .. .. ..$ date               : chr "Reference month."
#>   .. .. ..$ new_contracts      : chr "Number of new home equity loan contracts signed in the month."
#>   .. .. ..$ stock_contracts    : chr "Number of outstanding contracts at the end of the month."
#>   .. .. ..$ loan               : chr "Value of new loans granted in the month (R$)."
#>   .. .. ..$ outstanding_balance: chr "Outstanding loan balance at the end of the month (R$)."
#>   .. .. ..$ average_term       : chr "Average contract term (months)."
#>   .. .. ..$ default_rate       : chr "Share of loans in default (percent)."
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
