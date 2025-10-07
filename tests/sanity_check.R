# Sanity Check Script for realestatebr Package
# Tests all available datasets with basic visualizations
# Run this script to ensure all datasets are working properly

library(realestatebr)
library(ggplot2)
library(dplyr)
library(tidyr)

# Helper function to safely test a dataset
test_dataset <- function(name, fetch_fn, plot_fn) {
  cat("\n", strrep("=", 70), "\n")
  cat("Testing:", name, "\n")
  cat(strrep("=", 70), "\n")

  tryCatch(
    {
      data <- fetch_fn()
      cat("✓ Data loaded successfully\n")
      cat("  Structure:", class(data), "\n")

      if (is.data.frame(data)) {
        cat("  Dimensions:", nrow(data), "rows x", ncol(data), "columns\n")
        cat("  Columns:", paste(head(names(data), 10), collapse = ", "), "\n")
      } else if (is.list(data)) {
        cat(
          "  List with",
          length(data),
          "elements:",
          paste(names(data), collapse = ", "),
          "\n"
        )
      }

      # Create plot
      plot_fn(data)

      return(TRUE)
    },
    error = function(e) {
      cat("✗ ERROR:", e$message, "\n")
      return(FALSE)
    }
  )
}

# Initialize results tracker
results <- list()

# =============================================================================
# 1. ABECIP - Housing Credit Indicators
# =============================================================================
results$abecip <- test_dataset(
  "ABECIP Housing Credit Indicators",
  function() get_dataset("abecip"),
  function(data) {
    # ABECIP returns a data frame, plot netflow over time
    recent <- data %>% filter(date >= as.Date("2020-01-01"))

    if (nrow(recent) > 0 && "sbpe_netflow" %in% names(recent)) {
      p <- ggplot(recent, aes(x = date, y = sbpe_netflow)) +
        geom_line(color = "steelblue") +
        labs(
          title = "ABECIP - SBPE Net Flow (2020+)",
          x = "Date",
          y = "Net Flow"
        ) +
        theme_minimal()
      print(p)
      cat("✓ ABECIP visualization created\n")
    }
  }
)

# =============================================================================
# 2. ABRAINC - Primary Market Indicators
# =============================================================================
results$abrainc <- test_dataset(
  "ABRAINC Primary Market Indicators",
  function() get_dataset("abrainc"),
  function(data) {
    recent <- data %>% filter(year >= 2020)

    if (nrow(recent) > 0) {
      # Get a few key variables to plot
      key_vars <- recent %>%
        group_by(variable) %>%
        filter(n() >= 10) %>%
        ungroup() %>%
        filter(variable %in% head(unique(variable), 5))

      p <- ggplot(key_vars, aes(x = date, y = value, color = variable)) +
        geom_line() +
        labs(
          title = "ABRAINC - Market Indicators (2020+)",
          x = "Date",
          y = "Value"
        ) +
        theme_minimal() +
        theme(legend.position = "bottom")
      print(p)
      cat("✓ ABRAINC visualization created\n")
    }
  }
)

# =============================================================================
# 3. BCB Real Estate Market Data
# =============================================================================
results$bcb_realestate <- test_dataset(
  "BCB Real Estate Market Data",
  function() get_dataset("bcb_realestate"),
  function(data) {
    # Plot recent data for a subset of series
    recent_data <- data %>%
      filter(date >= as.Date("2020-01-01")) %>%
      group_by(v1, v2) %>%
      filter(n() > 10) %>%
      ungroup() %>%
      head(1000) # Limit for plotting

    if (nrow(recent_data) > 0) {
      p <- ggplot(recent_data, aes(x = date, y = value)) +
        geom_line() +
        facet_wrap(~v1, scales = "free_y") +
        labs(
          title = "BCB Real Estate - Recent Trends (2020+)",
          x = "Date",
          y = "Value"
        ) +
        theme_minimal()
      print(p)
      cat("✓ BCB Real Estate visualization created\n")
    }
  }
)

