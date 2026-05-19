# Fallback to GitHub Cache on Download Failure

Attempts to load a dataset from the GitHub release cache when a primary
web download has failed. Returns NULL on miss so callers can decide
whether to abort or degrade gracefully.

## Usage

``` r
fallback_to_github_cache(dataset_name, quiet = FALSE)
```

## Arguments

- dataset_name:

  Character. Cache key used in GitHub releases (e.g., "bcb_realestate",
  "secovi_sp").

- quiet:

  Logical. If TRUE, suppresses messages.

## Value

A tibble if the GitHub cache is available, otherwise NULL.
