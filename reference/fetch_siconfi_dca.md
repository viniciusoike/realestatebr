# Fetch all /dca items for one municipality-year

Follows pagination by advancing `offset` by the page's reported `limit`
while `hasMore` is true; every page must carry its declared `count` and
the requested `offset`, and the number of pages is capped: a truncated,
resent or misdirected response aborts instead of being silently parsed.
The default `request` also paces itself at at most one request per
second inside the retry loop.

## Usage

``` r
fetch_siconfi_dca(code_muni, year, request = NULL, call = caller_env())
```

## Arguments

- request:

  Injectable for tests: a callable taking a URL string and returning the
  parsed response body.
