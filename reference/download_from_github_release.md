# Download Dataset from GitHub Release

Downloads a cached dataset from GitHub releases and saves to user cache.

## Usage

``` r
download_from_github_release(dataset_name, overwrite = FALSE, quiet = FALSE)
```

## Arguments

- dataset_name:

  Character. Name of dataset to download

- overwrite:

  Logical. Overwrite existing cached file (default: FALSE)

- quiet:

  Logical. Suppress messages

## Value

Dataset or NULL if download fails
