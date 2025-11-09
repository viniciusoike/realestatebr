# Clean CBIC cement CUB price data (tabela_07.A.05)

**WARNING: This function only works for CUB price tables
(tabela_07.A.05).** Year and month in first two columns, states as
remaining columns.

## Usage

``` r
clean_cbic_cement_cub(file_path)
```

## Arguments

- file_path:

  Character. Path to Excel file

## Value

A tibble with columns:

- date:

  Date. Monthly date

- year:

  Numeric. Year

- state:

  Character. State abbreviation

- value:

  Numeric. CUB cement price (R\$/kg)
