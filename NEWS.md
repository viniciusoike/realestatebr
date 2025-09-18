# realestatebr 0.4.0

## Major Breaking Changes - API Consolidation

### 🎯 Unified Data Interface

This release implements a **major breaking change** that consolidates 15+ individual `get_*()` functions into a single, unified `get_dataset()` interface. This dramatically simplifies the package API while maintaining full functionality.

**BREAKING CHANGE**: All individual `get_*()` functions have been removed:
- `get_abecip_indicators()`, `get_abrainc_indicators()`, `get_rppi()`, `get_bcb_realestate()`, etc.
- **Migration**: Use `get_dataset("dataset_name")` instead

### 🏗️ New Internal Architecture

- **Internal fetch functions**: Created 12 new `fetch_*()` functions with `@keywords internal`
- **Registry-driven**: All datasets managed through centralized `inst/extdata/datasets.yaml`
- **Hierarchical RPPI**: Consolidated `rppi` and `rppi_indices` into single hierarchical structure
- **Consistent parameters**: All internal functions use standardized `table`, `cached`, `quiet`, `max_retries`

### 📋 Simplified Public API

**New unified interface:**
```r
# Get data from any dataset
data <- get_dataset("abecip")               # Default table
data <- get_dataset("abecip", table = "sbpe")  # Specific table
data <- get_dataset("rppi", table = "fipezap")  # Hierarchical access

# Discover datasets
datasets <- list_datasets()
info <- get_dataset_info("rppi")
```

**Removed functions (now internal):**
- `get_abecip_indicators()` → `get_dataset("abecip")`
- `get_abrainc_indicators()` → `get_dataset("abrainc")`
- `get_rppi()` → `get_dataset("rppi")`
- `get_bcb_realestate()` → `get_dataset("bcb_realestate")`
- `get_bcb_series()` → `get_dataset("bcb_series")`
- Plus 10 more functions

### 🔧 Enhanced Data Access

- **Smart fallback**: Auto fallback from GitHub cache → fresh download
- **Source control**: Explicit `source = "cache"/"github"/"fresh"` options
- **Better error messages**: Detailed troubleshooting information
- **Metadata preservation**: All data includes source tracking and download info

### 🧪 Comprehensive Testing

- **New test suite**: `test-internal-functions-0.4.0.R` with 100 tests
- **Registry validation**: Ensures all datasets have proper internal function mappings
- **Parameter consistency**: Validates all internal functions follow standard interface
- **Hierarchical testing**: Comprehensive RPPI access pattern validation

## Migration Guide

### For Existing Code (Breaking Changes)

```r
# OLD (0.3.x) - Will no longer work
data <- get_abecip_indicators(table = "sbpe")
data <- get_rppi(table = "fipezap")
data <- get_bcb_realestate(table = "all")

# NEW (0.4.0) - Required migration
data <- get_dataset("abecip", table = "sbpe")
data <- get_dataset("rppi", table = "fipezap")
data <- get_dataset("bcb_realestate", table = "all")
```

### Dataset Name Mapping

| Old Function | New get_dataset() Name |
|-------------|---------------------|
| `get_abecip_indicators()` | `"abecip"` |
| `get_abrainc_indicators()` | `"abrainc"` |
| `get_rppi()` | `"rppi"` |
| `get_bcb_realestate()` | `"bcb_realestate"` |
| `get_bcb_series()` | `"bcb_series"` |
| `get_bis_rppi()` | `"bis_rppi"` |
| `get_secovi()` | `"secovi"` |
| `get_fgv_indicators()` | `"fgv_indicators"` |
| `get_b3_stocks()` | `"b3_stocks"` |
| `get_nre_ire()` | `"nre_ire"` |
| `get_cbic_*()` | `"cbic"` |
| `get_itbi()` | `"itbi"` |
| `get_property_records()` | `"registro"` |

### RPPI Consolidation

```r
# OLD - Multiple functions
fipezap <- get_rppi_fipezap()
igmi <- get_rppi_igmi()
bis <- get_rppi_bis()

# NEW - Unified hierarchical access
fipezap <- get_dataset("rppi", table = "fipezap")
igmi <- get_dataset("rppi", table = "igmi")
bis <- get_dataset("rppi", table = "bis")
```

## Technical Implementation

