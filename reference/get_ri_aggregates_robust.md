# Get Aggregates Data with Robust Error Handling

Modern version of get_ri_aggregates with retry logic and progress
reporting.

## Usage

``` r
get_ri_aggregates_robust(url, quiet, max_retries)
```

## Arguments

- url:

  Download URL for the Excel file

- quiet:

  Logical controlling messages

- max_retries:

  Maximum retry attempts

## Value

Processed aggregates data
