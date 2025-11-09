# Get the IGMI Sales Index

Get the IGMI Sales Index

## Usage

``` r
get_rppi_igmi(cached = FALSE, quiet = FALSE, max_retries = 3L)
```

## Arguments

- cached:

  Logical. If TRUE, loads from GitHub cache

- quiet:

  Logical. If TRUE, suppresses warnings

- max_retries:

  Integer. Maximum retry attempts for downloads

## Value

Tibble with columns: date, name_muni, index, chg, acum12m

## Details

The IGMI-R (Residential Real Estate Index) is a hedonic sales index
based on bank appraisal reports, available for Brazil + 10 capital
cities. Hedonic indices account for both composition bias and quality
differentials across the housing stock. Maintained by ABECIP in
partnership with FGV.
