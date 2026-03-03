# Clean CBIC steel price data (file 1)

**WARNING: This function only works for steel price tables.** Steel data
has different structure than cement data.

## Usage

``` r
clean_cbic_steel_prices(file_path, skip_rows = 4)
```

## Arguments

- file_path:

  Character. Path to steel prices Excel file

- skip_rows:

  Numeric. Number of rows to skip when reading Excel

## Value

A tibble with columns:

- date:

  Date. Monthly date

- year:

  Numeric. Year

- code_state:

  Character. IBGE state code

- name_state:

  Character. State name

- avg_price:

  Numeric. Average steel price
