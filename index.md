# realestatebr <img src="man/figures/hexlogo.png" align="right" height="139" alt="" />

<!-- badges: start -->
<!-- badges: end -->

**realestatebr** is a comprehensive R package for accessing Brazilian real estate market data. Get property price indices, housing credit indicators, construction materials data, primary market statistics, and economic time series—all through a unified, consistent interface.

## Why realestatebr?

Brazilian real estate data is scattered across multiple sources, each with different formats, update schedules, and access methods. **realestatebr** solves this by:

- **Unified Access**: Single `get_dataset()` function for all 10+ data sources
- **Automatic Fallback**: Smart caching with GitHub → fresh download fallback
- **Clean Data**: Standardized column names and consistent date formats
- **Up-to-Date**: Regular updates via GitHub Actions workflow
- **Well Documented**: Comprehensive vignettes and examples for every dataset

## Key Features (v0.4.0)

### 🎯 Unified Interface

All datasets accessible through a single, consistent API:

```r
library(realestatebr)

# Discover what's available
datasets <- list_datasets()

# Get any dataset
abecip <- get_dataset("abecip")
rppi <- get_dataset("rppi", table = "fipezap")
```

### 📊 10+ Data Sources

Access data from Brazil's most authoritative sources:

| Category | Datasets |
|----------|----------|
| **Credit & Finance** | ABECIP housing credit, BCB real estate credit |
| **Price Indices** | FipeZap, IVGR, IGMI, IVAR, IQA, Secovi-SP, BIS international |
| **Market Indicators** | ABRAINC primary market, Secovi-SP São Paulo market |
| **Construction** | CBIC cement consumption and production |
| **Economic Data** | BCB economic time series |

### 🚀 Smart Data Access

Multiple data sources with automatic fallback:

```r
# Auto: Try cache first, fallback to fresh download
data <- get_dataset("bcb_realestate", source = "auto")

# GitHub: Fast cached data from GitHub
data <- get_dataset("bcb_realestate", source = "github")

# Fresh: Always download latest from source
data <- get_dataset("bcb_realestate", source = "fresh")
```

### 🔍 Easy Discovery

Built-in tools to explore available data:

```r
# See all datasets
list_datasets()

# Filter by source
list_datasets(source = "BCB")

# Get detailed info about a dataset
info <- get_dataset_info("rppi")
names(info$categories)  # See available tables
```

## Installation

Install the development version from GitHub:

```r
# install.packages("remotes")
remotes::install_github("viniciusoike/realestatebr")
```

## Quick Start

### Getting Housing Credit Data

```r
library(realestatebr)
library(dplyr)
library(ggplot2)

# Get SBPE housing credit flows
sbpe <- get_dataset("abecip", table = "sbpe")

# Visualize net flow over time
ggplot(sbpe, aes(x = date, y = netflow)) +
  geom_line(color = "steelblue", linewidth = 1) +
  labs(
    title = "SBPE Housing Credit Net Flow",
    subtitle = "Sistema Brasileiro de Poupança e Empréstimo",
    x = NULL,
    y = "R$ (millions)"
  ) +
  theme_minimal()
```

### Analyzing Property Prices

```r
# Get FipeZap property price index
fipezap <- get_dataset("rppi", table = "fipezap")

# Compare rent vs sale YoY changes in São Paulo
sp_data <- fipezap |>
  filter(
    name_muni == "São Paulo",
    market == "residential",
    rooms == "total",
    variable == "acum12m",
    date >= as.Date("2019-01-01")
  )

ggplot(sp_data, aes(x = date, y = value, color = rent_sale)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(
    title = "São Paulo Property Prices - Year-over-Year Change",
    subtitle = "Residential market - FipeZap Index",
    x = NULL,
    y = "YoY change (%)",
    color = "Market"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
```

### International Comparison

```r
# Get BIS international property price indices
bis <- get_dataset("rppi_bis")

# Compare Brazil with other countries
countries <- bis |>
  filter(
    reference_area %in% c("Brazil", "United States", "Japan"),
    is_nominal == FALSE,
    unit == "Index, 2010 = 100",
    date >= as.Date("2010-01-01")
  )

ggplot(countries, aes(x = date, y = value, color = reference_area)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 100) +
  labs(
    title = "Real Residential Property Prices - International",
    subtitle = "Deflated by CPI, 2010 = 100",
    x = NULL,
    y = "Index (2010 = 100)",
    color = "Country"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
```

