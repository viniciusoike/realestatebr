# Look Up the First Observation Date of a Series

Reads `first_value` from
[`bcb_metadata`](https://viniciusoike.github.io/realestatebr/reference/bcb_metadata.md)
so each series is requested from its own start rather than a shared
floor.

## Usage

``` r
bcb_series_first_date(code)
```

## Arguments

- code:

  Numeric. BCB series code.

## Value

A `Date`.
