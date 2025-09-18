# Version 0.4.0: Major Architecture Refactor (Breaking Changes)

## Executive Summary
Version 0.4.0 represents a major breaking change that removes all legacy `get_*` functions in favor of a single, clean `get_dataset()` interface. This refactor will dramatically simplify the codebase, improve maintainability, and provide a better user experience.

## Core Problems Being Addressed

### 1. Duplicate and Confusing Datasets
- **Current Issue**: Both `rppi` and `rppi_indices` exist with overlapping data (FipeZap appears in both)
- **Solution**: Single `rppi` dataset with hierarchical access to all Brazilian indices

### 2. Legacy Function Maintenance Burden
- **Current Issue**: Supporting both `get_abecip_indicators()` and `get_dataset("abecip")` doubles complexity
- **Solution**: Remove all legacy functions, keep only `get_dataset()` interface

### 3. Invalid Registry Entries
- **Current Issue**: Wildcards like `get_rppi_*` and `get_cbic_*` in legacy_function field
- **Solution**: Proper internal function mappings

### 4. Missing Test Coverage
- **Current Issue**: Tests don't cover problematic datasets, still use old names/parameters
- **Solution**: Comprehensive test suite for all datasets

## Breaking Changes

### Functions Being Removed
All `get_*` functions will be removed from the public API:
- `get_abecip_indicators()`
- `get_abrainc_indicators()`
- `get_bcb_realestate()`
- `get_bcb_series()`
- `get_fgv_indicators()`
- `get_secovi()`
- `get_bis_rppi()`
- `get_rppi_bis()`
- `get_b3_stocks()`
- `get_nre_ire()`
- `get_registro_imoveis()`
- `get_property_records()`
- `get_cbic_*()` functions
- `get_rppi_*()` individual functions (keep main `get_rppi()` as internal)

### New Public API
Only these functions will be exported:
- `get_dataset()` - Main data access function
- `list_datasets()` - Dataset discovery
- `get_dataset_info()` - Dataset metadata
- `check_cache_status()` - Cache management

## Implementation Plan

### Phase 1: Create Internal Architecture

#### 1.1 New Directory Structure
```
R/
├── get-dataset.R           # Public API
├── list-datasets.R          # Public API
├── cache.R                  # Cache utilities
├── utils.R                  # Helper functions
└── internal/               # Internal data fetching functions
    ├── fetch_rppi.R        # RPPI data (handles all indices)
    ├── fetch_cbic.R        # CBIC data
    ├── fetch_abecip.R      # ABECIP data
    ├── fetch_abrainc.R     # ABRAINC data
    ├── fetch_bcb.R         # BCB data
    ├── fetch_fgv.R         # FGV data
    ├── fetch_secovi.R      # SECOVI data
    ├── fetch_bis.R         # BIS international data
    ├── fetch_registro.R    # Property records
    └── fetch_itbi.R        # ITBI data
```

#### 1.2 Internal Function Pattern
Each internal function should follow this pattern:
```r
#' Internal function to fetch [dataset] data
#' @keywords internal
#' @param table Character. Specific table to fetch
#' @param cached Logical. Use cache if available
#' @param ... Additional parameters
fetch_[dataset] <- function(table = NULL, cached = FALSE, ...) {
  # Implementation
}
```

### Phase 2: Update Dataset Registry

#### 2.1 Consolidate RPPI Datasets
Remove `rppi_indices` and update `rppi`:
```yaml
rppi:
  name: "Brazilian Residential Property Price Indices"
  name_pt: "Índices de Preços Residenciais Brasileiros"
  description: "Comprehensive collection of all Brazilian residential property price indices"
  internal_function: "fetch_rppi"
  cache_key: "rppi"
  categories:
    # Individual indices
    fipezap:
      name: "FIPE-ZAP Index"
      description: "FIPE-ZAP residential property price index"
      type: "sales"
      coverage: "Major cities"
    ivgr:
      name: "IVGR - Índice de Valores Gerais Residenciais"
      description: "General residential values index"
      type: "sales"
      coverage: "National"
    igmi:
      name: "IGMI - Índice Geral do Mercado Imobiliário"
      description: "General real estate market index"
      type: "sales"
      coverage: "São Paulo"
    iqa:
      name: "IQA - Índice QuintoAndar"
      description: "QuintoAndar rent price index"
      type: "rent"
      coverage: "Major cities"
    ivar:
      name: "IVAR - Índice de Valores de Aluguéis Residenciais"
      description: "Residential rent values index"
      type: "rent"
      coverage: "National"
    secovi_sp:
      name: "SECOVI-SP Index"
      description: "São Paulo real estate syndicate index"
      type: "both"
      coverage: "São Paulo"
    # Aggregation categories
    sales:
      name: "All Sales Indices"
      description: "Aggregate of all sales-related indices"
      includes: ["fipezap", "ivgr", "igmi", "secovi_sp"]
    rent:
      name: "All Rent Indices"
      description: "Aggregate of all rent-related indices"
      includes: ["iqa", "ivar", "secovi_sp"]
    all:
      name: "All Indices"
      description: "All available RPPI indices"
      includes: ["fipezap", "ivgr", "igmi", "iqa", "ivar", "secovi_sp"]
```

