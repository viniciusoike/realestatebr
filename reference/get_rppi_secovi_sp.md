# Get Secovi-SP Rent Index

Get Secovi-SP Rent Index

## Usage

``` r
get_rppi_secovi_sp(quiet = FALSE, max_retries = 3L)
```

## Arguments

- quiet:

  Logical. If TRUE, suppresses warnings

- max_retries:

  Integer. Maximum retry attempts

## Value

Tibble with columns: date, name_muni, index, chg, acum12m

## Details

Secovi-SP rent price index for Sao Paulo. Wrapper around get_secovi()
that extracts and formats rent price data as RPPI.
