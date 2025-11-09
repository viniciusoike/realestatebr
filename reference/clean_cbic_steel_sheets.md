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

## Examples

``` r
if (FALSE) { # \dontrun{
steel_files <- get_cbic_files("aco")
steel_data <- clean_cbic_steel_sheets(steel_files)
} # }
```
