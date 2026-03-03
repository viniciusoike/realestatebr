# Extract Download URL from Web Page

Scrapes a web page to find a download link using XPath or CSS selector.
Useful for datasets where the download URL is embedded in a web page.

## Usage

``` r
scrape_download_url(
  page_url,
  xpath = NULL,
  css = NULL,
  base_url = NULL,
  max_retries = 3,
  quiet = FALSE
)
```

## Arguments

- page_url:

  Character. URL of the page containing the download link.

- xpath:

  Character. XPath selector for the download link element. Should select
  an element with an `href` attribute.

- css:

  Character. CSS selector (alternative to xpath). Use either xpath or
  css, not both.

- base_url:

  Character. Base URL to prepend if link is relative. If NULL, attempts
  to extract from page_url.

- max_retries:

  Integer. Number of retry attempts.

- quiet:

  Logical. Suppress progress messages.

## Value

Character. Full download URL.

## Details

This function only extracts the URL - it does not download the file. Use
download_excel() or download_file() to download the extracted URL.
