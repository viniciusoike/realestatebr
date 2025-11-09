# Import CBIC materials metadata from main page

Scrapes the main CBIC materials page to extract information about all
available construction materials data.

## Usage

``` r
import_cbic_materials(quiet = FALSE)
```

## Value

A tibble with columns:

- title:

  Character. Material name

- description:

  Character. Material description

- link:

  Character. URL to material-specific page

## Examples

``` r
if (FALSE) { # \dontrun{
materials <- import_cbic_materials()
} # }
```
