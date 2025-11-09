# Download Abecip Excel File with Retry Logic

Internal helper function to download Excel files from Abecip website
with automatic retry on failure.

## Usage

``` r
download_abecip_file(
  url_page,
  xpath,
  file_prefix,
  quiet = FALSE,
  max_retries = 3L
)
```

## Arguments

- url_page:

  URL of the Abecip page containing the download link

- xpath:

  XPath to locate the download link

- file_prefix:

  Prefix for the temporary file name

- quiet:

  Logical controlling messages

- max_retries:

  Maximum number of retry attempts

## Value

Path to the downloaded temporary file
