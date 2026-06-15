# Get QuintoAndar Rental Index (IQA)

Get QuintoAndar Rental Index (IQA)

## Usage

``` r
get_rppi_iqa(cached = FALSE, quiet = FALSE, max_retries = 3L)
```

## Arguments

- cached:

  Logical. If TRUE, loads from GitHub cache

- quiet:

  Logical. If TRUE, suppresses warnings

- max_retries:

  Integer. Maximum retry attempts for downloads

## Value

Tibble with columns: date, name_muni, rent_price, chg, acum12m

## Details

The IQA (QuintoAndar Rental Index) is a median stratified index for Rio
de Janeiro and São Paulo, based on new rent contracts managed by
QuintoAndar. Includes only apartments, studios, and flats. Note: IQA
provides raw prices (not index numbers), so `rent_price` is the median
rent per square meter.
