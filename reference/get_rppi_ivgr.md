# Get the IVGR Sales Index

Get the IVGR Sales Index

## Usage

``` r
get_rppi_ivgr(cached = FALSE, quiet = FALSE, max_retries = 3L)
```

## Arguments

- cached:

  Logical. If TRUE, loads from GitHub cache

- quiet:

  Logical. If TRUE, suppresses warnings

- max_retries:

  Integer. Maximum retry attempts for downloads

## Value

Tibble with columns: date, name_geo, index, chg, acum12m

## Details

The IVG-R (Residential Real Estate Collateral Value Index) is a monthly
median sales index based on bank appraisals, calculated by the Brazilian
Central Bank (BCB series 21340). The index estimates long-run trends in
home prices using the Hodrick-Prescott filter (lambda=3600) applied to
major metropolitan regions. Note: Median indices suffer from composition
bias and cannot account for quality changes across the housing stock.

## References

Banco Central do Brasil (2018) "Indice de Valores de Garantia de Imoveis
Residenciais Financiados (IVG-R). Seminario de Metodologia do IBGE."
