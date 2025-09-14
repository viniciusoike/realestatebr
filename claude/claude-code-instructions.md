# realestatebr Package Development - Claude Code Instructions

## Project Overview

R package for accessing Brazilian real estate market data. Currently transitioning from web-scraping approach to a robust data distribution system with:
- Simple user interface (`list_datasets()`, `get_dataset()`)
- Automated data pipeline using {targets}
- DuckDB integration for large datasets (ITBI, IPTU)
- Backward compatibility with existing `get_*()` functions

## Current Architecture Transition

### Phase 1: Core Functions (In Progress)
- ✅ Add `list_datasets()` and `get_dataset()` functions
- ✅ Keep existing `get_abecip_indicators()`, `get_rppi()`, `get_rppi_bis()` working
- ✅ Improve dataset documentation
- ✅ Create dataset registry system

### Phase 2: Data Pipeline
- 🔄 Implement {targets} workflow for data processing
- 🔄 Add data validation and quality checks
- 🔄 Set up automated data updates

### Phase 3: Scale Up
- ⏳ DuckDB integration for large datasets
- ⏳ Add ITBI and IPTU data
- ⏳ Lazy query support

## Key Technologies & Dependencies

```r
# Core package dependencies
library(dplyr)          # Data manipulation
library(readr)          # Data reading
library(rvest)          # Web scraping
library(httr)           # HTTP requests
library(yaml)           # Configuration files
library(glue)           # String templates

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

## File Structure & Organization

```
realestatebr/
├── .claude/                    # Claude Code configuration
├── _targets.R                  # Data processing pipeline (Phase 2)
├── data-raw/                   # Data processing scripts
│   ├── functions.R             # Pipeline functions
│   ├── validation.R            # Data validation rules
│   ├── abecip.R               # ABECIP data processing
│   ├── rppi.R                 # RPPI data processing
│   └── bis.R                  # BIS data processing
├── R/                         # Package functions
│   ├── list-datasets.R        # Dataset discovery
│   ├── get-dataset.R          # Unified data access
│   ├── get-abecip.R          # Legacy function (updated internally)
│   ├── get-rppi.R            # Legacy function (updated internally)
│   ├── get-bis.R             # Legacy function (updated internally)
│   ├── database.R            # DuckDB integration (Phase 3)
│   ├── cache.R               # Caching utilities
│   ├── utils.R               # Helper functions
│   └── data-*.R              # Dataset documentation
├── inst/extdata/
│   ├── datasets.yaml         # Dataset registry
│   ├── cache/                # Cached datasets
│   └── validation/           # Validation rules
├── tests/testthat/           # Unit tests
├── vignettes/                # Package documentation
├── man/                      # Generated documentation
└── docs/                     # pkgdown website
```

## Development Patterns & Standards

### Code Style
- Follow tidyverse style guide
- Use explicit package calls (`dplyr::filter()`) in functions
- Document all exported functions with roxygen2
- Prefer readability over brevity
- Use meaningful variable names

### Function Naming
- `list_datasets()` - main discovery function
- `get_dataset(name)` - unified data access
- `get_*_indicators()` - legacy functions (keep working)
- Internal functions: `load_*()`, `validate_*()`, `cache_*()`

### Error Handling
```r
# Graceful degradation pattern
get_dataset <- function(name, source = "auto") {
  tryCatch({
    # Try primary method
    load_from_cache(name)
  }, error = function(e) {
    tryCatch({
      # Try secondary method
      download_from_github(name)
    }, error = function(e2) {
      # Try fresh download
      download_fresh(name)
    })
  })
}
```

### Data Validation
```r
# Standard validation pattern
validate_dataset <- function(data, expected_structure) {
  # Check required columns
  required_cols <- expected_structure$columns
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing columns: ", paste(missing_cols, collapse = ", "))
  }
  
  # Check data types
  # Check reasonable ranges
  # Check for duplicates
  
  return(data)
}
```

## Dataset Registry System

### datasets.yaml Structure
```yaml
datasets:
  dataset_name:
    name: "Human-readable name"
    description: "Clear description"
    source: "Data source organization"
    url: "Source URL"
    geography: "Geographic coverage"
    frequency: "Update frequency"
    coverage: "Time coverage"
    variables:
      column_name: "Column description"
    function_name: "Legacy function name"
    data_type: "tibble|list|large"
    size_mb: 1.5
    last_updated: "2025-01-15"
    citation: "Proper citation"
