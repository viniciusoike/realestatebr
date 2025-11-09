# Check Cache Status

Display status of all locally cached datasets. Uses relaxed staleness
thresholds (2x update frequency) to identify datasets that may benefit
from updating.

## Usage

``` r
check_cache_status(verbose = TRUE)
```

## Arguments

- verbose:

  Logical. Show detailed formatted output (default: TRUE)

## Value

Tibble with cache status information (invisibly)

## Examples

``` r
if (FALSE) { # \dontrun{
# Check which datasets might benefit from updating
check_cache_status()

# Get status table for programmatic use
status <- check_cache_status(verbose = FALSE)
old_datasets <- status[status$age_days > 30, ]
} # }
```
