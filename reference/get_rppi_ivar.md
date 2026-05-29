# Get IVAR Rent Index

Get IVAR Rent Index

## Usage

``` r
get_rppi_ivar(quiet = FALSE, max_retries = 3L)
```

## Arguments

- quiet:

  Logical. If TRUE, suppresses warnings

- max_retries:

  Integer. Maximum retry attempts (not used for this data source)

## Value

Tibble with columns: date, name_muni, index, chg, acum12m,
name_simplified, abbrev_state

## Details

The IVAR (Residential Rent Variation Index) is a repeat-rent index from
IBRE/FGV, comparing the same housing unit over time. Based on rental
contracts from brokers. Available for 4 major cities (Sao Paulo, Rio,
Porto Alegre, Belo Horizonte); the national index is a weighted average.
More theoretically sound than IGP-M for rent contracts as it measures
only rent prices.

## Note

IVAR's underlying source (FGV) is not accessible via web scraping; when
the static `fgv_data` object is unavailable, this function falls back to
the package's GitHub release.
