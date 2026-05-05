# Clear User Cache

Removes cached datasets from user directory.

## Usage

``` r
clear_user_cache(dataset_names = NULL, confirm = TRUE)
```

## Arguments

- dataset_names:

  Character vector. Specific datasets to remove, or NULL for all

- confirm:

  Logical. Require confirmation (default: TRUE)

## Value

Logical. TRUE if successful

## Examples

``` r
# \donttest{
# Clear specific dataset
clear_user_cache("abecip")
#> Cache directory does not exist
#> [1] TRUE

# Clear all cache (with confirmation)
clear_user_cache()
#> Cache directory does not exist
#> [1] TRUE
# }
```
