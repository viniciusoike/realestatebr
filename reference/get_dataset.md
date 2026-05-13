# Get Dataset

Unified interface for accessing all realestatebr datasets with automatic
fallback between data sources: user cache, GitHub releases, and fresh
download.

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

  Character. Dataset name (see
  [`list_datasets`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
  for options).

- table:

  Character. Specific table within a multi-table dataset. See
  [`get_dataset_info`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
  for available tables per dataset.

- source:

  Character. Data source preference:

  "auto"

  :   Automatic fallback: user cache, then GitHub releases, then fresh
      download (default).

  "cache"

  :   User cache only (`~/.local/share/realestatebr/`).

  "github"

  :   GitHub releases (requires the piggyback package).

  "fresh"

  :   Fresh download from the original source; result is saved to user
      cache.

- date_start:

  Date. Start date for time series filtering (where applicable).

- date_end:

  Date. End date for time series filtering (where applicable).

- max_age:

  Numeric. Maximum acceptable cache age in days. Cached data older than
  this threshold is skipped and fresh data is downloaded instead.

- ...:

  Additional arguments passed to internal dataset functions.

## Value

A tibble or named list, depending on the dataset. Use
[`get_dataset_info`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
to inspect the expected structure.

## See also

[`list_datasets`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
for available datasets,
[`get_dataset_info`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
for dataset details.

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

# Get BCB data from a specific start date
bcb_recent <- get_dataset("bcb_series", date_start = as.Date("2020-01-01"))
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
# }
```
