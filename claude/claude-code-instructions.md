# realestatebr Package Development - Claude Code Instructions

## Project Overview

R package for accessing Brazilian real estate market data. Currently transitioning from web-scraping approach to a robust data distribution system with:
- Simple user interface (`list_datasets()`, `get_dataset()`)
- Automated data pipeline using {targets}
- DuckDB integration for large datasets (ITBI, IPTU)
- Backward compatibility with existing `get_*()` functions

## Current Architecture Transition

### Phase 1: Core Functions (Nearly Complete - 47% Modernized)
- ✅ Add `list_datasets()` and `get_dataset()` functions
- ✅ Modernized core functions with CLI error handling and progress reporting
- ✅ Implemented `table` parameter standardization with backward compatibility
- ✅ Fixed critical cache directory structure (moved to `inst/cached_data/`)
- ✅ Standardized column names for consistent data output
- ✅ Keep existing `get_abecip_indicators()`, `get_rppi()`, `get_rppi_bis()` working
- ✅ Improve dataset documentation
- ✅ Create dataset registry system
- ✅ Integrated CBIC construction materials data functionality

**Fully Modernized Functions (8/17 - 47%):**
- ✅ `get_property_records()` - Full CLI modernization
- ✅ `get_bcb_realestate()` - Full CLI modernization
- ✅ `get_secovi()` - Full CLI modernization
- ✅ `get_abecip_indicators()` - Full CLI modernization + table parameter
- ✅ `get_abrainc_indicators()` - Full CLI modernization + table parameter
- ✅ `get_cbic_cement()` - Full CLI modernization + table parameter (NEW)
- ✅ `get_cbic_steel()` - Full CLI modernization + table parameter (NEW)
- ✅ `get_cbic_pim()` - Full CLI modernization + table parameter (NEW)

**Partially Modernized Functions (7/17):**
- 🔄 `get_rppi()` - CLI modernized, needs table parameter
- 🔄 `get_rppi_bis()` - CLI modernized, needs table parameter
- 🔄 `get_bis_rppi()` - CLI modernized, needs table parameter
- 🔄 `get_bcb_series()` - CLI modernized, needs table parameter
- 🔄 `get_b3_stocks()` - Column standardization, needs full CLI modernization
- 🔄 `get_fgv_indicators()` - CLI modernized, needs table parameter
- 🔄 `get_nre_ire()` - CLI modernized, needs table parameter

**Not Yet Modernized (2/17):**
- ❌ `get_itbi()` - No modernization
- ❌ `get_itbi_bhe()` - No modernization

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
library(cli)            # Modern error handling and progress reporting
library(stringr)        # String manipulation

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
├── inst/
│   ├── extdata/
│   │   ├── datasets.yaml     # Dataset registry
│   │   └── validation/       # Validation rules
│   └── cached_data/          # Cached datasets (moved from package root)
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

## Modern Function Patterns

### Standard Modernized Function Signature
```r
get_function_name <- function(
  table = "default_table",    # Primary parameter (standardized)
  category = NULL,             # Deprecated, for backward compatibility
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Function implementation
}
```

### CLI-Based Error Handling
```r
# Input validation with helpful messages
if (!is.character(table) || length(table) != 1) {
  cli::cli_abort(c(
    "Invalid {.arg table} parameter",
    "x" = "{.arg table} must be a single character string",
    "i" = "Valid tables: {.val {valid_tables}}"
  ))
}

# Backward compatibility with deprecation warning
if (!is.null(category)) {
  cli::cli_warn(c(
    "Parameter {.arg category} is deprecated",
    "i" = "Use {.arg table} parameter instead",
    ">" = "This will be removed in a future version"
  ))
  table <- category
}
```

### Progress Reporting
```r
# For operations with multiple steps
if (!quiet) {
  cli::cli_progress_bar(
    name = "Downloading data",
    total = length(symbols),
    format = "{cli::pb_name} {cli::pb_current}/{cli::pb_total} [{cli::pb_bar}] {cli::pb_percent}"
  )
}

# For single operations
if (!quiet) {
  cli::cli_inform("Processing {length(items)} item{?s}...")
}
```

### Retry Logic Pattern
```r
download_with_retry <- function(url, max_retries = 3L, quiet = FALSE) {
  attempts <- 0

  while (attempts <= max_retries) {
    attempts <- attempts + 1

    tryCatch({
      # Download operation
      return(result)
    }, error = function(e) {
      if (attempts > max_retries) {
        cli::cli_abort("Failed after {max_retries} attempts: {e$message}")
      }

      if (!quiet) {
        cli::cli_warn("Attempt {attempts} failed, retrying...")
      }

      # Exponential backoff
      Sys.sleep(min(attempts * 0.5, 3))
    })
  }
}
```

