# Fetch a Single Series from the BCB SGS API

Wraps
[`GetBCBData::gbcbd_get_series()`](https://rdrr.io/pkg/GetBCBData/man/gbcbd_get_series.html),
which splits long spans into windows the API accepts. SGS rejects
requests covering more than ten years of a daily series, so the split is
what makes full history reachable.

## Usage

``` r
fetch_sgs_series(code, first_date)
```

## Arguments

- code:

  Numeric. BCB series code.

- first_date:

  Date. First period to request.

## Value

A tibble with columns `date`, `value`, and `code_bcb`.

## Details

A window that returns no data yields a row with no reference date, which
happens for discontinued series whose last window falls after the final
observation. Those rows are dropped.
