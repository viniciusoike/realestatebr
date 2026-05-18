# Modern Error Handling in R: From `tryCatch` to `try_fetch`

A practical guide for transitioning from base R error handling to the
modern `rlang` and `purrr` alternatives.

## Why move away from `tryCatch`?

`tryCatch()` has been R's workhorse for error handling since the
beginning, but it has a fundamental design issue: it **unwinds the call
stack** before your handler runs. By the time you're inside the error
handler, the context where the error occurred is gone. This means:

- `rlang::last_trace()` and `traceback()` are useless.
- You can't inspect the state of the environment that errored.
- Wrapping errors with context (chaining) is awkward.

`rlang::try_fetch()` solves all three by catching conditions **before**
unwinding, while keeping the familiar handler interface.

## The Transition at a Glance

| Base R | Modern (rlang / purrr) | When to use |
|---|---|---|
| `tryCatch(expr, error = fn)` | `try_fetch(expr, error = fn)` | General error handling with context |
| `tryCatch(expr, warning = fn)` | `try_fetch(expr, warning = fn)` | Catching warnings |
| `try(expr)` | `try_fetch(expr, error = fn)` | Simple try-or-default |
| `tryCatch(..., finally = ...)` | `tryCatch(..., finally = ...)` | Cleanup / finalizers (keep base) |
| N/A | `purrr::possibly(fn, otherwise)` | Map safely over a vector |
| N/A | `purrr::safely(fn)` | Map and keep both results + errors |

> **Note:** `try_fetch()` does not support `finally`. If you need
> cleanup logic (closing connections, deleting temp files), keep using
> `tryCatch()` or `on.exit()` — which is usually the better choice
> anyway.

## Side-by-side Examples

### 1. Basic error recovery

```r
# Before
result <- tryCatch(
  log("not a number"),
  error = function(e) NA_real_
)

# After
result <- rlang::try_fetch(
  log("not a number"),
  error = function(cnd) NA_real_
)
```

Functionally identical for simple cases. The payoff comes when you need
to debug or chain.

### 2. Adding context with chained errors

This is where `try_fetch` really shines. Wrapping a low-level error with
a high-level message makes logs and user-facing errors dramatically more
useful.

```r
# Before — awkward and loses the original traceback
tryCatch(
  jsonlite::fromJSON("bad_file.json"),
  error = function(e) {
    stop(paste("Failed to read config:", e$message), call. = FALSE)
  }
)

# After — proper error chain, full traceback preserved
rlang::try_fetch(
  jsonlite::fromJSON("bad_file.json"),
  error = function(cnd) {
    rlang::abort(
      "Failed to read config file.",
      parent = cnd
    )
  }
)
```

When the chained error prints, you get:

```
Error in `rlang::try_fetch()`:
! Failed to read config file.
Caused by error in `parse_con()`:
! lexical error: invalid char in json text.
```

Both the **what** (your message) and the **why** (the original error)
are visible.

### 3. Catching specific condition classes

Custom condition classes let you handle different failure modes
differently — common in package development and data pipelines.

```r
# Signal a custom condition
my_read <- function(path) {
  if (!file.exists(path)) {
    rlang::abort(
      c("File not found.", i = "Looked for: {.path {path}}"),
      class = "my_pkg_file_not_found",
      path = path
    )
  }
  readLines(path)
}

# Catch only that specific class
rlang::try_fetch(
  my_read("nope.csv"),
  my_pkg_file_not_found = function(cnd) {
    cli::cli_warn("Missing file {.path {cnd$path}}, using default.")
    readLines("default.csv")
  }
  # Other errors propagate normally — no silent swallowing
)
```

### 4. Catching warnings without suppressing them

`tryCatch` for warnings is surprising: it catches the warning **and**
aborts the expression. `try_fetch` works the same way here (the
condition is caught and execution stops), but with better tracebacks.

If you want to **record** warnings without interrupting execution, use
`withCallingHandlers()` directly — that hasn't changed.

