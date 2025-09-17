# realestatebr 0.2.0

## Major Features and Improvements

### 🎯 Phase 1 Modernization Complete

- **Modernized 13 core `get_*` functions** with consistent APIs, CLI-based error handling, and progress reporting
- **Standardized function signatures** with `table`, `cached`, `quiet`, and `max_retries` parameters
- **Robust error handling** with retry logic, exponential backoff, and informative error messages
- **Enhanced documentation** with comprehensive examples and @section blocks

### 📊 New Unified Data Architecture

- **`list_datasets()`** - Discover available datasets with filtering capabilities
- **`get_dataset()`** - Unified data access function with intelligent fallback
- **Registry system** in `inst/extdata/datasets.yaml` for centralized dataset management
- **Improved caching** with standardized cache location and validation

### 🔧 API Standardization

- **Introduced `table` parameter** replacing `category` across all functions
- **Backward compatibility maintained** with deprecation warnings for `category` parameter
- **Consistent return types** - single tibble by default, list when `table = "all"`
- **Metadata attributes** on all returned data with source tracking and download info

### 📈 New Data Sources

- **CBIC construction materials data**:
  - `get_cbic_cement()` - Cement consumption, production, and CUB prices
  - `get_cbic_steel()` - Steel prices and production data
  - `get_cbic_pim()` - Industrial production indices
- **Enhanced RPPI suite** with improved coordination and error handling
- **Updated B3 stock data** with standardized column names

### 🚀 Performance and Reliability

- **Progress reporting** with `cli` package integration for long-running operations
- **Exponential backoff** for failed web scraping and API calls
- **Parallel processing support** in web scraping functions
- **Comprehensive input validation** with helpful error messages

### 🌐 Bilingual Support

- **Translation system** for Portuguese/English column names and values
- **Standardized naming conventions** across all datasets
- **Region and state name translations** for geographic data

## Breaking Changes

### Parameter Changes
- **`category` parameter deprecated** across all functions in favor of `table`
  - Backward compatibility maintained with deprecation warnings
  - Will be removed in a future version
  - Migration: Replace `category = "value"` with `table = "value"`

### Cache Location
- **Cache moved** from `cached_data/` to `inst/cached_data/` for package compliance
- Existing cache files automatically migrated

## Modernized Functions

### Fully Modernized (13 functions)
- `get_abecip_indicators()` - ABECIP real estate financing data
- `get_abrainc_indicators()` - ABRAINC launches and sales data
- `get_b3_stocks()` - B3 stock market data with improved column naming
- `get_bcb_realestate()` - Central Bank real estate credit data
- `get_bcb_series()` - BCB macroeconomic time series
- `get_bis_rppi()` - Bank for International Settlements RPPI data
- `get_cbic_cement()` - CBIC cement industry data (NEW)
- `get_cbic_steel()` - CBIC steel industry data (NEW)
- `get_cbic_pim()` - CBIC industrial production data (NEW)
- `get_fgv_indicators()` - FGV construction confidence indicators
- `get_nre_ire()` - Real Estate Index from NRE-Poli USP
- `get_property_records()` - Property registration data with robust Excel processing
- `get_rppi()` - Comprehensive RPPI coordinator with all sources
- `get_secovi()` - SECOVI-SP real estate data with parallel processing

### Legacy Functions (Maintained)
- `get_rppi_bis()` - Maintained as deprecated wrapper with modernized backend
- `get_itbi()` and `get_itbi_bhe()` - Planned for Phase 3 (DuckDB integration)

## Infrastructure Improvements

### New Architecture Components
- **Dataset registry system** with YAML configuration
- **Unified cache management** with validation and fallback
- **Translation framework** for multilingual support
- **Helper function ecosystem** for robust web operations

### Developer Experience
- **Comprehensive test suite** with 35+ tests covering all modernized functions
- **Consistent documentation patterns** with @section blocks and examples
- **CLI-based development workflow** with `devtools` integration
- **GitHub Actions** for automated testing and deployment

## Migration Guide

### For Existing Code
```r
# Old (deprecated but still works)
data <- get_abecip_indicators(category = "all")

# New (recommended)
data <- get_abecip_indicators(table = "all")
```

### For New Code
```r
# Discover available datasets
datasets <- list_datasets()

# Get data with unified interface
data <- get_dataset("abecip_indicators")

# Use modernized functions with progress
data <- get_abecip_indicators(table = "indicators", quiet = FALSE)
```

## Technical Details

### Dependencies
- **Added**: `cli` for modern error handling and progress reporting
- **Enhanced**: Better integration with `dplyr`, `readr`, `httr`, and `rvest`
- **Maintained**: Full backward compatibility with existing dependencies

### Performance
- **Improved web scraping** with intelligent retry logic
- **Faster cache access** with optimized file structure
- **Better memory usage** with streaming and lazy loading where appropriate

---

*This release represents the completion of Phase 1 modernization, establishing a solid foundation for Phase 2 (data pipeline automation) and Phase 3 (large dataset support with DuckDB).*

**Full Changelog**: https://github.com/viniciusoike/realestatebr/compare/v0.1.5...v0.2.0