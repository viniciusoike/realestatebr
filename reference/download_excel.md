# Download and Validate Excel File

Downloads an Excel file with validation of expected sheets and file
size. Combines download_file() with validate_excel_file() from
helpers-dataset.R.

## Usage

``` r
download_excel(
  url,
  expected_sheets = NULL,
  min_size = 1000,
  ssl_verify = TRUE,
  max_retries = 3,
  quiet = FALSE
)
```

## Arguments

- url:

  Character. URL of the Excel file.

- expected_sheets:

  Character vector. Sheet names that must be present. If NULL, no sheet
  validation is performed.

- min_size:

  Integer. Minimum file size in bytes. Default 1000.

- ssl_verify:

  Logical. Whether to verify SSL certificates.

- max_retries:

  Integer. Number of retry attempts.

- quiet:

  Logical. Suppress progress messages.

## Value

Character. Path to downloaded and validated Excel file.
