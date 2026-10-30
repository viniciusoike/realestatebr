# Resident population by municipality-year from IBGE

The estimates come from SIDRA table 6579 (variable 9324, População
residente estimada, the requested years only, localities
N6[all](https://rdrr.io/r/base/all.html); table and variable verified 25
Oct 2026), the 2022 Census count from table 4709 (variable 93, single
2022 period), and 2023 gets a linear midpoint between the 2022 Census
and the 2024 estimate (ties round to even, R's
[`round()`](https://rdrr.io/r/base/Round.html)). Dataset years without a
figure stay absent: the builder fills them with NA. `fetch` is
injectable for tests: the aggregate fetcher called as
`fetch(aggregate, variables, periods, localities)`.

## Usage

``` r
fetch_siconfi_population(
  years,
  fetch = download_ibge_aggregate,
  call = caller_env()
)
```

## Arguments

- years:

  Exercise years the dataset covers.

## Value

A tibble `code_muni` (character, 7 digits), `year` (integer),
`population` (integer), `population_source` ("estimate", "census",
"interpolated").
