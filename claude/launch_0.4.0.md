# v0.4.0 Launch Plan - realestatebr Package

**Date**: 2025-10-04
**Branch**: `feat/fixes-0.4.0`
**Target**: Production release to main branch
**Status**: 🟡 90% Complete - Final push needed

---

## 🎯 MISSION

Release v0.4.0 with unified `get_dataset()` interface, validated cement data, and essential documentation.

---

## ✅ COMPLETED WORK

### Phase 1: Core Implementation (100%)
- ✅ Unified `get_dataset()` interface implemented
- ✅ Registry-based system (`inst/extdata/datasets.yaml`)
- ✅ Smart fallback: GitHub cache → Fresh download
- ✅ All 12 datasets accessible through unified interface
- ✅ RPPI suite completed with individual & stacked access
- ✅ Comprehensive verbosity system (user/progress/debug modes)
- ✅ Modern CLI-based error handling throughout
- ✅ Clean NAMESPACE (6 exported functions)

### CBIC Dataset Optimization (100%)
- ✅ **User validated cement data manually**
- ✅ Limited CBIC to cement-only tables for v0.4.0
- ✅ Steel and PIM tables deferred to v0.4.1
- ✅ Added informative error messages for unavailable tables
- ✅ Updated datasets.yaml to reflect cement-only availability
- ✅ Documentation in NEWS.md complete
- ✅ All 5 cement tables working (6,940-7,044 rows each)

**Commit**: `878e9f0` - "feat: Limit CBIC to cement tables only for v0.4.0 release"

### Documentation Fixes (100%)
- ✅ Fixed get_rppi.R documentation organization
- ✅ Removed roxygen2 parse error
- ✅ Reorganized helper function documentation with @noRd
- ✅ get_rppi.Rd properly generated

**Latest Commit**: Pending (documentation fixes in working directory)

---

## ⚠️ REMAINING ISSUES

### 1. Package Check Error (BLOCKER)
**Status**: 🔴 One ERROR remaining
**Issue**: Examples failing for `cli_debug` function
**Location**: R/utils.R (likely)
**Impact**: Prevents clean `R CMD check`

**Fix Required**: Add `@examplesIf` or `@dontrun` wrapper to cli_debug examples

**Estimated Time**: 5-10 minutes

### 2. Documentation Gap (BLOCKER for CRAN)
**Status**: 🔴 No vignettes
**Issue**: Package has 0 vignettes, CRAN strongly prefers at least 1-2
**Impact**: May prevent CRAN submission acceptance

**Required Vignettes**:
1. **Getting Started** (CRITICAL) - 30-40 minutes
2. **Working with RPPI** (IMPORTANT) - 20-30 minutes
3. **Migration Guide** (NICE-TO-HAVE) - 15-20 minutes

**Estimated Time**: 1-1.5 hours for critical vignettes

### 3. Minor Check Warnings (ACCEPTABLE)
**Status**: 🟡 2 warnings, 2 notes
**Issues**:
- Non-ASCII characters in R/get_bcb_realestate.R and R/get_cbic.R (Portuguese text - acceptable)
- Undefined global variables (dplyr/tidyr NSE - standard R package issue)
- "Consider adding importFrom" for graphics::title and stats::df (false positives)

**Action**: These are acceptable for a data package, can be addressed in v0.4.0.1

---

## 📋 LAUNCH SEQUENCE

### 🚀 OPTION A: Full Release (Recommended)
**Timeline**: 2-3 hours
**Quality**: CRAN-ready

#### Step 1: Fix cli_debug Example Error (10 min)
```r
# Find cli_debug in R/utils.R
# Wrap examples with @examplesIf or @dontrun
# Regenerate docs: devtools::document()
# Verify: devtools::check()
```

#### Step 2: Create Essential Vignettes (90 min)
1. **getting-started.Rmd** (40 min)
   - Adapt from doc/getting-started.Rmd
   - Update to v0.4.0 syntax
   - Include unified interface examples

