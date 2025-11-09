# Download and Process BCB Real Estate Data with Retry Logic

Internal function to download and process BCB real estate data with
retry logic and proper error handling.

## Usage

``` r
download_and_process_bcb_data(quiet, max_retries)
```

## Arguments

- quiet:

  Logical controlling messages

- max_retries:

  Maximum number of retry attempts

## Value

Processed BCB real estate data tibble