```

### Registry Functions
```r
load_dataset_registry() # Load from inst/extdata/datasets.yaml
get_dataset_info(name)  # Get metadata for specific dataset
update_registry_entry() # Update metadata after processing
```

## Common Development Tasks

### Adding a New Dataset

1. **Create data processing script**: `data-raw/[dataset-name].R`
```r
library(dplyr)
library(readr)

# Download and clean data
dataset_name <- download_and_clean_data()

# Validate
dataset_name <- validate_dataset(dataset_name, validation_rules)

# Save to package
usethis::use_data(dataset_name, overwrite = TRUE)
```

2. **Add to registry**: Update `inst/extdata/datasets.yaml`

3. **Update functions**: Add mapping in `get_dataset()` switch statement

4. **Document**: Create `R/data-[dataset-name].R` with roxygen2 docs

5. **Test**: Add tests in `tests/testthat/test-[dataset-name].R`

### Improving Documentation
- Focus on `@examples` sections with realistic use cases
- Include data structure descriptions in `@format`
- Add `@source` with proper attribution
- Use `@seealso` for related functions

### Testing Strategy
```r
# Test data availability
test_that("dataset loads correctly", {
  expect_no_error(data <- get_dataset("dataset_name"))
  expect_true(nrow(data) > 0)
  expect_true(all(expected_columns %in% names(data)))
})

# Test error handling
test_that("invalid dataset name fails gracefully", {
  expect_error(get_dataset("nonexistent"))
  expect_match(get_last_error(), "not found")
})
```

## Web Scraping Best Practices

### Robust Scraping
```r
download_with_retry <- function(url, max_attempts = 3) {
  for (i in 1:max_attempts) {
    tryCatch({
      # Download logic
      return(data)
    }, error = function(e) {
      if (i == max_attempts) stop(e)
      Sys.sleep(2^i)  # Exponential backoff
    })
  }
}
```

### User-Agent & Rate Limiting
```r
# Always set appropriate user agent
httr::GET(url, httr::user_agent("realestatebr R package - research use"))

# Add delays between requests
Sys.sleep(1)
```

## Package Maintenance Commands

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

### Release Preparation
```r
# Update version
usethis::use_version()

# Check reverse dependencies
revdepcheck::revdep_check()

# Build site
pkgdown::build_site()

# Final check
devtools::check(cran = TRUE)
```

## Debugging & Troubleshooting

### Common Issues
1. **Website structure changed**: Check CSS selectors in scraping functions
2. **Network timeouts**: Add retry logic and better error messages
3. **Data validation failures**: Check for new data patterns or missing values
4. **Memory issues**: Consider switching large datasets to DuckDB approach

### Debugging Tools
```r
# Interactive debugging
browser()  # Insert breakpoint

# Check data structure
str(data)
summary(data)

# Validate URLs
httr::http_status(httr::GET(url))
```

## Claude Code Usage Examples

### Quick Tasks
```bash
# Add new dataset
claude code "Add a new dataset for FGTS housing indicators following the established pattern"

# Fix documentation
claude code "Improve the documentation for get_rppi() function with better examples"

# Update scraping logic
claude code "The ABECIP website changed structure. Update the scraping logic in data-raw/abecip.R"

# Add tests
claude code "Create comprehensive tests for the new list_datasets() function"
```

### Complex Tasks
```bash
# Phase 2 implementation
claude code "Set up the targets workflow for automated data processing. Create _targets.R and supporting functions."

# Phase 3 implementation  
claude code "Implement DuckDB integration for large datasets. Add support for lazy queries and filtering."

# Package maintenance
claude code "Run full package check, fix any issues, and prepare for CRAN submission"
```

## Important Notes

- **Backward Compatibility**: All existing `get_*()` functions must continue working
- **Data Quality**: Always validate data before saving to package
- **User Experience**: Keep the interface simple - complexity should be hidden
- **Performance**: Cache aggressively, download only when necessary
- **Documentation**: Every dataset needs proper documentation and examples
- **Attribution**: Always provide proper citations for data sources

## Resources & References

- [R Packages Book](https://r-pkgs.org/)
- [Targets Manual](https://books.ropensci.org/targets/)
- [DuckDB R Documentation](https://duckdb.org/docs/api/r)
- [Brazilian Real Estate Data Sources](https://www.cbas.org.br/)

## Package Mission

Create the definitive R package for Brazilian real estate data - reliable, well-documented, and easy to use for researchers, analysts, and data scientists working with the Brazilian real estate market.
