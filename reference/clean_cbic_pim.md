# Clean CBIC PIM industrial production data

Processes the PIM (Pesquisa Industrial Mensal) industrial production
index for construction materials. This data uses a unique structure with
Excel serial dates for January and month abbreviations for other months.

## Usage

``` r
clean_cbic_pim(file_path, skip = 4)
```

## Arguments

- file_path:

  Character. Path to the PIM Excel file

- skip:

  Numeric. Number of rows to skip (default = 4)

## Value

A tibble with columns:

- date:

  Date. Monthly date

- year:

  Numeric. Year

- month:

  Character. Month name

- value:

  Numeric. Production index (base: 2022 = 100)

## Examples

``` r
if (FALSE) { # \dontrun{
pim_data <- clean_cbic_pim("path/to/pim_file.xlsx")
} # }
```
