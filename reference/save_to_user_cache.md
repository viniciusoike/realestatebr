# Save Dataset to User Cache

Saves a dataset to the user-level cache directory.

## Usage

``` r
save_to_user_cache(data, dataset_name, format = "rds", quiet = FALSE)
```

## Arguments

- data:

  Dataset to cache

- dataset_name:

  Character. Name to save as

- format:

  Character. File format ("rds" or "csv.gz")

- quiet:

  Logical. Suppress messages

## Value

Logical. TRUE if successful
