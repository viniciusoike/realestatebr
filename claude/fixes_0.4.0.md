
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
- When `source = "fresh"` is requested for CGI, users are informed it's static data and automatically loads from cache
- Added proper error handling for cache loading
- Updated success messages to be accurate (cache vs. download)
- Correct metadata attribution (`source = "cache"` for CGI)
