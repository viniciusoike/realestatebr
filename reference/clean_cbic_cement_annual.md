# Clean CBIC cement annual consumption data (tabela_07.A.01)

Clean CBIC cement annual consumption data (tabela_07.A.01)

## Usage

``` r
clean_cbic_cement_annual(file_path, sheet = 1)
```

## Arguments

- file_path:

  Character. Path to Excel file

- sheet:

  Character or numeric. Sheet to read

## Value

A tibble with columns:

- year:

  Numeric. Year

- region:

  Character. Region name

- value:

  Numeric. Annual consumption value

- variable:

  Character. Type of metric (consumption or growth)
