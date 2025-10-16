# Core Functions Verification Script
# Purpose: Verify that all core get_dataset() functions work correctly
# Date: 2025-10-15 (v0.6.0 Phase 3 kickoff)

# Load package from source
devtools::load_all(quiet = TRUE)

# Test datasets
test_datasets <- c(
  "abecip",
  "abrainc",
  "bcb_series",
  "bcb_realestate",
  "secovi",
  "rppi",
  "fgv_ibre",
  "cbic",
  "rppi_bis",
  "nre_ire"
)

cat("=== Core Functions Verification ===\n\n")
cat("Testing", length(test_datasets), "datasets with 3 sources each\n")
cat("Sources: cache, github, auto\n\n")

# Helper function to test a single dataset
test_dataset <- function(dataset_name) {
  results <- list(dataset = dataset_name)

  # Test cache source
  results$cache <- tryCatch(
    {
      data <- get_dataset(dataset_name, source = "cache")
      list(status = "PASS", rows = nrow(data), cols = ncol(data))
    },
    error = function(e) {
      list(status = "FAIL", error = conditionMessage(e))
    }
  )

  # Test github source
  results$github <- tryCatch(
    {
      data <- get_dataset(dataset_name, source = "github")
      list(status = "PASS", rows = nrow(data), cols = ncol(data))
    },
    error = function(e) {
      list(status = "FAIL", error = conditionMessage(e))
    }
  )

  # Test auto source (fallback chain)
  results$auto <- tryCatch(
    {
      data <- get_dataset(dataset_name, source = "auto")
      list(status = "PASS", rows = nrow(data), cols = ncol(data))
    },
    error = function(e) {
      list(status = "FAIL", error = conditionMessage(e))
    }
  )

  return(results)
}

# Run tests
all_results <- lapply(test_datasets, test_dataset)
names(all_results) <- test_datasets

# Print results
cat(strrep("=", 70), "\n")
cat("RESULTS SUMMARY\n")
cat(strrep("=", 70), "\n\n")

for (ds_name in names(all_results)) {
  result <- all_results[[ds_name]]

  cat(sprintf("Dataset: %s\n", ds_name))
  cat(sprintf("  Cache:  %s", result$cache$status))
  if (result$cache$status == "PASS") {
    cat(sprintf(" (%d rows, %d cols)\n", result$cache$rows, result$cache$cols))
  } else {
    cat(sprintf(" - %s\n", substr(result$cache$error, 1, 60)))
  }

  cat(sprintf("  GitHub: %s", result$github$status))
  if (result$github$status == "PASS") {
    cat(sprintf(" (%d rows, %d cols)\n", result$github$rows, result$github$cols))
  } else {
    cat(sprintf(" - %s\n", substr(result$github$error, 1, 60)))
  }

  cat(sprintf("  Auto:   %s", result$auto$status))
  if (result$auto$status == "PASS") {
    cat(sprintf(" (%d rows, %d cols)\n", result$auto$rows, result$auto$cols))
  } else {
    cat(sprintf(" - %s\n", substr(result$auto$error, 1, 60)))
  }

  cat("\n")
}

# Calculate statistics
total_tests <- length(test_datasets) * 3
passed_tests <- sum(sapply(all_results, function(r) {
  sum(
    r$cache$status == "PASS",
    r$github$status == "PASS",
    r$auto$status == "PASS"
  )
}))
failed_tests <- total_tests - passed_tests

cat(strrep("=", 70), "\n")
cat("STATISTICS\n")
cat(strrep("=", 70), "\n")
cat(sprintf("Total tests:  %d\n", total_tests))
cat(sprintf("Passed:       %d (%.1f%%)\n", passed_tests, 100 * passed_tests / total_tests))
cat(sprintf("Failed:       %d (%.1f%%)\n", failed_tests, 100 * failed_tests / total_tests))
cat("\n")

# Identify completely broken datasets (all sources fail)
broken_datasets <- names(all_results)[sapply(all_results, function(r) {
  r$cache$status == "FAIL" && r$github$status == "FAIL" && r$auto$status == "FAIL"
})]

# Identify working datasets (at least one source works)
working_datasets <- names(all_results)[sapply(all_results, function(r) {
  r$cache$status == "PASS" || r$github$status == "PASS" || r$auto$status == "PASS"
})]

cat(strrep("=", 70), "\n")
cat("VERDICT\n")
cat(strrep("=", 70), "\n")

if (length(broken_datasets) == 0) {
  cat("STATUS: All core functions are WORKING\n")
  cat("All datasets can be loaded from at least one source.\n")
  cat("\nCLAUDE.md should be updated to remove the 'aren't working at all' note.\n")
} else {
  cat("STATUS: Some core functions are BROKEN\n")
  cat(sprintf("\nBroken datasets (%d): %s\n",
              length(broken_datasets),
              paste(broken_datasets, collapse = ", ")))
  cat(sprintf("\nWorking datasets (%d): %s\n",
              length(working_datasets),
              paste(working_datasets, collapse = ", ")))
  cat("\nCLAUDE.md should be updated with specific broken datasets.\n")
}

cat("\n")
cat(strrep("=", 70), "\n")

# Return results invisibly for programmatic use
invisible(all_results)
