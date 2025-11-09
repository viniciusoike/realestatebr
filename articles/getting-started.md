# Getting Started with realestatebr

## Installation

``` r
# Install from GitHub
remotes::install_github("viniciusoike/realestatebr")
```

## Quick Start

The realestatebr package provides a unified interface for accessing
Brazilian real estate data from multiple sources.

``` r
library(realestatebr)
library(dplyr)
library(ggplot2)
```

## Basic Usage

### Discovering Datasets

Use
[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
to see all available data:

``` r
# List all available datasets
datasets <- list_datasets()
head(datasets)

# Filter by source
bcb_data <- list_datasets(source = "BCB")
```

### Getting Data

All data is accessed through
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md):

``` r
# Get dataset (returns default table)
abecip <- get_dataset("abecip")
head(abecip)

# Get specific table
sbpe <- get_dataset("abecip", table = "sbpe")

# See available tables for a dataset
info <- get_dataset_info("abecip")
names(info$categories)
```

### Data Sources

Control where data comes from with the `source` parameter:

``` r
# Auto (default): Try GitHub cache first, fallback to fresh download
data <- get_dataset("secovi", source = "auto")

# GitHub cache only (faster, may be outdated)
cached <- get_dataset("secovi", source = "github")

# Fresh download (slower, always current)
fresh <- get_dataset("secovi", source = "fresh")
```

## Available Datasets

The package currently provides access to these datasets:

**Credit & Finance:** - **abecip**: Housing credit data (SBPE flows,
units, home equity) - **bcb_realestate**: Real estate credit and market
data from BCB

**Market Indicators:** - **abrainc**: Primary market indicators
(launches, sales, business conditions) - **secovi**: São Paulo market
data (condos, rentals, launches, sales)

**Price Indices:** - **rppi**: Brazilian property price indices
(FipeZap, IVGR, IGMI, IVAR, IQA, IQAIW, Secovi-SP) - **rppi_bis**:
International property price indices from BIS (60+ countries)

**Economic Data:** - **bcb_series**: Economic time series from BCB -
**cbic**: Cement consumption and production data

**Other:** - **fgv_ibre**: FGV economic indicators

Use
[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
to see the full list with details.

## Example Workflows

### Example 1: Housing Credit Analysis

``` r
# Get SBPE housing credit data
sbpe <- get_dataset("abecip", table = "sbpe")

# Plot net flow over time
ggplot(sbpe, aes(x = date, y = sbpe_netflow)) +
  geom_line(color = "steelblue") +
  labs(title = "SBPE Net Flow",
       x = NULL,
       y = "R$ (millions)") +
  theme_minimal()
```

### Example 2: Real Estate Credit by State

``` r
# Get BCB real estate data
bcb <- get_dataset("bcb_realestate")

# Aggregate credit by date
credit_data <- bcb |>
  filter(category == "credito", type == "estoque") |>
  summarise(total = sum(value, na.rm = TRUE), .by = date)

# Plot
ggplot(credit_data, aes(x = date, y = total)) +
  geom_line(color = "steelblue") +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Total Real Estate Credit Stock",
       x = NULL,
       y = "R$ (billions)") +
  theme_minimal()
```

### Example 3: São Paulo Market Data

``` r
# Get Secovi São Paulo data
secovi <- get_dataset("secovi")

# See available categories
info <- get_dataset_info("secovi")
names(info$categories)

# Get specific categories
condo_fees <- get_dataset("secovi", table = "condo")
rental_data <- get_dataset("secovi", table = "rent")
```

## Working with Multi-Table Datasets

Some datasets have multiple tables (categories). Use
[`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
to explore:

``` r
# Get dataset structure
info <- get_dataset_info("cbic")

# See available tables
names(info$categories)

# Access specific tables
cement_monthly <- get_dataset("cbic", table = "cement_monthly_consumption")
cement_prices <- get_dataset("cbic", table = "cement_cub_prices")
```

## Controlling Output

### Verbosity

``` r
# Show progress messages (default)
data <- get_dataset("abecip", quiet = FALSE)

# Suppress messages
data <- get_dataset("abecip", quiet = TRUE)
```

### Error Handling

The package provides informative error messages:

``` r
# Invalid dataset name
get_dataset("invalid_name")
#> Error: Dataset 'invalid_name' not found
#> ℹ Available datasets: abecip, abrainc, bcb_realestate, ...
#> ℹ Use list_datasets() to see all available datasets

# Invalid table
get_dataset("abecip", table = "wrong_table")
#> Error: Table 'wrong_table' not found for dataset 'abecip'
#> ℹ Available tables: sbpe, units, cgi
```

## Migration from v0.3.x

**Breaking Change in v0.4.0**: Individual `get_*()` functions have been
removed.

``` r
# OLD (v0.3.x) - No longer works
# abecip_old <- get_abecip_indicators(table = "sbpe")

# NEW (v0.4.0) - Use get_dataset()
abecip_new <- get_dataset("abecip", table = "sbpe")
```

See [NEWS.md](https://viniciusoike.github.io/realestatebr/NEWS.md) for
complete migration details.

## Next Steps

- See
  [`vignette("working-with-rppi")`](https://viniciusoike.github.io/realestatebr/articles/working-with-rppi.md)
  for detailed property price index guide
- Use
  [`?get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
  for full documentation
- Visit the [package
  website](https://viniciusoike.github.io/realestatebr/) for more
  examples
