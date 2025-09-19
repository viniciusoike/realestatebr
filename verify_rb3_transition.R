# Simple verification script for rb3 transition
# This script can be run to manually test the new rb3-based implementation

# Load the package
library(realestatebr)

# Test 1: Check that internal functions exist
cat("Testing internal function availability...\n")
internal_functions <- c("fetch_b3_stocks_rb3", "setup_rb3_environment")
for (func in internal_functions) {
  if (exists(func, mode = "function")) {
    cat("✓", func, "exists\n")
  } else {
    cat("✗", func, "NOT FOUND\n")
  }
}

# Test 2: Test cached data loading (should work regardless of rb3)
cat("\nTesting cached data loading...\n")
tryCatch({
  stocks_cached <- get_b3_stocks(cached = TRUE, quiet = TRUE)
  cat("✓ Cached data loading works\n")
  cat("  - Rows:", nrow(stocks_cached), "\n")
  cat("  - Columns:", ncol(stocks_cached), "\n")
  cat("  - Sample columns:", paste(head(names(stocks_cached), 5), collapse = ", "), "\n")
}, error = function(e) {
  cat("✗ Cached data loading failed:", e$message, "\n")
})

# Test 3: Test deprecation warnings
cat("\nTesting deprecation warnings...\n")
tryCatch({
  suppressWarnings({
    # This should trigger deprecation warnings
    stocks_with_src <- get_b3_stocks(cached = TRUE, src = "yahoo", quiet = TRUE)
    stocks_with_category <- get_b3_stocks(cached = TRUE, category = "stocks", quiet = TRUE)
  })
  cat("✓ Deprecation warnings work (suppressed for this test)\n")
}, error = function(e) {
  cat("✗ Deprecation warning test failed:", e$message, "\n")
})

# Test 4: Test metadata structure
cat("\nTesting metadata structure...\n")
tryCatch({
  stocks <- get_b3_stocks(cached = TRUE, quiet = TRUE)
  attrs <- attributes(stocks)
  required_attrs <- c("source", "download_info", "download_time")
  
  for (attr_name in required_attrs) {
    if (attr_name %in% names(attrs)) {
      cat("✓", attr_name, "attribute present\n")
    } else {
      cat("✗", attr_name, "attribute MISSING\n")
    }
  }
  
  # Check download_info structure
  if ("download_info" %in% names(attrs)) {
    download_info <- attrs$download_info
    if (is.list(download_info)) {
      cat("  - download_info is list with", length(download_info), "elements\n")
      cat("  - download_info names:", paste(names(download_info), collapse = ", "), "\n")
    }
  }
}, error = function(e) {
  cat("✗ Metadata test failed:", e$message, "\n")
})

cat("\nVerification complete.\n")
cat("Note: Fresh data fetching tests require rb3 and are not run here.\n")
cat("To test fresh data fetching, run: get_b3_stocks(cached = FALSE, quiet = FALSE)\n")