
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

## What’s New in v0.2.0 🎉

**Phase 1 Modernization Complete** - This major release modernizes all
core functions with:

- **Standardized API** - All functions now use `table` parameter.
  (replacing `category`) with backward compatibility. All functions now return `tibble` by default.
- **Unified Data Access** - New `list_datasets()` and `get_dataset()`
  functions for easy data discovery.
- **Better Performance** - Robust error handling, retry logic, and
  progress reporting.
- **New Data Sources** - CBIC construction materials data (cement,
  steel, production indices).

[See full changelog](NEWS.md) for complete details.

## Installation

You can install the development version of realestatebr from
[GitHub](https://github.com/) with:

``` r
# install.packages("remotes")
remotes::install_github("viniciusoike/realestatebr")
```

## Getting Started

### New Unified Interface (Recommended)

The package now provides a modern, unified interface for accessing all
datasets:

``` r
library(realestatebr)

# Discover available datasets
datasets <- list_datasets()
head(datasets)

# Get dataset information
info <- get_dataset_info("abecip_indicators")
str(info$categories)

# Get data with automatic fallback (GitHub cache → fresh download)
abecip <- get_dataset("abecip_indicators")
abecip
```

The unified interface provides several advantages:

- **Automatic fallback**: Tries GitHub cache first, then fresh download
  if needed
- **Consistent naming**: All datasets use standardized English column
  names
- **Easy discovery**: Use `list_datasets()` to see all available data
- **Category filtering**: Access specific parts of complex datasets

``` r
# Get specific category only
sbpe <- get_dataset("abecip_indicators", category = "sbpe")
head(sbpe)

# Force fresh download
fresh_data <- get_dataset("bcb_realestate", source = "fresh")
```

### Legacy Functions (Still Supported)

All existing `get_*` functions continue to work as before:

``` r
# Modern function interface (recommended)
abecip_modern <- get_abecip_indicators(table = "sbpe", cached = TRUE)

# Legacy interface still works with deprecation warning
abecip_legacy <- get_abecip_indicators(category = "sbpe", cached = TRUE)

head(abecip_modern)
```

## Available Datasets

The package provides access to comprehensive Brazilian real estate data
from multiple sources:

| Dataset | Source | Description | Geography |
|----|----|----|----|
| `abecip_indicators` | ABECIP | Housing credit data (SBPE flows, units, home equity) | Brazil |
| `abrainc_indicators` | ABRAINC/FIPE | Primary market indicators (launches, sales, business conditions) | Brazil (major cities) |
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

There are several house price indices available in the Brazilian
residential real estate market. The `get_rppi_*` functions collect all
of these indices. A general `get_rppi()` function

``` r
# For better plots
library(ggplot2)

# Download and clean all sales RPPIs
rppi <- get_rppi(category = "sale", stack = TRUE)
# Filter only Brazil
rppi_brazil <- subset(rppi, name_muni == "Brazil" & date >= as.Date("2019-01-01"))

ggplot(rppi_brazil, aes(date, acum12m)) +
  geom_line(aes(color = source)) +
  scale_y_continuous(labels = scales::label_percent()) +
  theme_light()
```

International comparisons are also possible using the BIS data

``` r
library(dplyr, warn.conflicts = FALSE)
# Download simplified BIS RPPI data
bis <- get_rppi_bis()
# Highlight some countries, show only real indices
bis_brasil <- bis |> 
  filter(
    country %in% c("Australia", "Brazil", "Chile", "Japan", "United States"),
    is_nominal == FALSE,
    date >= as.Date("2000-01-01")
    )

ggplot(bis_brasil, aes(date, index)) +
  geom_line(aes(color = country)) +
  geom_hline(yintercept = 100) +
  theme_light() +
  theme(legend.position = "top")
```
