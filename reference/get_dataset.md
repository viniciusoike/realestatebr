# Get Dataset

Unified interface for accessing all realestatebr package datasets with
automatic fallback between different data sources (cache, GitHub, fresh
download).

## Usage

``` r
get_dataset(
  name,
  table = NULL,
  source = "auto",
  date_start = NULL,
  date_end = NULL,
  max_age = NULL,
  ...
)
```

## Arguments

- name:

  Character. Dataset name (see list_datasets() for available options)

- table:

  Character. Specific table within dataset (optional). Use
  get_dataset_info(name) to see available tables.

- source:

  Character. Data source preference:

  "auto"

  :   Automatic fallback: user cache → GitHub releases → fresh (default)

  "cache"

  :   User cache only (stored in ~/.local/share/realestatebr/)

  "github"

  :   Download from GitHub releases (requires piggyback package)

  "fresh"

  :   Fresh download from original source (saves to user cache)

- date_start:

  Date. Start date for time series data (where applicable)

- date_end:

  Date. End date for time series data (where applicable)

- max_age:

  Numeric. Optional. Maximum acceptable cache age in days. If specified,
  cached data older than this will be skipped and fresh data will be
  downloaded. This is an **advanced parameter** for users who need very
  recent data. Most users don't need to set this - the package uses
  relaxed thresholds by default (weekly datasets: 14 days, monthly: 60
  days) and only warns when cache is significantly stale.

- ...:

  Additional arguments passed to internal functions

## Value

Dataset as tibble or list, depending on the dataset structure. Use
get_dataset_info(name) to see the expected structure.

## Debug Mode

The realestatebr package includes a comprehensive debug mode for
development and troubleshooting. Debug mode shows detailed processing
messages including file-by-file progress, data type detection, web
scraping steps, and more.

**Enable debug mode:**

- Environment variable:

  Set `REALESTATEBR_DEBUG=TRUE` in your environment

- Package option:

  Use `options(realestatebr.debug = TRUE)`

**Debug mode examples:**

    # Enable debug mode via environment variable
    Sys.setenv(REALESTATEBR_DEBUG = "TRUE")
    data <- get_dataset("cbic")  # Shows detailed processing messages

    # Enable debug mode via package option
    options(realestatebr.debug = TRUE)
    data <- get_dataset("rppi")  # Shows detailed processing messages

    # Disable debug mode
    options(realestatebr.debug = FALSE)
    # or
    Sys.unsetenv("REALESTATEBR_DEBUG")

**What debug mode shows:**

- File download progress and retry attempts

- Excel sheet processing steps

- Data type detection and validation

- Web scraping details and error handling

- Cache access and fallback operations

- Data cleaning and transformation steps

Debug mode is particularly useful when troubleshooting data access
issues, understanding complex dataset processing, or developing new
functionality.

## See also

[`list_datasets`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
for available datasets,
[`get_dataset_info`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
for dataset details

## Examples

``` r
if (FALSE) { # \dontrun{
# Get all ABECIP indicators (default table)
abecip_data <- get_dataset("abecip")

# Get only SBPE data from ABECIP
sbpe_data <- get_dataset("abecip", "sbpe")

# Force fresh download
fresh_data <- get_dataset("bcb_realestate", source = "fresh")

# Get BCB data for specific time period
bcb_recent <- get_dataset("bcb_series",
                         date_start = as.Date("2020-01-01"))

# Advanced: Force very fresh data (< 1 day old)
very_fresh <- get_dataset("bcb_series", max_age = 1)

# Advanced: Only use cache if less than 3 days old
recent_data <- get_dataset("rppi", table = "sale", max_age = 3)
} # }
```
