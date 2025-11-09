# Check if Cache is Stale

Determine if a cached dataset is older than its update schedule. Uses
relaxed thresholds by default (2x update frequency) to avoid annoying
users with unnecessary warnings.

## Usage

``` r
is_cache_stale(dataset_name, warn_after_days = NULL)
```

## Arguments

- dataset_name:

  Character. Name of dataset

- warn_after_days:

  Numeric. Override default warning threshold

## Value

Logical. TRUE if stale, FALSE if fresh, NA if can't determine
