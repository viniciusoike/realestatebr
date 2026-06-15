# realestatebr 1.0.0

We are happy to announce that `realestatebr` 1.0.0 is the first version
of the package on CRAN. The goal of `realestatebr` is to provide a
unified interface to Brazilian real estate data from many public
sources, delivering everything in a tidy `tibble` format.

``` r

install.packages("realestatebr")
```

This release marks a milestone in how the package is used. The headline
change is the move from a long list of individual `get_*()` functions to
a single entry point,
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md).

## One function instead of many

Earlier versions exposed a separate function for each source. To read
financing data from ABECIP you called
[`get_abecip_indicators()`](https://viniciusoike.github.io/realestatebr/reference/get_abecip_indicators.md),
for the Central Bank series you called
[`get_bcb_series()`](https://viniciusoike.github.io/realestatebr/reference/get_bcb_series.md),
and so on. Every source had its own function, its own arguments, and its
own quirks.

``` r

# The old way, no longer available
abecip <- get_abecip_indicators(table = "sbpe")
bcb <- get_bcb_series(table = "price")
secovi <- get_secovi()
```

In 1.0.0 there is one function to learn.
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
takes the name of a dataset and, optionally, the name of a table within
it.

``` r

library(realestatebr)

# The new way
abecip <- get_dataset("abecip", table = "sbpe")
bcb <- get_dataset("bcb_series", table = "price")
secovi <- get_dataset("secovi")
```

When the `table` argument is omitted,
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
returns the default table for that dataset.

``` r

# Returns the default table
abecip <- get_dataset("abecip")
```

The individual `get_*()` functions are no longer part of the public
interface. The table below maps the most common ones to their
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
equivalent.

| Old function | New call |
|----|----|
| `get_abecip_indicators("sbpe")` | `get_dataset("abecip", "sbpe")` |
| [`get_abrainc_indicators()`](https://viniciusoike.github.io/realestatebr/reference/get_abrainc_indicators.md) | `get_dataset("abrainc")` |
| [`get_bcb_realestate()`](https://viniciusoike.github.io/realestatebr/reference/get_bcb_realestate.md) | `get_dataset("bcb_realestate")` |
| `get_bcb_series("price")` | `get_dataset("bcb_series", "price")` |
| [`get_secovi()`](https://viniciusoike.github.io/realestatebr/reference/get_secovi.md) | `get_dataset("secovi")` |
| `get_rppi("fipezap")` | `get_dataset("rppi", "fipezap")` |
| [`get_rppi_bis()`](https://viniciusoike.github.io/realestatebr/reference/get_rppi_bis.md) | `get_dataset("rppi_bis")` |

## Discovering what is available

Since the names of datasets and tables are now arguments, you need a way
to find them.
[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
returns a `tibble` describing every dataset, its source, and the tables
it contains.

``` r

datasets <- list_datasets()
datasets
```

The currently active datasets cover financing and credit, launches and
sales, macroeconomic series, and a wide range of residential property
price indices.

| Dataset | Source | Tables |
|----|----|----|
| `abecip` | ABECIP | `sbpe`, `units`, `cgi` |
| `abrainc` | ABRAINC / FIPE | `indicator`, `radar`, `leading` |
| `bcb_realestate` | Banco Central do Brasil | `accounting`, `application`, `indices`, `sources`, `units` |
| `bcb_series` | Banco Central do Brasil | `price`, `credit`, `production`, and others |
| `fgv_ibre` | FGV IBRE | — |
| `rppi` | FipeZap, IVG-R, IGMI-R, IQA, IVAR, SECOVI-SP | `sale`, `rent`, and individual indices |
| `rppi_bis` | Bank for International Settlements | `selected`, `detailed_monthly`, `detailed_quarterly` |
| `secovi` | SECOVI-SP | `condo`, `rent`, `launch`, `sale` |

## Choosing where data comes from

[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
resolves data in two tiers. By default it reads a pre-processed asset
from the package’s GitHub release, which is fast and updated
automatically by a weekly pipeline. If that asset is unavailable, it
falls back to a fresh download from the original source. The `source`
argument lets you control this behaviour.

``` r

# Auto (default): GitHub release, then fresh download as a fallback
data <- get_dataset("abecip")

# Pre-processed asset from the package's GitHub release
data <- get_dataset("abecip", source = "github")

# Fresh download straight from the original source
data <- get_dataset("abecip", source = "fresh")
```

Repeated calls within one R session are served from an in-memory store,
so asking for the same dataset twice does not download it twice. Use
[`clear_session_cache()`](https://viniciusoike.github.io/realestatebr/reference/clear_session_cache.md)
to drop that store without restarting R.

``` r

clear_session_cache()
```

This release also reworks the caching architecture so that the package
never writes outside the R session’s temporary directory, in line with
CRAN policy. The earlier user-level disk cache and its helper functions
have been removed.

## A worked example

The example below reads the FipeZap index and plots the year-on-year
change in sale and rent prices for the city of São Paulo.

``` r

library(dplyr)
library(ggplot2)

fipezap <- get_dataset("rppi", table = "fipezap")

rppi_spo <- fipezap |>
  filter(
    name_muni == "São Paulo",
    market == "residential",
    rooms == "total",
    variable == "acum12m",
    date >= as.Date("2019-01-01")
  )

ggplot(rppi_spo, aes(x = date, y = value, color = rent_sale)) +
  geom_line(lwd = 0.8) +
  geom_hline(yintercept = 0) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(
    title = "São Paulo Property Price Index",
    x = NULL,
    y = "YoY chg. (%)",
    color = ""
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
```

## Breaking changes

Consolidating the interface meant retiring a few datasets that could not
be maintained reliably. The `cbic`, `nre_ire`, `property_records`, and
`itbi` datasets have been removed. Some of these are deferred to a
future release once a stable upstream source is available.

The `bcb_series` and `rppi` datasets also changed shape. `bcb_series`
now returns a compact set of columns and accepts a hierarchy level such
as `"core"` or `"primary"` instead of a category name, while the stacked
`rppi` table gains `transaction_type` and `source` columns. See the
[changelog](https://viniciusoike.github.io/realestatebr/news/index.md)
for the full list.

## Learn more

To go further, read the [Getting
Started](https://viniciusoike.github.io/realestatebr/articles/getting-started.md)
article for a tour of the core interface, or [Working with
RPPI](https://viniciusoike.github.io/realestatebr/articles/working-with-rppi.md)
for a deeper look at the property price indices. Bug reports and
suggestions are welcome on
[GitHub](https://github.com/viniciusoike/realestatebr/issues).
