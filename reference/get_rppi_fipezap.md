# Get FipeZap RPPI

Get FipeZap RPPI

## Usage

``` r
get_rppi_fipezap(city = "all", cached = FALSE, quiet = FALSE, max_retries = 3L)
```

## Arguments

- city:

  City name or "all" (default). Filtering by city doesn't save
  processing time.

- cached:

  Logical. If TRUE, loads from GitHub cache

- quiet:

  Logical. If TRUE, suppresses warnings

- max_retries:

  Integer. Maximum retry attempts

## Value

Tibble with columns: date, name_muni, market, rent_sale, variable,
rooms, value

## Details

The FipeZap Index is a monthly median stratified index across ~20
Brazilian cities, based on online listings from Zap Imóveis. Includes
residential and commercial markets, both sale and rent, stratified by
number of rooms. The overall city index is a weighted sum of median
prices by room/region. Residential index includes only apartments,
studios, and flats. National index: `name_muni == 'Brazil'` (after
standardization).
