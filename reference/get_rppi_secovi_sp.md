# Get Secovi-SP Rent Index

Get Secovi-SP Rent Index

## Usage

``` r
get_rppi_secovi_sp(cached = FALSE, quiet = FALSE, max_retries = 3L)
```

## Arguments

- cached:

  Logical. If TRUE, loads from GitHub cache

- quiet:

  Logical. If TRUE, suppresses warnings

- max_retries:

  Integer. Maximum retry attempts

## Value

Tibble with columns: date, name_muni, index, chg, acum12m

## Details

Secovi-SP rent price index for São Paulo. Wrapper around get_secovi()
that extracts and formats rent price data as RPPI.