#### 2.2 Fix Other Registry Issues
- `cbic`: Change legacy_function to `fetch_cbic`
- `property_records`: Change to `fetch_registro`
- `bcb_series` → rename to `bcb_economic`
- `fgv_indicators` → rename to `fgv_ibre`

#### 2.3 Add Abstraction Layer
Add `internal_function` field to decouple dataset names from implementation:
```yaml
datasets:
  abecip:
    name: "ABECIP Housing Credit"
    internal_function: "fetch_abecip"  # Decoupled from dataset name
    cache_key: "abecip"
```

### Phase 3: Rewrite get-dataset.R

#### 3.1 Simplified Architecture
```r
get_dataset <- function(name, table = NULL, ...) {
  # 1. Load and validate registry
  registry <- load_dataset_registry()
  dataset_info <- registry$datasets[[name]]

  if (is.null(dataset_info)) {
    cli::cli_abort("Dataset '{name}' not found. Use list_datasets() to see available options.")
  }

  # 2. Handle RPPI special case (aggregations)
  if (name == "rppi" && !is.null(table)) {
    table <- resolve_rppi_table(table, dataset_info)
  }

  # 3. Get internal function
  internal_func <- dataset_info$internal_function
  if (is.null(internal_func)) {
    cli::cli_abort("No internal function defined for dataset '{name}'")
  }

  # 4. Call internal function
  func <- get(paste0("fetch_", internal_func), mode = "function", envir = asNamespace("realestatebr"))
  data <- func(table = table, ...)

  # 5. Apply any post-processing
  data <- apply_translations(data, name, dataset_info)

  return(data)
}
```

#### 3.2 RPPI Resolution Logic
```r
resolve_rppi_table <- function(table, dataset_info) {
  categories <- dataset_info$categories

  # Check if it's an aggregation
  if (table %in% c("sales", "rent", "all")) {
    includes <- categories[[table]]$includes
    return(includes)
  }

  # Otherwise return single table
  if (!table %in% names(categories)) {
    available <- paste(names(categories), collapse = ", ")
    cli::cli_abort("Invalid table '{table}' for RPPI. Available: {available}")
  }

  return(table)
}
```

### Phase 4: Create Internal Functions

#### 4.1 Example: fetch_rppi.R
```r
#' @keywords internal
fetch_rppi <- function(table = NULL, cached = FALSE, stack = FALSE, ...) {
  # Handle different table requests
  if (is.null(table) || table == "all") {
    indices <- c("fipezap", "ivgr", "igmi", "iqa", "ivar", "secovi_sp")
  } else if (table == "sales") {
    indices <- c("fipezap", "ivgr", "igmi", "secovi_sp")
  } else if (table == "rent") {
    indices <- c("iqa", "ivar", "secovi_sp")
  } else if (is.character(table)) {
    indices <- table  # Single index or custom list
  }

  # Fetch data for requested indices
  results <- list()
  for (idx in indices) {
    results[[idx]] <- fetch_single_rppi_index(idx, cached = cached)
  }

  # Stack if requested
  if (stack) {
    return(bind_rows(results, .id = "source"))
  }

  # Return single table if only one requested
  if (length(results) == 1) {
    return(results[[1]])
  }

  return(results)
}
```

### Phase 5: Update Tests

#### 5.1 Remove Legacy Tests
Delete all tests for deprecated functions.

