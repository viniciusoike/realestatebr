# Claude Code Configuration

This file contains configuration and commands for Claude Code to help with package development.

## Package Information
- **Package Name**: realestatebr
- **Type**: R Package for Brazilian real estate market data
- **Main Branch**: main
- **Mission**: Create the definitive R package for Brazilian real estate data - reliable, well-documented, and easy to use

## Recent Updates

### v0.4.1 (Latest) - Bug Fixes
✅ **RPPI Individual Table Access**
- Fixed `get_dataset("rppi", "ivgr")` and other individual RPPI tables
- Extended `get_rppi()` to support all individual tables (fipezap, ivgr, igmi, iqa, iqaiw, ivar, secovi_sp)
- Fixed vignette build errors

✅ **CRAN Compliance**
- Removed non-ASCII characters from R source files (7 files)
- Added `utils::globalVariables()` for NSE variables
- UTF-8 characters preserved in roxygen2 documentation

✅ **Dependencies & Tests**
- Added `testthat` to Suggests
- Updated deprecated `category=` to `table=` parameters

✅ **Package Check Status**: `0 errors ✔ | 0 warnings ✔ | 0 notes ✔`

## Architecture Transition Status

### Phase 1: Core Functions ✅ COMPLETED (v0.4.0)
- ✅ `list_datasets()` and `get_dataset()` functions implemented
- ✅ Dataset registry system created
- ✅ Unified API with backward compatibility
- ✅ All legacy functions modernized

### Phase 2: Data Pipeline ✅ COMPLETED
- ✅ {targets} workflow for automated data processing
- ✅ Weekly GitHub Actions workflow
- ✅ 37 targets across 12 datasets
- ✅ Data validation and quality checks

### Phase 3: Scale Up ⏳ PLANNED
- ⏳ DuckDB integration for large datasets (ITBI, IPTU)
- ⏳ Lazy query support
- ⏳ Large dataset handling

#### 🔍 MANUAL REVIEW NEEDED
- **CBIC cleaning scripts**: Review each table's data processing logic manually
  - Monthly consumption tables: Date parsing and state matching
  - Steel production: Multi-header Excel structure validation
  - PIM data: Excel serial date conversion verification
  - CUB prices: State abbreviation mapping accuracy

## Core Technologies & Dependencies

```r
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
- **`list_datasets()`**: Dataset discovery function
- **`get_dataset(name)`**: Unified data access function

### Dataset Registry System
- **Registry file**: `inst/extdata/datasets.yaml`
- **Functions**: `load_dataset_registry()`, `get_dataset_info()`, `update_registry_entry()`

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
  - `monthly`: BIS, CBIC, Property Records (3 datasets)
  - `all`: All datasets

#### Pipeline Architecture
The pipeline uses the modern `get_dataset()` interface with three targets per dataset:
1. **`{dataset}_data`**: Fetches fresh data using `get_dataset(source="fresh")`
2. **`{dataset}_cache`**: Saves to `inst/cached_data/` directory
3. **`{dataset}_validation`**: Validates data quality

**Weekly Datasets** (7-day update cycle):
- bcb_series, bcb_realestate, fgv_ibre
- abecip, abrainc, secovi
- rppi_sale, rppi_rent

**Monthly Datasets** (30-day update cycle):
- bis_rppi, cbic, property_records

**Manual Only**:
- nre_ire (never auto-updates)

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
│   ├── functions.R             # Pipeline functions
│   ├── validation.R            # Data validation rules
│   └── [dataset].R             # Individual dataset scripts
├── R/                          # Package functions
│   ├── list-datasets.R         # Dataset discovery
│   ├── get-dataset.R           # Unified data access
│   ├── get-*.R                 # Legacy functions
│   ├── database.R              # DuckDB integration (Phase 3)
│   ├── cache.R                 # Caching utilities
│   ├── utils.R                 # Helper functions
│   └── data-*.R                # Dataset documentation
├── inst/extdata/
│   ├── datasets.yaml           # Dataset registry
│   ├── cache/                  # Cached datasets
│   └── validation/             # Validation rules
├── tests/testthat/             # Unit tests
├── vignettes/                  # Package documentation
├── man/                        # Generated documentation
└── docs/                       # pkgdown website
```

## Adding New Datasets

1. **Create processing script**: `data-raw/[dataset-name].R`
2. **Add to registry**: Update `inst/extdata/datasets.yaml`
3. **Update functions**: Add mapping in `get_dataset()` switch statement
4. **Document**: Create `R/data-[dataset-name].R` with roxygen2 docs
5. **Test**: Add tests in `tests/testthat/test-[dataset-name].R`

## Important Notes

- **Data Quality**: Always validate data before saving to package
- **User Experience**: Keep interface simple - complexity should be hidden
- **Performance**: Cache aggressively, download only when necessary
- **Documentation**: Every dataset needs proper documentation and examples
- **Attribution**: Always provide proper citations for data sources
- **Web Scraping**: Use appropriate user agents and rate limiting
