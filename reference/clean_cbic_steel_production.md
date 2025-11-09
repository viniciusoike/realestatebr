# Clean CBIC steel production data (file 2)

**WARNING: This function only works for steel production tables.** This
handles complex multi-header Excel structure.

## Usage

``` r
clean_cbic_steel_production(file_path, skip_rows = 3)
```

## Arguments

- file_path:

  Character. Path to steel production Excel file

- skip_rows:

  Numeric. Number of rows to skip for headers

## Value

A tibble with columns:

- year:

  Numeric. Year

- product:

  Character. Steel product type

- variable:

  Character. Variable measured

- value:

  Numeric. Production value

## Examples

``` r
if (FALSE) { # \dontrun{
steel_files <- get_cbic_files("aco")
production <- clean_cbic_steel_production(steel_files$file_path[2])
} # }
```