# =============================================================================
# 4. BCB Economic Series
# =============================================================================
results$bcb_series <- test_dataset(
  "BCB Economic Series",
  function() get_dataset("bcb_series"),
  function(data) {
    # Get a few key series
    key_series <- data %>%
      filter(date >= as.Date("2020-01-01")) %>%
      group_by(name) %>%
      filter(n() > 10) %>%
      slice_head(n = 100) %>%
      ungroup()

    if (nrow(key_series) > 0) {
      p <- ggplot(key_series, aes(x = date, y = value)) +
        geom_line() +
        facet_wrap(~name, scales = "free_y") +
        labs(title = "BCB Economic Series (2020+)", x = "Date", y = "Value") +
        theme_minimal()
      print(p)
      cat("✓ BCB Series visualization created\n")
    }
  }
)

# =============================================================================
# 5. CBIC Cement Data
# =============================================================================
results$cbic <- test_dataset(
  "CBIC Cement Data",
  function() get_dataset("cbic"),
  function(data) {
    # CBIC returns a data frame
    recent <- data %>% filter(date >= as.Date("2020-01-01"))

    if (nrow(recent) > 0) {
      # Aggregate by date to get total
      monthly_total <- recent %>%
        group_by(date) %>%
        summarise(total_value = sum(value, na.rm = TRUE), .groups = "drop")

      p <- ggplot(monthly_total, aes(x = date, y = total_value)) +
        geom_line(color = "steelblue") +
        labs(
          title = "CBIC - Monthly Cement Consumption (2020+)",
          x = "Date",
          y = "Total Consumption"
        ) +
        theme_minimal()
      print(p)
      cat("✓ CBIC visualization created\n")
    }
  }
)

# =============================================================================
# 6. FGV IBRE Real Estate Indicators
# =============================================================================
results$fgv_ibre <- test_dataset(
  "FGV IBRE Real Estate Indicators",
  function() get_dataset("fgv_ibre"),
  function(data) {
    recent <- data %>% filter(date >= as.Date("2020-01-01"))

    if (nrow(recent) > 0) {
      p <- ggplot(recent, aes(x = date, y = value, color = series)) +
        geom_line() +
        labs(
          title = "FGV IBRE - Real Estate Indicators (2020+)",
          x = "Date",
          y = "Value"
        ) +
        theme_minimal()
      print(p)
      cat("✓ FGV IBRE visualization created\n")
    }
  }
)

# =============================================================================
# 7. ITBI Summary Statistics - SKIPPED (Hidden Dataset)
# =============================================================================
# Note: ITBI dataset is marked as "hidden" - under development for future release
# Skipping test for this dataset

# =============================================================================
# 8. NRE-IRE Real Estate Index
# =============================================================================
results$nre_ire <- test_dataset(
  "NRE-IRE Real Estate Index",
  function() get_dataset("nre_ire"),
  function(data) {
    recent <- data %>% filter(date >= as.Date("2020-01-01"))

    if (nrow(recent) > 0) {
      p <- ggplot(recent, aes(x = date, y = ire)) +
        geom_line(color = "steelblue") +
        labs(
          title = "NRE-IRE - Real Estate Index (2020+)",
          x = "Date",
          y = "IRE Index"
        ) +
        theme_minimal()
      print(p)
      cat("✓ NRE-IRE visualization created\n")
    }
  }
)

# =============================================================================
# 9. Property Records (ITBI Transactions)
# =============================================================================
results$property_records <- test_dataset(
  "Property Records",
  function() {
    # Try to get a smaller subset
    get_dataset("property_records", table = "capitals")
  },
  function(data) {
    # Property records returns a list with "records" and "transfers"
    if (is.list(data) && !is.null(data$records)) {
      records <- data$records %>% filter(year >= 2020)

      if (nrow(records) > 0) {
        p <- ggplot(
          records,
          aes(x = date, y = record_total, color = name_muni)
        ) +
          geom_line() +
          labs(
            title = "Property Records - Total Records by Capital (2020+)",
            x = "Date",
            y = "Total Records"
          ) +
          theme_minimal()
        print(p)
        cat("✓ Property Records visualization created\n")
      }
    }
  }
)

