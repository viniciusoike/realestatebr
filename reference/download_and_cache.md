# Download and Cache Dataset

Unified function to download from GitHub and cache locally. This is a
convenience wrapper around download_from_github_release().

## Usage

``` r
download_and_cache(dataset_name, overwrite = FALSE, quiet = FALSE)
```

## Arguments

- dataset_name:

  Character. Name of dataset

- overwrite:

  Logical. Overwrite existing cache

- quiet:

  Logical. Suppress messages

## Value

Dataset or NULL
