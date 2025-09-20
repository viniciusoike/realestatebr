# data-raw/generate_report.R
# Generate pipeline status and validation reports

library(targets)
library(dplyr)
library(readr)
library(cli)

# Source validation functions
source("data-raw/validation.R")
source("data-raw/targets_helpers.R")

#' Generate Comprehensive Pipeline Report
#'
#' Create status report combining targets metadata, cache status, and validation results
#'
generate_pipeline_report <- function() {
  cli::cli_inform("Generating pipeline status report...")

  # Ensure reports directory exists
  reports_dir <- file.path("inst", "reports")
  if (!dir.exists(reports_dir)) {
    dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # ---- COLLECT PIPELINE METADATA ----

  # Get targets metadata (if available)
  targets_meta <- NULL
  if (file.exists("_targets")) {
    tryCatch({
      targets_meta <- tar_meta()
    }, error = function(e) {
      cli::cli_warn("Could not load targets metadata: {e$message}")
    })
  }

  # Get cache summary
  cache_summary <- get_cache_summary()

  # Validate cache integrity
  cache_valid <- validate_cache_integrity()

  # ---- GENERATE REPORT ----

  report_timestamp <- Sys.time()
  report_lines <- c(
    "# realestatebr Pipeline Status Report",
    paste0("**Generated:** ", format(report_timestamp, "%Y-%m-%d %H:%M:%S %Z")),
    "",
    "## Executive Summary",
    ""
  )

  # Overall status
  if (!is.null(targets_meta) && nrow(targets_meta) > 0) {
    successful_targets <- sum(is.na(targets_meta$error))
    total_targets <- nrow(targets_meta)
    success_rate <- round(successful_targets / total_targets * 100, 1)

    report_lines <- c(report_lines,
      paste0("- **Pipeline Status:** ", if(success_rate >= 90) "🟢 Healthy" else if(success_rate >= 70) "🟡 Warning" else "🔴 Critical"),
      paste0("- **Success Rate:** ", success_rate, "% (", successful_targets, "/", total_targets, " targets)"),
      paste0("- **Last Run:** ", if(nrow(targets_meta) > 0) format(max(targets_meta$time, na.rm = TRUE), "%Y-%m-%d %H:%M") else "Unknown"),
      ""
    )
  } else {
    report_lines <- c(report_lines,
      "- **Pipeline Status:** 🟡 No targets metadata available",
      "- **Note:** Run `tar_make()` to initialize pipeline",
      ""
    )
  }

  # Cache status
  if (nrow(cache_summary) > 0) {
    total_cache_size <- sum(cache_summary$size_mb, na.rm = TRUE)
    oldest_cache <- max(cache_summary$age_hours, na.rm = TRUE)

    report_lines <- c(report_lines,
      paste0("- **Cached Datasets:** ", nrow(cache_summary)),
      paste0("- **Total Cache Size:** ", round(total_cache_size, 1), " MB"),
      paste0("- **Cache Status:** ", if(cache_valid) "🟢 Valid" else "🔴 Issues Detected"),
      paste0("- **Oldest Cache:** ", round(oldest_cache, 1), " hours ago"),
      ""
    )
  }

  # ---- DETAILED SECTIONS ----

  # Targets details
  if (!is.null(targets_meta) && nrow(targets_meta) > 0) {
    report_lines <- c(report_lines,
      "## Targets Status",
      ""
    )

    # Sort by most recent first
    targets_meta <- targets_meta[order(targets_meta$time, decreasing = TRUE, na.last = TRUE), ]

    for (i in 1:nrow(targets_meta)) {
      target <- targets_meta[i, ]
      status_icon <- if (is.na(target$error)) "✅" else "❌"

      # Format execution time
      exec_time <- if (!is.na(target$seconds)) {
        if (target$seconds < 60) {
          paste0(round(target$seconds, 1), "s")
        } else {
          paste0(round(target$seconds / 60, 1), "m")
        }
      } else {
        "Unknown"
      }

      # Format size
      size_str <- if (!is.na(target$bytes)) {
        if (target$bytes < 1024^2) {
          paste0(round(target$bytes / 1024, 1), " KB")
        } else {
          paste0(round(target$bytes / (1024^2), 1), " MB")
        }
      } else {
        "Unknown"
      }

      report_lines <- c(report_lines,
        paste0("### ", target$name, " ", status_icon),
        paste0("- **Last run:** ", if(!is.na(target$time)) format(target$time, "%Y-%m-%d %H:%M") else "Never"),
        paste0("- **Duration:** ", exec_time),
        paste0("- **Size:** ", size_str),
        ""
      )

      # Show error if failed
      if (!is.na(target$error)) {
        report_lines <- c(report_lines,
          paste0("- **Error:** `", target$error, "`"),
          ""
        )
      }
    }
  }

  # Cache details
  if (nrow(cache_summary) > 0) {
    report_lines <- c(report_lines,
      "## Cache Status",
      "",
      "| Dataset | Last Updated | Age (hours) | Size (MB) | Format |",
      "|---------|--------------|-------------|-----------|--------|"
    )

    for (i in 1:nrow(cache_summary)) {
      cache_row <- cache_summary[i, ]
      report_lines <- c(report_lines,
        paste0("| ", cache_row$dataset, " | ",
               format(cache_row$last_updated, "%m-%d %H:%M"), " | ",
               round(cache_row$age_hours, 1), " | ",
               cache_row$size_mb, " | ",
               cache_row$format, " |")
      )
    }

    report_lines <- c(report_lines, "")
  }

  # System information
  report_lines <- c(report_lines,
    "## System Information",
    "",
    paste0("- **R Version:** ", R.version.string),
    paste0("- **Platform:** ", R.version$platform),
    paste0("- **Package Version:** ", packageVersion("realestatebr")),
    paste0("- **Report Generated:** ", format(report_timestamp, "%Y-%m-%d %H:%M:%S %Z")),
    ""
  )

  # Performance summary
  if (!is.null(targets_meta) && nrow(targets_meta) > 0) {
    valid_times <- targets_meta$seconds[!is.na(targets_meta$seconds)]
    if (length(valid_times) > 0) {
      total_time <- sum(valid_times)
      avg_time <- mean(valid_times)

      report_lines <- c(report_lines,
        "## Performance Summary",
        "",
        paste0("- **Total Execution Time:** ", round(total_time / 60, 1), " minutes"),
        paste0("- **Average Target Time:** ", round(avg_time, 1), " seconds"),
        paste0("- **Fastest Target:** ", round(min(valid_times), 1), " seconds"),
        paste0("- **Slowest Target:** ", round(max(valid_times), 1), " seconds"),
        ""
      )
    }
  }

  # ---- SAVE REPORTS ----

  # Save main report
  main_report_path <- file.path(reports_dir, "pipeline_status.md")
  writeLines(report_lines, main_report_path)

  # Save metadata as CSV for tracking
  if (!is.null(targets_meta)) {
    csv_path <- file.path(reports_dir, paste0("targets_meta_", format(Sys.Date(), "%Y%m%d"), ".csv"))
    write_csv(targets_meta, csv_path)
  }

  # Save cache summary
  if (nrow(cache_summary) > 0) {
    cache_csv_path <- file.path(reports_dir, paste0("cache_summary_", format(Sys.Date(), "%Y%m%d"), ".csv"))
    write_csv(cache_summary, cache_csv_path)
  }

  cli::cli_alert_success("Pipeline report generated: {main_report_path}")

  return(list(
    report_path = main_report_path,
    targets_rows = if(is.null(targets_meta)) 0 else nrow(targets_meta),
    cache_datasets = nrow(cache_summary),
    success_rate = if(is.null(targets_meta) || nrow(targets_meta) == 0) NA else round(sum(is.na(targets_meta$error)) / nrow(targets_meta) * 100, 1)
  ))
}

#' Generate Quick Status Summary
#'
#' Create a brief status summary for quick checks
#'
generate_quick_status <- function() {
  cache_summary <- get_cache_summary()

  # Get most recent updates
  if (nrow(cache_summary) > 0) {
    most_recent <- cache_summary[which.min(cache_summary$age_hours), ]
    oldest <- cache_summary[which.max(cache_summary$age_hours), ]

    cli::cli_alert_info("Quick Status:")
    cli::cli_inform("- {nrow(cache_summary)} datasets cached")
    cli::cli_inform("- Most recent: {most_recent$dataset} ({round(most_recent$age_hours, 1)}h ago)")
    cli::cli_inform("- Oldest: {oldest$dataset} ({round(oldest$age_hours, 1)}h ago)")
    cli::cli_inform("- Total size: {round(sum(cache_summary$size_mb), 1)} MB")
  } else {
    cli::cli_alert_warning("No cached datasets found")
  }
}

# Run report generation if script is called directly
if (!interactive()) {
  generate_pipeline_report()
}