2. **working-with-rppi.Rmd** (30 min)
   - Focus on RPPI datasets
   - Individual vs stacked access
   - Practical examples

3. **migration-guide.Rmd** (20 min)
   - Function mapping table
   - Before/after examples
   - Quick reference

#### Step 3: Build & Test (20 min)
```bash
# Build vignettes
Rscript -e "devtools::build_vignettes()"

# Full check
Rscript -e "devtools::check()"

# Build pkgdown site
Rscript -e "pkgdown::build_site()"
```

#### Step 4: Final Testing (15 min)
```r
# Test key datasets
test_datasets <- c("abecip", "abrainc", "bcb_realestate", "secovi",
                    "rppi", "rppi_bis", "cbic", "fgv_ibre")

for (ds in test_datasets) {
  data <- get_dataset(ds)
  stopifnot(is.data.frame(data), nrow(data) > 0)
}
```

#### Step 5: Merge & Release (30 min)
```bash
# Commit documentation fixes
git add R/get_rppi.R R/utils.R man/ vignettes/
git commit -m "docs: Fix examples and add essential vignettes for v0.4.0"
git push

# Merge to main
git checkout main
git pull origin main
git merge feat/fixes-0.4.0 --no-ff
git push origin main

# Create release
git tag -a v0.4.0 -m "Release v0.4.0 - Unified Data Interface"
git push origin v0.4.0

# GitHub release
gh release create v0.4.0 \
  --title "v0.4.0 - Unified Data Interface" \
  --notes-file NEWS.md \
  --latest
```

**Total Time**: ~2.5 hours
**Result**: Production-ready, CRAN-submittable package

---

### ⚡ OPTION B: Fast Track Release (Acceptable)
**Timeline**: 1 hour
**Quality**: Functional, missing vignettes

#### Step 1: Fix cli_debug Example (10 min)
Same as Option A

#### Step 2: Create ONE Essential Vignette (30 min)
Just "getting-started.Rmd" - minimum viable documentation

#### Step 3: Quick Test & Merge (20 min)
Quick dataset tests + merge to main

**Total Time**: ~1 hour
**Result**: Functional package, add vignettes in v0.4.0.1

---

## 📊 CURRENT PACKAGE STATUS

### Working Features ✅
- **12 datasets** accessible via `get_dataset()`
- **CBIC cement data** fully validated (5 tables)
- **RPPI suite** complete (individual + stacked)
- **Smart caching** with GitHub fallback
- **CLI error handling** throughout
- **Verbosity system** (3 tiers)
- **Clean API** (6 exports)

### Available Datasets
| Dataset | Tables | Status |
|---------|--------|--------|
| abecip | sbpe, units, cgi | ✅ Working |
| abrainc | radar, indicator, leading | ✅ Working |
| bcb_realestate | credit, indices | ✅ Working |
| bcb_series | 15 core series | ✅ Working |
| secovi | condo, launch, sale, rent | ✅ Working |
| rppi | sale, rent, individual indices | ✅ Working |
| rppi_bis | selected, detailed_* | ✅ Working |
| fgv_ibre | indicators | ✅ Working |
| nre_ire | index | ✅ Working |
| cbic | 5 cement tables | ✅ Working |
| property_records | 5 table types | ✅ Working |

### Test Results ✅
- ✅ All cement tables return data (6,940-7,044 rows)
- ✅ Steel/PIM properly blocked with informative errors
- ✅ Registry shows correct "CBIC Cement Data" metadata
- ✅ `list_datasets()` returns 12 datasets
- ✅ `get_dataset_info("cbic")` shows 5 cement categories only

---

## 🎯 SUCCESS CRITERIA

### Minimum (Option B)
- [ ] `devtools::check()` passes with 0 errors, ≤2 warnings
- [ ] At least 1 vignette ("getting-started")
- [ ] All 12 datasets return data
- [ ] CBIC cement-only validated
- [ ] Merged to main
- [ ] GitHub release v0.4.0 created

