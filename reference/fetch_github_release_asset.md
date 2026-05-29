# Fetch a Cache Asset from GitHub Releases

Downloads a single asset from the package's `cache-latest` release into
a tempfile, reads it, and returns the deserialised object. Tries `.rds`
first, then `.csv.gz`. Returns `NULL` on miss (either format missing,
the release does not exist, or network failure).

## Usage

``` r
fetch_github_release_asset(cached_name, quiet = FALSE)
```

## Arguments

- cached_name:

  Character. Asset stem, e.g. `"abecip_sbpe"`.

- quiet:

  Logical. Suppress informational messages.

## Value

The deserialised dataset, or `NULL`.
