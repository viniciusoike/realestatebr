# Migration Guide: realestatebr 1.0.0

## Overview

realestatebr 1.0.0 introduces a major API simplification that makes the package easier to use while maintaining backward compatibility.

## Key Changes

### 1. Simplified API (Breaking Change)

**Before (0.3.0):**
```r
# Many exported functions
get_abecip_indicators()
get_abrainc_indicators() 
get_bcb_realestate()
get_secovi()
get_b3_stocks()
# ... 20+ functions
```

**After (1.0.0):**
```r
# Only 4 exported functions
get_dataset()
list_datasets()
get_dataset_info()
check_cache_status()
```

### 2. Consistent Return Types (Breaking Change)

**Before:** `get_dataset()` could return lists or tibbles
```r
# Returned a list with multiple tables
data <- get_dataset("abecip_indicators")
str(data)  # List with $sbpe, $units, $cgi
```

**After:** `get_dataset()` always returns a single tibble
```r
# Must specify which table you want
sbpe <- get_dataset("abecip", table = "sbpe")
units <- get_dataset("abecip", table = "units")
cgi <- get_dataset("abecip", table = "cgi")
```

### 3. Dataset Name Standardization

**Before:** Inconsistent naming (`abecip_indicators`, `abrainc_indicators`)
**After:** Simple, consistent names (`abecip`, `abrainc`)

## Migration Examples

### Multi-table Datasets

```r
# OLD (no longer works)
abecip_all <- get_abecip_indicators()
abecip_sbpe <- abecip_all$sbpe

# NEW (recommended)
abecip_sbpe <- get_dataset("abecip", table = "sbpe")

# Legacy function still works (deprecated)
abecip_sbpe <- get_abecip_indicators("sbpe", cached = TRUE)
```

### Single-table Datasets

```r
# OLD
stocks <- get_b3_stocks()

# NEW (simpler!)
stocks <- get_dataset("b3_stocks")
```

### Dataset Discovery

```r
# OLD
# No unified way to discover datasets

# NEW
datasets <- list_datasets()
View(datasets)

# Get details about a specific dataset
info <- get_dataset_info("abecip")
str(info$categories)  # See available tables
```

## Error Handling Improvements

The new API provides much better error messages:

```r
# If you forget to specify table for multi-table dataset:
get_dataset("abecip")
#> Error: Dataset 'abecip' contains multiple tables. Please specify which table you want:
#> ℹ Available tables: sbpe, units, cgi
#> ℹ Example: get_dataset('abecip', table = 'sbpe')

# Invalid dataset name:
get_dataset("typo_name")
#> Error: Dataset 'typo_name' not found.
#> ℹ Use list_datasets() to see all available datasets.
#> ℹ Available datasets: abecip, abrainc, bcb_realestate, secovi, bis_rppi...
```

## What Still Works

### Legacy Functions (Deprecated)

All old `get_*()` functions still work internally:

```r
# These still work but are deprecated
abecip_data <- get_abecip_indicators("sbpe", cached = TRUE)
abrainc_data <- get_abrainc_indicators("radar", cached = TRUE) 
bcb_data <- get_bcb_realestate(cached = TRUE)
```

### Existing Code

Your existing code will continue to work, but you'll see deprecation warnings encouraging you to migrate to the new API.

## Benefits of the New API

1. **Simpler**: Only 4 functions to remember instead of 20+
2. **Consistent**: Always returns tibbles, never lists
3. **Clearer**: Better error messages with helpful suggestions
4. **Discoverable**: Easy to find and explore available datasets
5. **Future-proof**: Easier to add new datasets without API bloat

## Complete Example

```r
library(realestatebr)

# Discover available data
datasets <- list_datasets()
datasets[datasets$source == "ABECIP", ]

# Get dataset info
info <- get_dataset_info("abecip") 
str(info$categories)

# Load specific data
sbpe <- get_dataset("abecip", table = "sbpe")
units <- get_dataset("abecip", table = "units")

# Single-table datasets
stocks <- get_dataset("b3_stocks")
secovi <- get_dataset("secovi")

# Check what's cached
cache_status <- check_cache_status()
```

This migration preserves all functionality while making the package much easier to use!