### Ideal (Option A)
- [ ] `devtools::check()` passes with 0 errors, ≤2 warnings
- [ ] 2-3 vignettes complete
- [ ] pkgdown site builds successfully
- [ ] All 12 datasets tested
- [ ] Documentation complete
- [ ] CRAN submission ready

---

## 📝 FILES TO COMMIT

### Already Staged
- ✅ `NEWS.md` - CBIC limitation documented
- ✅ `R/get_cbic.R` - Validation gate added
- ✅ `inst/extdata/datasets.yaml` - Cement-only metadata

### Need to Commit
- 🔄 `R/get_rppi.R` - Documentation reorganization (in working directory)
- 🔄 `R/utils.R` - cli_debug example fix (pending)
- 🔄 `man/*.Rd` - Regenerated documentation (pending)
- 🔄 `vignettes/*.Rmd` - New vignettes (pending)

---

## 🚨 KNOWN LIMITATIONS (v0.4.0)

### Documented & Acceptable
1. **CBIC**: Only cement tables available (steel/PIM in v0.4.1)
2. **Warnings**: Non-ASCII characters (Portuguese text - expected)
3. **Notes**: NSE global variables (standard dplyr/tidyr pattern)

### To Fix in v0.4.0.1
1. Add steel and PIM validation for CBIC
2. Expand vignettes if only 1 created
3. Address any post-release user feedback

---

## 📞 COMMUNICATION PLAN

### GitHub Release Notes (from NEWS.md)
- Unified `get_dataset()` interface
- 12 datasets accessible
- CBIC cement data validated
- Smart caching system
- Modern error handling
- Breaking change migration guide

### User Message
```
🎉 v0.4.0 Released - Unified Data Interface!

Major improvements:
✅ Single get_dataset() function for all 12 datasets
✅ Smart caching with GitHub fallback
✅ Modern CLI error handling
✅ CBIC cement data validated

⚠️ Breaking change: Individual get_*() functions removed
📖 See migration guide for updating your code

🔜 Coming in v0.4.1: CBIC steel & PIM tables
```

---

## 🎬 RECOMMENDED ACTION

**Choose Option A** for best long-term outcome:
1. Fix cli_debug example (10 min)
2. Create 2 essential vignettes (1 hour)
3. Test & merge (30 min)
4. **Total: 2 hours to production-ready release**

This gives us:
- ✅ CRAN-submittable package
- ✅ Proper user documentation
- ✅ Professional release quality
- ✅ Strong foundation for v0.4.1

---

## 📅 TIMELINE ESTIMATE

**Option A (Recommended)**:
- **Now**: Fix cli_debug (10 min)
- **+10 min**: Create getting-started vignette (40 min)
- **+50 min**: Create RPPI vignette (30 min)
- **+80 min**: Build & test (20 min)
- **+100 min**: Merge & release (30 min)
- **Total: ~2 hours**

**Option B (Fast Track)**:
- **Now**: Fix cli_debug (10 min)
- **+10 min**: Create 1 vignette (30 min)
- **+40 min**: Quick test & merge (20 min)
- **Total: ~1 hour**

---

## 📖 DETAILED IMPLEMENTATION PLAN

### STEP 1: Fix cli_debug Example Error

**File**: `R/utils.R`
**Time**: 10 minutes

#### Action:
```r
# Find the cli_debug function documentation
# Locate the @examples section
# Wrap with @examplesIf or change to @dontrun

# BEFORE:
#' @examples
#' cli_debug("Debug message")

# AFTER (Option 1 - Conditional):
#' @examples
#' \dontrun{
#' cli_debug("Debug message")
#' }

# OR (Option 2 - Better):
#' @examplesIf interactive()
#' cli_debug("Debug message")
```

#### Commands:
```bash
# Edit the file
# Then regenerate documentation
Rscript -e "devtools::document()"

# Verify fix
Rscript -e "devtools::check()" 2>&1 | grep -A5 "ERROR"
```

