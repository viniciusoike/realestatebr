# Download with Retry Logic

Executes a download function with automatic retry on failure. Uses
exponential backoff between retry attempts.

## Usage

``` r
download_with_retry(fn, max_retries = 3, quiet = FALSE, desc = "Download")
```

## Arguments

- fn:

  Function to execute (should return data on success)

- max_retries:

  Maximum number of retry attempts

- quiet:

  If TRUE, suppresses retry warnings

- desc:

  Description of what's being downloaded (for error messages)

## Value

Result from fn() if successful