# =============================================================================
# 10. RPPI - Brazilian Residential Property Price Indices
# =============================================================================
results$rppi <- test_dataset(
  "Brazilian RPPI",
  function() get_dataset("rppi", table = "fipezap"),
  function(data) {
    recent <- data %>%
      filter(
        date >= as.Date("2020-01-01"),
        variable == "index",
        rooms == "total"
      )

    if (nrow(recent) > 0) {
      p <- ggplot(recent, aes(x = date, y = value, color = name_muni)) +
        geom_line() +
        labs(
          title = "RPPI - FipeZap Price Index (2020+)",
          x = "Date",
          y = "Index Value"
        ) +
        theme_minimal() +
        theme(legend.position = "bottom")
      print(p)
      cat("✓ RPPI visualization created\n")
    }
  }
)

# =============================================================================
# 11. RPPI BIS - International Property Price Indices
# =============================================================================
results$rppi_bis <- test_dataset(
  "BIS RPPI",
  function() get_dataset("rppi_bis", table = "selected"),
  function(data) {
    # Filter for Brazil and a few other countries
    countries <- c("Brazil", "United States", "United Kingdom", "Germany")
    recent <- data %>%
      filter(
        reference_area %in% countries,
        date >= as.Date("2020-01-01"),
        is_nominal == TRUE,
        unit == "Index, 2010 = 100"
      )

    if (nrow(recent) > 0) {
      p <- ggplot(recent, aes(x = date, y = value, color = reference_area)) +
        geom_line() +
        labs(
          title = "BIS RPPI - Selected Countries (2020+)",
          x = "Date",
          y = "Index Value (2010 = 100)"
        ) +
        theme_minimal()
      print(p)
      cat("✓ BIS RPPI visualization created\n")
    }
  }
)

# =============================================================================
# 12. SECOVI-SP Real Estate Market Data
# =============================================================================
results$secovi <- test_dataset(
  "SECOVI-SP Real Estate Data",
  function() get_dataset("secovi"),
  function(data) {
    recent <- data %>% filter(date >= as.Date("2020-01-01"))

    if (nrow(recent) > 0) {
      # Get a subset of variables for plotting
      plot_data <- recent %>%
        group_by(variable) %>%
        filter(n() >= 10) %>%
        ungroup() %>%
        filter(variable %in% head(unique(variable), 5))

      p <- ggplot(plot_data, aes(x = date, y = value, color = variable)) +
        geom_line() +
        facet_wrap(~category, scales = "free_y") +
        labs(
          title = "SECOVI-SP - Market Data (2020+)",
          x = "Date",
          y = "Value"
        ) +
        theme_minimal()
      print(p)
      cat("✓ SECOVI visualization created\n")
    }
  }
)

# =============================================================================
# SUMMARY
# =============================================================================
cat("\n", strrep("=", 70), "\n")
cat("SANITY CHECK SUMMARY\n")
cat(strrep("=", 70), "\n")

success_count <- sum(unlist(results))
total_count <- length(results)
expected_count <- 11 # Excluding hidden ITBI dataset

cat(sprintf("Datasets tested: %d (excluding 1 hidden dataset)\n", total_count))
cat(sprintf("Successful: %d\n", success_count))
cat(sprintf("Failed: %d\n", total_count - success_count))

if (success_count == total_count && total_count == expected_count) {
  cat("\n✓ ALL DATASETS PASSED!\n")
} else if (success_count == total_count) {
  cat("\n✓ All tested datasets passed!\n")
  cat("  Note: ITBI Summary dataset is hidden (under development)\n")
} else {
  cat("\n✗ Some datasets failed. Review errors above.\n")
  cat("\nFailed datasets:\n")
  failed <- names(results)[!unlist(results)]
  for (f in failed) {
    cat("  -", f, "\n")
  }
}

cat(strrep("=", 70), "\n")
