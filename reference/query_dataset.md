# Query a Large Dataset Lazily

Opens a large dataset as one or more lazy DuckDB tables. No observations
enter R memory until the query is explicitly collected with
[`dplyr::collect()`](https://dplyr.tidyverse.org/reference/compute.html).
Related tables returned in the same catalog share one database
connection and can be joined with standard dplyr verbs.

## Usage

``` r
query_dataset(name, table = NULL, version = "latest", quiet = FALSE)
```

## Arguments

- name:

  Character. Dataset identifier. See
  [`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
  for datasets whose `access_mode` is `"query"`.

- table:

  Character or `NULL`. Return one table when supplied. When `NULL`,
  return a named catalog containing every related table.

- version:

  Character. Immutable dataset version, or `"latest"` to use the version
  referenced by the latest manifest.

- quiet:

  Logical. If `TRUE`, suppress informational messages.

## Value

If `table` is supplied, a closable lazy `dbplyr` table. Otherwise, a
`realestatebr_query_dataset` catalog containing named lazy tables. Close
either result explicitly with
[`close()`](https://rdrr.io/r/base/connections.html) when it is no
longer needed.

## See also

[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
for datasets returned directly in memory.

## Examples

``` r
if (FALSE) { # interactive()
cno <- query_dataset("cno")
on.exit(close(cno))

works_sp <- cno$works |>
  dplyr::filter(.data$state == "SP")

result <- works_sp |>
  dplyr::inner_join(cno$areas, by = "cno") |>
  dplyr::collect()
}
```
