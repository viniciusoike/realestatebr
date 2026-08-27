# realestatebr Development Guide

## Package

`realestatebr` is an R package for reliable, documented access to
Brazilian real estate data. Version 1.0.1 is on CRAN; the development
version is 1.0.1.9000. The main branch is `main`.

Active datasets are ABECIP, ABRAINC, BCB series, BCB real estate, FGV
IBRE, SECOVI, Brazilian sale and rent RPPIs, and BIS RPPIs. The registry
at `inst/extdata/datasets.yaml` is the source of truth for dataset
metadata, tables, cache assets, and internal functions.

## Working Principles

- Prefer simple, readable changes over clever abstractions.
- Treat questions as read-only requests. Edit files only when
  implementation is explicitly requested or agreed upon.
- Preserve unrelated changes in a dirty worktree.
- Validate data before it is returned, cached, or published.
- Keep the public interface simple and make expensive operations
  visible.
- Use appropriate user agents and rate limits when scraping.
- Preserve source attribution in data and documentation.

## Architecture

The primary user interface consists of the following functions.

- [`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
  for discovery.
- [`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
  for registry metadata.
- [`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
  for data access.
- [`clear_session_cache()`](https://viniciusoike.github.io/realestatebr/reference/clear_session_cache.md)
  for clearing the in-memory memo.

`get_dataset(source = "auto")` resolves data through three tiers.

1.  The package-private in-session memo.
2.  Preprocessed assets from the `cache-latest` GitHub release.
3.  A fresh download from the original source.

The package does not create a persistent user cache. Downloads use
temporary files to comply with CRAN filesystem policy.
`R/cache_github.R` implements the GitHub release client and memo;
`R/get_dataset.R` implements source resolution.

Shared infrastructure lives in the following files and directories.

- `R/helpers_download.R` for retry and download operations.
- `R/helpers_dataset.R` for parameter, metadata, and data validation.
- `R/rppi_helpers.R` for shared RPPI calculations.
- `inst/extdata/datasets.yaml` for the dataset registry.
- `data-raw/pipeline/` for pipeline validation and cache publication
  helpers.

Dataset-specific files under `R/` should delegate common work to these
helpers. Do not add another retry loop, download wrapper, metadata
convention, or cache implementation when the shared infrastructure
already covers it.

## Dataset Pipeline

The `targets` pipeline fetches fresh data, validates it, and writes
staged artifacts to the git-ignored `data-raw/cache_output/` directory.
GitHub Actions uploads those artifacts to the `cache-latest` release.

Weekly datasets use a six-day staleness cue. BIS RPPI is updated
monthly. FGV IBRE and ABECIP CGI require manually supplied source files
but are processed by the same pipeline.

When adding a conventional dataset, follow these steps.

1.  Add or update its dataset-specific implementation in `R/`.
2.  Register it in `inst/extdata/datasets.yaml`.
3.  Add its pipeline targets in `_targets.R`.
4.  Add user documentation and the relevant `_pkgdown.yml` entry.
5.  Add focused tests under `tests/testthat/`.
6.  Validate the staged artifact before publication.

Large microdata may require a different storage and query contract. Do
not force a large dataset through the in-memory RDS and memo
architecture without an explicit design decision.

## R Coding Conventions

Follow [the project coding
guide](https://viniciusoike.github.io/realestatebr/.claude/coding_guidelines.md).
The main rules are listed below.

- Follow the tidyverse style guide and use the native pipe (`|>`).
- Use explicit package qualification inside package functions.
- Use `cli` for user-facing messages, warnings, and errors.
- End nontrivial named functions with an explicit
  [`return()`](https://rdrr.io/r/base/function.html).
- Separate downloading, reading, cleaning, joining, and substantial
  transformations into readable steps.
- Format final R code with AIR.
- Use RStudio-style section headers with trailing dashes, never
  box-style `====` headers.

## Tests and Documentation

- Put tests for `R/name.R` in `tests/testthat/test-name.R` or beside the
  most closely related existing tests.
- Add focused tests for new behavior and regressions.
- Prefer specific expectations over `expect_true()` and
  `expect_false()`.
- Snapshot complete errors and warnings when their user-facing text
  matters.
- Document every exported function with roxygen2.
- Run `devtools::document()` after changing roxygen comments.
- Add new public documentation topics to `_pkgdown.yml`.
- Add a concise `NEWS.md` bullet for user-facing changes. Do not add one
  for a purely internal refactor or a small documentation correction.

## Commands

Run focused checks first and broaden verification in proportion to the
change.

``` r

devtools::load_all()
devtools::test(filter = "name")
devtools::test()
devtools::document()
pkgdown::check_pkgdown()
devtools::check()
```

Format generated or modified R code with this command.

``` sh
air format .
```

Useful pipeline commands include the following.

``` r

targets::tar_manifest()
targets::tar_outdated()
targets::tar_make()
```

The scheduled data workflow is
`.github/workflows/update_data_weekly.yml`. It runs on Mondays at 10:00
UTC and on the first day of each month at 11:00 UTC; it can also be
triggered manually.

## Documentation Style

- Write clearly, directly, and concisely.
- Avoid promotional language, emojis, and unnecessary conclusions.
- Do not end a sentence with a colon.
- Use natural Brazilian Portuguese for Portuguese output.
- Explain infrastructure and web-development tradeoffs with more context
  than statistical or R concepts.
