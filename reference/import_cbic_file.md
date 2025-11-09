# Import Excel file from CBIC with error handling

Import Excel file from CBIC with error handling

## Usage

``` r
import_cbic_file(url, dest_dir = tempdir(), delay = 1)
```

## Arguments

- url:

  Character vector of length 1. URL of the Excel file to download

- dest_dir:

  Character vector of length 1. Destination directory

- delay:

  Numeric vector of length 1. Delay between requests in seconds

## Value

Character vector of length 1. Path to downloaded file or NULL if failed

## Examples

``` r
if (FALSE) { # \dontrun{
url <- "http://www.cbicdados.com.br/media/anexos/example.xlsx"
file_path <- import_cbic_file(url)
} # }
```
