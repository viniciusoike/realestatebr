# Get Property Records Table

Imports and cleans specific tables from the most up to date property
transaction records available from Registro de Imoveis with modern error
handling, progress reporting, and robust download capabilities.

## Usage

``` r
get_property_records(
  table = "capitals",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
)
```

## Arguments

- table:

  Character. One of:

  "capitals"

  :   Records data for capital cities (default)

  "capitals_transfers"

  :   Transfer data for capital cities

  "cities"

  :   Records data for all cities

  "aggregates"

  :   Records data for SP regional aggregates

  "aggregates_transfers"

  :   Transfer data for SP aggregates

- cached:

  Logical. If `TRUE`, attempts to load data from package cache.

- quiet:

  Logical. If `TRUE`, suppresses progress messages and warnings. If
  `FALSE` (default), provides detailed progress reporting.

- max_retries:

  Integer. Maximum number of retry attempts for failed downloads.
  Defaults to 3.

## Value

A `tibble` with the requested property records table.

## Details

This function scrapes download links from the Registro de Imoveis
website and processes Excel files containing property transaction data.
The function handles multiple data categories and includes comprehensive
data cleaning.

## Progress Reporting

When `quiet = FALSE`, the function provides detailed progress
information including web scraping status, download progress, and data
processing steps.

## Error Handling

The function includes retry logic for failed downloads and robust error
handling for web scraping and Excel processing operations.
