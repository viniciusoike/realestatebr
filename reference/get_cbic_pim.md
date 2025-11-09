# Get CBIC PIM industrial production data

Complete workflow to get cleaned PIM (Pesquisa Industrial Mensal)
industrial production index data from CBIC. This data tracks the
physical production of typical construction industry inputs in Brazil.

## Usage

``` r
get_cbic_pim(
  table = "production_index",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
)
```

## Arguments

- table:

  Character. Which dataset to return: "production_index" or "all"
  (default: "production_index")

- cached:

  Logical. If TRUE, try to load data from cache first (default: FALSE)

- quiet:

  Logical. If TRUE, suppress progress messages (default: FALSE)

- max_retries:

  Integer. Maximum number of retry attempts for downloads (default: 3L)

## Value

A tibble with PIM production index data, or a list if table = "all"

## Details

The PIM data uses production index with base year 2022 = 100. The data
covers monthly observations from 2012 onwards. Note that files 1 and 2
available on CBIC website contain historical data with discontinued
methodologies and are not processed by this function.

## Progress Reporting

When `quiet = FALSE`, the function provides detailed progress
information about web scraping, file downloads, and data processing
steps.

## Error Handling

The function includes retry logic for failed downloads and robust error
handling for malformed Excel files.

## Examples

``` r
if (FALSE) { # \dontrun{
# Get production index data (default)
production <- get_cbic_pim()

# Get all PIM datasets
all_pim <- get_cbic_pim(table = "all")

# Get data with progress reporting
production <- get_cbic_pim(quiet = FALSE)
} # }
```
