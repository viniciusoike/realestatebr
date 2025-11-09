# Get User Cache Directory

Returns the path to the user-level cache directory for realestatebr
package. This directory is used to store downloaded datasets for faster
subsequent access.

## Usage

``` r
get_user_cache_dir()
```

## Value

Character. Path to user cache directory

## Examples

``` r
if (FALSE) { # \dontrun{
cache_dir <- get_user_cache_dir()
print(cache_dir)
} # }
```
