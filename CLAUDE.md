# Claude Code Configuration

This file contains configuration and commands for Claude Code to help
with package development.

## Package Information

- **Package Name**: realestatebr
- **Type**: R Package for Brazilian real estate market data
- **Main Branch**: main
- **Mission**: Create the definitive R package for Brazilian real estate
  data - reliable, well-documented, and easy to use

## Guidelines for writting

These apply when writting text for documentation like README.md or
vignettes.

- Avoid ending sentences with a colon.
  `# Bad Multiple data sources with automatic fallback: # Good Multiple data sources with automatic fallback.`
- Avoid emojis (e.g 🎯, 📊, etc.)

## Current Status

- All core functions verified working (100% pass rate)
- v0.6.0 Phase 3 completed (2025-10-15): Logic consolidation achieved
  15.4% codebase reduction
- Ready for v0.6.0 release - final documentation and quality checks
  pending

## Goals for v0.6.x

- Simplify codebase by removing (1) obsolete/outdated/unnecessary
  functions, (2) obsolete/outdated/unnecessary documentation, (3)
  repetitive import/download logic, (4) unnecessary complexity.

The codebase of this package is very large and overly complex for its
purpose.

1.  Almost all of the functions are now internal, but still feature
    extensive documentation. We can supress/simplify this by removing
    examples and other unnecessary details. We shoudld, however, keep
    the ‘core’ of the documentation (title, description, param, source,
    references, etc.) since this is useful for developers.

2.  There are still several functions with the sole purpose of printing
    deprecation warnings. These should be removed entirely.

3.  Several functions have questionable metadata like ‘download_time’,
    ‘download_info’, etc. These should be kept only if they serve a
    clear purpose. Otherwise, they should be removed.

4.  The import/download logic is repeated in several places. This should
    be consolidated into generic helper functions that can be reused
    across datasets.

5.  There is currently some ambiguity with the word ‘legacy’ in this
    package. Due to architcture transition in v0.4.0, all functions
    except
    [`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
    and
    [`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
    are considered ‘legacy’. However, these functions are the backbone
    of the package. The only change is that they are now internal.
    Despite this, several functions “treat” them as if they were legacy.
    The core `get_from_legacy_function` for instance implies that it
    calls legacy functions, when in fact it calls the main internal
    functions. This is confusing and should be fixed.

## Goals for v0.5.x

- Have all core functions working perfectly. This means
  [`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
  should work flawlessly for all datasets with both `source = 'cache'`
  and `source = 'fresh'`.
- Make sure that ALL datasets can be imported via ‘cache’. This ensures
  that the user can always get the data quickly and conviniently.
- Make sure the targets pipeline is fully functional and can update all
  datasets automatically on a weekly basis.
- Make codebase simpler by abandoning legacy functions, deprecation
  warnings, etc. In other words, make breaking changes if (1) it makes
  the codebase simpler; (2) makes the codebase significantly more
  efficient; (3) makes the codebaes less error-prone; and (4) makes the
  end-user experience better.

## Architecture Transition Status

### Phase 1: Core Functions ✅ COMPLETED (v0.4.0)

- ✅
  [`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
  and
  [`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
  functions implemented
- ✅ Dataset registry system created
- ✅ Unified API with backward compatibility
- ✅ All legacy functions modernized

### Phase 2: Data Pipeline ✅ COMPLETED

- ✅ {targets} workflow for automated data processing
- ✅ Weekly GitHub Actions workflow
- ✅ 37 targets across 12 datasets
- ✅ Data validation and quality checks

### Phase 3: Logic Consolidation ✅ COMPLETED (v0.6.0, 2025-10-15)

- ✅ Created 7 generic helper functions (R/helpers-dataset.R)
- ✅ Refactored 5 core files using new helpers
- ✅ Eliminated 890 lines of code duplication
- ✅ Achieved 15.4% codebase reduction (417 lines)
- ✅ Added 52 comprehensive tests for helpers
- ✅ Improved consistency across all dataset functions
- ✅ Centralized table filtering logic

**Results**: - get_abecip_indicators.R: 21.8% reduction -
get_abrainc_indicators.R: 18.2% reduction - get_secovi.R: 18.7%
reduction - get_bcb_series.R: 16.8% reduction - get-dataset.R: 7.2%
reduction

See `.claude/phase3_completion_summary.md` for full details.

### Phase 4: Scale Up ⏳ FUTURE

- ⏳ DuckDB integration for large datasets (ITBI, IPTU)
- ⏳ Lazy query support
- ⏳ Large dataset handling

## Core Technologies & Dependencies

``` r
# Core package dependencies
library(dplyr)          # Data manipulation
library(tidyr)          # Data tidying
library(readr)          # Data reading
library(rvest)          # Web scraping
library(httr)           # HTTP requests
library(yaml)           # Configuration files
library(stringr)           # String templates

# Development tools
library(devtools)       # Package development
library(usethis)        # Package setup utilities
library(testthat)       # Testing framework
library(pkgdown)        # Documentation website

# Data pipeline (Phase 2)
library(targets)        # Workflow management
library(tarchetypes)    # Additional target types

# Large data support (Phase 3)
library(duckdb)         # In-process database
library(DBI)            # Database interface
```

## Key Functions & Architecture

### Main Interface

- **[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)**:
  Dataset discovery function
- **`get_dataset(name)`**: Unified data access function

### Dataset Registry System

- **Registry file**: `inst/extdata/datasets.yaml`
- **Functions**:
  [`load_dataset_registry()`](https://viniciusoike.github.io/realestatebr/reference/load_dataset_registry.md),
  [`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md),
  `update_registry_entry()`

## Common Commands

### Development Workflow

``` r
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
- **Build pkgdown site**:
  [`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)

### Data Pipeline Operations

#### Running the Pipeline Locally

``` r
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
- **Manual trigger**: Go to Actions → “Weekly Data Updates” → “Run
  workflow”
- **Target groups**:
  - `weekly`: BCB, FGV, ABECIP, ABRAINC, SECOVI, RPPI (8 datasets)
  - `monthly`: BIS, CBIC, Property Records (3 datasets)
  - `all`: All datasets

#### Pipeline Architecture

The pipeline uses the modern
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
interface with three targets per dataset: 1. **`{dataset}_data`**:
Fetches fresh data using `get_dataset(source="fresh")` 2.
**`{dataset}_cache`**: Saves to `data-raw/cache_output/` (staging
directory for GitHub releases) 3. **`{dataset}_validation`**: Validates
data quality

After processing, GitHub Actions uploads files from
`data-raw/cache_output/` to the “cache-latest” GitHub release.

**Weekly Datasets** (7-day update cycle): - bcb_series, bcb_realestate,
fgv_ibre - abecip, abrainc, secovi - rppi_sale, rppi_rent

**Monthly Datasets** (30-day update cycle): - bis_rppi, cbic,
property_records

**Manual Only**: - nre_ire (never auto-updates)

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

- Follow tidyverse style guide.
- Use explicit package calls
  ([`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html))
  in functions.
