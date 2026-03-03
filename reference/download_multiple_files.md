# Download Multiple Files with Progress

Downloads multiple files from a list of URLs with progress reporting.
Useful for datasets with multiple source files (e.g., CBIC materials).

## Usage

``` r
download_multiple_files(
  urls,
  file_ext = ".xlsx",
  delay = 1,
  ssl_verify = TRUE,
  max_retries = 3,
  quiet = FALSE
)
```

## Arguments

- urls:

  Character vector. URLs to download.

- file_ext:

  Character. File extension for all files.

- delay:

  Numeric. Seconds to wait between downloads (rate limiting).

- ssl_verify:

  Logical. Whether to verify SSL certificates.

- max_retries:

  Integer. Number of retry attempts per file.

- quiet:

  Logical. Suppress progress messages.

## Value

List with two elements:

- paths: Character vector of successful download paths

- failed: Character vector of URLs that failed to download