## Available Datasets

### Credit & Finance

- **`abecip`** - ABECIP housing credit data
  - SBPE monetary flows (1982-present)
  - Financed units (2002-present)
  - Home equity loans (2017-present)

- **`bcb_realestate`** - BCB real estate market data
  - Credit accounting and applications
  - Market indices
  - State-level breakdowns

### Property Price Indices

- **`rppi`** - Brazilian residential property price indices
  - **FipeZap**: 20 cities, sale & rent (2011-present)
  - **IVGR**: National sales index (2001-present)
  - **IGMI**: Hedonic sales index (2010-present)
  - **IVAR**: National rent index (2008-present)
  - **IQA**: QuintoAndar rent prices (2020-present)
  - **Secovi-SP**: São Paulo market (2009-present)

- **`rppi_bis`** - BIS international property price indices
  - 60+ countries
  - Quarterly and monthly frequencies
  - Nominal and real indices

### Market Indicators

- **`abrainc`** - ABRAINC-FIPE primary market indicators
  - Launches, sales, deliveries
  - Business radar (0-10 index)
  - Leading indicators

- **`secovi`** - Secovi-SP São Paulo market
  - Condominium fees
  - Rental market
  - New launches
  - Sales data

### Construction & Economic

- **`cbic`** - CBIC construction materials
  - Cement consumption by state
  - Production and exports
  - CUB prices

- **`bcb_series`** - BCB economic time series
  - Price indices
  - Credit indicators
  - Economic activity

## Learn More

### Vignettes

Comprehensive guides for getting started and specialized topics:

- **[Getting Started](articles/getting-started.html)** - Package basics, main functions, and workflows
- **[Working with Property Price Indices](articles/working-with-rppi.html)** - Detailed RPPI guide with examples

### Documentation

- **[Function Reference](reference/index.html)** - Complete documentation for all functions
- **[News](news/index.html)** - Version history and changelog

## Data Sources & Citation

This package aggregates data from multiple authoritative sources:

- **ABECIP** - Associação Brasileira das Entidades de Crédito Imobiliário e Poupança
- **ABRAINC/FIPE** - Associação Brasileira de Incorporadoras / Fundação Instituto de Pesquisas Econômicas
- **Banco Central do Brasil (BCB)** - Brazilian Central Bank
- **BIS** - Bank for International Settlements
- **CBIC** - Câmara Brasileira da Indústria da Construção
- **FGV IBRE** - Fundação Getúlio Vargas / Instituto Brasileiro de Economia
- **FipeZap** - FIPE / ZAP Imóveis
- **Secovi-SP** - Sindicato da Habitação de São Paulo

When using this package in your research or publications, please cite both the package and the original data sources.

To cite the package:

```r
citation("realestatebr")
```

## What's New in v0.4.0?

Version 0.4.0 introduces major breaking changes with a unified interface:

- **🔧 Single Function API** - All data accessed via `get_dataset()`
- **📊 Hierarchical Access** - Simple `table` parameter for multi-table datasets
- **🚀 Smart Fallback** - Automatic GitHub cache → fresh download
- **✨ Better Errors** - Informative CLI-based error messages
- **🔄 Internal Architecture** - 12 new `fetch_*()` functions with consistent design

**Breaking Change**: Individual `get_*()` functions removed. Use `get_dataset("dataset_name")` instead.

See the [full migration guide](news/index.html) for details.

## Contributing

Contributions are welcome! Please feel free to:

- Report bugs or request features via [GitHub Issues](https://github.com/viniciusoike/realestatebr/issues)
- Submit pull requests for bug fixes or new features
- Improve documentation

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Maintainer**: Vinicius Oike Reginatto (viniciusoike@gmail.com)
**Website**: https://viniciusoike.github.io/realestatebr/
**Repository**: https://github.com/viniciusoike/realestatebr