### Metadata Attribution
```r
# Add comprehensive metadata to results
attr(result, "source") <- if(cached) "cache" else "web"
attr(result, "download_time") <- Sys.time()
attr(result, "download_info") <- list(
  table = table,
  total_records = nrow(result),
  retry_attempts = attempts,
  source = "web"
)
```

### Unified Data Access Pattern
```r
# Graceful degradation with modern error handling
get_dataset <- function(name, source = "auto", category = NULL, ...) {
  # Input validation with CLI
  if (!is.character(name) || length(name) != 1) {
    cli::cli_abort(c(
      "Invalid dataset name",
      "x" = "Dataset name must be a single character string"
    ))
  }

  # Try each source with informative progress
  if (source == "auto") {
    if (!quiet) cli::cli_inform("Attempting to load {name} from GitHub cache...")

    tryCatch({
      return(get_dataset_from_source(name, "github", category, ...))
    }, error = function(e) {
      if (!quiet) cli::cli_warn("GitHub cache failed, trying fresh download...")

      tryCatch({
        return(get_dataset_from_source(name, "fresh", category, ...))
      }, error = function(e2) {
        cli::cli_abort(c(
          "All data sources failed for dataset '{name}'",
          "x" = "GitHub cache: {e$message}",
          "x" = "Fresh download: {e2$message}",
          "i" = "Check your internet connection and try again"
        ))
      })
    })
  }
}
```

### Data Validation
```r
# Standard validation pattern with CLI error handling
validate_dataset <- function(data, expected_structure, dataset_name = "dataset") {
  # Check required columns
  required_cols <- expected_structure$columns
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "Data validation failed for {dataset_name}",
      "x" = "Missing required columns: {.val {missing_cols}}",
      "i" = "Expected columns: {.val {required_cols}}"
    ))
  }

  # Check data types
  type_issues <- check_column_types(data, expected_structure$types)
  if (length(type_issues) > 0) {
    cli::cli_warn(c(
      "Data type issues in {dataset_name}:",
      type_issues
    ))
  }

  # Check for reasonable data ranges
  range_issues <- check_data_ranges(data, expected_structure$ranges)
  if (length(range_issues) > 0) {
    cli::cli_warn(c(
      "Data range issues in {dataset_name}:",
      range_issues
    ))
  }

  # Check for duplicates if required
  if (expected_structure$unique && anyDuplicated(data)) {
    cli::cli_warn("Duplicate rows found in {dataset_name}")
  }

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

## Critical Infrastructure Fixes (Completed)

### Cache Directory Structure Fix
**Issue**: `import_cached()` function couldn't locate cached data files in package
**Solution**: Moved `cached_data/` from package root to `inst/cached_data/`
**Impact**: All cached data access now works properly with `system.file()`

```r
# Before (broken)
cache_path <- file.path("cached_data", filename)

# After (working)
cache_path <- system.file("cached_data", filename, package = "realestatebr")
```

### API Parameter Standardization
**Issue**: Inconsistent parameter naming across functions (`category` vs `table`)
**Solution**: Standardized on `table` parameter with backward compatibility
**Affected Functions**: `get_abecip_indicators()`, `get_abrainc_indicators()`

```r
# New standardized approach
get_function_name <- function(table = "default", category = NULL, ...) {
  # Handle backward compatibility
  if (!is.null(category)) {
    cli::cli_warn("Parameter 'category' is deprecated. Use 'table' instead.")
    table <- category
  }
  # Continue with table parameter
}
```

### Column Name Consistency
**Issue**: Inconsistent column names in B3 stock data (open, high, low, close)
**Solution**: Standardized column mapping in `convert_xts_to_tibble()`
**Impact**: Predictable column names across all downloads

```r
# Standardized column mapping
col_names <- stringr::str_replace_all(
  col_names,
  c(
    "^open$" = "price_open",
    "^high$" = "price_high",
    "^low$" = "price_low",
    "^close$" = "price_close"
  )
)
```

### Return Type Predictability
**Pattern**: Functions return single tibble by default, list only when explicitly requested
**Implementation**: Use `table` parameter to control return type

```r
# Default: returns single tibble
data <- get_abecip_indicators()  # Returns SBPE table
data <- get_abrainc_indicators() # Returns indicator table

# Explicit: returns list when requested
all_data <- get_abecip_indicators(table = "all")    # Returns list
all_data <- get_abrainc_indicators(table = "all")   # Returns list
```

## Common Development Tasks

### Modernizing Existing Functions

Use this checklist when modernizing legacy `get_*()` functions:

#### 1. **Update Function Signature**
```r
# Before
get_function_name <- function(category = "all", cached = FALSE) { ... }

