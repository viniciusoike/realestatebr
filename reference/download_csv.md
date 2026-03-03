# Download CSV File

Downloads a CSV file to a temporary location with retry logic.

## Usage

``` r
download_csv(
  url,
  min_size = 100,
  ssl_verify = TRUE,
  max_retries = 3,
  quiet = FALSE
)
```

## Arguments

- url:

  Character. URL of the CSV file.

- min_size:

  Integer. Minimum file size in bytes. Default 100.

- ssl_verify:

  Logical. Whether to verify SSL certificates.

- max_retries:

  Integer. Number of retry attempts.

- quiet:

  Logical. Suppress progress messages.

## Value

Character. Path to downloaded CSV file.
