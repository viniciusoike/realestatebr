# Check if Debug Mode is Enabled

Checks whether debug mode is enabled for detailed package messaging.
Debug mode can be enabled via environment variable or package option.

## Usage

``` r
is_debug_mode()
```

## Value

Logical. TRUE if debug mode is enabled, FALSE otherwise.

## Details

Debug mode can be enabled in two ways (checked in order of precedence):

1.  Environment variable: `REALESTATEBR_DEBUG=TRUE`

2.  Package option: `options(realestatebr.debug = TRUE)`

When debug mode is enabled, all detailed processing messages are shown,
including file-by-file progress, type detection, and intermediate steps.
This is useful for development and troubleshooting.
