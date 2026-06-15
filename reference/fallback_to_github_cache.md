# Fallback to GitHub Release on Download Failure

Attempts to load a dataset from the package's GitHub release when a
primary web download has failed. Returns NULL on miss so callers can
decide whether to abort or degrade gracefully.

## Usage

``` r
fallback_to_github_cache(dataset_name, quiet = FALSE)
```

## Arguments

- dataset_name:

  Character. Asset stem used in the GitHub release (e.g.,
  `"bcb_realestate"`, `"secovi_sp"`).

- quiet:

  Logical. If TRUE, suppresses messages.

## Value

A tibble if the GitHub release asset is available, otherwise NULL.