**Success**: No ERROR related to cli_debug examples

---

### STEP 2A: Create getting-started.Rmd

**File**: `vignettes/getting-started.Rmd`
**Time**: 40 minutes
**Source**: Adapt from `doc/getting-started.Rmd`

#### Setup:
```bash
# Create vignettes directory if needed
mkdir -p vignettes

# Use usethis helper
Rscript -e "usethis::use_vignette('getting-started')"
```

#### Template:
```yaml
---
title: "Getting Started with realestatebr"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Getting Started with realestatebr}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---
```

#### Content Structure:
```r
## Installation

```{r, eval = FALSE}
# Install from GitHub
remotes::install_github("viniciusoike/realestatebr")
```

## Quick Start

The realestatebr package provides a unified interface for accessing Brazilian
real estate data from multiple sources.

```{r setup, message=FALSE}
library(realestatebr)
library(dplyr)
library(ggplot2)
```

## Main Functions

### Discovering Datasets

```{r, eval=FALSE}
# List all available datasets
datasets <- list_datasets()
head(datasets)

# Get information about a specific dataset
info <- get_dataset_info("abecip")
names(info$categories)
```

### Getting Data

```{r, eval=FALSE}
# Get default table
abecip <- get_dataset("abecip")
head(abecip)

# Get specific table
sbpe <- get_dataset("abecip", "sbpe")

# Force fresh download
fresh <- get_dataset("abecip", source = "fresh")
```

## Example: ABECIP Housing Credit

```{r, eval=FALSE}
# Get SBPE housing credit data
sbpe <- get_dataset("abecip", "sbpe")

# Plot net flow over time
ggplot(sbpe, aes(x = date, y = netflow)) +
  geom_line() +
  labs(title = "SBPE Net Flow",
       x = NULL,
       y = "R$ (millions)") +
  theme_minimal()
```

## Example: BCB Real Estate Data

```{r, eval=FALSE}
# Get BCB real estate data
bcb <- get_dataset("bcb_realestate")

# Filter and aggregate
credit_data <- bcb %>%
  filter(category == "credit",
         type == "stock") %>%
  group_by(date) %>%
  summarise(total = sum(value, na.rm = TRUE))

# Plot
ggplot(credit_data, aes(x = date, y = total)) +
  geom_line() +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Total Real Estate Credit Stock",
       x = NULL,
       y = "R$ (billions)") +
  theme_minimal()
```

## Available Datasets

The package provides access to 12 datasets:

- **abecip**: Housing credit data
- **abrainc**: Primary market indicators
- **bcb_realestate**: Real estate credit
- **bcb_series**: Economic time series
- **secovi**: São Paulo market data
- **rppi**: Property price indices (sale/rent)
- **rppi_bis**: International RPPI from BIS
- **cbic**: Cement data (v0.4.0)
- **fgv_ibre**: FGV indicators
- **nre_ire**: Real estate index
- **property_records**: ITBI records

## Data Sources

Use the `source` parameter to control data origin:

- `"auto"` (default): GitHub cache → Fresh download
- `"github"`: Force GitHub cache
- `"fresh"`: Force fresh download

```{r, eval=FALSE}
# Try cache first, fallback to fresh
data <- get_dataset("secovi", source = "auto")

# Always use cache (faster but may be outdated)
cached <- get_dataset("secovi", source = "github")

# Always fresh download (slower but current)
fresh <- get_dataset("secovi", source = "fresh")
```

## Next Steps

- See `vignette("working-with-rppi")` for RPPI datasets
- See `vignette("migration-guide")` for v0.3.x migration
- Use `?get_dataset` for full documentation
```

#### Build & Test:
```bash
# Build the vignette
Rscript -e "devtools::build_vignettes()"

# Check it renders
Rscript -e "rmarkdown::render('vignettes/getting-started.Rmd')"
```

---

### STEP 2B: Create working-with-rppi.Rmd

**File**: `vignettes/working-with-rppi.Rmd`
**Time**: 30 minutes

