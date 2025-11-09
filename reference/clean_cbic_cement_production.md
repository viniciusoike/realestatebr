# Clean CBIC cement production/consumption/export data (tabela_07.A.02)

**WARNING: This function only works for production tables
(tabela_07.A.02).** Simple year-based structure with multiple metrics as
columns.

## Usage

``` r
clean_cbic_cement_production(file_path)
```

## Arguments

- file_path:

  Character. Path to Excel file

## Value

A tibble with columns:

- year:

  Numeric. Year

- variable:

  Character. Metric name

- value:

  Numeric. Value