### Internal Architecture
- **12 internal fetch functions**: `fetch_rppi()`, `fetch_abecip()`, etc.
- **Registry system**: Complete mapping in `datasets.yaml`
- **Fallback mechanism**: `get_from_internal_function()` → `get_from_legacy_function()`
- **NAMESPACE cleanup**: Only exports `get_dataset()`, `list_datasets()`, utilities

### Backward Compatibility
- **Phase 1**: Internal functions call legacy functions for gradual transition
- **Testing**: Comprehensive test coverage ensures functionality preservation
- **Error handling**: Graceful degradation with informative error messages

---

*This release represents a major architectural shift toward a unified, maintainable API. While it introduces breaking changes, the new interface is significantly simpler and more powerful.*

**Full Changelog**: https://github.com/viniciusoike/realestatebr/compare/v0.3.0...v0.4.0

---

# realestatebr 0.3.0

## Major Features and Improvements

### 🎯 Phase 2: Data Pipeline Implementation Complete

- **{targets} Pipeline Framework**: Implemented comprehensive targets workflow for automated data processing and validation
- **Automated Data Workflows**: Added daily and weekly GitHub Actions workflows using the targets pipeline
- **Data Validation Infrastructure**: Added comprehensive validation rules and reporting for all datasets
- **Pipeline Performance Monitoring**: Added automated report generation and validation status tracking

### 📊 Enhanced Data Processing

- **Targets Pipeline**: `_targets.R` workflow with automated dependency management and parallel processing
- **Validation System**: Comprehensive data validation rules with automated quality checks
- **Pipeline Helpers**: Centralized helper functions for consistent data processing across all sources
- **Report Generation**: Automated pipeline status reports and data quality summaries

### 🔧 Improved Function Reliability

- **Error Handling**: Enhanced error handling in `cache.R` with better fallback mechanisms
- **Function Fixes**: Fixed parameter bugs in `get_abrainc_indicators()` (category → table)
- **Data Access**: Improved `get_nre_ire()` to use internal package data directly
- **Internal Data**: Updated `sysdata.rda` with latest processed datasets

### 🚀 Infrastructure Improvements

- **Workflow Automation**: Replaced single update workflow with focused daily/weekly pipelines
- **Cache Management**: Improved cache validation and fallback strategies
- **Data Source Updates**: Enhanced FGV data cleaning with improved formatting
- **Dependency Updates**: Added `targets` and `tarchetypes` to package dependencies

### 📈 New Data Sources

- **B3 Stocks**: Added enhanced B3 stock data processing with standardized formatting
- **FGV Indicators**: Improved FGV consultation data processing and validation
- **Industrial Production**: Enhanced CBIC PIM data integration
- **Construction Materials**: Updated CBIC cement and steel data processing

## Technical Implementation

### Targets Pipeline Architecture
- **Automated Processing**: All datasets now processed through unified targets pipeline
- **Quality Assurance**: Built-in validation and quality checks for all data sources
- **Performance Monitoring**: Real-time pipeline status and error reporting
- **Dependency Management**: Automatic detection of data updates and re-processing

### Enhanced Error Handling
- **Graceful Degradation**: Improved fallback mechanisms for failed data retrievals
- **Better Diagnostics**: Enhanced error messages and troubleshooting information
- **Retry Logic**: Smart retry mechanisms with exponential backoff
- **Progress Reporting**: Real-time progress updates during long-running operations

### Data Quality Improvements
- **Validation Rules**: Comprehensive validation for all datasets
- **Metadata Tracking**: Enhanced metadata preservation and source tracking
- **Format Standardization**: Consistent data formatting across all sources
- **Quality Metrics**: Automated quality assessment and reporting

## Migration Notes

### For Existing Users
- All existing functions continue to work unchanged
- Enhanced reliability and performance with new pipeline backend
- Improved error messages and troubleshooting information
- Better cache management and fallback strategies

### For Developers
- New targets pipeline provides foundation for custom data workflows
- Enhanced validation framework for quality assurance
- Standardized helper functions for consistent data processing
- Comprehensive pipeline documentation and examples

---

*This release establishes the foundation for automated data processing and validation, setting the stage for Phase 3 implementation with large dataset support.*

**Full Changelog**: https://github.com/viniciusoike/realestatebr/compare/v0.2.0...v0.3.0

---

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