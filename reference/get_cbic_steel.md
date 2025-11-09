# Get CBIC steel data (prices and production)

Complete workflow to get cleaned steel price and production data from
CBIC. Returns steel price data by default, or all datasets when
requested.

## Usage

``` r
get_cbic_steel(
  table = "prices",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
)
```

## Arguments

- table:

  Character. Which dataset to return: "prices", "production", or "all"
  (default: "prices")

- cached:

  Logical. If TRUE, try to load data from cache first (default: FALSE)

- quiet:

  Logical. If TRUE, suppress progress messages (default: FALSE)

- max_retries:

  Integer. Maximum number of retry attempts for downloads (default: 3L)

## Value

A tibble with steel data, or a list if table = "all"

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
# Get steel prices (default)
prices <- get_cbic_steel()

# Get all steel datasets
all_steel <- get_cbic_steel(table = "all")

# Get production data with progress reporting
production <- get_cbic_steel(table = "production", quiet = FALSE)
} # }
```
