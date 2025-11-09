# Import Excel file links for a specific CBIC material

Import Excel file links for a specific CBIC material

## Usage

``` r
import_cbic_material_links(material_url, quiet = FALSE)
```

## Arguments

- material_url:

  Character vector of length 1. URL of the material page

## Value

A tibble with columns:

- title:

  Character. File title/description

- link:

  Character. Direct URL to Excel file

## Examples

``` r
if (FALSE) { # \dontrun{
cement_url <- "http://www.cbicdados.com.br/menu/materiais-de-construcao/cimento"
files <- import_cbic_material_links(cement_url)
} # }
```
