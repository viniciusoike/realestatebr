# Version 0.3.0 Fixes and Refactoring

## Overview
This document tracks all planned changes for v0.3.0 package cleanup and refactoring.

## Issues Identified

### 1. Inconsistent Parameter Naming
**Issue**: Functions use both `category` and `table` parameters inconsistently
**Recommendation**: Standardize to `table` throughout the codebase

### 2. CSV Format Issues
**Issue**: Potential tab delimiters in some cached files (mentioned but not confirmed)
**Recommendation**: Ensure all CSV files use proper comma delimiters with `readr::write_delim(data, path, delim = ",")`

### 3. Function Deprecation Needed
**Issue**: Package maintains too many legacy get_* functions alongside new unified interface
**Recommendation**: Deprecate individual get_* functions in favor of unified interface

### 4. Dataset Discovery
**Issue**: list_datasets() doesn't show available table options for multi-table datasets
**Recommendation**: Enhance to show available tables for each dataset. Using get_datasets() can trigger a message listing available tables for each specific choice. Currenly, get_dataset() always returns the first table if multiple tables exist which is good. But even when the users inputs the wrong value in 'category' it returns the first table without warning. We should warn the user if they input a wrong value.

```r
# How it currently works

# Returns the IVGR table from rppi with no message
get_dataset("rppi")

# Returns the IVGR table from rppi with no warning
# note that category is the outdated parameter name, we should standardize to 'table'
get_dataset("rppi", category = "oijdfoasd")

# How it should work

get_datasets("abecip")
# Returns the sbpe tibble from abecip.
# Message: Imported 'sbpe' table from 'abecip'. All tables available: 'sbpe', 'units', 'cgi'

# Returns the IVGR table from rppi with a message
get_dataset("rppi")
# Returns the IVGR table
# Message: Imported 'IVGR' table from 'rppi'. All tables available: 'ivgr', 'fipe', [insert other tables here].

# Return the FIPE table with a message
get_dataset("rppi", table = "fipe")
# Returns the Fipe table
# Message: Imported 'FIPEZAP' table from 'rppi'. All tables available: 'ivgr', 'fipe', [insert other tables here].

# Don't return any table and warn the user
get_dataset("rppi", table = "oijdfoasd")
# Error: Invalid table 'oijdfoasd' for dataset 'rppi'. Available tables: 'ivgr', 'fipe', [insert other tables here].
```

```r

```

### 5. Export Cleanup
**Issue**: explore_cbic_structure() is exported but should be internal
**Recommendation**: Remove export

### 6. Dataset Registry Naming
**Issue**: Dataset names inconsistent with function names and conventions
**Recommendation**: Rename for consistency. Prioritize brevity and clarity, since the user has to mannually type these names.

### 7. Missing Datasets
**Issue**: Some datasets (property_records) missing from registry
**Recommendation**: Add all datasets to registry. Remember to always ignore ITBI. The rppi dataset seems to return only IVGR, make sure that it provides

---

## Detailed Change Plan

### 1. Parameter Standardization: category → table

#### Files to Update
- **Primary Functions** (already use table, need to verify consistency):
  - `R/get_abecip_indicators.R` - Uses `table` parameter ✓
  - `R/get_abrainc_indicators.R` - Uses `table` parameter (was category, fixed in previous commit)
  - `R/get_bcb_series.R` - Uses `table` parameter ✓
  - `R/get_cbic.R` - Uses `table` parameter ✓
  - `R/get_fgv_indicators.R` - Uses `table` parameter ✓
  - `R/get_rppi.R` - Uses `table` parameter ✓
  - `R/get_secovi.R` - Uses `category` parameter ⚠️
  - check similar functions

- **Helper Functions**:
  - `R/get-dataset.R`:
    - `get_dataset_with_fallback()` - uses `category` ⚠️
    - `get_dataset_from_source()` - uses `category` ⚠️
    - `get_from_local_cache()` - uses `category` ⚠️
    - `get_from_github_cache()` - uses `category` ⚠️
    - `get_from_legacy_function()` - uses `category` ⚠️
    - `get_cached_name()` - uses `category` ⚠️
    - `functions_with_category` variable - rename to `functions_with_table` ⚠️

- **list_datasets.R**:
  - Update filter parameter from `category` to `table.

#### Documentation Updates
- Update all @param documentation from `category` to `table`.
- Update all function examples that use `category` parameter.
- Update vignettes if they mention `category`.

#### Test Updates
- `tests/testthat/test-new-architecture.R` - verify if uses category parameter.
- Update any test that calls functions with `category = ` parameter.

#### Targets Pipeline Updates
- Check `_targets.R` for any references to `category` parameter
- Check `data-raw/` scripts for category references

---

### 2. CSV Format Standardization

#### Investigation Needed
- Check actual cached files to see current format
- Files currently use `readr::write_csv()` in:
  - `data-raw/targets_helpers.R` ✓
  - `data-raw/generate_report.R` ✓
  - `data-raw/DATASET.R` ✓

#### Action Items
- Verify all cached datasets use comma delimiters
- If tab-delimited files found, convert them
- Ensure all write operations use `readr::write_delim(x, delim = ",")`

---

### 3. Function Deprecation Strategy

#### Functions to Deprecate
All get_* functions except:
- `get_dataset()` - main unified interface
- `get_dataset_info()` - metadata function
- `get_cache_path()` - utility function
- `get_cbic_files()` - specialized utility (consider keeping)

#### Deprecation Implementation
1. Add `.Deprecated()` call at the beginning of each function
2. Update roxygen documentation:
   - Add `@keywords internal`
   - Add deprecation notice in @description
   - Point users to `get_dataset()`
3. Keep functions working for backward compatibility

#### Example Deprecation Pattern
```r
#' @keywords internal
#' @description
#' \lifecycle{deprecated}
#' This function is deprecated. Please use `get_dataset("dataset_name")` instead.
get_abecip_indicators <- function(table = "all") {
  .Deprecated("get_dataset", package = "realestatebr",
              msg = "get_abecip_indicators() is deprecated. Use get_dataset('abecip') instead.")
  # ... existing code continues to work
}
```

#### NAMESPACE Changes
- Remove exports for deprecated functions (Phase 2 - after deprecation period)
- For now, keep exports but add deprecation warnings

---

### 4. Enhance list_datasets()

#### Current Output
- Shows: name, title, description, source, geography, frequency, coverage, categories (count), data_type, legacy_function

#### Proposed Enhancement
- Add `available_tables` column showing table options for multi-table datasets
- Format: "sbpe, units, cgi" for abecip_indicators
- Extract from datasets.yaml categories section

#### Implementation
- Modify `registry_to_tibble()` function to extract category names
- Add new column to output tibble
- Update documentation

---

### 5. Remove explore_cbic_structure() Export

#### Changes Required
- Add `#' @keywords internal` to function documentation in `R/get_cbic.R`
- Regenerate NAMESPACE with `devtools::document()`
- Verify function is no longer exported

