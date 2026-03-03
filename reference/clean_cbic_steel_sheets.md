# Process CBIC steel Excel files

Handles both steel price and production files with appropriate cleaning.

## Usage

``` r
clean_cbic_steel_sheets(download_results, quiet = FALSE)
```

## Arguments

- download_results:

  A tibble. Output from import_cbic_files()

## Value

A list with 'prices' and 'production' data frames
