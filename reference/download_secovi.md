# Download raw SECOVI-SP indicator tables

Pages are requested one at a time with a short pause between them, and
each page is retried on its own. Indicators whose page cannot be read
are dropped with a warning; an error is raised only when no page can be
read.

## Usage

``` r
download_secovi(table, quiet, max_retries, delay = 0.5)
```

## Arguments

- table:

  Data table to import

- quiet:

  Logical controlling messages

- max_retries:

  Maximum number of retry attempts

- delay:

  Seconds to wait between page requests

## Value

Named list of scraped data tables