- Document all exported functions with roxygen2.
- Prefer readability over brevity.
- Use meaningful variable names.

### Error Handling Pattern

``` r
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

### Data Validation

- Check required columns and data types
- Validate reasonable ranges
- Check for duplicates
- Always validate data before saving to package

## Project Structure

    realestatebr/
    ├── .claude/                    # Claude Code configuration
    ├── _targets.R                  # Data processing pipeline (Phase 2)
    ├── data-raw/                   # Data processing scripts
    │   ├── pipeline/               # Pipeline helper functions
    │   │   ├── targets_helpers.R   # Caching and validation helpers
    │   │   └── validation.R        # Data validation rules
    │   ├── cache_output/           # Staging directory for GitHub releases (git-ignored)
    │   └── [dataset].R             # Individual dataset scripts
    ├── R/                          # Package functions
    │   ├── list-datasets.R         # Dataset discovery
    │   ├── get-dataset.R           # Unified data access
    │   ├── get-*.R                 # Internal dataset functions
    │   ├── database.R              # DuckDB integration (Phase 4)
    │   ├── cache.R                 # Deprecated cache utilities
    │   ├── cache-user.R            # User-level cache management
    │   ├── cache-github.R          # GitHub releases cache
    │   ├── utils.R                 # Helper functions
    │   └── data-*.R                # Dataset documentation
    ├── inst/extdata/
    │   ├── datasets.yaml           # Dataset registry
    │   └── validation/             # Validation rules
    ├── tests/testthat/             # Unit tests
    ├── vignettes/                  # Package documentation
    ├── man/                        # Generated documentation
    └── docs/                       # pkgdown website

## Caching Architecture

The package uses a three-tier caching system:

1.  **User Cache** (~/.local/share/realestatebr/)
    - Fastest access
    - Managed by R/cache-user.R
    - Used for runtime caching
2.  **GitHub Releases** (tag: cache-latest)
    - Medium speed (download from GitHub)
    - Managed by R/cache-github.R
    - Updated weekly/monthly by GitHub Actions
3.  **Fresh Download** (original sources)
    - Slowest but always current
    - Automatically saves to user cache after download

The `data-raw/cache_output/` directory is a git-ignored staging location
where the targets pipeline saves processed datasets before GitHub
Actions uploads them to releases.

## Adding New Datasets

1.  **Create processing script**: `data-raw/[dataset-name].R`
2.  **Add to registry**: Update `inst/extdata/datasets.yaml`
3.  **Update functions**: Add mapping in
    [`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
    switch statement
4.  **Document**: Create `R/data-[dataset-name].R` with roxygen2 docs
5.  **Test**: Add tests in `tests/testthat/test-[dataset-name].R`

## Important Notes

- **Data Quality**: Always validate data before saving to package
- **User Experience**: Keep interface simple - complexity should be
  hidden
- **Performance**: Cache aggressively, download only when necessary
- **Documentation**: Every dataset needs proper documentation and
  examples
- **Attribution**: Always provide proper citations for data sources
- **Web Scraping**: Use appropriate user agents and rate limiting
