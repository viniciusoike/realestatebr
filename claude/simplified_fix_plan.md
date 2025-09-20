# Simplified Fix Plan: realestatebr Package

## Goal
Fix the broken transition to `get_dataset()` unified interface. Make it work properly without worrying about deprecation or backward compatibility complexities.

## Executive Summary

This plan addresses the incomplete migration to a unified `get_dataset()` interface by taking an **incremental, test-driven approach**. We will fix one dataset at a time, starting with the most problematic ones

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

## Priority Issues to Fix

### 1. Missing `get_cbic()` Function (CRITICAL)
**Problem**: Registry references `get_cbic` but it doesn't exist
**Solution**: Create wrapper function that calls the existing sub-functions

### 2. Parameter Mismatches
**Problem**: Functions expect different parameter names (category vs table)
**Solution**: Fix the mapping in `get_from_legacy_function()`

### 3. Empty Data Returns
**Problem**: Some functions return empty lists/tibbles
**Solution**: Debug and fix each one

## Step-by-Step Implementation

---

## Day 1: Fix CBIC (Most Critical)

### Step 1: Create the missing `get_cbic()` wrapper

```r
# R/get_cbic_wrapper.R
get_cbic <- function(table = "all", cached = FALSE, quiet = FALSE, max_retries = 3L) {

  # Map to existing functions
  result <- switch(table,
    "all" = list(
      cement = get_cbic_cement(table = "all", cached = cached, quiet = quiet, max_retries = max_retries),
      steel = get_cbic_steel(table = "all", cached = cached, quiet = quiet, max_retries = max_retries),
      pim = get_cbic_pim(cached = cached, quiet = quiet, max_retries = max_retries)
    ),
    "cement" = get_cbic_cement(table = "all", cached = cached, quiet = quiet, max_retries = max_retries),
    "steel" = get_cbic_steel(table = "all", cached = cached, quiet = quiet, max_retries = max_retries),
    "pim" = get_cbic_pim(cached = cached, quiet = quiet, max_retries = max_retries),
    # For specific cement tables
    "monthly_consumption" = get_cbic_cement(table = "monthly_consumption", cached = cached, quiet = quiet),
    "annual_consumption" = get_cbic_cement(table = "annual_consumption", cached = cached, quiet = quiet),
    "production_exports" = get_cbic_cement(table = "production_exports", cached = cached, quiet = quiet),
    "cub_prices" = get_cbic_cement(table = "cub_prices", cached = cached, quiet = quiet),
    # Default error
    cli::cli_abort("Invalid table '{table}'. Options: all, cement, steel, pim, or specific cement tables")
  )

  return(result)
}
```

### Test it works:
```bash
R -e "devtools::load_all(); get_dataset('cbic', source = 'fresh')"
```

---

## Day 2: Fix Parameter Mapping

### Step 2: Fix BCB and other parameter issues

In `R/get-dataset.R`, update the `get_from_legacy_function()`:

```r
get_from_legacy_function <- function(name, dataset_info, table, date_start, date_end, ...) {

  legacy_function <- dataset_info$legacy_function

  if (is.null(legacy_function) || legacy_function == "") {
    cli::cli_abort("No legacy function available for fresh download of '{name}'")
  }

  # Build arguments for legacy function
  args <- list(...)

  # Special parameter mappings
  if (legacy_function == "get_bcb_realestate") {
    # BCB uses 'category' not 'table'
    if (!is.null(table)) {
      args$category <- table
    } else {
      args$category <- "all"
    }
  } else if (legacy_function == "get_rppi") {
    # RPPI also uses 'category' for backward compatibility
    if (!is.null(table)) {
      args$category <- table
    }
  } else if (legacy_function %in% c("get_abecip_indicators", "get_abrainc_indicators",
                                     "get_secovi", "get_bis_rppi", "get_cbic")) {
    # These use 'table'
    if (!is.null(table)) {
      args$table <- table
    }
  }

  # Add date arguments if provided
  if (!is.null(date_start)) args$date_start <- date_start
  if (!is.null(date_end)) args$date_end <- date_end

  # Set cached = FALSE for fresh download
  args$cached <- FALSE

  # Call the legacy function
  func <- get(legacy_function, mode = "function")
  data <- do.call(func, args)

  return(data)
}
```

---

## Day 3: Fix ABRAINC Empty Returns

### Step 3: Debug and fix ABRAINC

First, test what's happening:
```r
# Debug code
abrainc_raw <- get_abrainc_indicators(table = "indicator", cached = FALSE)
str(abrainc_raw)
```

The issue is likely in the import or clean functions. Check `import_abrainc_*` functions.

---

## Day 4: Fix User Messages

### Step 4: Add helpful messages and error handling

In `R/get-dataset.R`, enhance the message system:

