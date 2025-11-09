# Get Stacked RPPI Data

Get Stacked RPPI Data

## Usage

``` r
get_rppi(table = "sale", cached = FALSE, quiet = FALSE, max_retries = 3L)
```

## Arguments

- table:

  Character. "sale", "rent", or "all"

- cached:

  Logical. If TRUE, loads from GitHub cache

- quiet:

  Logical. If TRUE, suppresses messages

- max_retries:

  Integer. Maximum retry attempts

## Value

Tibble with columns: date, name_muni, index, chg, acum12m, source (plus
transaction_type if table="all")

## Details

Stacks multiple Brazilian residential property price indices into a
single tibble with consistent columns for easy comparison. Handles
different RPPI sources (IGMI-R, IVG-R, FipeZap, IVAR, IQA, Secovi-SP)
and standardizes their formats.

Note: IQA provides raw prices, not index numbers. Use
get_dataset("rppi", table) for individual indices.
