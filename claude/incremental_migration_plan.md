# Incremental Migration Plan: realestatebr Package

## Executive Summary

This plan addresses the incomplete migration to a unified `get_dataset()` interface by taking an **incremental, test-driven approach**. We will fix one dataset at a time, starting with the most problematic ones, while maintaining full backward compatibility.

**Key Principle**: Never break working code. Add new functionality alongside existing code, validate thoroughly, then deprecate old code.

## Learning from Past Failures

### From v0.4.0 Post-Mortem
- ❌ **Don't**: Remove working code before replacement is proven
- ❌ **Don't**: Create placeholder implementations
- ❌ **Don't**: Make big-bang changes in single commits
- ✅ **Do**: Keep old functions working during transition
- ✅ **Do**: Test actual data, not just structure
- ✅ **Do**: Make incremental, reversible changes

### From v0.3.0 Fixes Document
- Need to standardize `category` → `table` parameter
- Must provide informative messages about available tables
- Should validate user inputs and provide helpful errors

## Current State Assessment

### Critical Issues (Priority 1)
1. **Missing function**: `get_cbic()` doesn't exist but registry references it
2. **Parameter mismatch**: `get_bcb_realestate()` expects `category` not `table`
3. **Empty returns**: `get_abrainc_indicators()` returns empty list
4. **Incomplete data**: `get_b3_stocks()` has missing tickers

### Working Functions
- ✅ `get_abecip_indicators()` - Fully functional
- ✅ `get_rppi()` family - Complex but working
- ✅ `get_secovi()` - Working with minor issues

## Implementation Strategy

### Phase 0: Setup Testing Infrastructure (Day 1)

#### Step 0.1: Create validation tests
```r
# tests/testthat/test-data-validation.R
test_that("dataset returns actual data", {
  data <- get_dataset("abecip", source = "fresh")
  expect_true(nrow(data) > 0)
  expect_false(all(is.na(data[[2]])))  # Check second column has values
})
```

#### Step 0.2: Create snapshot tests for working functions
```r
# Capture current working state
abecip_snapshot <- get_abecip_indicators(table = "sbpe")
saveRDS(abecip_snapshot, "tests/testthat/snapshots/abecip_sbpe.rds")
```

### Phase 1: Fix Critical Bug - Missing `get_cbic()` (Day 2)

#### Step 1.1: Create minimal wrapper function
```r
# R/get_cbic_wrapper.R
#' @keywords internal
get_cbic <- function(table = "cement", cached = FALSE, quiet = FALSE, max_retries = 3L) {
  # Minimal wrapper to make get_dataset() work
  if (table == "all" || table == "cement") {
    return(get_cbic_cement(table = "all", cached = cached, quiet = quiet))
  } else if (table == "steel") {
    return(get_cbic_steel(table = "all", cached = cached, quiet = quiet))
  } else if (table == "pim") {
    return(get_cbic_pim(cached = cached, quiet = quiet))
  } else {
    cli::cli_abort("Unknown CBIC table: {table}")
  }
}
```

#### Step 1.2: Test the fix
```r
# Verify get_dataset("cbic") now works
test_that("cbic dataset accessible via get_dataset", {
  expect_no_error(get_dataset("cbic", source = "fresh"))
})
```

### Phase 2: Fix Parameter Mapping Issues (Day 3-4)

#### Step 2.1: Fix `get_bcb_realestate` parameter mismatch
```r
# In R/get-dataset.R, update get_from_legacy_function()
if (legacy_function == "get_bcb_realestate") {
  args$category <- table  # BCB uses 'category' not 'table'
  args$table <- NULL
}
```

#### Step 2.2: Add parameter validation with helpful messages
```r
# In R/get-dataset.R, enhance validate_and_resolve_table()
validate_and_resolve_table <- function(name, dataset_info, table = NULL) {
  available_tables <- get_available_tables(dataset_info)

  if (!is.null(table) && !is.null(available_tables)) {
    if (!table %in% available_tables) {
      cli::cli_abort(c(
        "Invalid table '{table}' for dataset '{name}'",
        "i" = "Available tables: {paste(available_tables, collapse = ', ')}"
      ))
    }
  }
  # ... rest of function
}
```

### Phase 3: Fix ABRAINC Empty Returns (Day 5)

#### Step 3.1: Debug why abrainc returns empty list
```r
# Investigation code
data <- get_abrainc_indicators(table = "indicator", cached = FALSE)
# Check what's actually being returned
str(data)
```

#### Step 3.2: Fix the data fetching logic
```r
# Likely issue: wrong table name or parsing error
# Fix in get_abrainc_indicators() or its import functions
```

#### Step 3.3: Add validation
```r
test_that("abrainc returns non-empty data", {
  data <- get_dataset("abrainc", table = "indicator")
  expect_s3_class(data, "data.frame")
  expect_gt(nrow(data), 0)
})
```

### Phase 4: Enhance User Experience (Day 6-7)

#### Step 4.1: Add informative messages
```r
# In R/get-dataset.R
show_import_message <- function(name, table_info) {
  if (!is.null(table_info$available_tables)) {
    imported <- table_info$resolved_table
    available <- paste(table_info$available_tables, collapse = "', '")
    cli::cli_inform(
      "Imported '{imported}' table from '{name}'. Available tables: '{available}'"
    )
  }
}
```

