# User-Level Messaging

Displays concise informational messages for end-users. This function
shows a simplified, clean message unless the user has requested verbose
output via the quiet parameter.

## Usage

``` r
cli_user(message, quiet = FALSE, ...)
```

## Arguments

- message:

  Character string. The message to display.

- quiet:

  Logical. If TRUE, suppresses the message.

- ...:

  Additional arguments passed to
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html).

## Details

This function should be used for essential status messages that provide
value to end-users, such as final results or major milestones. The
message is shown unless explicitly suppressed by quiet=TRUE.
