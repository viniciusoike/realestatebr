# Update Cache from GitHub

Updates local cache for specific datasets if GitHub has newer versions.

## Usage

``` r
update_cache_from_github(dataset_names = NULL, quiet = FALSE)
```

## Arguments

- dataset_names:

  Character vector. Datasets to update, or NULL for all

- quiet:

  Logical. Suppress messages

## Value

Named logical vector indicating success/failure for each dataset

## Examples

``` r
if (FALSE) { # \dontrun{
# Update specific datasets
update_cache_from_github(c("abecip", "bcb_series"))

# Update all cached datasets
update_cache_from_github()
} # }
```
