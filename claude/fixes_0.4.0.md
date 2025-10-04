
# Main goal

Have a complete functioning package. There are major problems with almost all functions. All functions should be working and returing a tibble.

# Major issues

1. [partially complete] Completely drop old arguments such as `category`. There is no need for backward compatibility since the package is still in version 0.x.y.

2. [complete] The get_* functions are not legacy, neither beign deprecated neither being replaced. They are the main functions of the package. The ONLY difference is that now they are INTERAL functions (not exported to the user). These functions are called by `get_dataset()`.

3. [complete] Remove `get_b3_stocks()` and its related dependencies.

### Details

THe `get_b3_stocks()` function brings {tidyquant} and {zoo} dependencies. These packages are not necessary for the main purpose of the package, which is to get datasets from Brazilian sources. Create a backup of this script inside the `old/` directory. Remove all references to this function in the documentation and vignettes. In the future, we will create an improved version of this function using the `rb3` package.

4. [complete] Simplify `get_bcb_series()`.

### Details

Currently, this function returns a lot of errors and too many series at once. Let's reduce it to only these series:

190
192
432
433
20704
20756
20768
20914
21072
21084
21340
24364
28545
28763
28770

# Minor goals

1. [complete] Define table as the second argument of `get_dataset()`. Set `source` as the third argument.

```r
# Current
get_dataset("abecip", table = "sbpe")

# Proposed
get_dataset("abecip", "sbpe")

# Syntax
get_dataset(name, table, source)
```

This makes it easier for the user.


2. [complete] Standardize the return of `get_dataset("rppi_bis", table = "detailed")`.

Issues:
- ✅ Fixed: Returns a list of tibbles instead of a single tibble.
- ✅ Fixed: "bis_rppi" is counter-intuitive since the other dataset is named "rppi". Rename it to "rppi_bis".
- ✅ Fixed: Also rename the actual script file to avoid confusion.
- ✅ Fixed: "horizontalize" the output, i.e., have

```r
get_dataset("rppi_bis", "detailed_monthly")
get_dataset("rppi_bis", "detailed_quarterly")
get_dataset("rppi_bis", "detailed_annual")
get_dataset("rppi_bis", "detailed_semiannual")
get_dataset("rppi_bis", "selected")  # default
```

Note that we can't `bind_rows()` because the datasets are very different.

3. [complete] Standardize the return of `get_dataset("property_records")`.

Issues:
- ✅ Fixed: Returns a list of a list of tibbles (nested) instead of a single tibble.
- ✅ Fixed: Doesn't support the `table` argument.
- ✅ Fixed: "Horizontalize" the output, i.e., have

```r
get_dataset("property_records", "capitals")          # default
get_dataset("property_records", "capitals_transfers")
get_dataset("property_records", "cities")
get_dataset("property_records", "aggregates")
get_dataset("property_records", "aggregates_transfers")
```

Fix: should use table argument to select each individual dataset.
use:

```r
capitals$capitals$records -> capitals
capitals$capitals$transfers -> capitals_transfers
aggregates$aggregates$record_cities -> cities
aggregates$aggregates$record_aggregates -> aggregates
aggregates$aggregates$transfers -> aggregates_transfers
```

4. [complete] Confusing get_rppi_bis and get_bis_rppi functions.

- ✅ Fixed: Understand the differences between functions.
- ✅ Fixed: Consolidate into the same file/script "get_rppi_bis.R".
- ✅ Fixed: Make sure the functionality is preserved.


5. [complete] Abrainc is failing fresh downloads.

Issues:
- ✅ Fixed: Variable reference error in `clean_abrainc()` function calls
- ✅ Fixed: Undefined `category` variable when `table != "all"`

```r
# All working now
get_dataset("abrainc", table = "radar", source = "fresh")
get_dataset("abrainc", table = "indicator", source = "fresh")
get_dataset("abrainc", table = "leading", source = "fresh")
```

**Fix details**: In `get_abrainc_indicators.R`:
- Changed `table` to `category` in lines 384, 393, 403 within `clean_abrainc()` calls
- Added proper `category` variable definition for non-"all" table selections

6. [complete] Abecip is failing a specific table

Issue:
- ✅ Fixed: CGI table was trying to access non-existent `abecip_cgi` object
- ✅ Fixed: Misleading success messages for static data

```r
get_dataset("abecip")
get_dataset("abecip", table = "sbpe")
get_dataset("abecip", table = "units")
get_dataset("abecip", table = "cgi")

get_dataset("abecip", table = "sbpe", source = "fresh")
get_dataset("abecip", table = "units", source = "fresh")
# Now working with proper messaging
get_dataset("abecip", table = "cgi", source = "fresh")
```

**Fix details**: In `get_abecip_indicators.R`:
- CGI data is now properly handled as a static historical dataset
- When `source = "fresh"` is requested forAlN CGI, users are informed it's static data and automatically loads from cache
- Added proper error handling for cache loading
- Updated success messages to be accurate (cache vs. download)
- Correct metadata attribution (`source = "cache"` for CGI)


# New fixes

## Minor issues

1. [complete] Some functions are showing unnecessary deprecation warnings for users.

```r
# ✅ Fixed: No longer show deprecation warnings when using get_dataset()
get_dataset("abrainc", table = "radar", source = "fresh")
get_dataset("abrainc", table = "indicator", source = "fresh")
get_dataset("abrainc", table = "leading", source = "fresh")
```

**Fix details**: Removed `.Deprecated()` calls from internal functions:
- Removed from `get_abrainc_indicators.R` lines 85-86
- Removed from `get_bcb_realestate.R` lines 80-83
- Removed from `get_secovi.R` lines 66-67

