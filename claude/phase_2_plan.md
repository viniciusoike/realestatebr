# Phase 2: Simplified Data Pipeline with {targets}

## Executive Summary

Phase 2 implements a **pragmatic, lightweight {targets} pipeline** that enhances the existing data update infrastructure created in Phase 1. Rather than rebuilding functionality, we leverage the 20+ modernized `get_*()` functions to create an efficient, maintainable pipeline with dependency tracking and basic validation.

### 🎯 **Core Principle**
Build on what works - wrap existing functions with {targets} for better dependency management and incremental updates.

### **Key Objectives**
1. **Dependency Tracking** - Only update data when sources change
2. **Simple Validation** - Basic quality checks without heavy frameworks
3. **Improved Scheduling** - Daily updates for critical data, weekly for others
4. **Basic Monitoring** - Simple status reports, not complex dashboards

### **Scope**
- 20+ datasets from Phase 1 functions
- Sequential processing (appropriate for current data sizes)
- GitHub Actions automation
- Markdown-based reporting

---

## Technical Architecture

### 🔧 **Minimal Technology Stack**

```r
# Core dependencies (already in package)
library(targets)        # Workflow orchestration
library(dplyr)          # Data manipulation
library(readr)          # Fast I/O
library(cli)            # Progress reporting

# No new heavy dependencies needed!
# No {crew}, {pointblank}, {visNetwork}, etc.
```

### 🏛️ **Simple Pipeline Architecture**

```
Existing get_*() Functions → {targets} Wrapper → Validation → Cache Update
                              ↑                      ↓
                        Dependency Tracking    Simple Reports
```

### 📁 **Minimal File Additions**

```
realestatebr/
├── _targets.R                    # Main targets workflow (NEW)
├── _targets/                     # Targets metadata (auto-generated)
├── R/                            # Existing functions (NO CHANGES)
│   ├── get_*.R                   # Already modernized in Phase 1
│   └── cache.R                   # Existing cache utilities
├── data-raw/
│   ├── update_data.R             # Existing update script (minor updates)
│   └── validation.R              # Simple validation functions (NEW)
├── .github/workflows/
│   └── update_data.yml           # Enhanced scheduling (UPDATED)
└── inst/
    └── reports/                  # Status reports (NEW)
        └── pipeline_status.md    # Auto-generated status
```

---

## Implementation Plan (2 Weeks)

### **Week 1: Core {targets} Integration**

#### **Day 1-2: Basic _targets.R Setup**

Create minimal pipeline that wraps existing functions:

```r
# _targets.R
library(targets)
library(tarchetypes)

# Source existing package functions
tar_option_set(packages = c("realestatebr", "dplyr", "readr"))

list(
  # High priority - daily updates
  tar_target(
    bcb_series_data,
    get_bcb_series(cached = FALSE),
    cue = tar_cue(mode = "always")  # Simple for now
  ),

  tar_target(
    bcb_realestate_data,
    get_bcb_realestate(cached = FALSE),
    cue = tar_cue(mode = "always")
  ),

  tar_target(
    b3_stocks_data,
    get_b3_stocks(cached = FALSE),
    cue = tar_cue(mode = "always")
  ),

  # Medium priority - weekly updates
  tar_target(
    abecip_data,
    get_abecip_indicators(cached = FALSE),
    cue = tar_cue(mode = "always")
  ),

  tar_target(
    rppi_sale_data,
    get_rppi("sale", cached = FALSE),
    cue = tar_cue(mode = "always")
  ),

  # Save to cache
  tar_target(
    update_cache,
    {
      save_to_cache(bcb_series_data, "bcb_series")
      save_to_cache(bcb_realestate_data, "bcb_realestate")
      save_to_cache(b3_stocks_data, "b3_stocks")
      save_to_cache(abecip_data, "abecip")
      save_to_cache(rppi_sale_data, "rppi_sale")
      "Cache updated"
    }
  )
)
```

#### **Day 3-4: Add All Datasets**

Extend to cover all 20+ datasets with appropriate update frequencies:

