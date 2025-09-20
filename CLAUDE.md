# Claude Code Configuration

This file contains configuration and commands for Claude Code to help with package development.

## Package Information
- **Package Name**: realestatebr
- **Type**: R Package for Brazilian real estate market data
- **Main Branch**: main
- **Mission**: Create the definitive R package for Brazilian real estate data - reliable, well-documented, and easy to use

## Architecture Transition Status

### Phase 1: Core Functions 🔄 IN PROGRESS
- ✅ `list_datasets()` and `get_dataset()` functions implemented
- ✅ Dataset registry system created
- ✅ Improved dataset documentation
- ✅ CBIC dataset efficiency and UX improvements (commit 65c861b)
- Extended functionality to all datasets
- Improve webscraping and web API calls. Use `get_b3_stocks()` as a model.
- Review existing codebase for consistency and style. For simple pipelines, use only a single `get_*()` function. For more complex datasets, break into multiple steps. Use `import_()` functions to download and read local files. Use `clean_()` functions for cleaning data. Use `get_()` functions as wrapper functions. Some datasets may need multiple specialized functions.

#### 🔍 MANUAL REVIEW NEEDED
- **CBIC cleaning scripts**: Review each table's data processing logic manually
  - Monthly consumption tables: Date parsing and state matching
  - Steel production: Multi-header Excel structure validation
  - PIM data: Excel serial date conversion verification
  - CUB prices: State abbreviation mapping accuracy


### Phase 2: Data Pipeline ⏳ PLANNED
- 🔄 {targets} workflow for automated data processing
- 🔄 Data validation and quality checks
- 🔄 Automated data updates

### Phase 3: Scale Up ⏳ PLANNED
- ⏳ DuckDB integration for large datasets (ITBI, IPTU)
- ⏳ Lazy query support
- ⏳ Large dataset handling

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
- **Legacy functions**: `get_abecip_indicators()`, `get_rppi()`, `get_rppi_bis()` (maintained for backward compatibility)

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

### Data Updates
- **Update cached data**: Run the GitHub Actions workflow "Update Cached Data"
- **Manual data update**: Source the scripts in `data-raw/` directory
- **Data pipeline**: `targets::tar_make()`

### Code Quality
- **Lint code**: `lintr::lint_package()`
- **Style code**: `styler::style_pkg()`
- **Final check**: `devtools::check(cran = TRUE)`

## Development Standards

- Always refer to claude/coding_guidelines.md for detailed instructions

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

- **Backward Compatibility**: All existing `get_*()` functions must continue working
- **Data Quality**: Always validate data before saving to package
- **User Experience**: Keep interface simple - complexity should be hidden
- **Performance**: Cache aggressively, download only when necessary
- **Documentation**: Every dataset needs proper documentation and examples
- **Attribution**: Always provide proper citations for data sources
- **Web Scraping**: Use appropriate user agents and rate limiting
