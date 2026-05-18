# Resolve BCB Hierarchy Level to Series Codes

Maps a hierarchy level name to a vector of BCB series codes. The levels
are cumulative: "primary" includes all "core" series, "secondary"
includes all "primary" series, and so on.

## Usage

``` r
resolve_bcb_hierarchy(table)
```

## Arguments

- table:

  Character. One of "core", "primary", "secondary", "tertiary", "full",
  or "all".

## Value

Integer vector of BCB series codes.