```r
# Group by update frequency
daily_targets <- list(
  bcb_series = quote(get_bcb_series(cached = FALSE)),
  bcb_realestate = quote(get_bcb_realestate(cached = FALSE)),
  b3_stocks = quote(get_b3_stocks(cached = FALSE)),
  fgv_indicators = quote(get_fgv_indicators(cached = FALSE))
)

weekly_targets <- list(
  abecip = quote(get_abecip_indicators(cached = FALSE)),
  abrainc = quote(get_abrainc_indicators(cached = FALSE)),
  secovi = quote(get_secovi(cached = FALSE)),
  rppi_sale = quote(get_rppi("sale", cached = FALSE)),
  rppi_rent = quote(get_rppi("rent", cached = FALSE))
)

monthly_targets <- list(
  bis_rppi = quote(get_bis_rppi(cached = FALSE)),
  property_records = quote(get_property_records("all"))
)
```

#### **Day 5: Dependency Tracking**

Implement smarter cue strategies to avoid unnecessary updates:

```r
# Use file modification times for web-scraped data
tar_target(
  secovi_data,
  get_secovi(cached = FALSE),
  cue = tar_cue(
    mode = "thorough",
    command = TRUE,
    depend = TRUE,
    format = TRUE,
    iteration = TRUE,
    file = FALSE  # Don't track file changes
  )
)

# For API data, check if enough time has passed
tar_target(
  bcb_series_data,
  get_bcb_series(cached = FALSE),
  cue = tar_cue_age(
    name = bcb_series_data,
    age = as.difftime(1, units = "days")
  )
)
```

### **Week 2: Validation, Scheduling & Monitoring**

#### **Day 1-2: Simple Validation**

Add basic validation without heavy frameworks:

```r
# data-raw/validation.R
validate_dataset <- function(data, dataset_name) {
  checks <- list()

  # Basic structure checks
  checks$has_rows <- nrow(data) > 0
  checks$has_expected_cols <- check_required_columns(data, dataset_name)

  # Date range checks
  if ("date" %in% names(data)) {
    checks$valid_dates <- all(data$date >= as.Date("1990-01-01") &
                              data$date <= Sys.Date() + 30)
  }

  # Outlier detection (simple)
  numeric_cols <- names(data)[sapply(data, is.numeric)]
  for (col in numeric_cols) {
    values <- data[[col]][!is.na(data[[col]])]
    if (length(values) > 0) {
      mean_val <- mean(values)
      sd_val <- sd(values)
      checks[[paste0(col, "_outliers")]] <-
        sum(abs(values - mean_val) > 4 * sd_val) / length(values) < 0.01
    }
  }

  # Return validation result
  list(
    dataset = dataset_name,
    timestamp = Sys.time(),
    passed = all(unlist(checks)),
    checks = checks
  )
}

# Add to targets pipeline
tar_target(
  bcb_series_validated,
  {
    data <- bcb_series_data
    validation <- validate_dataset(data, "bcb_series")
    if (!validation$passed) {
      warning("Validation failed for bcb_series: ",
              paste(names(validation$checks)[!unlist(validation$checks)],
                    collapse = ", "))
    }
    attr(data, "validation") <- validation
    data
  }
)
```

#### **Day 3-4: Enhanced GitHub Actions**

Update scheduling for different priorities:

```yaml
# .github/workflows/update_data_daily.yml
name: Daily Data Updates

on:
  schedule:
    - cron: '0 9 * * *'  # 6 AM Brazil time
  workflow_dispatch:

jobs:
  update-daily:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-r@v2

      - name: Install dependencies
        run: |
          install.packages(c("targets", "tarchetypes"))
          remotes::install_local(".")

      - name: Run daily targets
        run: |
          targets::tar_make(names = c(
            "bcb_series_data", "bcb_realestate_data",
            "b3_stocks_data", "fgv_indicators_data"
          ))

      - name: Generate status report
        run: Rscript data-raw/generate_report.R

      - name: Commit updates
        run: |
          git add inst/cached_data/
          git add inst/reports/
          git commit -m "Daily update: $(date +%Y-%m-%d)" || exit 0
          git push
```

