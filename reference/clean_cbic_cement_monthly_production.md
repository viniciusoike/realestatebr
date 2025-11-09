# Clean CBIC cement monthly production data (tabela_07.A.04)

**WARNING: This function only works for monthly production tables
(tabela_07.A.04).** Similar to consumption but uses "..." for missing
data.

## Usage

``` r
clean_cbic_cement_monthly_production(dat, year)
```

## Arguments

- dat:

  A data.frame. Raw data from Excel sheet

- year:

  Numeric. Year of the data

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

- value:

  Numeric. Production value (NA for missing)
