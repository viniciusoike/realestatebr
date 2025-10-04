
<!-- README.md is generated from README.Rmd. Please edit that file -->

# realestatebr

<!-- badges: start -->

<!-- badges: end -->

The **realestatebr** package provides easy access to Brazilian real
estate market data from multiple authoritative sources. Access property
price indices, housing credit indicators, construction materials data,
and more—all through a unified, consistent interface.

## Installation

``` r
# install.packages("remotes")
remotes::install_github("viniciusoike/realestatebr")
```

## Quick Start

``` r
library(realestatebr)

# Discover available datasets
datasets <- list_datasets()

# Get housing credit data
abecip <- get_dataset("abecip")

# Get specific table
sbpe <- get_dataset("abecip", table = "sbpe")

# Get property price indices
rppi <- get_dataset("rppi", table = "fipezap")
```

## Available Datasets

The package provides access to 10+ datasets from authoritative sources:

| Dataset | Source | Description |
|----|----|----|
| `abecip` | ABECIP | Housing credit flows, financed units, home equity |
| `abrainc` | ABRAINC/FIPE | Primary market indicators (launches, sales) |
| `bcb_realestate` | BCB | Real estate credit and market data |
| `secovi` | SECOVI-SP | São Paulo market indicators |
| `rppi` | Multiple | Property price indices (sale/rent, 50+ cities) |
| `rppi_bis` | BIS | International property price indices (60+ countries) |
| `bcb_series` | BCB | Economic time series |
| `cbic` | CBIC | Cement consumption and production |

``` r
# See all datasets
list_datasets()

# Filter by source
list_datasets(source = "BCB")
```

## Example: Property Price Indices

``` r
library(ggplot2)
library(dplyr, warn.conflicts = FALSE)

# Get FipeZap index
fipezap <- get_dataset("rppi", table = "fipezap")

# Brazil national index
rppi_br <- fipezap |>
  filter(
    name_muni == "Brazil",
    market == "residential",
    rooms == "total",
    variable == "index",
    date >= as.Date("2019-01-01")
  )

ggplot(rppi_br, aes(x = date, y = value, color = rent_sale)) +
  geom_line() +
  labs(title = "Brazil Property Price Index",
       x = NULL, y = "Index") +
  theme_minimal()
```

## International Comparison

``` r
# Get BIS international data
bis <- get_dataset("rppi_bis")

# Compare countries
bis_compare <- bis |>
  filter(
    reference_area %in% c("Brazil", "United States", "Japan"),
    is_nominal == FALSE,
    date >= as.Date("2010-01-01")
  )

ggplot(bis_compare, aes(x = date, y = value, color = reference_area)) +
  geom_line() +
  labs(title = "Real Property Prices - International",
       x = NULL, y = "Index") +
  theme_minimal()
```

## What’s New

**v0.4.0** introduces a unified `get_dataset()` interface replacing all
individual `get_*()` functions. This is a breaking change. See
[NEWS.md](NEWS.md) for migration details.

## Learn More

- [Getting Started vignette](vignettes/getting-started.Rmd)
- [Working with RPPI vignette](vignettes/working-with-rppi.Rmd)
