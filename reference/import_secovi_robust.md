# Import SECOVI Data with Robust Error Handling

Modern version of import_secovi with retry logic and progress reporting.

## Usage

``` r
import_secovi_robust(table, quiet, max_retries)
```

## Arguments

- table:

  Data table to import

- quiet:

  Logical controlling messages

- max_retries:

  Maximum number of retry attempts

## Value

List of scraped data tables