#### Setup:
```bash
Rscript -e "usethis::use_vignette('working-with-rppi')"
```

#### Content:
```yaml
---
title: "Working with Property Price Indices"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Working with Property Price Indices}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.width = 7,
  fig.height = 5
)
```

## Introduction

Brazil has several Residential Property Price Indices (RPPI) from different
sources. This vignette shows how to access and work with them.

```{r, message=FALSE}
library(realestatebr)
library(dplyr)
library(ggplot2)
```

## Available RPPI Datasets

### Individual Indices

Access specific RPPI by name:

```{r, eval=FALSE}
# FipeZap Index (most comprehensive)
fipezap <- get_dataset("rppi", "fipezap")

# IVGR - National sales index from BCB
ivgr <- get_dataset("rppi", "ivgr")

# IGMI - Hedonic sales index
igmi <- get_dataset("rppi", "igmi")

# IVAR - Rent index
ivar <- get_dataset("rppi", "ivar")

# IQA - QuintoAndar rent prices
iqa <- get_dataset("rppi", "iqa")
```

### Stacked Indices

For comparison across sources:

```{r, eval=FALSE}
# All sale indices in one table
sale_indices <- get_dataset("rppi", "sale")
unique(sale_indices$source)  # Shows: IGMI-R, IVG-R, FipeZap

# All rent indices
rent_indices <- get_dataset("rppi", "rent")
unique(rent_indices$source)  # Shows: IVAR, IQA, Secovi-SP, FipeZap
```

## Example: Comparing Sale Indices

```{r, eval=FALSE}
# Get stacked sale data
sales <- get_dataset("rppi", "sale")

# Filter for national indices
national <- sales %>%
  filter(name_muni %in% c("Brazil", "Brasil"))

# Plot comparison
ggplot(national, aes(x = date, y = index, color = source)) +
  geom_line() +
  labs(title = "Brazil National RPPI - Sales",
       x = NULL,
       y = "Index (base varies by source)",
       color = "Source") +
  theme_minimal()
```

## Example: FipeZap by City

```{r, eval=FALSE}
# Get FipeZap data
fz <- get_dataset("rppi", "fipezap")

# Filter for major cities, residential, total, sale
cities <- fz %>%
  filter(
    market == "residential",
    rooms == "total",
    variable == "index",
    rent_sale == "sale",
    name_muni %in% c("São Paulo", "Rio De Janeiro", "Belo Horizonte")
  )

# Plot
ggplot(cities, aes(x = date, y = value, color = name_muni)) +
  geom_line() +
  labs(title = "FipeZap Sale Index - Major Cities",
       x = NULL,
       y = "Index",
       color = "City") +
  theme_minimal()
```

## International Comparison (BIS)

```{r, eval=FALSE}
# Get BIS international RPPI
bis <- get_dataset("rppi_bis")

# Filter for select countries
countries <- bis %>%
  filter(
    reference_area %in% c("Brazil", "United States", "Japan"),
    is_nominal == TRUE,
    unit == "Index, 2010 = 100",
    date >= as.Date("2000-01-01")
  )

# Plot
ggplot(countries, aes(x = date, y = value, color = reference_area)) +
  geom_line() +
  labs(title = "Residential Property Prices - International",
       x = NULL,
       y = "Index (2010 = 100)",
       color = "Country") +
  theme_minimal()
```

## Understanding the Data

### Column Definitions

- **index**: Index number (base varies by source)
- **chg**: Monthly percent change
- **acum12m**: 12-month accumulated change
- **date**: Reference date (usually month-end)
- **name_muni**: City or region name
- **source**: Data source (for stacked data)

### Special Cases

**IQA**: Returns `rent_price` (raw price per m²) instead of index
**FipeZap**: Most detailed with market/rooms breakdowns
**IVGR/IGMI**: National focus with some city detail

## Next Steps

