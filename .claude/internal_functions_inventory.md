# Internal Functions Inventory - realestatebr Package
**Generated**: 2025-10-08
**Package Version**: 0.5.1
**Purpose**: Track internal functions for Phase 1 documentation cleanup (v0.6.0)

---

## Executive Summary

| Metric | Count |
|--------|-------|
| **Total Internal Functions** | 115+ |
| **Files with Internal Functions** | 21 |
| **Total @examples Blocks** | 38 |
| **Files with Examples** | 15 |
| **Target for Removal** | 12 blocks (Tier 2-3) |
| **Estimated Line Savings** | 240-360 lines |

---

## Documentation Cleanup Status

### ⚠️ BLOCKED - Requires Manual Review First
- **R/get_cbic.R**: 17 examples, 2,078 lines, 21 internal functions
  - **Action Required**: User must manually review and clean file before automated cleanup
  - **Estimated Savings**: 340-510 lines (after manual review)

### 🟢 KEEP - Exported User Functions
These have `@keywords internal` but are also `@export` for users:
- **R/cache-user.R**: 3 examples (get_user_cache_dir, load_from_user_cache, etc.)
- **R/cache-github.R**: 2 examples (list_github_assets, download_from_github_release, etc.)
- **R/list-datasets.R**: 2 examples (list_datasets, get_dataset_info)

### ✅ TIER 2 - High Impact, Quick Win
- **R/utils.R**: 4 examples, 259 lines, 3 internal functions
  - Estimated savings: 80-120 lines

### ✅ TIER 3 - Low Impact, Batch Process
8 files with 1 example each:
- R/get-dataset.R
- R/get_secovi.R
- R/get_rppi_bis.R
- R/get_bcb_series.R
- R/get_bcb_realestate.R
- R/get_abrainc_indicators.R
- R/get_abecip_indicators.R
- R/cache.R (deprecated)

Estimated savings: 160-240 lines

---

## Complete File Inventory

### Files by Internal Function Count

#### Large Files (10+ internal functions)
| File | Functions | Lines | Examples | Status |
|------|-----------|-------|----------|--------|
| get_cbic.R | 21 | 2,078 | 17 | ⚠️ BLOCKED |
| get-dataset.R | 11 | 832 | 1 | ✅ Tier 3 |
| get_rppi.R | 11 | 771 | 0 | - |

#### Medium Files (5-9 internal functions)
| File | Functions | Lines | Examples | Status |
|------|-----------|-------|----------|--------|
| translation.R | 9 | 396 | 0 | - |
| cache.R | 8 | 358 | 1 | ✅ Tier 3 |
| cache-user.R | 8 | 385 | 3 | 🟢 KEEP |
| cache-github.R | 7 | 343 | 2 | 🟢 KEEP |
| get_property_records.R | 6 | 679 | 0 | - |
| rppi-helpers.R | 5 | 134 | 0 | - |
| get_rppi_bis.R | 5 | 405 | 1 | ✅ Tier 3 |
| get_abecip_indicators.R | 5 | 579 | 1 | ✅ Tier 3 |

#### Small Files (1-4 internal functions)
| File | Functions | Lines | Examples | Status |
|------|-----------|-------|----------|--------|
| get_itbi.R | 4 | 200 | 0 | - |
| utils.R | 3 | 259 | 4 | ✅ Tier 2 |
| utils-encoding.R | 3 | 57 | 0 | - |
| list-datasets.R | 2 | 228 | 2 | 🟢 KEEP |
| get_bcb_realestate.R | 2 | 435 | 1 | ✅ Tier 3 |
| utils-globals.R | 1 | 46 | 0 | - |
| realestatebr-package.R | 1 | 9 | 0 | - |
| get_secovi.R | 1 | 438 | 1 | ✅ Tier 3 |
| get_bcb_series.R | 1 | 351 | 1 | ✅ Tier 3 |
| get_abrainc_indicators.R | 1 | 580 | 1 | ✅ Tier 3 |

---

