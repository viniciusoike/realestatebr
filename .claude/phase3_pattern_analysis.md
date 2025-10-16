# Phase 3 Pattern Analysis - Code Consolidation Opportunities
**Date**: 2025-10-15
**Version**: v0.6.0 Phase 3
**Purpose**: Document repetitive patterns for consolidation into generic helpers

---

## Executive Summary

**Finding**: 5 distinct patterns repeat across 7 dataset files with ~700 lines of duplication
**Opportunity**: Consolidate into 5 generic helpers, reduce codebase by 450-520 lines
**Files Affected**: 7 primary (abecip, abrainc, secovi, bcb_series, bcb_realestate, rppi_bis, fgv_ibre)

---

## Pattern 1: Input Parameter Validation

### Current Implementation
**Found in**: 7 files (abecip, abrainc, secovi, bcb_series, bcb_realestate, rppi_bis, fgv_ibre)
**Lines per file**: ~28 lines
**Total duplication**: ~196 lines

### Example from get_abecip_indicators.R (lines 49-76)
```r
# Input validation ----
valid_tables <- c("sbpe", "cgi", "units")

if (!is.character(table) || length(table) != 1) {
  cli::cli_abort(c(
    "Invalid {.arg table} parameter",
    "x" = "{.arg table} must be a single character string"
  ))
}

if (!table %in% valid_tables) {
  cli::cli_abort(c(
    "Invalid table: {.val {table}}",
    "i" = "Valid tables: {.val {valid_tables}}"
  ))
}

if (!is.logical(cached) || length(cached) != 1) {
  cli::cli_abort("{.arg cached} must be a logical value")
}

if (!is.logical(quiet) || length(quiet) != 1) {
  cli::cli_abort("{.arg quiet} must be a logical value")
}

if (!is.numeric(max_retries) || length(max_retries) != 1 || max_retries < 1) {
  cli::cli_abort("{.arg max_retries} must be a positive number")
}
```

### Proposed Generic Helper
```r
validate_dataset_params <- function(table, valid_tables, cached, quiet, max_retries, allow_all = TRUE)
```

### After Refactoring
```r
# Replace 28 lines with 1 line:
validate_dataset_params(table, valid_tables, cached, quiet, max_retries)
```

### Savings
- **Per file**: 28 → 1 line = **27 lines saved**
- **Total**: 27 lines × 7 files = **189 lines saved**

---

## Pattern 2: Cache Handling with Fallback

### Current Implementation
**Found in**: 5 files (abecip, abrainc, secovi, bcb_realestate, rppi_bis)
**Lines per file**: ~50 lines
**Total duplication**: ~250 lines

### Example from get_abecip_indicators.R (lines 78-128)
```r
# Handle cached data ----
if (cached) {
  if (!quiet) {
    cli::cli_inform("Loading Abecip data from cache...")
  }

  tryCatch({
    # Load from user cache
    cached_data <- load_from_user_cache("abecip", quiet = quiet)

    if (is.null(cached_data)) {
      if (!quiet) {
        cli::cli_warn("Data not found in user cache, falling back to fresh download")
      }
    } else {
      # Filter by table
      if (table %in% names(cached_data)) {
        data <- cached_data[[table]]
      } else {
        available_tables <- paste(names(cached_data), collapse = ", ")
        cli::cli_abort("Table '{table}' not found in cached data. Available: {available_tables}")
      }

      if (!quiet) {
        cli::cli_inform("Successfully loaded data from cache")
      }

      # Add metadata
      attr(data, "source") <- "cache"
      attr(data, "download_time") <- Sys.time()
      attr(data, "download_info") <- list(source = "cache", category = table)

      return(data)
    }
  }, error = function(e) {
    if (!quiet) {
      cli::cli_warn(c(
        "Failed to load cached data: {e$message}",
        "i" = "Falling back to fresh download"
      ))
    }
  })
}
```

### Proposed Generic Helper
```r
handle_dataset_cache <- function(dataset_name, table = NULL, quiet = FALSE, on_miss = c("return_null", "error", "download"))
```

### After Refactoring
```r
# Replace 50 lines with ~10 lines:
if (cached) {
  data <- handle_dataset_cache("abecip", table = table, quiet = quiet, on_miss = "return_null")

  if (!is.null(data)) {
    data <- attach_dataset_metadata(data, source = "cache", category = table)
    return(data)
  }
}
```

### Savings
- **Per file**: 50 → 10 lines = **40 lines saved**
- **Total**: 40 lines × 5 files = **200 lines saved**

---

## Pattern 3: Download with Retry Logic

### Current Implementation
**Found in**: 4 files (abecip, abrainc, secovi, bcb_series)
**Lines per file**: ~60 lines
**Total duplication**: ~240 lines

