# Clear the In-Session Dataset Memo

Drops every dataset memoised during the current R session. Useful when
iterating during development or to force re-fetch without restarting R.

## Usage

``` r
clear_session_cache()
```

## Value

`NULL`, invisibly.

## Examples

``` r
if (FALSE) { # interactive()
clear_session_cache()
}
```