#### 5.2 Create Comprehensive Test Suite
```r
# test-get-dataset.R
test_that("all datasets in registry are accessible", {
  datasets <- list_datasets()

  for (dataset_name in datasets$name) {
    # Test that each dataset can be accessed
    expect_no_error(
      get_dataset_info(dataset_name),
      info = paste("Failed to get info for", dataset_name)
    )
  }
})

test_that("RPPI hierarchical access works", {
  # Individual index
  ivgr <- get_dataset("rppi", table = "ivgr")
  expect_s3_class(ivgr, "data.frame")

  # Sales aggregation
  sales <- get_dataset("rppi", table = "sales")
  expect_type(sales, "list")
  expect_true("fipezap" %in% names(sales))

  # Rent aggregation
  rent <- get_dataset("rppi", table = "rent")
  expect_type(rent, "list")
  expect_true("iqa" %in% names(rent))
})

test_that("error handling works", {
  # Invalid dataset
  expect_error(
    get_dataset("invalid_dataset"),
    "Dataset 'invalid_dataset' not found"
  )

  # Invalid table
  expect_error(
    get_dataset("rppi", table = "invalid_table"),
    "Invalid table"
  )
})
```

### Phase 6: Migration Guide

#### 6.1 Update NEWS.md
```markdown
# realestatebr 0.4.0

## BREAKING CHANGES

This version removes all legacy `get_*()` functions. Users must now use the unified `get_dataset()` interface.

### Migration Guide

| Old Function | New Function |
|--------------|--------------|
| `get_abecip_indicators(table = "sbpe")` | `get_dataset("abecip", table = "sbpe")` |
| `get_rppi_fipezap()` | `get_dataset("rppi", table = "fipezap")` |
| `get_bcb_series()` | `get_dataset("bcb_economic")` |
| `get_fgv_indicators()` | `get_dataset("fgv_ibre")` |

### New Features
- Unified RPPI dataset with hierarchical access
- Cleaner error messages
- Simplified codebase
```

#### 6.2 Update README
Include clear examples of the new API.

### Phase 7: Final Cleanup

#### 7.1 Delete Legacy Files
Remove all `R/get_*.R` files after internal functions are working.

#### 7.2 Update NAMESPACE
Ensure only public API functions are exported.

#### 7.3 Version Bump
Update DESCRIPTION to version 0.4.0.

## Implementation Checklist

### Pre-Implementation
- [ ] Create git branch `breaking-change-v0.4.0`
- [ ] Document all existing function signatures for reference
- [ ] Identify all downstream dependencies

### Implementation
- [ ] Create internal function directory structure
- [ ] Write all fetch_* internal functions
- [ ] Update dataset registry (consolidate RPPI, fix invalid entries)
- [ ] Rewrite get-dataset.R without legacy support
- [ ] Create comprehensive test suite
- [ ] Test all datasets thoroughly
- [ ] Update all documentation

### Cleanup
- [ ] Delete all legacy get_* files
- [ ] Update NAMESPACE (remove legacy exports)
- [ ] Update vignettes and examples
- [ ] Write migration guide
- [ ] Update NEWS.md with breaking changes
- [ ] Bump version to 0.4.0

### Post-Implementation
- [ ] Run full R CMD check
- [ ] Test on fresh R session
- [ ] Create GitHub release with migration guide
- [ ] Consider keeping 0.3.x branch for transition period

## Risk Assessment

### High Risk
- Breaking existing user code
- Missing edge cases in internal functions

### Mitigation
- Comprehensive testing before release
- Clear migration documentation
- Keep 0.3.x version available
- Consider deprecation warnings in 0.3.1 before full removal in 0.4.0

## Benefits After Implementation

1. **50% code reduction** - Removing duplicate functions
2. **Single source of truth** - One way to access data
3. **Better user experience** - Consistent, predictable interface
4. **Easier maintenance** - Less code to maintain and debug
5. **Cleaner architecture** - Clear separation of public/internal
6. **Future flexibility** - Easy to rename datasets without breaking functions

## Timeline Estimate

- **Week 1**: Create internal functions, test individually
- **Week 2**: Update registry, rewrite get-dataset.R
- **Week 3**: Comprehensive testing, documentation
- **Week 4**: Final cleanup, release preparation

## Decision Point

Before proceeding with this breaking change, consider:
1. Is the user base ready for a breaking change?
2. Should we release 0.3.1 with deprecation warnings first?
3. How long should we maintain the 0.3.x branch?

## Conclusion

This refactor represents a significant improvement in package architecture. While it requires breaking changes, the long-term benefits of a cleaner, more maintainable codebase far outweigh the short-term migration costs. The new architecture will make the package more intuitive for users and easier to extend for developers.