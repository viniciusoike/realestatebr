# Check if GitHub Cache is Up to Date

Compares local cache timestamp with GitHub release timestamp.

## Usage

``` r
is_cache_up_to_date(dataset_name)
```

## Arguments

- dataset_name:

  Character. Name of dataset

## Value

Logical. TRUE if local cache is up to date, FALSE if GitHub is newer, NA
if can't determine
