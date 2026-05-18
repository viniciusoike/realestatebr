# Claude Code Configuration

This file contains configuration and commands for Claude Code to help with package development.

## Package Information
- **Package Name**: realestatebr
- **Type**: R Package for Brazilian real estate market data
- **Main Branch**: main
- **Mission**: Create the definitive R package for Brazilian real estate data - reliable, well-documented, and easy to use

## Guidelines for writting
These apply when writting text for documentation like README.md or vignettes.

- Avoid ending sentences with a colon.
- Avoid emojis (e.g 🎯, 📊, etc.)

## Current Status

- v1.0.0 released — all core functions verified, CRAN submission prepared
- Breaking changes in v1.0.0: cbic, nre_ire, property_records, itbi removed
- Active datasets: abecip, abrainc, bcb_series, bcb_realestate, fgv_ibre, secovi, rppi_sale, rppi_rent, bis_rppi

## Core Technologies & Dependencies

```r
# Core package dependencies
library(cli)            # User-facing messages and errors
library(dplyr)          # Data manipulation
library(httr)           # HTTP requests
library(lubridate)      # Date handling
library(purrr)          # Functional programming
library(readr)          # Data reading
library(readxl)         # Excel reading
library(rlang)          # Tidy evaluation
library(rvest)          # Web scraping
library(stringr)        # String manipulation
library(tibble)         # Modern data frames
library(tidyr)          # Data tidying
library(xml2)           # HTML/XML parsing
library(yaml)           # Configuration files
library(zoo)            # Time series utilities

# Development tools
library(devtools)       # Package development
library(usethis)        # Package setup utilities
library(testthat)       # Testing framework
library(pkgdown)        # Documentation website

# Data pipeline
library(targets)        # Workflow management
library(tarchetypes)    # Additional target types
```

## Key Functions & Architecture

### Main Interface
- **`list_datasets()`**: Dataset discovery function
- **`get_dataset(name)`**: Unified data access function

### Dataset Registry System
- **Registry file**: `inst/extdata/datasets.yaml`
- **Functions**: `load_dataset_registry()`, `get_dataset_info()`, `update_registry_entry()`

### Internal Helper Functions

New and existing dataset functions must use these helpers to avoid code duplication.

#### `R/helpers-download.R` — Download operations
| Function | Purpose |
|---|---|
| `download_with_retry(fn, max_retries, quiet, desc)` | Core retry loop with exponential backoff; wrap any download call in it |
| `download_file(url, file_ext, ...)` | Generic file download to a temp path |
| `download_excel(url, expected_sheets, min_size, ...)` | Excel download with sheet and size validation |
| `download_csv(url, min_size, ...)` | CSV download to temp path |
| `download_zip(url, file_pattern, ...)` | Download a ZIP and extract the matching file |
| `scrape_download_url(page_url, xpath, css, ...)` | Scrape a page for a download link, returns URL |
| `download_multiple_files(urls, file_ext, delay, ...)` | Batch download with progress and rate limiting |

#### `R/helpers-dataset.R` — Dataset lifecycle
| Function | Purpose |
|---|---|
| `validate_dataset_params(table, valid_tables, cached, quiet, max_retries)` | Standard parameter validation at the top of every dataset function |
| `handle_dataset_cache(dataset_name, table, quiet, on_miss)` | Load from user cache with configurable miss behavior (`"download"` / `"return_null"` / `"error"`) |
| `attach_dataset_metadata(data, source, category, extra_info)` | Attach `source`, `download_time`, and `download_info` attributes to the returned data |
| `validate_dataset(data, dataset_name, required_cols, min_rows, ...)` | Check non-empty, required columns, and date sanity |

#### `R/rppi-helpers.R` — RPPI-specific helpers
| Function | Purpose |
|---|---|
| `try_rppi_cached(table, source_filter)` | Load RPPI data from GitHub cache with optional source filter; returns `NULL` on miss |
| `try_rppi_user_cache(dataset_name, quiet)` | Load RPPI data from user cache; returns `NULL` on miss |
| `calculate_rppi_changes(data, index_col, group_col)` | Adds `chg` (month-on-month) and `acum12m` (year-on-year) columns to an index series |

## Common Commands

### Development Workflow
```r
# Load and test changes
devtools::load_all()

# Update documentation
devtools::document()

# Run tests
devtools::test()

# Check package
devtools::check()

# Update data (with targets)
targets::tar_make()
```

### Package Development
- **Build package**: `R CMD build .`
- **Check package**: `R CMD check --as-cran *.tar.gz`
- **Install package**: `R CMD INSTALL .`
- **Test package**: `devtools::test()`

### Documentation
- **Build documentation**: `devtools::document()`
- **Build vignettes**: `devtools::build_vignettes()`
- **Build pkgdown site**: `pkgdown::build_site()`

### Data Pipeline Operations

