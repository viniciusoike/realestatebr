# Download File to Temporary Location

Downloads a file from a URL to a temporary location with retry logic.
This is the core download function used by format-specific helpers.

## Usage

``` r
download_file(
  url,
  file_ext = ".xlsx",
  ssl_verify = TRUE,
  max_retries = 3,
  quiet = FALSE,
  desc = "file"
)
```

## Arguments

- url:

  Character. URL to download from.

- file_ext:

  Character. File extension (e.g., ".xlsx", ".csv").

- ssl_verify:

  Logical. Whether to verify SSL certificates. Set to FALSE for sites
  with problematic certificates.

- max_retries:

  Integer. Number of retry attempts.

- quiet:

  Logical. Suppress progress messages.

- desc:

  Character. Description for error messages.

## Value

Character. Path to downloaded temp file.

## Details

The function downloads to a temporary file created with
[`tempfile()`](https://rdrr.io/r/base/tempfile.html). The temp file will
be cleaned up by R's session cleanup, but callers can explicitly
[`unlink()`](https://rdrr.io/r/base/unlink.html) if needed.
