# Get SINAPI Construction Costs and Indices

Downloads monthly SINAPI costs, indices, and percentage changes from
IBGE for Brazil, the five geographic regions, and all states. The result
includes series both with and without payroll-tax relief.

## Usage

``` r
get_sinapi(quiet = FALSE, max_retries = 3L)
```

## Source

IBGE Sistema Nacional de Pesquisa de Custos e Índices da Construção
Civil (SINAPI), SIDRA tables 2296 and 6586

## Arguments

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

- max_retries:

  Integer. Maximum retry attempts. Defaults to 3.

## Value

A tibble with monthly construction costs, indices, and percentage
changes by geography and payroll-relief treatment.