```yaml
# .github/workflows/update_data_weekly.yml
name: Weekly Data Updates

on:
  schedule:
    - cron: '0 10 * * 1'  # Mondays at 7 AM Brazil time
  workflow_dispatch:

jobs:
  update-weekly:
    runs-on: ubuntu-latest
    steps:
      # Similar structure but targets weekly datasets
```

#### **Day 5: Basic Monitoring Report**

Create simple markdown status report:

```r
# data-raw/generate_report.R
generate_pipeline_report <- function() {
  # Get targets metadata
  meta <- targets::tar_meta()

  # Create status summary
  report <- c(
    "# Pipeline Status Report",
    paste0("Generated: ", Sys.time()),
    "",
    "## Summary",
    paste0("- Total targets: ", nrow(meta)),
    paste0("- Successful: ", sum(meta$error == "NA")),
    paste0("- Failed: ", sum(meta$error != "NA")),
    "",
    "## Dataset Status",
    ""
  )

  # Add details for each dataset
  for (i in 1:nrow(meta)) {
    target <- meta[i, ]
    status <- ifelse(is.na(target$error), "✅", "❌")

    report <- c(report,
      paste0("### ", target$name, " ", status),
      paste0("- Last run: ", target$time),
      paste0("- Duration: ", round(target$seconds, 2), " seconds"),
      paste0("- Size: ", format(target$bytes, big.mark = ",")),
      ""
    )

    # Add validation info if available
    if (exists(paste0(target$name, "_validated"))) {
      validation <- attr(get(paste0(target$name, "_validated")), "validation")
      if (!is.null(validation)) {
        report <- c(report,
          "- Validation: ",
          paste0("  - ", names(validation$checks), ": ",
                 ifelse(unlist(validation$checks), "✅", "❌")),
          ""
        )
      }
    }
  }

  # Save report
  writeLines(report, "inst/reports/pipeline_status.md")

  # Also create simple CSV for tracking
  write_csv(meta, paste0("inst/reports/pipeline_meta_",
                         format(Sys.Date(), "%Y%m%d"), ".csv"))
}
```

---

## Key Differences from Original Plan

### **What We're Adding**
✅ {targets} dependency tracking
✅ Simple validation checks
✅ Better scheduling (daily/weekly/monthly)
✅ Basic status reports
✅ Incremental updates (only changed data)

### **What We're NOT Adding**
❌ {crew} parallel processing (unnecessary for current data sizes)
❌ {pointblank} validation framework (too heavy)
❌ Complex monitoring dashboards (markdown is sufficient)
❌ Multi-layer caching (existing cache works fine)
❌ Elaborate error recovery (Phase 1 functions already handle errors)
❌ 5-week implementation (2 weeks is realistic)

---

## Success Metrics

### **Practical Goals**
- **Efficiency**: Reduce unnecessary data downloads by 50%
- **Reliability**: Maintain existing 95%+ success rate
- **Speed**: Keep total pipeline under 10 minutes
- **Simplicity**: No new heavy dependencies
- **Maintainability**: Easy to debug and extend

### **Deliverables**
1. Working `_targets.R` file wrapping existing functions
2. Updated GitHub Actions with appropriate scheduling
3. Simple validation functions
4. Basic markdown status reports
5. Documentation updates

---

## Migration Path

### **Week 1**
1. Create `_targets.R` with existing functions
2. Test locally with `tar_make()`
3. Ensure cache updates work correctly

### **Week 2**
1. Add validation layer
2. Update GitHub Actions workflows
3. Implement status reporting
4. Test end-to-end in GitHub Actions

### **Post-Implementation**
- Monitor for 1 week
- Adjust cue strategies based on actual usage
- Consider incremental enhancements as needed

---

## Conclusion

This simplified Phase 2 plan delivers the core benefits of a {targets} pipeline without unnecessary complexity. It leverages all the hard work from Phase 1, adds meaningful improvements, and can be implemented in 2 weeks rather than 5. The focus is on practical enhancements that improve reliability and efficiency while maintaining the simplicity that makes the package maintainable.

**Next Step**: Create the basic `_targets.R` file and test with a few high-priority datasets.

---

*Phase 2 Plan v2.0 - Simplified & Pragmatic*
*Building on Phase 1's solid foundation*