#### Step 4.2: Improve error messages
```r
# Better error for missing functions
if (!exists(legacy_function, mode = "function")) {
  cli::cli_abort(c(
    "Dataset '{name}' is not properly configured",
    "x" = "Implementation function '{legacy_function}' not found",
    "i" = "This is a package bug. Please report it at:",
    "i" = "https://github.com/realestatebr/realestatebr/issues"
  ))
}
```

### Phase 5: Handle Complex RPPI Dataset (Day 8-10)

The RPPI dataset is complex with multiple sub-indices. Handle carefully:

#### Step 5.1: Map RPPI categories properly
```r
# In datasets.yaml, ensure all RPPI subcategories are listed
categories:
  fipezap:
    name: "FIPE-ZAP Index"
  ivgr:
    name: "IVGR Index"
  igmi:
    name: "IGMI Index"
  # ... etc
```

#### Step 5.2: Update get_rppi to handle table parameter correctly
```r
# Current uses 'category', need to support both
get_rppi <- function(table = "sale", category = NULL, ...) {
  # Backward compatibility
  if (!is.null(category)) {
    .Deprecated(msg = "Use 'table' instead of 'category'")
    table <- category
  }
  # ... rest of function
}
```

### Phase 6: Add Deprecation Warnings (Day 11)

Only after everything works via `get_dataset()`:

#### Step 6.1: Add soft deprecation
```r
# In each get_* function, add at the top:
if (!isTRUE(getOption("realestatebr.suppress_deprecation"))) {
  cli::cli_inform(c(
    "i" = "Consider using `get_dataset('{dataset_name}')` instead",
    "i" = "The direct get_* functions will be deprecated in future versions"
  ))
}
```

### Phase 7: Documentation and Testing (Day 12)

#### Step 7.1: Update examples
```r
#' @examples
#' # Modern way (recommended)
#' data <- get_dataset("abecip", table = "sbpe")
#'
#' # Legacy way (still works but discouraged)
#' data <- get_abecip_indicators(table = "sbpe")
```

#### Step 7.2: Create migration guide
Create `vignettes/migration-guide.Rmd` showing how to update code.

## Testing Strategy

### Before Each Change
```r
# Capture current state
snapshot_before <- get_[function_name]()
saveRDS(snapshot_before, "temp_snapshot.rds")
```

### After Each Change
```r
# Verify still works
snapshot_after <- get_[function_name]()
snapshot_before <- readRDS("temp_snapshot.rds")

# Same structure?
expect_equal(names(snapshot_after), names(snapshot_before))

# Same data?
expect_equal(nrow(snapshot_after), nrow(snapshot_before))

# Via get_dataset?
unified_result <- get_dataset("[dataset_name]")
expect_equal(unified_result, snapshot_after)
```

## Implementation Schedule

| Week | Phase | Focus | Validation |
|------|-------|-------|------------|
| 1 | 0-1 | Setup & Critical Bugs | CBIC works via get_dataset() |
| 1 | 2 | Parameter Mapping | BCB realestate works |
| 1 | 3 | Fix ABRAINC | Returns actual data |
| 2 | 4 | User Experience | Clear messages shown |
| 2 | 5 | Complex RPPI | All sub-indices accessible |
| 3 | 6-7 | Deprecation & Docs | Migration guide complete |

## Success Criteria

### Phase Completion Checklist
- [ ] All tests pass (`devtools::test()`)
- [ ] No functions return empty data
- [ ] `get_dataset()` works for all datasets
- [ ] Legacy functions still work
- [ ] Informative messages displayed
- [ ] Errors are helpful and actionable

### Overall Success Metrics
1. **Backward Compatibility**: 100% of existing code continues to work
2. **Data Integrity**: All functions return same data as before
3. **User Experience**: Clear messages and helpful errors
4. **Test Coverage**: Every dataset has validation tests
5. **Documentation**: Migration path clearly documented

## Risk Mitigation

### For Each Change
1. **Test first**: Write test for current behavior
2. **Change small**: One function/parameter at a time
3. **Validate**: Compare before/after results
4. **Commit**: Save working state immediately
5. **Document**: Update relevant documentation

### Rollback Strategy
- Each phase is independently revertible
- Git commits after each successful change
- Snapshot tests preserve expected behavior
- Feature flags for gradual rollout if needed

## Common Pitfalls to Avoid

1. **Don't remove working code** until replacement is proven
2. **Don't use placeholders** that return empty structures
3. **Don't trust structure tests** - verify actual data
4. **Don't batch changes** - one fix at a time
5. **Don't skip validation** - test every change

## Communication Plan

### For Users
- No breaking changes in this migration
- Deprecation warnings will appear gradually
- Full migration guide will be provided
- Legacy functions continue working

### For Developers
- Each phase has clear success criteria
- All changes are incremental and testable
- Rollback is always possible
- Documentation updated continuously

## Next Steps

1. **Day 1**: Set up testing infrastructure
2. **Day 2**: Fix critical CBIC bug
3. **Day 3-4**: Fix parameter mapping
4. **Continue**: Follow schedule above

## Notes

- This plan prioritizes stability over speed
- Each phase builds on the previous one
- User experience is paramount
- Full backward compatibility maintained throughout

---

**Remember**: It's better to take 3 weeks and maintain a working package than to break everything in one day. Every change should be validated with actual data, not just structure checks.