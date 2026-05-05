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
    data <- get_dataset("bcb_series")  # Shows detailed processing messages

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
# \donttest{
# Get all ABECIP indicators (default table)
abecip_data <- get_dataset("abecip")
#> Checking user cache for abecip...
#> Created cache directory: ~/.cache/realestatebr
#> Dataset 'abecip_sbpe' not found in user cache
#> User cache not available: Dataset 'abecip' not found in cache
#> Attempting to download abecip from GitHub releases...
#> Attempting to download abecip_sbpe.rds from GitHub...
#> Downloaded abecip_sbpe.rds (0.03 MB)
#> Successfully downloaded from GitHub releases
#> Retrieved 'sbpe' from 'abecip' (default table). Available tables: 'sbpe',
#> 'units', 'cgi'

# Get only SBPE data from ABECIP
sbpe_data <- get_dataset("abecip", "sbpe")
#> Checking user cache for abecip...
#> Successfully loaded from user cache
#> Retrieved 'sbpe' from 'abecip'. Available tables: 'sbpe', 'units', 'cgi'

# Force fresh download
fresh_data <- get_dataset("bcb_realestate", source = "fresh")
#> Downloading real estate data from BCB API
#> Downloading real estate data from the Brazilian Central Bank.
#> Retrieved 'all' from 'bcb_realestate' (default table). Available tables:
#> 'accounting', 'application', 'indices', 'sources', 'units'

# Get BCB data for specific time period
bcb_recent <- get_dataset("bcb_series",
                         date_start = as.Date("2020-01-01"))
#> Checking user cache for bcb_series...
#> Dataset 'bcb_series' not found in user cache
#> User cache not available: Dataset 'bcb_series' not found in cache
#> Attempting to download bcb_series from GitHub releases...
#> Attempting to download bcb_series.rds from GitHub...
#> Downloaded bcb_series.rds (0.11 MB)
#> Successfully downloaded from GitHub releases
#> Retrieved 'all' from 'bcb_series' (default table). Available tables: 'price',
#> 'credit', 'production', 'interest-rate', 'exchange', 'government',
#> 'real-estate'

# Advanced: Force very fresh data (< 1 day old)
very_fresh <- get_dataset("bcb_series", max_age = 1)
#> Checking user cache for bcb_series...
#> Successfully loaded from user cache
#> Retrieved 'all' from 'bcb_series' (default table). Available tables: 'price',
#> 'credit', 'production', 'interest-rate', 'exchange', 'government',
#> 'real-estate'

# Advanced: Only use cache if less than 3 days old
recent_data <- get_dataset("rppi", table = "sale", max_age = 3)
#> Checking user cache for rppi...
#> Dataset 'rppi_sale' not found in user cache
#> User cache not available: Dataset 'rppi' not found in cache
#> Attempting to download rppi from GitHub releases...
#> Attempting to download rppi_sale.rds from GitHub...
#> Downloaded rppi_sale.rds (0.19 MB)
#> Successfully downloaded from GitHub releases
#> Retrieved 'sale' from 'rppi'. Available tables: 'fipezap', 'ivgr', 'igmi',
#> 'iqa', 'iqaiw', 'ivar', 'secovi_sp', 'sale', 'rent', 'all'
# }
```
