# Get Dataset with Fallback Strategy

Auto strategy: in-session memo -\> GitHub release -\> fresh download.

## Usage

``` r
get_dataset_with_fallback(name, dataset_info, table, quiet)
```

## Value

A list with elements `data` and `tier`, where `tier` names the source
that served the data.