#### Running the Pipeline Locally
```r
# Load targets library
library(targets)

# View all targets
tar_manifest()

# Check which targets are outdated
tar_outdated()

# Run entire pipeline
tar_make()

# Run specific targets (e.g., just ABECIP)
tar_make(names = c("abecip_data", "abecip_cache", "abecip_validation"))

# Visualize pipeline
tar_visnetwork()
```

#### Automated Updates (GitHub Actions)
- **Weekly updates**: Runs every Monday at 10 AM UTC
- **Manual trigger**: Go to Actions → "Weekly Data Updates" → "Run workflow"
- **Target groups**:
  - `weekly`: BCB, FGV, ABECIP, ABRAINC, SECOVI, RPPI (8 datasets)
  - `monthly`: BIS RPPI (1 dataset)
  - `all`: All datasets

#### Pipeline Architecture
The pipeline uses the modern `get_dataset()` interface with three targets per dataset:
1. **`{dataset}_data`**: Fetches fresh data using `get_dataset(source="fresh")`
2. **`{dataset}_cache`**: Saves to `data-raw/cache_output/` (staging directory for GitHub releases)
3. **`{dataset}_validation`**: Validates data quality

After processing, GitHub Actions uploads files from `data-raw/cache_output/` to the "cache-latest" GitHub release.

**Weekly Datasets** (7-day update cycle):
- bcb_series, bcb_realestate, fgv_ibre
- abecip, abrainc, secovi
- rppi_sale, rppi_rent

**Monthly Datasets** (1st of month trigger):
- bis_rppi

### Code Quality
- Look into claude/coding_guidelines.md for detailed coding standards
- **Lint code**: `lintr::lint_package()`
- **Style code**: `styler::style_pkg()`
- **Final check**: `devtools::check(cran = TRUE)`

## Development Standards

- Always refer to claude/coding_guidelines.md for detailed instructions

### Document changes
- Update `NEWS.md` with each release
- Commit to GitHub with descriptive messages

### Code Style
- Follow tidyverse style guide (sole exception: use `return` at the end of functions).
- Use explicit package calls (`dplyr::filter()`) in functions.
- Document all exported functions with roxygen2.
- Prefer readability over brevity.
- Use meaningful variable names.

### Error Handling Pattern
```r
# Graceful degradation with fallbacks
get_dataset <- function(name, source = "auto") {
  tryCatch({
    load_from_cache(name)  # Try primary method
  }, error = function(e) {
    tryCatch({
      download_from_github(name)  # Try secondary method
    }, error = function(e2) {
      download_fresh(name)  # Try fresh download
    })
  })
}
```

### Using Helper Functions

Every dataset function must use the shared helpers instead of re-implementing these patterns:

- **Parameter validation** — call `validate_dataset_params()` at the top
- **Cache loading** — use `handle_dataset_cache()` instead of raw `tryCatch` around `load_from_user_cache()`
- **Downloading files** — use `download_excel()`, `download_csv()`, `download_zip()`, or `download_file()` (all in `helpers-download.R`)
- **Retry logic** — wrap any custom download in `download_with_retry()`; do not write manual retry loops
- **Metadata** — call `attach_dataset_metadata()` before returning data
- **Data validation** — call `validate_dataset()` after downloading; use `validate_excel_file()` before reading Excel files
- **RPPI series only** — use `try_rppi_cached()`, `try_rppi_user_cache()`, and `calculate_rppi_changes()`

### Data Validation
- Check required columns and data types
- Validate reasonable ranges
- Check for duplicates
- Always validate data before saving to package

## Project Structure
```
realestatebr/
├── .claude/                    # Claude Code configuration
├── _targets.R                  # Data processing pipeline (Phase 2)
├── data-raw/                   # Data processing scripts
│   ├── pipeline/               # Pipeline helper functions
│   │   ├── targets_helpers.R   # Caching and validation helpers
│   │   ├── validation.R        # Data validation rules
│   │   ├── generate_report.R   # Pipeline summary report
│   │   └── update_data.R       # Data update helpers
│   ├── cache_output/           # Staging directory for GitHub releases (git-ignored)
│   └── [dataset].R             # Individual dataset scripts
├── R/                          # Package functions
│   ├── list-datasets.R         # Dataset discovery
│   ├── get-dataset.R           # Unified data access
│   ├── get-*.R                 # Internal dataset functions
│   ├── helpers-dataset.R       # Shared helpers: validation, cache, metadata
│   ├── helpers-download.R      # Shared helpers: download, retry, scraping
│   ├── rppi-helpers.R          # RPPI-specific helpers: cache, changes
│   ├── cache-user.R            # User-level cache management
│   ├── cache-github.R          # GitHub releases cache
│   ├── utils.R                 # General helper functions
│   ├── utils-encoding.R        # Encoding utilities
│   ├── utils-globals.R         # Global variable declarations
│   └── data.R                  # Dataset documentation (roxygen2 @docType data)
├── inst/extdata/
│   ├── datasets.yaml           # Dataset registry
│   └── validation/             # Validation rules
├── tests/testthat/             # Unit tests
├── vignettes/                  # Package documentation
├── man/                        # Generated documentation
└── docs/                       # pkgdown website
```