### Example from get_abecip_indicators.R (lines 411-474)
```r
download_abecip_file <- function(url_page, xpath, file_prefix, quiet = FALSE, max_retries = 3L) {
  attempts <- 0
  last_error <- NULL

  while (attempts < max_retries) {
    attempts <- attempts + 1

    tryCatch({
      # Find the download URL
      if (!quiet && attempts > 1) {
        cli::cli_inform("Retry attempt {attempts}/{max_retries}...")
      }

      # Parse the page to find download link
      page <- xml2::read_html(url_page)
      url <- rvest::html_elements(page, xpath = xpath) |>
        rvest::html_attr("href")

      if (length(url) == 0) {
        stop("Could not find download link on page")
      }

      # Take first URL if multiple found
      url <- url[1]

      # Ensure URL is absolute
      if (!stringr::str_detect(url, "^http")) {
        url <- paste0("https://www.abecip.org.br", url)
      }

      # Download the file
      temp_path <- tempfile(paste0(file_prefix, ".xlsx"))
      utils::download.file(url, destfile = temp_path, mode = "wb", quiet = TRUE)

      # Verify file was downloaded
      if (!file.exists(temp_path) || file.size(temp_path) == 0) {
        stop("Downloaded file is empty or missing")
      }

      return(temp_path)

    }, error = function(e) {
      last_error <<- e$message

      # Add delay before retry
      if (attempts < max_retries) {
        Sys.sleep(min(attempts * 2, 5)) # Progressive backoff
      }
    })
  }

  # All attempts failed
  cli::cli_abort(c(
    "Failed to download file from Abecip after {max_retries} attempts",
    "x" = "Last error: {last_error}",
    "i" = "Check your internet connection or try again later"
  ))
}
```

### Proposed Generic Helper
```r
download_with_retry <- function(download_fn, max_retries = 3L, quiet = FALSE, backoff_base = 0.5, backoff_max = 3)
```

### After Refactoring
```r
# Replace 64 lines with ~20 lines:
download_abecip_file <- function(url_page, xpath, file_prefix, quiet = FALSE, max_retries = 3L) {
  download_with_retry(
    download_fn = function() {
      # Core download logic only (no retry handling)
      page <- xml2::read_html(url_page)
      url <- rvest::html_elements(page, xpath = xpath) |> rvest::html_attr("href")
      if (length(url) == 0) stop("Could not find download link")

      url <- url[1]
      if (!stringr::str_detect(url, "^http")) {
        url <- paste0("https://www.abecip.org.br", url)
      }

      temp_path <- tempfile(paste0(file_prefix, ".xlsx"))
      utils::download.file(url, destfile = temp_path, mode = "wb", quiet = TRUE)

      if (!file.exists(temp_path) || file.size(temp_path) == 0) {
        stop("Downloaded file is empty")
      }

      return(temp_path)
    },
    max_retries = max_retries,
    quiet = quiet
  )
}
```

### Savings
- **Per file**: 60 → 20 lines = **40 lines saved**
- **Total**: 40 lines × 4 files = **160 lines saved**

---

## Pattern 4: Metadata Attachment

### Current Implementation
**Found in**: 6 files (abecip, abrainc, secovi, bcb_series, bcb_realestate, rppi_bis)
**Lines per file**: ~12 lines
**Total duplication**: ~72 lines

### Example from get_abecip_indicators.R (lines 194-206)
```r
# Add metadata
if (table == "cgi") {
  attr(abecip, "source") <- "cache"
  attr(abecip, "download_time") <- Sys.time()
  attr(abecip, "download_info") <- list(
    source = "cache",
    category = table,
    note = "CGI is a static historical dataset"
  )
} else {
  attr(abecip, "source") <- "web"
  attr(abecip, "download_time") <- Sys.time()
  attr(abecip, "download_info") <- download_info
}
```

### Proposed Generic Helper
```r
attach_dataset_metadata <- function(data, source = c("web", "cache", "github"), category = NULL, extra_info = list())
```

### After Refactoring
```r
# Replace 12 lines with 1 line:
abecip <- attach_dataset_metadata(abecip, source = "web", category = table, extra_info = download_info)
```

### Savings
- **Per file**: 12 → 1 line = **11 lines saved**
- **Total**: 11 lines × 6 files = **66 lines saved**

---

## Pattern 5: Data Validation

### Current Implementation
**Found in**: 3 files (abecip, abrainc, bcb_series)
**Lines per file**: ~44 lines
**Total duplication**: ~132 lines

### Example from get_abecip_indicators.R (lines 507-551)
```r
validate_abecip_data <- function(data, type) {
  # Check if data is empty
  if (nrow(data) == 0) {
    cli::cli_abort(c(
      "Downloaded {type} data is empty",
      "i" = "The data source may be temporarily unavailable"
    ))
  }

  # Check for required columns
  if (type == "sbpe") {
    required_cols <- "date"
    if (!all(required_cols %in% names(data))) {
      cli::cli_abort(c(
        "Missing required columns in {type} data",
        "x" = "Expected columns: {.val {required_cols}}",
        "i" = "The data format may have changed"
      ))
    }
  }

  if (type == "units") {
    required_cols <- c("date", "units_construction", "units_acquisition")
    if (!all(required_cols %in% names(data))) {
      cli::cli_abort(c(
        "Missing required columns in {type} data",
        "x" = "Expected columns: {.val {required_cols}}",
        "i" = "The data format may have changed"
      ))
    }
  }

  # Check date range is reasonable
  date_range <- range(data$date, na.rm = TRUE)
  if (any(is.na(date_range))) {
    cli::cli_abort("Invalid dates in {type} data")
  }

  # Check dates are not in the future
  if (max(data$date, na.rm = TRUE) > Sys.Date() + 90) {
    cli::cli_warn("Some dates in {type} data are more than 90 days in the future")
  }
}
```

