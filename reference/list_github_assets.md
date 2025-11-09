# List Available GitHub Assets

Lists all cached datasets available on GitHub releases.

## Usage

``` r
list_github_assets(quiet = FALSE)
```

## Arguments

- quiet:

  Logical. Suppress messages

## Value

Character vector of available asset names, or NULL if unavailable

## Examples

``` r
if (FALSE) { # \dontrun{
assets <- list_github_assets()
print(assets)
} # }
```
