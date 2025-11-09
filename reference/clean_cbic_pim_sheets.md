# Process CBIC PIM Excel sheets

Wrapper function to process PIM files. Currently handles only the
current methodology file (file 3), as files 1 and 2 are historical data
with discontinued methodologies.

## Usage

``` r
clean_cbic_pim_sheets(download_results, quiet = FALSE)
```

## Arguments

- download_results:

  A tibble. Output from import_cbic_files()

## Value

A list with the cleaned PIM data

## Examples

``` r
if (FALSE) { # \dontrun{
download_results <- import_cbic_files(pim_files)
pim_data <- clean_cbic_pim_sheets(download_results)
} # }
```
