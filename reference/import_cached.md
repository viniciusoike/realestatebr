# Import Cached Dataset (DEPRECATED)

**DEPRECATED**: This function loaded data from `inst/cached_data/` which
is no longer included in the package. Use
[`load_from_user_cache`](https://viniciusoike.github.io/realestatebr/reference/load_from_user_cache.md)
or
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
with `source="cache"` instead.

## Usage

``` r
import_cached(
  dataset_name,
  cache_dir = "cached_data",
  format = "auto",
  quiet = FALSE
)
```

## Arguments

- dataset_name:

  Character. Name of the cached dataset (without extension)

- cache_dir:

  Character. Path to cache directory (default: "cached_data")

- format:

  Character. File format ("auto", "rds", "csv"). If "auto", will try RDS
  first, then compressed CSV.

- quiet:

  Logical. Suppress informational messages (default: FALSE)

## Value

Dataset as tibble or list, depending on original structure

## See also

[`load_from_user_cache`](https://viniciusoike.github.io/realestatebr/reference/load_from_user_cache.md),
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
