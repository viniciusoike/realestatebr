# Download Units Data from Abecip

Internal function to download and process financed units data from
Abecip with robust error handling and retry logic.

## Usage

``` r
download_abecip_units(quiet = FALSE, max_retries = 3L)
```

## Arguments

- quiet:

  Logical controlling progress messages

- max_retries:

  Maximum number of retry attempts

## Value

A tibble with processed units data
