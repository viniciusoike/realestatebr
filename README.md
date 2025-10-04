
<!-- README.md is generated from README.Rmd. Please edit that file -->

# Brazilian Real Estate

<!-- badges: start -->

<!-- badges: end -->

The goal of realestatebr is to facilitate the access to reports and
indicators on the Brazilian real estate market. This package currently
covers only the residential market but in the future it will also
encompass other real estate markets.

**Important**: This package is still under development but can already
be installed. Feedback is welcome.

## What's New in v0.4.0 🎉

**Major Breaking Changes - API Consolidation** - This release implements a unified interface:

- **Single Function Interface** - All 15+ individual `get_*()` functions consolidated into `get_dataset()`
- **Hierarchical Dataset Access** - Simplified access with `get_dataset("dataset_name", table = "table_name")`
- **Smart Fallback System** - Automatic fallback from GitHub cache → fresh download
- **Enhanced Error Handling** - Better troubleshooting and informative error messages
- **Internal Architecture** - 12 new internal fetch functions with consistent parameters

**⚠️ Breaking Change**: Individual `get_*()` functions have been removed. Use `get_dataset("dataset_name")` instead.

[See full migration guide](NEWS.md) for complete details.

## Installation

You can install the development version of realestatebr from
[GitHub](https://github.com/) with:

``` r
# install.packages("remotes")
remotes::install_github("viniciusoike/realestatebr")
```

## Getting Started

### Unified Interface (New in v0.4.0)

The package now provides a single, unified interface for accessing all datasets:

``` r
library(realestatebr)

# Discover available datasets
datasets <- list_datasets()
head(datasets)

# Get dataset information
info <- get_dataset_info("abecip")
str(info$tables)

# Get data with automatic fallback (GitHub cache → fresh download)
abecip <- get_dataset("abecip")
abecip
```

The unified interface provides several advantages:

- **Single function**: All data accessed through `get_dataset()`
- **Automatic fallback**: Tries GitHub cache first, then fresh download if needed
- **Hierarchical access**: Use `table` parameter for specific data tables
- **Smart caching**: Intelligent cache management with validation
- **Consistent API**: Standardized parameters across all datasets

``` r
# Get specific table only
sbpe <- get_dataset("abecip", table = "sbpe")
head(sbpe)

# Hierarchical access for RPPI datasets
fipezap <- get_dataset("rppi", table = "fipezap")

# Force fresh download
fresh_data <- get_dataset("bcb_realestate", source = "fresh")
```

### Migration from v0.3.x

**Breaking Change in v0.4.0**: Individual `get_*()` functions have been removed. Update your code:

``` r
# OLD (v0.3.x) - No longer works
# abecip_old <- get_abecip_indicators(table = "sbpe")

# NEW (v0.4.0) - Required migration
abecip_new <- get_dataset("abecip", table = "sbpe")

# Dataset name mapping
rppi_data <- get_dataset("rppi", table = "fipezap")  # was get_rppi_fipezap()
bcb_data <- get_dataset("bcb_realestate")            # was get_bcb_realestate()
```

See the [full migration guide](NEWS.md) for complete details.

## Available Datasets

The package provides access to comprehensive Brazilian real estate data
from multiple sources:

| Dataset | Source | Description | Geography |
|----|----|----|----|
| `abecip` | ABECIP | Housing credit data (SBPE flows, units, home equity) | Brazil |
| `abrainc` | ABRAINC/FIPE | Primary market indicators (launches, sales, business conditions) | Brazil (major cities) |
| `bcb_realestate` | BCB | Real estate credit and market data | Brazil (by state) |
| `secovi` | SECOVI-SP | São Paulo market indicators (fees, rentals, launches, sales) | São Paulo |
| `bis_rppi` | BIS | International residential property price indices | International (60+ countries) |
| `rppi` | Multiple | Property price indices for sales and rentals | Brazil (50+ cities) |
| `bcb_series` | BCB | Economic time series (price indices, credit, activity) | Brazil |
| `b3_stocks` | B3 | Real estate company stock data | Brazil |
| `fgv_indicators` | FGV | Real estate market indicators | Brazil |
| `cbic` | CBIC | Construction materials data (cement, steel, production) | Brazil |

``` r
# See all available datasets with details
available_data <- list_datasets()
print(available_data[, c("name", "source", "frequency", "coverage")])

# Filter by source
bcb_datasets <- list_datasets(source = "BCB")
print(bcb_datasets$name)
```

## Residential Property Price Indexes

There are several house price indices available in the Brazilian residential real estate market. All can be accessed through the unified `get_dataset()` interface:

``` r
# For better plots
library(ggplot2)
library(dplyr, warn.conflicts = FALSE)

# Get specific RPPI source
fipezap <- get_dataset("rppi", table = "fipezap")

# Filter Brazil data for recent period
rppi_brazil <- fipezap |>
  filter(name_muni == "Brazil", date >= as.Date("2019-01-01"))

ggplot(rppi_brazil, aes(date, index)) +
  geom_line(aes(color = market)) +
  scale_y_continuous(labels = scales::label_number()) +
  facet_wrap(~rent_sale) +
  theme_light()
```

International comparisons are also possible using the BIS data:

``` r
# Download BIS RPPI data
bis <- get_dataset("bis_rppi")

# Highlight some countries, show only real indices
bis_selected <- bis |>
  filter(
    reference_area %in% c("Australia", "Brazil", "Chile", "Japan", "United States"),
    is_nominal == FALSE,
    date >= as.Date("2000-01-01")
  )

ggplot(bis_selected, aes(date, value)) +
  geom_line(aes(color = reference_area)) +
  geom_hline(yintercept = 100) +
  theme_light() +
  theme(legend.position = "top")
```