# After
get_function_name <- function(
  table = "default_table",    # Primary parameter
  category = NULL,             # Deprecated, for backward compatibility
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) { ... }
```

#### 2. **Replace Error Handling**
- [ ] Replace `stop()` with `cli::cli_abort()`
- [ ] Replace `warning()` with `cli::cli_warn()`
- [ ] Replace `message()` with `cli::cli_inform()`
- [ ] Add structured error messages with suggestions

#### 3. **Add Progress Reporting**
- [ ] Add `cli::cli_progress_bar()` for multi-step operations
- [ ] Add `cli::cli_inform()` for status updates
- [ ] Respect `quiet` parameter

#### 4. **Implement Retry Logic**
- [ ] Add retry logic for web operations
- [ ] Include exponential backoff
- [ ] Provide informative error messages

#### 5. **Update Documentation**
- [ ] Add `@section Progress Reporting` block
- [ ] Add `@section Error Handling` block
- [ ] Update examples with new parameters
- [ ] Document backward compatibility

#### 6. **Add Metadata**
- [ ] Include `source`, `download_time`, `download_info` attributes
- [ ] Track retry attempts and processing statistics

#### 7. **Ensure Backward Compatibility**
- [ ] Handle deprecated `category` parameter
- [ ] Issue deprecation warnings
- [ ] Maintain existing return types where possible

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

#### Core Function Tests
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

#### Modernized Function Tests
```r
# Test CLI error messages
test_that("provides helpful CLI error messages", {
  expect_error(
    get_function_name(table = "invalid"),
    class = "cli_error"
  )
})

# Test backward compatibility
test_that("category parameter still works with deprecation warning", {
  expect_warning(
    result <- get_function_name(category = "all"),
    "deprecated"
  )
  expect_s3_class(result, "data.frame")
})

# Test progress reporting
test_that("progress reporting works when quiet = FALSE", {
  expect_message(
    get_function_name(quiet = FALSE),
    "Processing"
  )
})

# Test metadata attributes
test_that("metadata attributes are properly set", {
  result <- get_function_name()
  expect_true("source" %in% names(attributes(result)))
  expect_true("download_time" %in% names(attributes(result)))
  expect_true("download_info" %in% names(attributes(result)))
})

# Test return type consistency
test_that("returns predictable data types", {
  # Single table by default
  single_result <- get_function_name()
  expect_s3_class(single_result, "data.frame")

  # List when explicitly requested
  all_result <- get_function_name(table = "all")
  expect_type(all_result, "list")
})

# Test caching integration
test_that("cached data access works", {
  expect_no_error(
    cached_result <- get_function_name(cached = TRUE)
  )
  expect_equal(attr(cached_result, "source"), "cache")
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

### Modernization Tasks
```bash
# Modernize a legacy function
claude code "Modernize get_bcb_series() following the established CLI patterns and table parameter approach"

# Fix parameter inconsistency
claude code "Update get_rppi() to use table parameter with backward compatibility for the category parameter"

# Add progress reporting
claude code "Add CLI progress bars and informative messages to get_property_records() long-running operations"

# Fix column naming
claude code "Standardize column names in get_bis_rppi() to ensure consistent output format"

# Add retry logic
claude code "Implement robust retry logic with exponential backoff for all web scraping operations in get_fgv_indicators()"

# Update error handling
claude code "Replace all stop(), warning(), and message() calls with CLI equivalents in get_nre_ire()"
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

- **Backward Compatibility**: All existing `get_*()` functions must continue working exactly as before
- **CLI Integration**: Use CLI package for all user-facing messages, errors, and progress reporting
- **Parameter Standardization**: Standardize on `table` parameter, but maintain `category` for backward compatibility
- **Cache Structure**: All cached data must be in `inst/cached_data/` for proper package structure
- **Return Type Consistency**: Return single tibble by default, list only when `table="all"`
- **Data Quality**: Always validate data before saving to package using CLI error messages
- **User Experience**: Keep the interface simple - complexity should be hidden behind robust error handling
- **Performance**: Cache aggressively, download only when necessary, provide progress feedback
- **Documentation**: Every dataset needs proper documentation with @section blocks for modernized functions
- **Attribution**: Always provide proper citations for data sources
- **Retry Logic**: All web operations must include retry logic with exponential backoff
- **Metadata**: Include comprehensive metadata attributes on all returned data

### Best Practices from Modernization

1. **Always provide helpful error messages** with suggestions for fixing issues
2. **Respect the `quiet` parameter** in all progress reporting
3. **Include retry attempts in metadata** for transparency
4. **Test backward compatibility** thoroughly when adding new parameters
5. **Use structured CLI messages** with bullets and formatting for clarity
6. **Provide fallback strategies** for all critical operations
7. **Document deprecation warnings** clearly in function documentation

## Resources & References

- [R Packages Book](https://r-pkgs.org/)
- [Targets Manual](https://books.ropensci.org/targets/)
- [DuckDB R Documentation](https://duckdb.org/docs/api/r)
- [Brazilian Real Estate Data Sources](https://www.cbas.org.br/)

## Package Mission

Create the definitive R package for Brazilian real estate data - reliable, well-documented, and easy to use for researchers, analysts, and data scientists working with the Brazilian real estate market.
