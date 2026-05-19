# Download Abecip Excel File

Scrapes the given page to find the download link, then downloads the
Excel file using the shared
[`download_excel()`](https://viniciusoike.github.io/realestatebr/reference/download_excel.md)
helper.

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

  Prefix used in retry-attempt messages

- quiet:

  Logical controlling messages

- max_retries:

  Maximum number of retry attempts

## Value

Path to the downloaded temporary file