```r
# Update show_import_message function
show_import_message <- function(name, table_info) {
  if (is.null(table_info$available_tables)) {
    # Single table dataset - no message needed
    return(invisible())
  }

  # Multi-table dataset
  imported_table <- table_info$resolved_table
  available_str <- paste(table_info$available_tables, collapse = "', '")

  cli::cli_inform(
    "Retrieved '{imported_table}' from '{name}'. Available tables: '{available_str}'"
  )
}

# Update validate_and_resolve_table to be more helpful
validate_and_resolve_table <- function(name, dataset_info, table = NULL) {
  available_tables <- get_available_tables(dataset_info)

  # Single-table datasets
  if (is.null(available_tables)) {
    if (!is.null(table)) {
      cli::cli_warn("Dataset '{name}' has only one table. Ignoring table parameter.")
    }
    return(list(
      resolved_table = NULL,
      available_tables = NULL,
      is_default = TRUE
    ))
  }

  # Multi-table datasets
  if (is.null(table)) {
    # Use first table as default but inform user
    resolved_table <- available_tables[1]
    return(list(
      resolved_table = resolved_table,
      available_tables = available_tables,
      is_default = TRUE
    ))
  }

  # Validate specified table
  if (!table %in% available_tables) {
    available_str <- paste(available_tables, collapse = "', '")
    cli::cli_abort(
      c("Invalid table '{table}' for dataset '{name}'.",
        "i" = "Available options: '{available_str}'",
        "i" = "Example: get_dataset('{name}', table = '{available_tables[1]}')")
    )
  }

  return(list(
    resolved_table = table,
    available_tables = available_tables,
    is_default = FALSE
  ))
}
```

---

## Day 5: Test Everything

### Step 5: Comprehensive testing

Create a test script to verify all datasets work:

```r
# tests/manual/test_all_datasets.R
library(realestatebr)

datasets <- list_datasets()$name

results <- list()
for (dataset in datasets) {
  cat("\nTesting:", dataset, "\n")

  # Test with auto source
  tryCatch({
    data_auto <- get_dataset(dataset, source = "auto")
    results[[dataset]]$auto <- list(
      success = TRUE,
      rows = nrow(data_auto),
      cols = ncol(data_auto)
    )
    cat("  ✓ Auto source: ", nrow(data_auto), "rows\n")
  }, error = function(e) {
    results[[dataset]]$auto <- list(
      success = FALSE,
      error = e$message
    )
    cat("  ✗ Auto source failed:", e$message, "\n")
  })

  # Test with fresh source
  tryCatch({
    data_fresh <- get_dataset(dataset, source = "fresh")
    results[[dataset]]$fresh <- list(
      success = TRUE,
      rows = nrow(data_fresh),
      cols = ncol(data_fresh)
    )
    cat("  ✓ Fresh source:", nrow(data_fresh), "rows\n")
  }, error = function(e) {
    results[[dataset]]$fresh <- list(
      success = FALSE,
      error = e$message
    )
    cat("  ✗ Fresh source failed:", e$message, "\n")
  })
}

# Summary
cat("\n=== SUMMARY ===\n")
for (dataset in names(results)) {
  auto_status <- if(results[[dataset]]$auto$success) "✓" else "✗"
  fresh_status <- if(results[[dataset]]$fresh$success) "✓" else "✗"
  cat(sprintf("%-20s Auto: %s  Fresh: %s\n", dataset, auto_status, fresh_status))
}
```

---

## Quick Fixes for Known Issues

### Fix B3 Stocks missing tickers
In `R/get_b3_stocks.R`, add better error handling:
```r
# Wrap the failing ticker downloads in tryCatch
# Continue even if some tickers fail
# Return partial data with warning about missing tickers
```

### Hide internal functions from users
Just add `@keywords internal` to functions we don't want users to see directly:
- All import_* functions
- All clean_* functions
- Helper functions

But keep them exported so get_dataset() can call them.

---

## Testing Checklist

After each fix:
- [ ] Run: `devtools::load_all()`
- [ ] Test: `get_dataset("[dataset_name]", source = "fresh")`
- [ ] Verify: Returns actual data, not empty tibble
- [ ] Check: Helpful messages are shown

---

## Success Criteria

The package is fixed when:
1. ✅ `get_dataset("cbic")` works
2. ✅ `get_dataset("bcb_realestate")` works
3. ✅ `get_dataset("abrainc")` returns data
4. ✅ All datasets accessible via `get_dataset()`
5. ✅ Users see helpful messages about available tables
6. ✅ Invalid table names produce helpful errors

---

## What NOT to Do

Based on the v0.4.0 failure:
- ❌ Don't delete working code
- ❌ Don't create placeholder returns
- ❌ Don't try to fix everything at once
- ❌ Don't trust empty tibbles as "working"

---

## Implementation Order

1. **Fix CBIC** - Create missing wrapper (30 min)
2. **Fix parameter mapping** - Update get_from_legacy_function (30 min)
3. **Test all datasets** - Run comprehensive test (1 hour)
4. **Fix broken ones** - Debug specific issues (2-3 hours)
5. **Add messages** - Improve user feedback (30 min)
6. **Final validation** - Test everything works (30 min)

**Total time**: ~1 day of focused work

---

This simplified plan focuses on making things work rather than perfect architecture. The goal is a functional package where `get_dataset()` reliably returns data for all datasets.
