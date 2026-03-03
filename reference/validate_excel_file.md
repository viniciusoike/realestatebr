# Validate Excel File Download

Validates that a downloaded Excel file is valid and contains expected
sheets. Useful for datasets downloaded from Excel sources (e.g.,
Abrainc, Abecip).

## Usage

``` r
validate_excel_file(path, expected_sheets, min_size = 1000)
```

## Arguments

- path:

  Character. Path to the Excel file.

- expected_sheets:

  Character vector. Sheet names that must be present.

- min_size:

  Numeric. Minimum file size in bytes. Default 1000.

## Value

Invisible TRUE if all validations pass. Errors otherwise.
