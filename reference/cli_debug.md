# Debug-Level Messaging

Displays informational messages only when debug mode is enabled. This
function is a wrapper around
[`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html)
that respects the debug mode setting.

## Usage

``` r
cli_debug(message, ...)
```

## Arguments

- message:

  Character string. The message to display.

- ...:

  Additional arguments passed to
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html).

## Details

This function should be used for detailed processing messages that are
useful for development and debugging but would be too verbose for
end-users. Messages are only shown when debug mode is enabled via
[`is_debug_mode()`](https://viniciusoike.github.io/realestatebr/reference/is_debug_mode.md).

## See also

[`is_debug_mode()`](https://viniciusoike.github.io/realestatebr/reference/is_debug_mode.md)