---

### 6. Dataset Registry Renaming

#### Proposed Renames
| Current Name | New Name | Rationale |
|--------------|----------|-----------|
| abecip_indicators | abecip | Consistency, brevity |
| abrainc_indicators | abrainc | Consistency, brevity |
| bcb_series | bcb_macroeconomic | More descriptive |
| fgv_indicators | fgv_ibre | More specific |
| rppi | fipezap | Match data source |

#### Impact Analysis
- Update `inst/extdata/datasets.yaml`
- Update cache file names (if using dataset name in filename)
- Update get_dataset() switch statement mappings
- Update any hardcoded dataset names in:
  - `R/get-dataset.R`
  - Test files
  - Documentation
  - Vignettes

#### Migration Strategy
- Support both old and new names temporarily
- Add aliases in get_dataset() function
- Warn users about name changes

---

### 7. Add Missing Datasets to Registry

#### Datasets to Add

3. **property_records** / **registro_imoveis** - Property registration data


#### Required Information
For each dataset, add to datasets.yaml:
- name (English and Portuguese)
- description
- source and URL
- geography coverage
- frequency
- time coverage
- categories (if applicable)
- data_type

---

## Implementation Order

### Phase 1: Non-Breaking Changes
1. ✅ Fix explore_cbic_structure() export
2. ✅ Add missing datasets to registry
3. ✅ Enhance list_datasets() with available_tables
4. ✅ Verify CSV format (no changes if already correct)

### Phase 2: Parameter Standardization
1. ⚠️ Update all `category` → `table` in helper functions
2. ⚠️ Update get_secovi() parameter
3. ⚠️ Update documentation
4. ⚠️ Update tests
5. ⚠️ Test thoroughly

### Phase 3: Deprecation (Can be done gradually)
1. 🔄 Add deprecation warnings to get_* functions
2. 🔄 Update documentation with @keywords internal
3. 🔄 Create migration guide for users

### Phase 4: Registry Renaming (Major Change)
1. 📋 Create alias system first
2. 📋 Update registry with new names
3. 📋 Update all references
4. 📋 Test backward compatibility
5. 📋 Document changes in NEWS.md

---

## Testing Checklist

Before each phase:
- [ ] Run `devtools::check()`
- [ ] Run `devtools::test()`
- [ ] Test key functions manually
- [ ] Verify backward compatibility
- [ ] Update documentation
- [ ] Check examples still work

## Backward Compatibility Notes

### Critical Requirements
1. All existing code using get_* functions must continue working
2. Dataset names in get_dataset() should support old names via aliases
3. Parameter changes should accept both old and new parameter names temporarily

### Deprecation Timeline
- v0.3.0: Add deprecation warnings
- v0.4.0: Remove exports but keep functions
- v1.0.0: Consider removing deprecated functions entirely

---

## Documentation Updates Required

1. **NEWS.md** - Document all changes
2. **README.md** - Update examples if needed
3. **Vignettes** - Update any that use deprecated functions
4. **Website** - Regenerate pkgdown site
5. **CHANGELOG** - Create if doesn't exist

---

## Risk Assessment

### High Risk Changes
- Dataset renaming (could break existing user code)
- Parameter renaming (could break existing user code)

### Medium Risk Changes
- Function deprecation (managed with warnings)
- Registry updates (backward compatible with aliases)

### Low Risk Changes
- Remove explore_cbic_structure() export (unlikely to be used externally)
- CSV format verification (no change if already correct)
- list_datasets() enhancement (additive only)

---

## Notes and Considerations

1. **Timing**: Consider releasing non-breaking changes first (0.3.1), then breaking changes in 0.4.0
2. **Communication**: Need clear migration guide for users
3. **Testing**: Extensive testing required for parameter changes
4. **Documentation**: Must be very clear about deprecations
5. **Support**: May need to maintain deprecated functions longer than planned

---

## Status Tracking

- [ ] Issue analysis complete
- [ ] Plan reviewed and approved
- [ ] Phase 1 implementation
- [ ] Phase 2 implementation
- [ ] Phase 3 implementation
- [ ] Phase 4 implementation
- [ ] Documentation updated
- [ ] Tests updated
- [ ] Package checked
- [ ] Release prepared
