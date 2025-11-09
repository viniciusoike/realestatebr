# Import all Excel files for a specific CBIC material

Import all Excel files for a specific CBIC material

## Usage

``` r
import_cbic_files(file_params, dest_dir = tempdir(), quiet = FALSE)
```

## Arguments

- file_params:

  A tibble. Output from import_cbic_material_links()

- dest_dir:

  Character vector of length 1. Destination directory

## Value

A tibble with download results including success status and file paths

## Examples

``` r
if (FALSE) { # \dontrun{
files <- import_cbic_material_links(cement_url)
results <- import_cbic_files(files)
} # }
```
