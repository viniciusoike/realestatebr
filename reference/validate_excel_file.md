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

## Details

Performs the following checks:

1.  File exists and is readable

2.  File size meets minimum threshold

3.  File is a valid Excel file (can read sheets)

4.  All expected sheets are present

This is particularly useful after download operations to ensure the
download completed successfully and the file structure is as expected.

## Examples

``` r
if (FALSE) { # \dontrun{
validate_excel_file(
  temp_path,
  expected_sheets = c("Indicadores Abrainc-Fipe", "Radar Abrainc-Fipe")
)
} # }
```
