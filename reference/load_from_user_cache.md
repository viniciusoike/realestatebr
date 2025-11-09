# Load Dataset from User Cache

Loads a dataset from the user-level cache directory.

## Usage

``` r
load_from_user_cache(dataset_name, quiet = FALSE)
```

## Arguments

- dataset_name:

  Character. Name of the cached dataset

- quiet:

  Logical. Suppress informational messages (default: FALSE)

## Value

Dataset as tibble or list, or NULL if not found