## Detailed Function Analysis

### R/get_cbic.R (⚠️ BLOCKED)
**21 internal functions, 17 examples**

Helper Functions (4):
1. `warn_if_level()` - Conditional warning
2. `suppress_external_warnings()` - Suppress package warnings
3. `get_cbic_specific_file()` - Targeted file download
4. `get_cbic_dim_state()` - State dimension helper

Import Functions (4):
5. `import_cbic_materials()` - 1 example
6. `import_cbic_material_links()` - 1 example
7. `import_cbic_file()` - 1 example
8. `import_cbic_files()` - 1 example

Cleaning Functions (13):
9. `read_cbic_cement_monthly()` - No example
10. `clean_cbic_cement_monthly()` - 1 example
11. `clean_cbic_cement_annual()` - No example
12. `clean_cbic_cement_production()` - No example
13. `clean_cbic_cement_monthly_production()` - No example
14. `clean_cbic_cement_cub()` - No example
15. `clean_cbic_pim()` - 1 example
16. `clean_cbic_pim_sheets()` - 1 example
17. `clean_cbic_cement()` - No example
18. `clean_cbic_cement_sheets()` - 1 example
19. `explore_cbic_structure()` - 1 example
20. `clean_cbic_steel_prices()` - 1 example
21. `clean_cbic_steel_production()` - 1 example
22. `clean_cbic_string()` - No example
23. `clean_cbic_steel_sheets()` - 1 example

Get Functions (4 - not counted as internal):
- `get_cbic_files()` - 1 example
- `get_cbic_cement()` - 1 example
- `get_cbic_steel()` - 1 example
- `get_cbic_pim()` - 1 example
- `get_cbic_materials()` - 1 example
- `get_cbic()` - Main function, no example

**Action**: Wait for manual review before cleanup

---

### R/utils.R (✅ TIER 2)
**3 internal functions, 4 examples**

1. `cli_user()` - 1 example
   - User-facing messages
   - ~20-30 lines of examples

2. `cli_debug()` - 1 example
   - Debug messages
   - ~20-30 lines of examples

3. `validate_and_resolve_table()` - 2 examples
   - Table parameter validation
   - ~30-50 lines of examples

**Action**: Remove all 4 example blocks

---

### R/get-dataset.R (✅ TIER 3)
**11 internal functions, 1 example**

Internal functions:
1. `get_from_internal_function()` - Core routing function
2. `get_from_legacy_function()` - Legacy routing
3. `resolve_data_source()` - Source resolution
4. `handle_cache_data()` - Cache handling
5. `handle_github_data()` - GitHub handling
6. `handle_fresh_data()` - Fresh data handling
7. `fetch_rppi()` - RPPI fetcher
8. `fetch_abecip()` - ABECIP fetcher
9. `fetch_abrainc()` - ABRAINC fetcher
10. (and others...)

**Action**: Remove 1 example block from main internal function

---

### Cache Files Analysis

#### R/cache.R (✅ TIER 3 - Deprecated)
**8 internal functions, 1 example**

Functions:
1. `import_cached()` - 1 example (DEPRECATED function)
2. `check_cache_status()` - No example
3. `get_cache_path()` - No example
4. `load_cached_dataset()` - No example
5. `validate_cache_structure()` - No example
6. `cache_timestamp()` - No example
7. `cache_metadata()` - No example

**Status**: Deprecated since v0.5.0, entire file may be removed in Phase 2

**Action**: Remove 1 example block

---

#### R/cache-user.R (🟢 KEEP)
**8 internal functions, 3 examples**

Exported functions (keep examples):
1. `get_user_cache_dir()` - @export, @keywords internal
2. `load_from_user_cache()` - @export, @keywords internal, 1 example
3. `list_cached_files()` - @export, @keywords internal, 1 example
4. `clear_user_cache()` - @export, @keywords internal, 1 example
5. `is_cached()` - @export, @keywords internal