- See `?get_dataset` for all available tables
- See `vignette("getting-started")` for basics
- Visit package website for more examples
```

---

### STEP 2C: Create migration-guide.Rmd (Optional)

**File**: `vignettes/migration-guide.Rmd`
**Time**: 20 minutes

#### Content:
```yaml
---
title: "Migration from v0.3.x to v0.4.0"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Migration from v0.3.x to v0.4.0}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

## Breaking Changes

Version 0.4.0 introduces a unified `get_dataset()` interface, replacing 15+
individual `get_*()` functions.

## Quick Reference

### Old → New Function Mapping

| Old Function (v0.3.x) | New Syntax (v0.4.0) |
|----------------------|---------------------|
| `get_abecip_indicators()` | `get_dataset("abecip")` |
| `get_abecip_indicators(category="sbpe")` | `get_dataset("abecip", "sbpe")` |
| `get_abrainc_indicators()` | `get_dataset("abrainc")` |
| `get_rppi_fipezap()` | `get_dataset("rppi", "fipezap")` |
| `get_rppi_ivgr()` | `get_dataset("rppi", "ivgr")` |
| `get_bcb_realestate()` | `get_dataset("bcb_realestate")` |
| `get_secovi()` | `get_dataset("secovi")` |
| `get_bis_rppi()` | `get_dataset("rppi_bis")` |

## Parameter Changes

### category → table

The `category` parameter has been renamed to `table`:

```r
# OLD
data <- get_abecip_indicators(category = "sbpe")

# NEW
data <- get_dataset("abecip", "sbpe")
# Or explicitly:
data <- get_dataset("abecip", table = "sbpe")
```

### New source Parameter

Control data source explicitly:

```r
# Auto (cache → fresh)
data <- get_dataset("abecip", source = "auto")  # default

# GitHub cache only
data <- get_dataset("abecip", source = "github")

# Fresh download only
data <- get_dataset("abecip", source = "fresh")
```

## Common Migration Patterns

### Pattern 1: Simple Function Call

```r
# OLD
data <- get_bcb_realestate()

# NEW
data <- get_dataset("bcb_realestate")
```

### Pattern 2: With Category/Table

```r
# OLD
sbpe <- get_abecip_indicators(category = "sbpe")

# NEW
sbpe <- get_dataset("abecip", "sbpe")
```

### Pattern 3: RPPI Functions

```r
# OLD
fipezap <- get_rppi_fipezap()
ivgr <- get_rppi_ivgr()

# NEW
fipezap <- get_dataset("rppi", "fipezap")
ivgr <- get_dataset("rppi", "ivgr")

# Or use stacked data
sale_indices <- get_dataset("rppi", "sale")
```

### Pattern 4: Cached Data

```r
# OLD
data <- get_abecip_indicators(cached = TRUE)

# NEW
data <- get_dataset("abecip", source = "github")
```

## Discovery Functions

New helper functions for exploration:

```r
# List all datasets
datasets <- list_datasets()

# Get dataset metadata
info <- get_dataset_info("abecip")
names(info$categories)  # Available tables
```

## Benefits of New Interface

1. **Consistency**: One function for all datasets
2. **Discovery**: Easy to find available data
3. **Smart Caching**: Automatic fallback
4. **Better Errors**: Informative CLI messages
5. **Metadata**: Rich information about data

## CBIC Note (v0.4.0)

The CBIC dataset is limited to cement tables in v0.4.0:

```r
# Available
get_dataset("cbic", "cement_monthly_consumption")
get_dataset("cbic", "cement_cub_prices")

# Not yet available (coming in v0.4.1)
get_dataset("cbic", "steel_prices")  # Error
get_dataset("cbic", "pim")  # Error
```

## Need Help?

- `?get_dataset` - Full documentation
- `vignette("getting-started")` - Tutorial
- `vignette("working-with-rppi")` - RPPI guide
- GitHub Issues: Report problems or ask questions
```

---

### STEP 3: Build & Test All Vignettes

**Time**: 20 minutes

#### Commands:
```bash
# Build all vignettes
Rscript -e "devtools::build_vignettes()"

