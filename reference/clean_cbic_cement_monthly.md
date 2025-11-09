# Clean CBIC cement monthly consumption data (tabela_07.A.03)

**WARNING: This function only works for monthly consumption tables
(tabela_07.A.03).** CBIC data is very messy and inconsistent. Each
material type likely needs its own cleaning function. Always inspect raw
data first before applying cleaning.

## Usage

``` r
clean_cbic_cement_monthly(dat, year, quiet = FALSE, warn_level = "user")
```

## Arguments

- dat:

  A data.frame. Raw data from Excel sheet with 'localidade' column

- year:

  Numeric vector of length 1. Year of the data

## Value

A tibble with columns:

- date:

  Date. Monthly date (first day of month)

- year:

  Numeric. Year

- code_state:

  Character. IBGE state code

- name_state:

  Character. State name

- value:

  Numeric. Cement consumption value

## Details

Processes raw cement consumption data from CBIC Excel files by removing
total rows/columns, pivoting to long format, and adding state codes.

## Examples

``` r
if (FALSE) { # \dontrun{
# Only works for monthly consumption tables!
cleaned_data <- clean_cbic_cement_monthly(raw_data, 2023)
} # }
```
