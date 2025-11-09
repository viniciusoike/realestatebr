# Finds import range for each table

Finds import range for each table

## Usage

``` r
get_range(path = NULL, sheet, skip_row = 4)
```

## Arguments

- path:

  Path to excel file

- sheet:

  Name or number of sheet to be analyzed

- skip_row:

  Additional argument passed to
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html)

## Details

Based on the date column, finds the range to be imported.
