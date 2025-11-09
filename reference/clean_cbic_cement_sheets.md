# Process CBIC cement Excel sheets specifically

Routes to the appropriate cleaning function based on file type.

## Usage

``` r
clean_cbic_cement_sheets(
  download_results,
  skip_rows = 4,
  quiet = FALSE,
  warn_level = "user"
)
```

## Arguments

- download_results:

  A tibble. Output from import_cbic_files()

- skip_rows:

  Numeric vector of length 1. Number of rows to skip when reading Excel

## Value

A list of cleaned cement data frames, named by file type

## Examples

``` r
if (FALSE) { # \dontrun{
download_results <- import_cbic_files(cement_files)
processed_data <- clean_cbic_cement_sheets(download_results)
} # }
```