# Check they rendered
ls -la doc/*.html

# Build pkgdown site
Rscript -e "pkgdown::build_site()"

# Full package check
Rscript -e "devtools::check()"
```

#### Expected Output:
```
✔ Building Getting Started vignette
✔ Building Working with RPPI vignette
✔ Building Migration Guide vignette
✔ Building pkgdown site
✔ R CMD check: 0 errors ✔ | 0 warnings ✔ | 2 notes ✔
```

---

### STEP 4: Final Dataset Testing

**Time**: 15 minutes

#### Test Script:
```r
# File: tests/manual/test_all_datasets.R
library(realestatebr)

cat("\n=== Testing All Datasets ===\n\n")

test_datasets <- c(
  "abecip", "abrainc", "bcb_realestate", "bcb_series",
  "secovi", "rppi", "rppi_bis", "cbic", "fgv_ibre",
  "nre_ire", "property_records"
)

results <- list()

for (ds in test_datasets) {
  cat("Testing:", ds, "... ")

  tryCatch({
    data <- get_dataset(ds)

    # Validate
    stopifnot(is.data.frame(data))
    stopifnot(nrow(data) > 0)
    stopifnot(ncol(data) > 0)

    results[[ds]] <- list(
      status = "✓ PASS",
      rows = nrow(data),
      cols = ncol(data)
    )

    cat("✓ PASS (", nrow(data), " rows)\n", sep = "")

  }, error = function(e) {
    results[[ds]] <- list(
      status = "✗ FAIL",
      error = e$message
    )
    cat("✗ FAIL:", e$message, "\n")
  })
}

# Summary
cat("\n=== Summary ===\n")
passed <- sum(sapply(results, function(x) x$status == "✓ PASS"))
cat("Passed:", passed, "/", length(test_datasets), "\n")

if (passed == length(test_datasets)) {
  cat("\n🎉 All datasets working!\n")
} else {
  cat("\n⚠️  Some datasets failed!\n")
}
```

#### Run:
```bash
Rscript tests/manual/test_all_datasets.R
```

---

### STEP 5: Commit Documentation Fixes

**Time**: 5 minutes

```bash
# Stage files
git add R/get_rppi.R
git add R/utils.R
git add man/
git add vignettes/
git add doc/

# Commit
git commit -m "$(cat <<'EOF'
docs: Fix documentation and add essential vignettes for v0.4.0

- Fix get_rppi.R documentation organization
- Fix cli_debug example wrapper
- Add getting-started vignette
- Add working-with-rppi vignette
- Add migration-guide vignette
- Build pkgdown site

All vignettes tested and rendering correctly.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

# Push
git push origin feat/fixes-0.4.0
```

---

### STEP 6: Merge to Main

**Time**: 10 minutes

```bash
# Switch to main
git checkout main

# Pull latest
git pull origin main

# Merge with no-ff (preserve branch history)
git merge feat/fixes-0.4.0 --no-ff -m "$(cat <<'EOF'
Merge feat/fixes-0.4.0: Release v0.4.0

Major Features:
- Unified get_dataset() interface for all 12 datasets
- Smart caching with GitHub fallback
- CBIC cement data validated and working
- Modern CLI error handling throughout
- Comprehensive verbosity system
- Complete RPPI suite with stacking

Breaking Changes:
- Removed individual get_*() functions
- Renamed 'category' parameter to 'table'
- See migration guide for updating code

Documentation:
- Essential vignettes added
- pkgdown site updated
- Full migration guide

CBIC Note:
- v0.4.0 includes cement tables only
- Steel and PIM tables coming in v0.4.1
EOF
)"

# Push to main
git push origin main
```

---

### STEP 7: Create Git Tag & GitHub Release

**Time**: 15 minutes

#### Create Tag:
```bash
# Create annotated tag
git tag -a v0.4.0 -m "$(cat <<'EOF'
Release v0.4.0 - Unified Data Interface

Major release introducing unified data access via get_dataset().

Highlights:
- Unified interface for 12 datasets
- Smart caching system
- CBIC cement data validated
- Modern error handling
- Complete documentation

See NEWS.md for full details.
EOF
)"

# Push tag
git push origin v0.4.0
```

#### Create GitHub Release:
```bash
# Using gh CLI
gh release create v0.4.0 \
  --title "v0.4.0 - Unified Data Interface" \
  --notes "$(cat <<'EOF'
# realestatebr v0.4.0

## 🎯 Major Features

### Unified Data Interface
- **Single function**: All datasets now accessed via `get_dataset()`
- **Smart caching**: Automatic GitHub cache → Fresh download fallback
- **12 datasets**: ABECIP, ABRAINC, BCB, SECOVI, RPPI, CBIC, and more
- **Modern errors**: CLI-based error handling with helpful messages

### CBIC Dataset (Cement Only)
- ✅ 5 cement tables validated and working
- ⏳ Steel and PIM tables coming in v0.4.1

### Complete RPPI Suite
- Individual indices: FipeZap, IVGR, IGMI, IVAR, IQA
- Stacked data: Sale and rent indices for easy comparison
- BIS international data

## 💥 Breaking Changes

**All individual `get_*()` functions removed**. Update your code:

```r
# OLD (v0.3.x)
data <- get_abecip_indicators(category = "sbpe")

# NEW (v0.4.0)
data <- get_dataset("abecip", "sbpe")
```

See the [migration guide](vignettes/migration-guide.html) for details.

## 📚 Documentation

- New vignettes: Getting Started, RPPI Guide, Migration
- Updated pkgdown site
- Comprehensive function documentation

## 🐛 Bug Fixes

- Standardized parameter naming (`table` instead of `category`)
- Fixed CBIC data processing
- Improved caching system
- Better error messages

## 📊 Available Datasets

- abecip: Housing credit data
- abrainc: Primary market indicators
- bcb_realestate: Real estate credit
- bcb_series: Economic time series
- secovi: São Paulo market
- rppi: Property price indices
- rppi_bis: International RPPI
- cbic: Cement data (v0.4.0)
- fgv_ibre: FGV indicators
- nre_ire: Real estate index
- property_records: ITBI records

## 🔜 Coming in v0.4.1

- CBIC steel and PIM tables
- Additional documentation
- Performance improvements

---

**Full Changelog**: See [NEWS.md](NEWS.md)
EOF
)" \
  --latest

# Or use GitHub web interface
echo "Create release at: https://github.com/viniciusoike/realestatebr/releases/new?tag=v0.4.0"
```

---

## ✨ NEXT STEPS

### Immediate (Today)
1. **Decide**: Option A (full) or Option B (fast track)
2. **Fix**: cli_debug example error (10 min)
3. **Create**: Essential vignettes (1-1.5 hours)
4. **Test**: All datasets working (15 min)
5. **Merge**: To main branch (10 min)
6. **Release**: GitHub v0.4.0 (15 min)

### Short Term (This Week)
7. **Monitor**: GitHub issues for user feedback
8. **Document**: Any user-reported issues
9. **Plan**: v0.4.1 with CBIC steel/PIM

### Medium Term (This Month)
10. **CRAN**: Consider CRAN submission if feedback good
11. **Promote**: Announce on R-bloggers, social media
12. **Expand**: Additional vignettes if needed

---

## 🎉 SUCCESS CELEBRATION

When v0.4.0 is released:
- ✅ 90% architecture migration complete
- ✅ Modern, unified interface shipped
- ✅ 12 datasets accessible
- ✅ Professional documentation
- ✅ Strong foundation for growth

**The package is production-ready! 🚀**

---

*Last Updated: 2025-10-04*
*Branch: feat/fixes-0.4.0*
*Ready: 878e9f0 (CBIC cement-only) + doc fixes*
*Target: main branch release*
*Timeline: 1-2 hours to completion*
