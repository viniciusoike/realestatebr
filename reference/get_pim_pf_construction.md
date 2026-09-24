# Get PIM-PF Construction-input Production Index

Downloads and links the monthly IBGE physical-production index for
inputs typically used in construction. The historical series from SIDRA
table 2294 is rescaled to the 2022-reference series in table 8886 using
the ratio of their 2012 annual means.

## Usage

``` r
get_pim_pf_construction(quiet = FALSE, max_retries = 3L)
```

## Source

IBGE Pesquisa Industrial Mensal - Produção Física (PIM-PF), SIDRA tables
2294 and 8886

## Arguments

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

- max_retries:

  Integer. Maximum retry attempts. Defaults to 3.

## Value

A tibble containing one linked monthly index from January 1991.
