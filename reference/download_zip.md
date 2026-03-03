# Download and Extract File from ZIP Archive

Downloads a ZIP archive, extracts a file matching `file_pattern`,
validates its size, and returns the path to the extracted file.

## Usage

``` r
download_zip(
  url,
  file_pattern = "\\.csv$",
  min_size = 1000,
  ssl_verify = TRUE,
  max_retries = 3,
  quiet = FALSE
)
```

## Arguments

- url:

  Character. URL of the ZIP archive.

- file_pattern:

  Character. Regex pattern to match the target file inside the archive.
  Default `"\\.csv$"`.

- min_size:

  Integer. Minimum extracted file size in bytes. Default 1000.

- ssl_verify:

  Logical. Whether to verify SSL certificates.

- max_retries:

  Integer. Number of retry attempts.

- quiet:

  Logical. Suppress progress messages.

## Value

Character. Path to the extracted file.
