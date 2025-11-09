# Get CBIC cement consumption data

Complete workflow to get cleaned cement consumption data from CBIC.
Includes annual, monthly, production, and CUB price data.

## Usage

``` r
get_cbic_cement(
  table = "monthly_consumption",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L,
  warn_level = "user"
)
```

## Arguments

- table:

  Character. Which dataset to return: "annual_consumption",
  "production_exports", "monthly_consumption", "monthly_production",
  "cub_prices", or "all" (default: "monthly_consumption")

- cached:

  Logical. If TRUE, try to load data from cache first (default: FALSE)

- quiet:

  Logical. If TRUE, suppress progress messages (default: FALSE)

- max_retries:

  Integer. Maximum number of retry attempts for downloads (default: 3L)

- warn_level:

  Character. Warning level for messages: "none", "user", or "dev".
  Defaults to "none" for internal use.

## Value

A tibble with cement data, or a list if table = "all"

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
# Get monthly consumption data (default)
monthly_data <- get_cbic_cement()

# Get all datasets
all_cement <- get_cbic_cement(table = "all")

# Get specific dataset with progress reporting
prices <- get_cbic_cement(table = "cub_prices", quiet = FALSE)
} # }
```
