# Getting Started with realestatebr

``` r

library(realestatebr)
library(dplyr)
library(ggplot2)
```

`realestatebr` provides a unified interface to Brazilian real estate
data from multiple public sources. All datasets are returned as tidy
`tibble` objects.

## Core Interface

Three functions cover most use cases.

**[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)**
returns a catalogue of all available datasets and their tables.

``` r

list_datasets()
```

**[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)**
retrieves any dataset by name. Without a `table` argument it returns the
default table; use `table` to select a specific sub-table.

``` r

# Default table
abecip <- get_dataset("abecip")

# Specific table
sbpe <- get_dataset("abecip", table = "sbpe")
```

**[`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)**
shows available tables and metadata for a given dataset.

``` r

info <- get_dataset_info("abecip")
names(info$categories)
#> [1] "sbpe"  "units"  "cgi"
```

## The `source` Argument

The `source` argument controls where data comes from. The default
(`"auto"`) checks the local cache first, then falls back to the GitHub
release. Typically, the best option is to use the default or `"github"`.

``` r

get_dataset("abecip", source = "cache")    # local cache (instant, works offline)
get_dataset("abecip", source = "github")   # GitHub release
get_dataset("abecip", source = "fresh")    # direct from the original source
```

Cache files are stored in the user data directory and can be inspected
with
[`list_cached_files()`](https://viniciusoike.github.io/realestatebr/reference/list_cached_files.md)
or cleared with
[`clear_user_cache()`](https://viniciusoike.github.io/realestatebr/reference/clear_user_cache.md).

## Example: Housing Credit Cycle

SBPE (Sistema Brasileiro de Poupança e Empréstimo) is the primary
funding vehicle for residential mortgages in Brazil. The table tracks
monthly inflows, outflows, and the resulting net credit flow.

``` r

sbpe <- get_dataset("abecip", table = "sbpe")

# Annual net credit flow
sbpe_annual <- sbpe |>
  filter(date >= as.Date("2019-01-01")) |>
  mutate(year = lubridate::year(date)) |>
  summarise(net_flow = sum(sbpe_netflow, na.rm = TRUE) / 1e3, .by = year)

ggplot(sbpe_annual, aes(year, net_flow)) +
  geom_col(fill = "steelblue", alpha = 0.9) +
  labs(
    title = "SBPE: Annual Net Housing Credit",
    x     = NULL,
    y     = "R$ billions"
  ) +
  theme_minimal()
```

The companion table `"units"` contains monthly counts of financed units
broken down by programme (SBPE, FGTS, CGI). Joining the two tables gives
a credit-per-unit metric:

``` r

units <- get_dataset("abecip", table = "units")

# SBPE units financed per year
units_annual <- units |>
  filter(date >= as.Date("2019-01-01")) |>
  mutate(year = lubridate::year(date)) |>
  summarise(sbpe_units = sum(units_total, na.rm = TRUE), .by = year)

# Implied credit per unit (R$ thousands)
sbpe_annual |>
  left_join(units_annual, by = "year") |>
  mutate(credit_per_unit = net_flow * 1e6 / sbpe_units) |>
  ggplot(aes(year, credit_per_unit)) +
  geom_line(color = "steelblue", linewidth = 0.9) +
  labs(
    title = "SBPE: Average Credit per Financed Unit",
    x     = NULL,
    y     = "R$ thousands"
  ) +
  theme_minimal()
```

## Example 2: Real Estate Credit Portfolio

The `bcb_realestate` dataset imports all real estate statistics from the
Brazilian Central Bank. This is a relatively large dataset and exploring
can be cumbersome. Each series is uniquely identified dy `date` and
`series_info`. Helper functions `v1`, `v2`, …, `v5`, `abbrev_state`,
`category`, and `type` are provided to simplify exploring the dataset.

``` r

bcb <- get_dataset("bcb_realestate")

# Get a specific series
sfh_pf <- bcb |>
  filter(series_info == "credito_estoque_carteira_credito_pf_sfh_br")

# Get all series for a specific category
# All credit lines for brazilian households
credit_stock <- bcb |>
  filter(
    category == "credito",
    type == "estoque",
    v1 == "carteira",
    v2 == "credito",
    v3 == "pf",
    v5 == "br"
  )

ggplot(credit_stock, aes(date, value)) +
  geom_area(aes(fill = v4), alpha = 0.9)
```

As a final warning, note that the `bcb_realestate` dataset follows the
`YYYY-MM-DD` format with the last day of the month (e.g. `2023-01-31`).
This can cause issues when merging with other datasets, since the first
day of the month is the more common date format. To avoid this, use
`lubridate::floor_date(date, 'month')`. Future versions of
`realestatebr` might provide this as a default behavior.

## Next Steps

- [`vignette("working-with-rppi")`](https://viniciusoike.github.io/realestatebr/articles/working-with-rppi.md)
  — property price indices in depth
- [`?get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
  — full parameter reference