```r
# Record warnings, let execution continue
warnings <- list()
result <- withCallingHandlers(
  log(-1),
  warning = function(w) {
    warnings[[length(warnings) + 1]] <<- w
    invokeRestart("muffleWarning")
  }
)
```

## When to use `purrr::possibly()` and `purrr::safely()`

These are purpose-built for **mapping over vectors** where some elements
might fail. They're not general error-handling tools — think of them as
`try_fetch` pre-packaged for the map pattern.

### `possibly()` — fail gracefully, return a default

Use when you want to skip failures and move on.

```r
library(purrr)

urls <- c("https://httpbin.org/get", "not_a_url", "https://httpbin.org/ip")

# Without possibly: one failure kills the whole map
# With possibly: failures return the default, everything else runs
safe_get <- possibly(httr2::request, otherwise = NULL)

results <- urls |>
  map(safe_get) |>
  compact()  # drop NULLs
```

A common pattern with data files:

```r
read_if_exists <- possibly(readr::read_csv, otherwise = NULL)

all_data <- list.files("data/", "*.csv", full.names = TRUE) |>
  map(read_if_exists) |>
  compact() |>
  list_rbind()
```

### `safely()` — keep both results and errors

Use when you need to know **what** failed and **why**, not just skip it.

```r
safe_read <- safely(readr::read_csv)

outcomes <- list.files("data/", "*.csv", full.names = TRUE) |>
  set_names() |>
  map(safe_read)

# Each element is a list with $result and $error
successes <- outcomes |> map("result") |> compact() |> list_rbind()
failures  <- outcomes |> keep(~ !is.null(.x$error))

if (length(failures) > 0) {
  cli::cli_warn("Failed to read {length(failures)} file{?s}:")
  iwalk(failures, ~ cli::cli_bullets(c(x = "{.y}: {.x$error$message}")))
}
```

### Decision guide: `try_fetch` vs `possibly` vs `safely`

```
Are you mapping over a vector/list?
├── Yes
│   ├── Do you need to inspect the errors? → safely()
│   └── Just skip failures? → possibly()
└── No
    └── Use try_fetch()
```

## Patterns to Retire

### ❌ Silent `try()` with class check

```r
# Old pattern — fragile, no context
result <- try(some_func(), silent = TRUE)
if (inherits(result, "try-error")) {
  result <- fallback_value
}
```

Replace with:

```r
result <- rlang::try_fetch(
  some_func(),
  error = function(cnd) fallback_value
)
```

### ❌ Nested `tryCatch` for multiple error types

```r
# Old — deeply nested, hard to read
tryCatch(
  tryCatch(
    expr,
    my_custom_error = function(e) handle_custom(e)
  ),
  error = function(e) handle_generic(e)
)
```

Replace with:

```r
# Flat, readable, correct
rlang::try_fetch(
  expr,
  my_custom_error = function(cnd) handle_custom(cnd),
  error = function(cnd) handle_generic(cnd)
)
```

Handlers are matched in order — more specific classes first.

### ❌ `paste("Context:", e$message)` for wrapping

```r
# Old — loses the original error object and trace
tryCatch(expr, error = function(e) {
  stop(paste("While processing X:", e$message), call. = FALSE)
})
```

Replace with `parent` chaining as shown in example 2 above.

## Summary

- **Default choice:** `rlang::try_fetch()` — better tracebacks, error
  chaining, same ergonomics.
- **Mapping with tolerance:** `purrr::possibly()` (skip failures) or
  `purrr::safely()` (keep failures).
- **Cleanup logic:** Keep `on.exit()` or `tryCatch(..., finally = ...)`.
- **Record warnings without stopping:** Keep `withCallingHandlers()`.

The core mental model is simple: `try_fetch` for handling, `abort(parent
= cnd)` for chaining, `possibly`/`safely` for mapping. Everything else
stays the same.