## Caching Architecture

The package uses a three-tier caching system:

1. **User Cache** (~/.local/share/realestatebr/)
   - Fastest access
   - Managed by R/cache-user.R
   - Used for runtime caching

2. **GitHub Releases** (tag: cache-latest)
   - Medium speed (download from GitHub)
   - Managed by R/cache-github.R
   - Updated weekly/monthly by GitHub Actions

3. **Fresh Download** (original sources)
   - Slowest but always current
   - Automatically saves to user cache after download

The `data-raw/cache_output/` directory is a git-ignored staging location where the targets pipeline saves processed datasets before GitHub Actions uploads them to releases.

## Adding New Datasets

1. **Create processing script**: `data-raw/[dataset-name].R`
2. **Add to registry**: Update `inst/extdata/datasets.yaml`
3. **Update functions**: Add mapping in `get_dataset()` switch statement
4. **Document**: Create `R/data-[dataset-name].R` with roxygen2 docs
5. **Test**: Add tests in `tests/testthat/test-[dataset-name].R`

## MCP Tools Available

- **r-btw**: R session integration — `btw_tool_pkg_load_all`, `btw_tool_pkg_test`, `btw_tool_pkg_check`, `btw_tool_pkg_document`, `btw_tool_pkg_coverage`, `btw_tool_docs_help_page`, `btw_tool_cran_search`
- Use ToolSearch to load schemas before calling, e.g. `ToolSearch("select:mcp__r-btw__btw_tool_pkg_test")`

## Goals

- **Data Quality**: Always validate data before saving to package
- **User Experience**: Keep interface simple - complexity should be hidden
- **Performance**: Cache aggressively, download only when necessary
- **Documentation**: Every dataset needs proper documentation and examples
- **Attribution**: Always provide proper citations for data sources
- **Web Scraping**: Use appropriate user agents and rate limiting

## Important notes

1. Always use relevant Posit skills
2. Always follow coding convetions when coding (both listed here and @claude/coding_guidelines.md)

### Coding conventions

#### Functions

- Use `return` at the end of functions to make the return explicit. Only exception are anonymous functions and very short functions.

```r
# OK to not use returm
\(x) is.na(sum(x, na.rm = TRUE))

as_numeric_comma <- function(x) {
	as.numeric(gsub(",", ".", x))
}

# Use return
str_simplify <- function(x) {
	y <- stringr::str_to_lower(x)
	y <- stringr::str_replace_all(y, " ", "_")
	y <- stringr::str_squish(y)

	return(y)
}

```
- Follow tidyverse style guide with the sole exception of the `return` rule above.

#### Pipes

- Avoid using `%>%` and `|>` in favor of `|>`
- Make sure pipe chains are short (not more than 5)
- Never use single pipes (e.g. x |> mean())
- Never pipe a `read` function into data cleaning
- Code should be logically organized and easy to understand: reading data, cleaning, joining, transforming, etc.

```r
# Correct
dat <- readr::read_csv(...)

clean_dat <- dat |>
  basic_clean() |>
  parse_dates() |>
  add_dimensions()

# Never
dat <- readr::read_csv() |>
  basic_clean() |>
  parse_dates() |>
  add_dimensions()

# Avoid mixing joins into data cleaning

# Bad
left_join(x, y, by = "key") |>
  basic_clean()

# Good
new_data <- left_join(x, y, by = "key")
clean_data <- basic_clean(new_data)

# The same applies to bind_rows

# Bad
bind_rows(list_of_data) |>
  basic_clean()

# When using bind_rows, use the .id argument instead of creating identifiers
# for each data.frame

# Good
series <- list(
  "igmi" = igmi,
  "ivar" = ivar,
  "fipezap" = fipezap
)

stacked <- bind_rows(series, .id = "source")

# Bad

bind_rows(
  mutate(igmi, source = "igmi"),
  mutate(ivar, source = "ivar"),
  mutate(fipezap, source = "fipezap")
)

# Try to order functions logically and efficiently

# Bad - filters after creating new columns
dat |>
  mutate(
    y = log(x),
    z = RcppRoll::roll_sumr(y, n = 12, align = "right")
  ) |>
  filter(group == "a") |>
  rename(price = y)

# Good - renames first, filters, then calculates
dat |>
  rename(price = y) |>
  filter(group == "a") |>
  mutate(
    z = RcppRoll::roll_sumr(log(price), n = 12, align = "right")
  )
```

- Prefer using dplyr::rename and dplyr::select with character vectors
- This improves standardization across tables

```r

cols_select <- c("a", "b", "c")
cols_rename <- c("new_a" = "a")


dat <- dat |>
  dplyr::select(dplyr::all_of(cols_select)) |>
  dplyr::rename(dplyr::any_of(cols_rename))

```
- Use modern tidyverse functions whenever possible.