2. [complete] Make messaging more concise. Don't overwhelm the user with too much information.

**Major UX improvement implemented**:

✅ **Comprehensive verbosity system created** with three tiers:
- **User Mode** (default): 2-3 essential messages per function
- **Progress Mode** (`quiet=FALSE`): Moderate detail for long operations
- **Debug Mode** (`options(realestatebr.debug = TRUE)`): Full detail for development

✅ **Functions updated**:
- `get_rppi.R`: 49 messages → 3 user messages
- `get_cbic.R`: 33 messages → 3 user messages
- `get_rppi_bis.R`: 10 messages → 2 user messages
- `get_property_records.R`: 10 messages → 2 user messages
- `get_secovi.R`: 6 messages → 2 user messages
- `get_bcb_realestate.R`: 5 messages → 2 user messages
- `get_fgv_ibre.R`: 4 messages → 2 user messages

✅ **Infrastructure added** in `utils.R`:
- `is_debug_mode()`: Checks for debug environment/options
- `cli_debug()`: Shows detailed messages only in debug mode
- `cli_user()`: Shows concise user-level messages

✅ **Debug mode documentation** added to main `get_dataset()` function with examples

```r
# Now shows minimal, clean output by default
get_dataset("cbic")  # Shows 2-3 essential messages

# Enable debug mode to see all processing details
options(realestatebr.debug = TRUE)
get_dataset("cbic")  # Shows 30+ detailed processing messages

# Or via environment variable
Sys.setenv(REALESTATEBR_DEBUG = "TRUE")
```

3. [complete] Minor fixes with rppi_bis.

```r
# ✅ Fixed: All working correctly
get_dataset("rppi_bis")
get_dataset("rppi_bis", "detailed_monthly")
get_dataset("rppi_bis", "detailed_quarterly")
get_dataset("rppi_bis", "detailed_semiannual")
get_dataset("rppi_bis", "detailed_annual")
```

**Fix details**: Updated cached file mappings in `inst/extdata/datasets.yaml` lines 152-155

4. [complete] Change fgv_indicators to fgv_ibre

```r
# ✅ Fixed: Renamed throughout codebase
get_dataset("fgv_ibre")  # Now works correctly
```

**Fix details**:
- Renamed `get_fgv_indicators.R` → `get_fgv_ibre.R`
- Updated all function names and references
- Updated dataset registry mapping (line 320 in `get-dataset.R`)
- Updated `datasets.yaml` (line 257)

5. [complete] NRE IRE dataset is not working

```r
# ✅ Fixed: Now working correctly
get_dataset("nre_ire")
```

**Fix details**: Fixed integration with `get_dataset()` by updating cache handling in `get_nre_ire.R`

6. [review!] The table argument doesn't seem to be working in SECOVI

```r
# ✅ Fixed: Table filtering now works correctly
get_dataset("secovi", table = "condo")
get_dataset("secovi", table = "launch")
get_dataset("secovi", table = "sale")
```

**Fix details**: Added SECOVI table filtering logic in `get-dataset.R` lines 216-229

# Major issues

1. [complete] RPPI suite isn't working as intended

**✅ RPPI Implementation Complete**:

All core RPPI functionality has been successfully implemented:

**Individual Dataset Access**:
- ✅ `get_dataset("rppi", "fipezap")` - Returns complete FipeZap data (both sale and rent)
- ✅ `get_dataset("rppi", "igmi")` - Returns IGMI sales data (1,529 records)
- ✅ `get_dataset("rppi", "ivgr")` - Returns IVGR sales data (293 records)
- ✅ `get_dataset("rppi", "iqa")` - Returns IQA rent data (96 records)

**Stacked Dataset Access**:
- ✅ `get_dataset("rppi", "sale")` - Returns harmonized sale indices (13,906 records from IGMI-R, IVG-R, FipeZap)
- ✅ Proper harmonization with `source` column for identification
- ✅ FipeZap correctly filtered to residential/total/sale only
- ✅ Consistent use of "sale" (singular) throughout

**Fix Details**:
- Updated `get_rppi()` function with individual and stacked table support
- Added harmonization functions: `standardize_city_names()`, `harmonize_fipezap_for_stacking()`, `standardize_rppi_structure()`
- Fixed parameter mapping: changed `category` to `table` in `get-dataset.R` line 295
- Updated cache name mappings for individual indices
- Updated `datasets.yaml` with clear individual vs stacked definitions

**⚠️ Known Issues to Review**:
- CLI environment interpolation issues in messaging functions (non-critical)
- SECOVI rent stacking has CLI message variable scope issue
- Review needed for consistent CLI message patterns across all functions

1. [review needed] CLI messaging inconsistencies

**Issue**: Several functions have CLI environment interpolation problems where variable names are not properly resolved in `cli::cli_inform()` calls.

**Affected Functions**:
- `get_rppi()` - Fixed by using direct `cli::cli_inform()` instead of `cli_user()`
- `get_secovi()` - Has `tbl_secovi` variable scope issue in CLI messages
- Other functions may have similar patterns

**Root Cause**: The `cli_user()` function and string interpolation with `{}` syntax requires proper variable scope, but some variables are not accessible in the CLI environment.

**Recommended Fix**:
- Review all `cli_user()` calls and `cli::cli_inform()` with `{}` interpolation
- Either pre-compute variables (e.g., `record_count <- nrow(data)`) before CLI calls
- Or use direct string concatenation/formatting instead of CLI interpolation
- Ensure consistent messaging patterns across all functions

**Priority**: Low (functionality works, only messaging is affected)
