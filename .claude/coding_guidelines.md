# R Coding Guidelines

These conventions supplement the tidyverse style guide for new and refactored
code in `realestatebr`. Prefer consistency with nearby code when an unrelated
legacy section has not yet been modernized.

## Formatting and Names

- Format final R code with AIR by running `air format .`.
- Use `snake_case` for objects and functions. Functions should normally be
  verbs and data objects nouns.
- Use explicit package qualification inside package functions, such as
  `dplyr::filter()` and `readr::read_csv()`.
- Keep comments concise and explain intent or a non-obvious constraint.
- Use RStudio-style section headers: `# Section ----`,
  `## Subsection ----`, and `### Subsubsection ----`, with trailing dashes to
  approximately 76 characters.
- Do not use box-style comment headers with `====` borders.

## Functions

End nontrivial named functions with an explicit `return()`. A short helper or
single-line anonymous function may return implicitly.

```r
str_simplify <- function(x) {
  simplified <- stringr::str_to_lower(x)
  simplified <- stringr::str_replace_all(simplified, " ", "_")
  simplified <- stringr::str_squish(simplified)

  return(simplified)
}
```

Use `\(x) expression` for a single-line anonymous function. Use
`function(x) { ... }` when the body spans multiple lines.

Use `cli::cli_inform()`, `cli::cli_warn()`, and `cli::cli_abort()` for
user-facing conditions. Do not use `cat()` for user messages.

## Pipes and Transformations

- Use the native pipe (`|>`), never `%>%`.
- Do not use a pipe for a single function call.
- Keep pipe chains short, normally no more than five operations.
- Break substantial transformations into named intermediate objects.
- Read a source into an object before cleaning it.
- Keep joins and row binding separate from subsequent cleaning when either
  operation is substantial.
- Order operations logically: rename and select early, filter before expensive
  calculations, and derive columns after the relevant subset is established.

```r
raw <- readr::read_csv(source_path, show_col_types = FALSE)

selected <- raw |>
  dplyr::select(dplyr::all_of(cols_select)) |>
  dplyr::rename(dplyr::any_of(cols_rename))

filtered <- selected |>
  dplyr::filter(.data$year >= 2020)
```

When combining named datasets, use the `.id` argument instead of adding the
same identifier column repeatedly.

```r
series <- list(
  igmi = igmi,
  ivar = ivar,
  fipezap = fipezap
)

stacked <- dplyr::bind_rows(series, .id = "source")
```

## Column Selection and Joins

For programmatic selection and renaming, define character vectors and use
`all_of()` or `any_of()`.

```r
cols_select <- c("date", "name_muni", "index")
cols_rename <- c("name_muni" = "municipio")

selected <- data |>
  dplyr::select(dplyr::all_of(cols_select)) |>
  dplyr::rename(dplyr::any_of(cols_rename))
```

Use `dplyr::join_by()` for new joins when the package's declared dependency
versions support it. Specify expected relationships or unmatched-row behavior
when they encode a data-quality invariant. Do not modernize stable joins only
for syntax consistency.

## Dataset Function Boundaries

Use these roles for new dataset implementations and substantial refactors.

| Prefix | Responsibility |
|---|---|
| `get_*` | Orchestrate parameters, retrieval, validation, metadata, and return |
| `download_*` | Perform network I/O and return a path or raw object |
| `clean_*` | Rename, parse, and clean without network access |
| `format_*` | Reshape when that work would make `clean_*` hard to follow |

Dataset-specific download functions should call the generic helpers in
`R/helpers_download.R`. They should not implement independent retries or call
`utils::download.file()` directly when a shared helper applies.

Prefix helpers used by only one dataset with that dataset name. Use a generic
name only when the helper is genuinely shared.

Common utility prefixes include the following.

| Prefix | Responsibility |
|---|---|
| `parse_*` | Convert individual values or narrow structures |
| `build_*` | Construct lookup tables, names, or helper objects |
| `validate_*` | Enforce parameters or data-quality invariants |
| `calculate_*` | Derive values from existing data |
| `standardize_*` | Harmonize values across sources |
| `resolve_*` | Map or look up a value |

## Local Variable Names

Use these names when they fit the object.

| Object | Name |
|---|---|
| Temporary file path | `temp_path` |
| Raw import | `raw` |
| Intermediate data frame | `df` or a descriptive stage name |
| Column selection vector | `cols_select` |
| Column rename mapping | `cols_rename` |
| Landing-page URL | `url_page` |
| Final download URL | `url` |

Do not prefix ordinary local variables with `.`. Reserve leading dots for
established interface conventions such as `.data` and `.by`, or for rare
module-level internal objects.

## Compatibility

The package currently supports R 4.1 and later. Do not assume a newer R or
dependency feature merely because it is installed locally. When using a recent
package API, verify that `DESCRIPTION` declares a compatible minimum version
or use an implementation supported by the existing dependency floor.