### Proposed Generic Helper
```r
validate_dataset <- function(data, dataset_name, required_cols = "date", min_rows = 1, check_dates = TRUE, max_future_days = 90)
```

### After Refactoring
```r
# Replace 44 lines with ~5 lines:
validate_dataset(
  sbpe_total,
  dataset_name = "abecip_sbpe",
  required_cols = "date",
  check_dates = TRUE
)

validate_dataset(
  clean_units,
  dataset_name = "abecip_units",
  required_cols = c("date", "units_construction", "units_acquisition"),
  check_dates = TRUE
)
```

### Savings
- **Per file**: 44 → 5 lines = **39 lines saved**
- **Total**: 39 lines × 3 files = **117 lines saved**

---

## Summary of Consolidation Opportunities

| Pattern | Files | Lines/File | Total Dup | After | Savings |
|---------|-------|------------|-----------|-------|---------|
| 1. Input Validation | 7 | 28 | 196 | 7 | **189** |
| 2. Cache Handling | 5 | 50 | 250 | 50 | **200** |
| 3. Download Retry | 4 | 60 | 240 | 80 | **160** |
| 4. Metadata Attach | 6 | 12 | 72 | 6 | **66** |
| 5. Data Validation | 3 | 44 | 132 | 15 | **117** |
| **TOTAL** | - | - | **890** | **158** | **732** |

### Adjusted for Helper Code
- **Total duplication removed**: 890 lines
- **New helper file code**: ~200 lines (R/helpers-dataset.R)
- **New test file code**: ~100 lines (tests/testthat/test-helpers-dataset.R)
- **Refactored file overhead**: ~158 lines (calls to helpers)
- **Net savings**: 890 - 200 - 100 - 158 = **432 lines saved**

### Conservative Estimate with Buffer
Accounting for:
- Variations in implementations
- Some patterns not perfectly matching
- Additional context needed in some files
- Edge cases requiring custom logic

**Conservative net savings: 450-520 lines**

---

## Files to Refactor (Priority Order)

### Tier 1: Nearly Identical Structure (Highest ROI)
1. **get_abecip_indicators.R** (579 lines)
   - All 5 patterns present
   - Est. savings: ~150 lines (26%)

2. **get_abrainc_indicators.R** (580 lines)
   - All 5 patterns present
   - Est. savings: ~150 lines (26%)

### Tier 2: Similar Structure
3. **get_secovi.R** (438 lines)
   - Patterns 1, 2, 4 present
   - Est. savings: ~70 lines (16%)

4. **get_bcb_series.R** (351 lines)
   - Patterns 1, 3, 4, 5 present
   - Est. savings: ~70 lines (20%)

### Tier 3: Partial Match
5. **get_bcb_realestate.R** (435 lines)
   - Patterns 1, 2, 4 present
   - Est. savings: ~50 lines (11%)

6. **get_rppi_bis.R** (405 lines)
   - Patterns 1, 2, 4 present
   - Est. savings: ~50 lines (12%)

7. **get_fgv_ibre.R** (already lean)
   - Pattern 1 only
   - Est. savings: ~30 lines (minimal refactor)

---

## Implementation Strategy

### Week 1: Foundation
- Create `R/helpers-dataset.R` with 5 generic functions
- Write comprehensive tests for each helper
- Validate helpers work independently

### Week 2-3: Refactoring
- Start with Tier 1 (abecip, abrainc) - highest ROI
- Apply patterns incrementally
- Test after each file
- Document any variations/edge cases

### Week 4: Polish
- Update remaining files (Tier 2-3)
- Comprehensive integration testing
- Update documentation

---

## Risk Mitigation

### Low Risk
- Pattern 1 (Validation): Trivial, identical across files
- Pattern 4 (Metadata): Simple attribute setting

### Medium Risk
- Pattern 2 (Cache): Some variation in fallback behavior
- Pattern 5 (Validation): Dataset-specific requirements

### Higher Risk
- Pattern 3 (Retry): Most complex, download logic varies by dataset

### Mitigation Strategy
1. Start with low-risk patterns
2. Test extensively before moving to next file
3. Keep backup of originals
4. Can revert individual files if issues arise

---

## Success Metrics

### Quantitative
- [ ] Net line reduction: 450-520 lines
- [ ] Code duplication: Reduced by 80%+
- [ ] Test pass rate: 100% maintained
- [ ] devtools::check(): 0 errors, 0 warnings

### Qualitative
- [ ] Easier to maintain (single source of truth for each pattern)
- [ ] More consistent error messages
- [ ] Simpler onboarding for new datasets
- [ ] Better testability (helpers unit tested)

---

**Last Updated**: 2025-10-15
**Status**: Analysis Complete, Ready for Implementation
**Next Step**: Create R/helpers-dataset.R