Internal-only functions:
6. `save_to_user_cache()` - @keywords internal only
7. `ensure_cache_dir()` - @keywords internal only
8. `get_cached_file_path()` - @keywords internal only

**Action**: KEEP all examples (user-facing functions)

---

#### R/cache-github.R (🟢 KEEP)
**7 internal functions, 2 examples**

Exported functions (keep examples):
1. `list_github_assets()` - @export, 1 example
2. `download_from_github_release()` - @export, 1 example
3. `is_cache_up_to_date()` - @export
4. `update_cache_from_github()` - @export

Internal-only functions:
5. `check_github_available()` - Internal only
6. `download_and_cache()` - Internal only
7. `get_github_repo()` - Internal only

**Action**: KEEP all examples (user-facing functions)

---

### Single-Example Files (✅ TIER 3)

#### R/get_secovi.R
- 1 internal function: `import_secovi()`
- 1 example block
- Main function `get_secovi()` is internal

#### R/get_rppi_bis.R
- 5 internal functions
- 1 example in main `get_rppi_bis()` function

#### R/get_bcb_series.R
- 1 internal function: `get_bcb_series()`
- 1 example block

#### R/get_bcb_realestate.R
- 2 internal functions
- 1 example in main function

#### R/get_abrainc_indicators.R
- 1 internal function: `import_abrainc()`
- 1 example block

#### R/get_abecip_indicators.R
- 5 internal functions
- 1 example in main function

---

## Documentation Cleanup Pattern

### What to KEEP
```r
#' Function Title
#'
#' Brief description (1-3 lines explaining what it does)
#'
#' @param param1 Description
#' @param param2 Description
#'
#' @return What it returns
#' @keywords internal
#' @source Data source URL (if applicable)
#' @references Citation (if applicable)
```

### What to REMOVE
```r
#' @details
#' Long verbose explanation that duplicates what's in description...
#' (Remove if >5 lines and not adding value)
#'
#' @section Progress Reporting:
#' When quiet = FALSE... (Remove entire section)
#'
#' @section Error Handling:
#' The function includes retry logic... (Remove entire section)
#'
#' @examples
#' \dontrun{
#'   # All example code...
#' }
#' (Remove entire @examples block for internal functions)
```

---

## Expected Outcomes

### Phase 1B Completion (Tiers 2-3 only)
- Files modified: 9
- Examples removed: 12
- Estimated lines saved: 240-360
- Documentation quality: Improved (cleaner, more focused)

### After get_cbic.R Manual Review
- Additional examples removed: 17
- Additional lines saved: 340-510
- Total Phase 1 savings: 580-870 lines

### Quality Metrics
- Internal docs reduced by ~30-40%
- All essential info preserved (@param, @return)
- Easier to navigate for package developers
- No user-facing documentation affected

---

## Notes

1. **Exported but Internal**: Some functions have both `@export` and `@keywords internal`. These are user-facing utilities (cache management). Keep their examples.

2. **get_cbic.R Complexity**: This file needs careful manual review due to:
   - Size (2,078 lines, 21 internal functions)
   - Complex multi-material structure (cement/steel/PIM)
   - Commented-out code blocks (lines 882-983)
   - Incomplete steel/PIM implementation

3. **Priority Order**: Focus on Tier 2 (utils.R) first for quick win, then batch-process Tier 3 files.

4. **Verification**: After cleanup, run `devtools::document()` to regenerate man/ files and ensure no errors.

5. **Next Phase**: After documentation cleanup, proceed to Phase 2 (deprecation removal) focusing on cache.R.

---

## Change Log

| Date | Action | Impact |
|------|--------|--------|
| 2025-10-08 | Initial inventory created | Baseline established |
| TBD | Tier 2 completion | utils.R cleaned |
| TBD | Tier 3 completion | 8 files cleaned |
| TBD | get_cbic.R manual review | User action required |
| TBD | get_cbic.R cleanup | 17 examples removed |

---

**Last Updated**: 2025-10-08
**Status**: Phase 1B in progress
**Next Review**: After Tier 2 completion
