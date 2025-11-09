# Get CBIC Data (Unified Interface)

Main wrapper function for accessing CBIC construction materials data
through the unified get_dataset() interface. This function handles the
complex multi-material, multi-table structure of CBIC data by flattening
it into a consistent single-tibble API.

## Usage

``` r
get_cbic(
  table = "cement_monthly_consumption",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L,
  warn_level = "none"
)
```

## Arguments

- table:

  Character. Which specific table to retrieve. Options include:

  cement_monthly_consumption

  :   Monthly cement consumption by state (default)

  cement_annual_consumption

  :   Annual cement consumption by region

  cement_production_exports

  :   Production, consumption, and export data

  cement_monthly_production

  :   Monthly cement production by state

  cement_cub_prices

  :   CUB cement prices by state

  steel_prices

  :   Steel prices by state

  steel_production

  :   Steel production data

  pim

  :   Industrial production index for construction materials

- cached:

  Logical. If TRUE, try to load data from cache first

- quiet:

  Logical. If TRUE, suppress progress messages

- max_retries:

  Integer. Maximum number of retry attempts for downloads

- warn_level:

  Character. Warning level for messages: "none", "user", or "dev".
  Defaults to "none" for internal use.

## Value

A tibble with the requested CBIC data
