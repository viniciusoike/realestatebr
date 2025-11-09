# Download Abrainc Excel File with Retry Logic

Internal function to download the Abrainc-Fipe Excel file with retry
attempts and proper error handling.

## Usage

``` r
download_abrainc_excel(max_retries, quiet)
```

## Arguments

- max_retries:

  Maximum number of retry attempts

- quiet:

  Logical controlling messages

## Value

List with path (character or NULL) and attempt count
